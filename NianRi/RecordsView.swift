import SwiftUI

enum RecordsTab: String, CaseIterable, Identifiable {
    case diary = "日记"
    case checkin = "打卡"
    case ledger = "记账"
    case period = "生理期"
    case wish = "愿望"

    var id: String { rawValue }
}

struct RecordsView: View {
    @EnvironmentObject private var store: NianRiStore
    @Binding var initialTab: RecordsTab
    @State private var tab: RecordsTab

    init(initialTab: Binding<RecordsTab>) {
        _initialTab = initialTab
        _tab = State(initialValue: initialTab.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("记录")
                    .font(.system(size: 31, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("只保存在本机")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(RecordsTab.allCases) { item in
                        Button {
                            tab = item
                            initialTab = item
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 12, weight: tab == item ? .medium : .regular))
                                .foregroundStyle(tab == item ? Theme.cinnabar : Theme.muted)
                                .padding(.horizontal, 15)
                                .frame(height: 34)
                                .background(tab == item ? Theme.cinnabarSoft : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            ScrollView {
                Group {
                    switch tab {
                    case .diary: DiaryView()
                    case .checkin: CheckInView()
                    case .ledger: LedgerView()
                    case .period: PeriodView()
                    case .wish: WishlistView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .nianriScreen()
        .onChange(of: initialTab) { _, value in
            tab = value
        }
    }
}

struct CheckInView: View {
    @EnvironmentObject private var store: NianRiStore
    @State private var showEditor = false
    @State private var editingPlan: CheckInPlan?
    @State private var newPlanCategory: CheckInCategory = .daily

    private var today: Int { AppDate.today }
    private var plans: [CheckInPlan] {
        store.data.workbench.plans.sorted { $0.createdDay < $1.createdDay }
    }
    private var checked: Int { plans.filter { $0.checkedDays.contains(today) }.count }
    private var weekDays: [Int] { (0..<7).map { today - 6 + $0 } }
    private var weekDone: Int {
        plans.reduce(0) { result, plan in
            result + weekDays.filter { plan.checkedDays.contains($0) }.count
        }
    }
    private var weekTotal: Int { max(1, plans.count * 7) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Card {
                Text("今日打卡")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(checked)")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.cinnabar)
                    Text("/ \(plans.count) 个小约定")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 3)
                Text("每天完成一件小事，日子会慢慢长出秩序。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 4)
                HStack {
                    Text("近 7 天")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\(weekDone) / \(weekTotal) 次")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.cinnabar)
                }
                .padding(.top, 9)
                ProgressView(value: Double(weekDone), total: Double(weekTotal))
                    .tint(Theme.cinnabar)
                    .padding(.top, 3)
                HStack(spacing: 5) {
                    ForEach(CheckInCategory.allCases) { category in
                        Button("＋ \(category.label)") {
                            newPlanCategory = category
                            editingPlan = nil
                            showEditor = true
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
                .padding(.top, 10)
            }

            ForEach(CheckInCategory.allCases) { category in
                let group = plans.filter { $0.category == category }
                if !group.isEmpty {
                    SectionHeading(title: "\(category.label) · \(group.count)")
                        .padding(.top, 22)
                        .padding(.bottom, 9)
                    VStack(spacing: 8) {
                        ForEach(group) { plan in
                            planRow(plan)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            CheckInEditorView(plan: editingPlan, initialCategory: newPlanCategory)
                .environmentObject(store)
        }
    }

    private func planRow(_ plan: CheckInPlan) -> some View {
        let checkedToday = plan.checkedDays.contains(today)
        return HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    store.updateWorkbench(refreshWidget: false) { data in
                        guard let index = data.plans.firstIndex(where: { $0.id == plan.id }) else { return }
                        if data.plans[index].checkedDays.contains(today) {
                            data.plans[index].checkedDays.removeAll { $0 == today }
                        } else {
                            data.plans[index].checkedDays.append(today)
                        }
                    }
                }
            } label: {
                CircleCheck(checked: checkedToday, color: color(for: plan.category), size: 27)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checkedToday ? "取消打卡 \(plan.title)" : "打卡 \(plan.title)")

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 5) {
                    let streak = plan.streak(today: today)
                    Text(streak > 0 ? "连续 \(streak) 天" : "累计 \(plan.checkedDays.count) 天")
                        .font(.system(size: 9))
                        .foregroundStyle(streak > 0 ? color(for: plan.category) : Theme.faint)
                    HStack(spacing: 3) {
                        ForEach(weekDays, id: \.self) { day in
                            Circle()
                                .fill(plan.checkedDays.contains(day) ? color(for: plan.category) : Theme.line)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            Spacer()
            Menu {
                Button("编辑名称") {
                    editingPlan = plan
                    newPlanCategory = plan.category
                    showEditor = true
                }
                Button("删除打卡", role: .destructive) {
                    store.updateWorkbench(refreshWidget: false) { data in
                        data.plans.removeAll { $0.id == plan.id }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.faint)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(13)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.7))
    }

    private func color(for category: CheckInCategory) -> Color {
        switch category {
        case .daily: return Theme.sage
        case .love: return Theme.rose
        case .fan: return Color(hex: 0x7C6E9E)
        }
    }
}

struct CheckInEditorView: View {
    @EnvironmentObject private var store: NianRiStore
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var category: CheckInCategory
    private let plan: CheckInPlan?

    init(plan: CheckInPlan?, initialCategory: CheckInCategory) {
        self.plan = plan
        _title = State(initialValue: plan?.title ?? "")
        _category = State(initialValue: plan?.category ?? initialCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("小约定") {
                    TextField("例如：喝够八杯水", text: $title)
                }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        ForEach(CheckInCategory.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(plan == nil ? "添加打卡" : "编辑打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        if let plan, let index = store.data.workbench.plans.firstIndex(where: { $0.id == plan.id }) {
                            store.updateWorkbench(refreshWidget: false) { data in
                                data.plans[index].title = clean
                                data.plans[index].category = category
                            }
                        } else {
                            let newPlan = CheckInPlan(
                                title: clean,
                                category: category,
                                createdDay: AppDate.today,
                                checkedDays: []
                            )
                            store.updateWorkbench(refreshWidget: false) { data in
                                data.plans.append(newPlan)
                            }
                        }
                        dismiss()
                    }
                    .foregroundStyle(Theme.cinnabar)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
