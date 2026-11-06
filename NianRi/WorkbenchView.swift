import SwiftUI

struct WorkbenchView: View {
    @EnvironmentObject private var store: NianRiStore
    var openRecords: (RecordsTab) -> Void

    @StateObject private var weather = WeatherStore()
    @State private var showCityEditor = false

    private var today: Int { AppDate.today }

    private var plans: [CheckInPlan] {
        store.data.workbench.plans.sorted { $0.createdDay < $1.createdDay }
    }

    private var checkedCount: Int {
        plans.filter { $0.checkedDays.contains(today) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                weatherCard
                    .padding(.top, 16)
                moodCard
                    .padding(.top, 12)
                SectionHeading(title: "今天", detail: nil)
                    .padding(.top, 22)
                    .padding(.bottom, 10)
                checkInCard
                diaryCard
                    .padding(.top, 10)
                SectionHeading(title: "记录", detail: nil)
                    .padding(.top, 24)
                    .padding(.bottom, 10)
                recordsCard
                Text("所有记录只保存在这台 iPhone 上。")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 20)
        }
        .nianriScreen()
        .task {
            if weather.snapshot == nil {
                await weather.configure(city: store.data.weatherCity)
            } else if weather.isStale {
                await weather.refresh()
            }
        }
        .sheet(isPresented: $showCityEditor) {
            CityEditorView(city: store.data.weatherCity) { city in
                store.update { data in data.weatherCity = city }
                Task { await weather.configure(city: city) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                Text("工作台")
                    .font(.system(size: 31, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("只属于今天")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
            }
            Text(AppDate.todayText("yyyy年M月d日 EEEE"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
            Text(DailyCopy.today())
                .font(.system(size: 21, design: .serif))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
                .lineSpacing(3)
        }
        .padding(.top, 12)
    }

    private var weatherCard: some View {
        Card {
            if let snapshot = weather.snapshot {
                HStack(alignment: .top, spacing: 14) {
                    Text(weatherSymbol(snapshot.code))
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(Theme.cinnabar)
                        .frame(width: 54, height: 54)
                        .background(Theme.cinnabarSoft)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(snapshot.city)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text("\(Int(snapshot.temperature.rounded()))°")
                                .font(.system(size: 27, weight: .light, design: .serif))
                                .foregroundStyle(Theme.ink)
                        }
                        Text("\(snapshot.summary) · \(Int(snapshot.min.rounded()))°–\(Int(snapshot.max.rounded()))°")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                        Text(snapshot.tip)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.cinnabar)
                            .padding(.top, 2)
                    }
                    Spacer()
                    Button("换城市") {
                        showCityEditor = true
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.cinnabar)
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Theme.cinnabar)
                        .frame(width: 54, height: 54)
                        .background(Theme.cinnabarSoft)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.loading ? "正在看看窗外…" : "天气还没设置")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.ink)
                        Text(weather.error ?? "手动填一个城市，不需要定位权限。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("设置") {
                        showCityEditor = true
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        }
    }

    private var moodCard: some View {
        Card {
            HStack {
                Text("今天心情")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if let mood = MoodCatalog.option(store.data.workbench.mood(on: today)) {
                    Text(mood.label)
                        .font(.system(size: 10))
                        .foregroundStyle(mood.color)
                }
            }
            HStack(spacing: 4) {
                ForEach(MoodCatalog.all) { mood in
                    let selected = store.data.workbench.mood(on: today) == mood.key
                    Button {
                        store.updateWorkbench { data in
                            if selected {
                                data.moods.removeValue(forKey: String(today))
                            } else {
                                data.moods[String(today)] = mood.key
                            }
                        }
                    } label: {
                        Text(mood.label)
                            .font(.system(size: 10, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? mood.color : Theme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(selected ? mood.color.opacity(0.14) : Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected ? Color.clear : Theme.line, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 9)
        }
    }

    private var checkInCard: some View {
        Card {
            HStack {
                Text("今日打卡")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(checkedCount) / \(max(1, plans.count))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.cinnabar)
                Button("查看全部") {
                    openRecords(.checkin)
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.cinnabar)
            }
            .padding(.bottom, 3)

            if plans.isEmpty {
                Text("先定一个小约定，完成它，就算赢了一点点。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 7)
            } else {
                ForEach(Array(plans.prefix(3).enumerated()), id: \.element.id) { index, plan in
                    HStack(spacing: 10) {
                        Button {
                            toggle(plan)
                        } label: {
                            CircleCheck(checked: plan.checkedDays.contains(today), color: categoryColor(plan.category), size: 24)
                        }
                        .buttonStyle(.plain)
                        Text(plan.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(plan.category.label)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(categoryColor(plan.category))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(categoryColor(plan.category).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 8)
                    if index < min(2, plans.count - 1) {
                        Divider().overlay(Theme.line)
                    }
                }
            }
        }
    }

    private var diaryCard: some View {
        Card {
            HStack {
                Text("今天的一页")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("继续写") {
                    openRecords(.diary)
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.cinnabar)
            }
            if let entry = store.data.workbench.diary(on: today) {
                Text(entry.text)
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
                    .padding(.top, 7)
                if let mood = MoodCatalog.option(entry.moodKey) {
                    Text(mood.label)
                        .font(.system(size: 9))
                        .foregroundStyle(mood.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(mood.color.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 7)
                }
            } else {
                Text("不必写得完整。一句话，也算把今天留住。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 7)
            }
        }
    }

    private var recordsCard: some View {
        VStack(spacing: 0) {
            recordRow(icon: "yensign", title: "记账", detail: ledgerDetail) {
                openRecords(.ledger)
            }
            Divider().overlay(Theme.line).padding(.leading, 54)
            recordRow(icon: "drop", title: "生理期", detail: periodDetail) {
                openRecords(.period)
            }
            Divider().overlay(Theme.line).padding(.leading, 54)
            recordRow(icon: "sparkles", title: "愿望清单", detail: wishDetail) {
                openRecords(.wish)
            }
        }
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 0.8))
    }

    private func recordRow(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.cinnabar)
                    .frame(width: 34, height: 34)
                    .background(Theme.cinnabarSoft)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var ledgerDetail: String {
        let month = AppDate.startOfMonth(Date())
        let entries = store.data.workbench.ledger.filter {
            AppDate.sameMonth(AppDate.date(epochDay: $0.epochDay), month)
        }
        let expense = entries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
        return "本月支出 \(money(expense))"
    }

    private var periodDetail: String {
        guard let latest = store.data.workbench.latestPeriod else {
            return "还没有周期记录"
        }
        let next = latest.startDay + store.data.workbench.cycleLength
        let days = next - today
        if latest.endDay == nil { return "经期第 \(max(1, today - latest.startDay + 1)) 天" }
        if days > 0 { return "预计 \(days) 天后 · \(AppDate.dayText(next))" }
        if days == 0 { return "预计就是今天" }
        return "预计时间已到"
    }

    private var wishDetail: String {
        let wishes = store.data.workbench.wishes
        let done = wishes.filter { $0.done }.count
        if wishes.isEmpty { return "写下第一个愿望" }
        return "\(wishes.count) 个愿望 · \(done) 个实现"
    }

    private func toggle(_ plan: CheckInPlan) {
        store.updateWorkbench { data in
            guard let index = data.plans.firstIndex(where: { $0.id == plan.id }) else { return }
            if data.plans[index].checkedDays.contains(today) {
                data.plans[index].checkedDays.removeAll { $0 == today }
            } else {
                data.plans[index].checkedDays.append(today)
            }
        }
    }

    private func categoryColor(_ category: CheckInCategory) -> Color {
        switch category {
        case .daily: return Theme.sage
        case .love: return Theme.rose
        case .fan: return Color(hex: 0x7C6E9E)
        }
    }

    private func weatherSymbol(_ code: Int) -> String {
        switch code {
        case 0, 1: return "☀︎"
        case 2, 3, 45, 48: return "☁︎"
        case 51...67, 80...82: return "☂︎"
        case 71...77, 85, 86: return "❄︎"
        case 95...99: return "⚡︎"
        default: return "◌"
        }
    }
}

struct CityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var city: String
    var onSave: (String) -> Void

    init(city: String, onSave: @escaping (String) -> Void) {
        _city = State(initialValue: city)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("城市") {
                    TextField("例如：上海", text: $city)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("天气使用 Open-Meteo 公开数据，只根据你填写的城市查询，不申请定位权限。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("设置天气城市")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let clean = city.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        onSave(clean)
                        dismiss()
                    }
                    .foregroundStyle(Theme.cinnabar)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
