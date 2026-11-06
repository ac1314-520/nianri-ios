import SwiftUI

struct PeriodView: View {
    @EnvironmentObject private var store: NianRiStore

    @State private var month = AppDate.startOfMonth(Date())
    @State private var showStartSheet = false
    @State private var startDate = Date()
    @State private var showTips = false
    @State private var showCycleEditor = false
    @State private var cycleInput = "28"
    @State private var deletedRecord: PeriodRecord?
    @State private var showUndo = false

    private var today: Int { AppDate.today }
    private var workbench: WorkbenchData { store.data.workbench }
    private var latest: PeriodRecord? { workbench.latestPeriod }
    private var sorted: [PeriodRecord] { workbench.periods.sorted { $0.startDay < $1.startDay } }

    private var intervals: [Int] {
        sorted.count > 1 ? (1..<sorted.count).map { sorted[$0].startDay - sorted[$0 - 1].startDay } : []
    }
    private var lengths: [Int] { sorted.compactMap(\.length) }
    private var avgCycle: Int? {
        intervals.isEmpty ? nil : Int((Double(intervals.reduce(0, +)) / Double(intervals.count)).rounded())
    }
    private var avgPeriod: Int? {
        lengths.isEmpty ? nil : Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded())
    }
    private var minCycle: Int? { intervals.min() }
    private var maxCycle: Int? { intervals.max() }
    private var regularity: String {
        guard intervals.count >= 2, let minCycle, let maxCycle else { return "记录中" }
        let range = maxCycle - minCycle
        if range <= 3 { return "较规律" }
        if range <= 7 { return "有波动" }
        return "波动较大"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            calendar
                .padding(.top, 12)
            if !sorted.isEmpty {
                analysis
                    .padding(.top, 12)
            }
            care
                .padding(.top, 12)
            history
                .padding(.top, 22)
        }
        .sheet(isPresented: $showStartSheet) {
            startSheet
        }
        .sheet(isPresented: $showTips) {
            tipsSheet
        }
        .alert("周期长度", isPresented: $showCycleEditor) {
            TextField("28", text: $cycleInput)
                .keyboardType(.numberPad)
            Button("保存") {
                if let value = Int(cycleInput), (21...45).contains(value) {
                    store.updateWorkbench { $0.cycleLength = value }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("一般可按 21–45 天记录。这个数字只用于预测，不用于避孕或诊断。")
        }
        .alert("已删除这次记录", isPresented: $showUndo) {
            Button("撤销") {
                if let record = deletedRecord {
                    store.updateWorkbench { data in
                        if !data.periods.contains(where: { $0.id == record.id }) {
                            data.periods.append(record)
                            data.periods.sort { $0.startDay > $1.startDay }
                        }
                    }
                    month = AppDate.startOfMonth(AppDate.date(epochDay: record.startDay))
                }
                deletedRecord = nil
            }
            Button("知道了", role: .cancel) { deletedRecord = nil }
        }
    }

    private var hero: some View {
        Card {
            HStack {
                Text("周期记录")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("只存在本机")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
            }
            Text(status)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(Theme.ink)
                .padding(.top, 5)
            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.muted)
                .padding(.top, 5)
            if let avgCycle, let avgPeriod {
                Text("平均周期 \(avgCycle) 天 · 平均经期 \(avgPeriod) 天")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 5)
            } else {
                Text("再记录一次，就能看到平均周期。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 5)
            }
            HStack {
                Text("周期长度 \(workbench.cycleLength) 天")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button("修改") {
                    cycleInput = String(workbench.cycleLength)
                    showCycleEditor = true
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.cinnabar)
            }
            .padding(.top, 9)

            if let latest {
                let cycleDay = max(1, today - latest.startDay + 1)
                let next = latest.startDay + workbench.cycleLength
                let progress = min(1, max(0, Double(today - latest.startDay) / Double(max(1, workbench.cycleLength))))
                HStack {
                    Text("周期第 \(cycleDay) 天")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text(next > today ? "预计 \(AppDate.dayText(next))" : "预计时间已到")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.top, 9)
                ProgressView(value: progress)
                    .tint(Theme.rose)
                    .padding(.top, 2)
            }

            HStack(spacing: 8) {
                Button(latest?.endDay == nil && latest != nil ? "记录新的开始" : "记录开始") {
                    startDate = Date()
                    showStartSheet = true
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("今天结束") {
                    endPeriod()
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(latest?.endDay != nil || latest == nil)
                .opacity(latest?.endDay == nil && latest != nil ? 1 : 0.45)
            }
            .padding(.top, 10)
        }
    }

    private var status: String {
        guard let latest else { return "从一次记录开始" }
        if latest.endDay == nil {
            return "经期第 \(max(1, today - latest.startDay + 1)) 天"
        }
        let days = latest.startDay + workbench.cycleLength - today
        if days > 0 { return "预计 \(days) 天后" }
        if days == 0 { return "预计就是今天" }
        return "预计时间已到"
    }

    private var subtitle: String {
        guard let latest else { return "记下开始和结束，慢慢看见自己的节律。" }
        return "上次 \(AppDate.dayText(latest.startDay)) 开始 · 周期 \(workbench.cycleLength) 天"
    }

    private var calendar: some View {
        let periodDays = actualDays()
        let predicted = predictedDays()
        let offset = AppDate.firstWeekdayOffset(month)
        let dayCount = AppDate.monthDayCount(month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return Card {
            HStack {
                Button {
                    month = AppDate.calendar.date(byAdding: .month, value: -1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Theme.paper)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text(AppDate.monthLabel(month))
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                Button {
                    month = AppDate.calendar.date(byAdding: .month, value: 1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Theme.paper)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                if !AppDate.sameMonth(month, Date()) {
                    Button("本月") { month = AppDate.startOfMonth(Date()) }
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.cinnabar)
                }
            }
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 10)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0..<(offset + dayCount), id: \.self) { index in
                    if index < offset {
                        Color.clear.frame(height: 32)
                    } else {
                        let day = index - offset + 1
                        let date = AppDate.calendar.date(byAdding: .day, value: day - 1, to: AppDate.startOfMonth(month)) ?? month
                        let epoch = AppDate.epochDay(date)
                        let actual = periodDays.contains(epoch)
                        let expected = predicted.contains(epoch)
                        let isToday = epoch == today
                        ZStack {
                            if actual {
                                Circle().fill(Theme.cinnabar)
                            } else if expected {
                                Circle().stroke(Theme.cinnabar, lineWidth: 1.3)
                            }
                            if isToday {
                                Circle().stroke(Theme.inkSoft, lineWidth: 0.9)
                                    .padding(1.5)
                            }
                            Text("\(day)")
                                .font(.system(size: 9.5, weight: isToday ? .medium : .regular))
                                .foregroundStyle(actual ? Theme.cream : (expected ? Theme.cinnabar : Theme.inkSoft))
                        }
                        .frame(height: 32)
                    }
                }
            }
            .padding(.top, 4)
            HStack(spacing: 12) {
                legendDot(color: Theme.cinnabar, text: "经期")
                legendDot(color: Theme.cinnabar, text: "预计", outlined: true)
                legendDot(color: Theme.inkSoft, text: "今天", ring: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 5)
        }
    }

    private func legendDot(color: Color, text: String, outlined: Bool = false, ring: Bool = false) -> some View {
        HStack(spacing: 4) {
            ZStack {
                if ring {
                    Circle().stroke(color, lineWidth: 0.8).frame(width: 8, height: 8)
                } else if outlined {
                    Circle().stroke(color, lineWidth: 0.9).frame(width: 7, height: 7)
                } else {
                    Circle().fill(color).frame(width: 7, height: 7)
                }
            }
            Text(text)
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.faint)
        }
    }

    private var analysis: some View {
        Card {
            HStack {
                Text("周期分析")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("记录 \(sorted.count) 次")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                stat("平均周期", avgCycle.map { "\($0)" } ?? "—", "天")
                stat("平均经期", avgPeriod.map { "\($0)" } ?? "—", "天")
                stat("规律度", regularity, "")
                stat("周期范围", minCycle != nil && maxCycle != nil ? "\(minCycle!)–\(maxCycle!)" : "—", "天")
            }
            .padding(.top, 10)
            if !intervals.isEmpty {
                Text("最近周期 " + intervals.suffix(6).map { String($0) }.joined(separator: " · ") + " 天")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 10)
            }
            if let latest {
                Text("接下来三次预计：" + predictedStarts(cycleLength: workbench.cycleLength, latestStart: latest.startDay)
                    .map { AppDate.dayText($0) }.joined(separator: "、"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.cinnabar)
                    .padding(.top, 8)
            }
            Text("按你的记录和周期长度估算，仅供参考，不用于诊断或避孕。")
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.faint)
                .padding(.top, 6)
        }
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.faint)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var care: some View {
        Card {
            Text("今天想对你说")
                .font(.system(size: 9.5, weight: .medium))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
            Text(PeriodCopy.today())
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .padding(.top, 6)
            ForEach(careTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 7) {
                    Text("·").foregroundStyle(Theme.cinnabar)
                    Text(tip)
                        .font(.system(size: 10.3))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(2)
                }
                .padding(.top, 6)
            }
            Button("更多建议") { showTips = true }
                .buttonStyle(SoftButtonStyle())
                .padding(.top, 8)
        }
    }

    private var careTips: [String] {
        guard let latest else {
            return [
                "记录周期，也记录身体的感觉，慢慢更懂自己。",
                "保持轻走、拉伸和规律作息，不用追求完美。",
                "有不确定的变化时，先观察，必要时咨询医生。",
            ]
        }
        if latest.endDay == nil {
            return [
                "热敷小腹，或洗个热水澡，让身体慢慢放松。",
                "能躺就躺一会儿；轻走、拉伸也可以，不必硬撑。",
                "多喝水，吃点含铁食物：瘦肉、豆类、深绿色蔬菜。",
            ]
        }
        let days = latest.startDay + workbench.cycleLength - today
        if (0...5).contains(days) {
            return [
                "这几天把安排放松一点，给自己留些余地。",
                "提前准备卫生用品、热水袋和舒服的衣服。",
                "早点睡，少熬一点；情绪有起伏时先照顾自己。",
            ]
        }
        return [
            "记录周期，也记录身体的感觉，慢慢更懂自己。",
            "保持轻走、拉伸和规律作息，不用追求完美。",
            "有不确定的变化时，先观察，必要时咨询医生。",
        ]
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("周期记录 · \(sorted.count)")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !sorted.isEmpty {
                    Text("左滑删除")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                }
            }
            .padding(.bottom, 9)
            if sorted.isEmpty {
                Card {
                    Text("还没有周期记录。")
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("点「记录开始」，先记下这一次。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sorted.reversed())) { record in
                        SwipeDeleteRow(onDelete: {
                            delete(record)
                        }) {
                            historyRow(record)
                                .background(Theme.cream)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ record: PeriodRecord) -> some View {
        let index = sorted.firstIndex { $0.id == record.id } ?? 0
        let previous = index > 0 ? sorted[index - 1] : nil
        let meta: String = {
            var values: [String] = []
            if let previous { values.append("周期 \(record.startDay - previous.startDay) 天") }
            if let length = record.length {
                values.append("经期 \(length) 天")
            } else {
                values.append("已持续 \(max(1, today - record.startDay + 1)) 天")
            }
            return values.joined(separator: " · ")
        }()
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.roseSoft)
                Text("期")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(Theme.rose)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.endDay == nil
                    ? "\(AppDate.dayText(record.startDay)) · 进行中"
                    : "\(AppDate.dayText(record.startDay)) – \(AppDate.dayText(record.endDay ?? record.startDay))")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(meta)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.faint)
            }
            Spacer()
            if record.endDay == nil {
                Text("进行中")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Theme.cinnabar)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Theme.cinnabarSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(13)
    }

    private var startSheet: some View {
        NavigationStack {
            Form {
                Section("开始日期") {
                    DatePicker("日期", selection: $startDate, in: ...Date(), displayedComponents: .date)
                }
                Section {
                    Text("如果已有进行中的记录，会自动结束在上一次开始的前一天。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("记录开始")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showStartSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        startPeriod()
                        showStartSheet = false
                    }
                    .foregroundStyle(Theme.cinnabar)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var tipsSheet: some View {
        NavigationStack {
            ScrollView {
                Text(fullTips)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(5)
                    .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle("这几天，可以对自己好一点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("知道了") { showTips = false }
                        .foregroundStyle(Theme.cinnabar)
                }
            }
        }
    }

    private var fullTips: String {
        "· 热敷小腹，或洗个热水澡，让身体慢慢放松。\n" +
        "· 轻走、拉伸都可以；累了就休息，不必硬撑。\n" +
        "· 多喝水，吃点含铁食物：瘦肉、豆类、深绿色蔬菜。\n" +
        "· 疼痛可按说明书使用止痛药；有哮喘、胃/肝肾问题或正在服其他药，先咨询医生或药师；16 岁以下不要用阿司匹林。\n" +
        "· 如果疼痛影响日常生活、出血量突然很大（例如每小时湿透一片）、经期超过 7 天，或伴发热、晕厥，请及时就医。\n" +
        "· 记录症状和周期，就诊时更有帮助。\n\n" +
        "以上是一般生活建议，不替代医生诊断，也不用于避孕。参考 NHS 与 ACOG 公开资料。"
    }

    private func actualDays() -> Set<Int> {
        var days = Set<Int>()
        for record in store.data.workbench.periods {
            let end = min(record.endDay ?? today, today)
            if record.startDay <= end {
                for day in record.startDay...end { days.insert(day) }
            }
        }
        return days
    }

    private func predictedDays() -> Set<Int> {
        guard let latest else { return [] }
        let length = max(2, min(10, avgPeriod ?? 5))
        var days = Set<Int>()
        for start in predictedStarts(cycleLength: workbench.cycleLength, latestStart: latest.startDay) {
            for day in start..<(start + length) {
                if !actualDays().contains(day) { days.insert(day) }
            }
        }
        return days
    }

    private func predictedStarts(cycleLength: Int, latestStart: Int) -> [Int] {
        let cycle = max(1, cycleLength)
        var next = latestStart + cycle
        while next < today - 7 { next += cycle }
        return (0..<3).map { next + cycle * $0 }
    }

    private func startPeriod() {
        let start = AppDate.epochDay(startDate)
        guard start <= today else { return }
        store.updateWorkbench { data in
            if let activeIndex = data.periods.firstIndex(where: { $0.endDay == nil && $0.startDay <= start }) {
                data.periods[activeIndex].endDay = max(data.periods[activeIndex].startDay, start - 1)
            }
            data.periods.append(PeriodRecord(startDay: start, endDay: nil))
            data.periods.sort { $0.startDay > $1.startDay }
        }
        month = AppDate.startOfMonth(AppDate.date(epochDay: start))
    }

    private func endPeriod() {
        guard let latest, latest.endDay == nil else { return }
        store.updateWorkbench { data in
            guard let index = data.periods.firstIndex(where: { $0.id == latest.id }) else { return }
            data.periods[index].endDay = max(today, data.periods[index].startDay)
        }
    }

    private func delete(_ record: PeriodRecord) {
        store.updateWorkbench { data in
            data.periods.removeAll { $0.id == record.id }
        }
        deletedRecord = record
        showUndo = true
    }
}

struct WishlistView: View {
    @EnvironmentObject private var store: NianRiStore
    @State private var newTitle = ""
    @State private var editingWish: WishItem?
    @State private var editTitle = ""
    @State private var showEdit = false

    private var wishes: [WishItem] { store.data.workbench.wishes }
    private var pending: [WishItem] { wishes.filter { !$0.done }.sorted { $0.createdDay > $1.createdDay } }
    private var completed: [WishItem] { wishes.filter(\.done).sorted { $0.createdDay > $1.createdDay } }
    private var doneCount: Int { wishes.filter(\.done).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Card {
                Text("愿望清单")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Text("\(wishes.count)")
                    .font(.system(size: 31, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text(wishes.isEmpty
                    ? "把想做的事写下来，愿望就有了形状。"
                    : "\(doneCount) 个已经实现 · 还有 \(wishes.count - doneCount) 个在路上")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 3)
                if !wishes.isEmpty {
                    ProgressView(value: Double(doneCount), total: Double(max(1, wishes.count)))
                        .tint(Theme.cinnabar)
                        .padding(.top, 8)
                }
            }

            Card {
                Text("写下一个愿望")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    TextField("想去看的海、想见的人、想学会的事…", text: $newTitle)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Theme.paper)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 0.7))
                    Button("收进清单") {
                        addWish()
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                .padding(.top, 8)
            }
            .padding(.top, 12)

            if pending.isEmpty && completed.isEmpty {
                Card {
                    Text("还没有愿望。写下一个，慢慢去实现。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 18)
            } else {
                if !pending.isEmpty {
                    wishSection(title: "在路上的 · \(pending.count)", items: pending)
                }
                if !completed.isEmpty {
                    wishSection(title: "已实现 · \(completed.count)", items: completed)
                }
            }
        }
        .alert("编辑愿望", isPresented: $showEdit) {
            TextField("愿望", text: $editTitle)
            Button("保存") {
                guard let wish = editingWish else { return }
                let clean = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return }
                store.updateWorkbench { data in
                    if let index = data.wishes.firstIndex(where: { $0.id == wish.id }) {
                        data.wishes[index].title = clean
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("把愿望写得再具体一点，它会更有形状。")
        }
    }

    private func wishSection(title: String, items: [WishItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: title)
                .padding(.top, 22)
                .padding(.bottom, 9)
            VStack(spacing: 8) {
                ForEach(items) { wish in
                    HStack(spacing: 10) {
                        Button {
                            store.updateWorkbench { data in
                                if let index = data.wishes.firstIndex(where: { $0.id == wish.id }) {
                                    data.wishes[index].done.toggle()
                                }
                            }
                        } label: {
                            CircleCheck(checked: wish.done, color: Theme.sage, size: 27)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(wish.title)
                                .font(.system(size: 13))
                                .foregroundStyle(wish.done ? Theme.muted : Theme.ink)
                                .strikethrough(wish.done)
                            Text("\(AppDate.dayText(wish.createdDay)) 写下")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.faint)
                        }
                        Spacer()
                        Menu {
                            Button("编辑愿望") {
                                editingWish = wish
                                editTitle = wish.title
                                showEdit = true
                            }
                            Button("删除", role: .destructive) {
                                store.updateWorkbench { data in
                                    data.wishes.removeAll { $0.id == wish.id }
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
            }
        }
    }

    private func addWish() {
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.updateWorkbench { data in
            data.wishes.append(WishItem(title: clean, done: false, createdDay: AppDate.today))
        }
        newTitle = ""
    }
}
