import SwiftUI
import Charts

struct LedgerView: View {
    @EnvironmentObject private var store: NianRiStore

    @State private var mode = 0
    @State private var month = AppDate.startOfMonth(Date())
    @State private var showEditor = false
    @State private var editingEntry: LedgerEntry?
    @State private var editorDate = Date()
    @State private var showBudgetEditor = false
    @State private var budgetText = ""
    @State private var showDaysSheet = false
    @State private var showLoanSheet = false

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
            HStack {
                Text("记账")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    editingEntry = nil
                    editorDate = Date()
                    showEditor = true
                } label: {
                    Label("记一笔", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Button {
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 40, height: 40)
                        .background(Theme.cream)
                        .clipShape(Circle())
                        .contentShape(Circle())
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
                        .frame(width: 40, height: 40)
                        .background(Theme.cream)
                        .clipShape(Circle())
                        .contentShape(Circle())
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
                .padding(.top, 12)
            statCards
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
                        editorDate = Date()
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
                if mode == 0 {
                    flowSection
                }
                if !categoryTotals.isEmpty {
                    SectionHeading(title: mode == 0 ? "支出分类" : "全年支出分类")
                        .padding(.top, 22)
                        .padding(.bottom, 9)
                    categoryCard
                }
                if mode == 1 {
                    monthsSection
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            LedgerEditorView(entry: editingEntry, initialDate: editorDate)
                .environmentObject(store)
        }
        .sheet(isPresented: $showDaysSheet) {
            LedgerDaysSheet(month: month, entries: monthEntries)
        }
        .sheet(isPresented: $showLoanSheet) {
            LedgerLoanSheet(entries: allEntries)
        }
    }

    private var summary: some View {
        let expense = entries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
        let income = entries.filter { $0.income }.reduce(0) { $0 + $1.amountCents }
        let balance = income - expense
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(mode == 0 ? "本月支出" : "\(year) 年支出")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Picker("账单范围", selection: $mode) {
                    Text("月").tag(0)
                    Text("年").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 104)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("¥")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(plainMoney(expense))
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.top, 6)

            Text("每天记一笔，月底自动生成报表")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)

