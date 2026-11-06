import SwiftUI
import Charts

struct LedgerView: View {
    @EnvironmentObject private var store: NianRiStore

    @State private var mode = 0
    @State private var month = AppDate.startOfMonth(Date())
    @State private var showEditor = false
    @State private var editingEntry: LedgerEntry?
    @State private var editorDate = Date()

    private var allEntries: [LedgerEntry] {
        store.data.workbench.ledger.sorted { $0.epochDay > $1.epochDay }
    }

    private var monthEntries: [LedgerEntry] {
        allEntries.filter { AppDate.sameMonth(AppDate.date(epochDay: $0.epochDay), month) }
    }

    private var year: Int {
        AppDate.calendar.component(.year, from: month)
    }

    private var yearEntries: [LedgerEntry] {
        allEntries.filter { AppDate.calendar.component(.year, from: AppDate.date(epochDay: $0.epochDay)) == year }
    }

    private var entries: [LedgerEntry] { mode == 0 ? monthEntries : yearEntries }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Picker("账单范围", selection: $mode) {
                    Text("月账单").tag(0)
                    Text("年账单").tag(1)
                }
                .pickerStyle(.segmented)
                Button("＋ 记一笔") {
                    editingEntry = nil
                    editorDate = mode == 0 ? month : Date()
                    showEditor = true
                }
                .buttonStyle(SoftButtonStyle())
            }

            HStack(spacing: 4) {
                Button {
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Theme.cream)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text(mode == 0 ? AppDate.monthLabel(month) : "\(year) 年")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Theme.cream)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                if !isCurrent {
                    Button(mode == 0 ? "本月" : "今年") {
                        month = AppDate.startOfMonth(Date())
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.cinnabar)
                }
            }
            .padding(.top, 10)

            summary
                .padding(.top, 10)

            if entries.isEmpty {
                Card {
                    Text("这里还没有记账。")
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("记下第一笔，月底就能看见钱都去了哪里。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 5)
                    Button("记下第一笔") {
                        editingEntry = nil
                        editorDate = mode == 0 ? month : Date()
                        showEditor = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 10)
                }
                .padding(.top, 12)
            } else {
                if mode == 1 {
                    yearChart
                        .padding(.top, 18)
                }
                if !categoryTotals.isEmpty {
                    SectionHeading(title: mode == 0 ? "支出分类" : "全年支出分类")
                        .padding(.top, 22)
                        .padding(.bottom, 9)
                    categoryCard
                }
                if mode == 0 {
                    flowSection
                } else {
                    monthsSection
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            LedgerEditorView(entry: editingEntry, initialDate: editorDate)
                .environmentObject(store)
        }
    }

    private var summary: some View {
        let expense = entries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
        let income = entries.filter { $0.income }.reduce(0) { $0 + $1.amountCents }
        return Card {
            HStack {
                Text(mode == 0 ? "\(AppDate.calendar.component(.month, from: month)) 月支出" : "\(year) 年支出")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(entries.count) 笔")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.faint)
            }
            Text(money(expense))
                .font(.system(size: 31, weight: .regular, design: .serif))
                .foregroundStyle(Theme.ink)
                .padding(.top, 3)
            HStack(spacing: 0) {
                Text("收入 \(money(income))")
                    .foregroundStyle(Theme.sage)
                Text("  ·  结余 \(money(income - expense))")
                    .foregroundStyle(Theme.muted)
            }
            .font(.system(size: 10.5))
            .padding(.top, 4)
        }
    }

    private var categoryTotals: [CategoryTotal] {
        let expenseEntries = entries.filter { !$0.income }
        let grouped = Dictionary(grouping: expenseEntries, by: \.category)
        return grouped.map { category, list in
            CategoryTotal(
                category: LedgerCatalog.option(category, income: false),
                amount: list.reduce(0) { $0 + $1.amountCents }
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var categoryCard: some View {
        let total = max(1, categoryTotals.reduce(0) { $0 + $1.amount })
        return Card(padding: 0) {
            ForEach(Array(categoryTotals.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Circle().fill(item.category.color).frame(width: 8, height: 8)
                        Text(item.category.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(money(item.amount))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    ProgressView(value: Double(item.amount), total: Double(total))
                        .tint(item.category.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                if index < categoryTotals.count - 1 {
                    Divider().overlay(Theme.line).padding(.leading, 16)
                }
            }
        }
    }

    private var flowSection: some View {
        let grouped = Dictionary(grouping: monthEntries, by: \.epochDay)
        let days = grouped.keys.sorted(by: >)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "流水 · \(monthEntries.count) 笔")
                .padding(.top, 22)
                .padding(.bottom, 9)
            Card(padding: 0) {
                ForEach(Array(days.enumerated()), id: \.element) { dayIndex, day in
                    let dayEntries = grouped[day] ?? []
                    let dayExpense = dayEntries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
                    HStack {
                        Text(AppDate.dayText(day, format: "M月d日 · EEEE"))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        if dayExpense > 0 {
                            Text("支出 \(money(dayExpense))")
                                .font(.system(size: 8.5))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    ForEach(dayEntries) { entry in
                        ledgerRow(entry)
                    }
                    if dayIndex < days.count - 1 {
                        Divider().overlay(Theme.line).padding(.horizontal, 14)
                    }
                }
            }
        }
    }

    private var yearChart: some View {
        let bars = (1...12).map { monthNumber in
            let list = yearEntries.filter {
                AppDate.calendar.component(.month, from: AppDate.date(epochDay: $0.epochDay)) == monthNumber
            }
            return MonthBar(month: monthNumber, amount: list.filter { !$0.income }.reduce(0) { $0 + $1.amountCents })
        }
        return Card {
            HStack {
                Text("每月支出")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("月均 \(money(yearEntries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents } / 12))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.faint)
            }
            Chart(bars) { bar in
                BarMark(
                    x: .value("月份", bar.month),
                    y: .value("支出", Double(bar.amount) / 100)
                )
                .foregroundStyle(Theme.cinnabar)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 12)) { value in
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text("\(month)")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
            .padding(.top, 6)
        }
    }

    private var monthsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "月度明细")
                .padding(.top, 22)
                .padding(.bottom, 9)
            Card(padding: 0) {
                ForEach(1...12, id: \.self) { monthNumber in
                    let list = yearEntries.filter {
                        AppDate.calendar.component(.month, from: AppDate.date(epochDay: $0.epochDay)) == monthNumber
                    }
                    let expense = list.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
                    Button {
                        month = AppDate.calendar.date(
                            from: DateComponents(year: year, month: monthNumber, day: 1)
                        ) ?? month
                        mode = 0
                    } label: {
                        HStack {
                            Text("\(monthNumber) 月")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                            Spacer()
                            Text(list.isEmpty ? "没有记录" : "支出 \(money(expense))")
                                .font(.system(size: 10.5))
                                .foregroundStyle(list.isEmpty ? Theme.faint : Theme.muted)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    if monthNumber < 12 {
                        Divider().overlay(Theme.line).padding(.leading, 14)
                    }
                }
            }
        }
    }

    private func ledgerRow(_ entry: LedgerEntry) -> some View {
        let option = LedgerCatalog.option(entry.category, income: entry.income)
        return Button {
            editingEntry = entry
            editorDate = AppDate.date(epochDay: entry.epochDay)
            showEditor = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(option.color.opacity(0.14))
                    Text(String(entry.category.prefix(1)))
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(option.color)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.category)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.faint)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text((entry.income ? "+" : "-") + money(entry.amountCents))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(entry.income ? Theme.sage : Theme.cinnabar)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑") {
                editingEntry = entry
                editorDate = AppDate.date(epochDay: entry.epochDay)
                showEditor = true
            }
            Button("删除", role: .destructive) {
                store.updateWorkbench { data in data.ledger.removeAll { $0.id == entry.id } }
            }
        }
    }

    private func step(_ value: Int) {
        if mode == 0 {
            month = AppDate.calendar.date(byAdding: .month, value: value, to: month) ?? month
        } else {
            month = AppDate.calendar.date(byAdding: .year, value: value, to: month) ?? month
        }
    }

    private var isCurrent: Bool {
        if mode == 0 {
            return AppDate.sameMonth(month, Date())
        }
        return year == AppDate.calendar.component(.year, from: Date())
    }
}

private struct CategoryTotal: Identifiable {
    let category: LedgerCategoryInfo
    let amount: Int

    var id: String { category.name }
}

private struct MonthBar: Identifiable {
    let month: Int
    let amount: Int
    var id: Int { month }
}

struct LedgerEditorView: View {
    @EnvironmentObject private var store: NianRiStore
    @Environment(\.dismiss) private var dismiss

    @State private var income: Bool
    @State private var amount: String
    @State private var category: String
    @State private var date: Date
    @State private var note: String
    @State private var showInvalid = false
    private let existing: LedgerEntry?

    init(entry: LedgerEntry?, initialDate: Date) {
        existing = entry
        _income = State(initialValue: entry?.income ?? false)
        _amount = State(initialValue: entry.map { plainMoney($0.amountCents) } ?? "")
        _category = State(initialValue: entry?.category ?? "餐饮")
        _date = State(initialValue: entry.map { AppDate.date(epochDay: $0.epochDay) } ?? initialDate)
        _note = State(initialValue: entry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $income) {
                        Text("支出").tag(false)
                        Text("收入").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField("金额（元）", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 24, design: .serif))
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                Section("分类") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(LedgerCatalog.categories(income: income)) { item in
                            Button {
                                category = item.name
                            } label: {
                                Text(item.name)
                                    .font(.system(size: 11, weight: category == item.name ? .medium : .regular))
                                    .foregroundStyle(category == item.name ? Theme.cinnabar : Theme.muted)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 33)
                                    .background(category == item.name ? Theme.cinnabarSoft : Theme.cream)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(category == item.name ? Color.clear : Theme.line, lineWidth: 0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("备注") {
                    TextField("可选，例如：楼下的面和一杯热豆浆", text: $note)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(existing == nil ? "记一笔" : "编辑这笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundStyle(Theme.cinnabar)
                        .fontWeight(.semibold)
                }
            }
            .alert("填一个 0 到 1000 万之间的金额", isPresented: $showInvalid) {
                Button("知道了", role: .cancel) {}
            }
        }
    }

    private func save() {
        let normalized = amount.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0, value <= 10_000_000 else {
            showInvalid = true
            return
        }
        let cents = Int((value * 100).rounded())
        let entry = LedgerEntry(
            id: existing?.id ?? UUID(),
            epochDay: AppDate.epochDay(date),
            income: income,
            amountCents: cents,
            category: LedgerCatalog.normalized(category, income: income),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        store.updateWorkbench { data in
            data.ledger.removeAll { $0.id == entry.id }
            data.ledger.append(entry)
            data.ledger.sort { $0.epochDay > $1.epochDay }
        }
        dismiss()
    }
}