            Divider().overlay(Theme.line).padding(.vertical, 14)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("收入")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                    Text(money(income))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Theme.line).frame(width: 0.7, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text("结余")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                    Text(money(balance))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(balance < 0 ? Theme.cinnabar : Theme.sage)
                }
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Theme.line.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Theme.ink.opacity(0.06), radius: 20, x: 0, y: 8)
    }

    private var statCards: some View {
        let expense = monthEntries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
        let budget = store.data.workbench.monthlyBudgetCents
        let remaining = budget.map { max(0, $0 - expense) }
        let days = Set(monthEntries.map(\.epochDay)).count
        return HStack(spacing: 8) {
            statCard(
                title: "预算还剩",
                value: remaining.map(money) ?? "未设置",
                detail: budget == nil ? "点这里设置" : "日均 \(money(max(0, (remaining ?? 0) / 30)))"
            ) {
                budgetText = budget.map { plainMoney($0) } ?? ""
                showBudgetEditor = true
            }
            statCard(
                title: "本月有账",
                value: "\(days) 天",
                detail: "点开看每天"
            ) { showDaysSheet = true }
            statCard(
                title: "本月待还",
                value: money(loanOutstanding),
                detail: "贷款余额"
            ) { showLoanSheet = true }
        }
        .alert("设置本月预算", isPresented: $showBudgetEditor) {
            TextField("例如 10000", text: $budgetText)
                .keyboardType(.decimalPad)
            Button("保存") {
                let normalized = budgetText.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized), value >= 0 {
                    store.updateWorkbench { data in
                        data.monthlyBudgetCents = Int((value * 100).rounded())
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("预算只保存在本机，用来计算剩余额度。")
        }
    }

    private func statCard(
        title: String,
        value: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Theme.faint)
                }
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cream.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 0.8)
            )
            .shadow(color: Theme.ink.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
            HStack(alignment: .lastTextBaseline) {
                Text("本月最近账单")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("全部") { showDaysSheet = true }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
            }
            .padding(.top, 24)

            Text("显示当前日期全部账单")
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .padding(.top, 3)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element) { dayIndex, day in
                    let dayEntries = (grouped[day] ?? []).sorted {
                        ($0.minuteOfDay ?? 0) > ($1.minuteOfDay ?? 0)
                    }
                    let dayExpense = dayEntries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
                    HStack {
                        Text(dayHeading(day))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text("\(dayEntries.count) 笔")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.faint)
                        if dayExpense > 0 {
                            Text(" · 支出 \(money(dayExpense))")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 13)
                    .padding(.bottom, 3)

                    ForEach(dayEntries) { entry in
                        ledgerRow(entry)
                    }
                    if dayIndex < days.count - 1 {
                        Divider().overlay(Theme.line.opacity(0.7)).padding(.leading, 58)
                    }
                }
            }
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.line.opacity(0.6), lineWidth: 0.7)
            )
            .shadow(color: Theme.ink.opacity(0.04), radius: 14, x: 0, y: 6)
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
            HStack(alignment: .top, spacing: 11) {
                Text(timeLabel(entry.minuteOfDay))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Theme.faint)
                    .frame(width: 34, alignment: .leading)
                    .padding(.top, 7)

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(option.color.opacity(0.12))
                    Image(systemName: categorySymbol(entry.category, income: entry.income))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(option.color)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.note.isEmpty ? entry.category : entry.note)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(entry.category)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.muted)
                        Text(entry.account ?? "本机")
                            .font(.system(size: 8.5))
                            .foregroundStyle(Theme.faint)
                    }
                }
                .padding(.top, 3)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    Text((entry.income ? "+" : "-") + money(entry.amountCents))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.income ? Theme.sage : Theme.cinnabar)
                    Text(entry.income ? "收入" : "支出")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
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

    private func timeLabel(_ minute: Int?) -> String {
        guard let minute else { return "--:--" }
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func categorySymbol(_ category: String, income: Bool) -> String {
        if income { return "tray.and.arrow.down" }
        switch category {
        case "餐饮": return "fork.knife"
        case "交通": return "bus"
        case "购物": return "bag"
        case "居住": return "house"
        case "娱乐": return "gamecontroller"
        case "医疗": return "cross.case"
        case "学习": return "book"
        case "工资": return "banknote"
        case "贷款": return "building.columns"
        case "还贷": return "arrow.uturn.backward.circle"
        default: return "creditcard"
        }
    }

    private var loanOutstanding: Int {
        let loans = store.data.workbench.ledger
            .filter { $0.income && $0.category == "贷款" }
            .reduce(0) { $0 + $1.amountCents }
        let repaid = store.data.workbench.ledger
            .filter { !$0.income && $0.category == "还贷" }
            .reduce(0) { $0 + $1.amountCents }
        return max(0, loans - repaid)
    }

    private func dayHeading(_ day: Int) -> String {
        let base = AppDate.dayText(day, format: "M月d日 · EEEE")
        let relative = AppDate.relativeDayText(day)
        return relative.isEmpty ? base : "\(base) · \(relative)"
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
    @State private var account: String
    @State private var showInvalid = false
    private let existing: LedgerEntry?

    init(entry: LedgerEntry?, initialDate: Date) {
        existing = entry
        _income = State(initialValue: entry?.income ?? false)
        _amount = State(initialValue: entry.map { plainMoney($0.amountCents) } ?? "")
        _category = State(initialValue: entry?.category ?? "餐饮")
        _date = State(initialValue: entry.map { AppDate.date(epochDay: $0.epochDay) } ?? initialDate)
        _note = State(initialValue: entry?.note ?? "")
        _account = State(initialValue: entry?.account ?? "本机")
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
                    HStack(spacing: 8) {
                        ForEach([0, 1, 2], id: \.self) { offset in
                            let target = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                            Button {
                                date = target
                            } label: {
                                Text(offset == 0 ? "今天" : offset == 1 ? "昨天" : "前天")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.cinnabar)
                                    .padding(.horizontal, 11)
                                    .frame(height: 30)
                                    .background(Theme.cinnabarSoft)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
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

                Section("账户") {
                    TextField("例如：微信钱包", text: $account)
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

    private func currentMinuteOfDay() -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
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
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            minuteOfDay: existing?.minuteOfDay ?? currentMinuteOfDay(),
            account: account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "本机"
                : account.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        store.updateWorkbench { data in
            data.ledger.removeAll { $0.id == entry.id }
            data.ledger.append(entry)
            data.ledger.sort { $0.epochDay > $1.epochDay }
        }
        dismiss()
    }
}
