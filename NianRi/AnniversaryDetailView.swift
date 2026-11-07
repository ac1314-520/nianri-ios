import SwiftUI
import UIKit

// Detail page follows the Claude DESIGN.md direction:
// warm cream canvas, coral accent, serif display, hairline cards, no heavy chrome.

struct AnniversaryDetailView: View {
    @EnvironmentObject private var store: NianRiStore
    @Environment(\.dismiss) private var dismiss

    let eventID: UUID

    @State private var showingEditor = false
    @State private var showDelete = false
    @State private var showLivePlayer = false
    @State private var unitMode: CountUnitMode = .days

    private var event: Anniversary? {
        store.data.anniversaries.first { $0.id == eventID }
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if let event {
                detail(event)
            } else {
                missing
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let event {
                AnniversaryEditorView(event: event)
                    .environmentObject(store)
            }
        }
        .alert("删除这一天？", isPresented: $showDelete) {
            Button("删除", role: .destructive) {
                if let event {
                    store.deleteAnniversary(event)
                    NotificationManager.shared.reschedule(events: store.data.anniversaries)
                }
                dismiss()
            }
            Button("先留着", role: .cancel) {}
        } message: {
            Text("「\(event?.title ?? "")」的照片和记录会一起删除。")
        }
        .onChange(of: store.data.anniversaries) { _, _ in
            if event == nil { dismiss() }
        }
    }

    private func detail(_ event: Anniversary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cover(event)
                identity(event)
                    .padding(.top, 22)
                countCard(event)
                    .padding(.top, 20)
                milestoneSection(event)
                    .padding(.top, 30)
                if !event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    noteSection(event.note)
                        .padding(.top, 28)
                }
                if let music = event.music, let musicTitle = event.musicTitle {
                    musicSection(event, title: musicTitle)
                        .padding(.top, 28)
                }
                reminderSection(event)
                    .padding(.top, 28)
                actions(event)
                    .padding(.top, 24)
                Text(footer(for: event))
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper.ignoresSafeArea())
    }

    private func cover(_ event: Anniversary) -> some View {
        ZStack {
            PhotoView(filename: event.photo, cornerRadius: 30)
                .frame(height: 330)

            LinearGradient(
                colors: [Theme.ink.opacity(0.24), .clear, Theme.ink.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack {
                HStack {
                    circleButton("arrow.left", label: "返回") { dismiss() }
                    Spacer()
                    Menu {
                        Button("编辑这一天") { showingEditor = true }
                        Button("删除这一天", role: .destructive) { showDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 42, height: 42)
                            .background(Theme.cream.opacity(0.94))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 12)

                Spacer()

                HStack(alignment: .bottom) {
                    Text(event.recurring ? "纪念日" : "倒数日")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Theme.cream.opacity(0.92))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.cream.opacity(0.16))
                        .clipShape(Capsule())
                    Spacer()
                    if let url = store.liveVideoURL(for: event.photo) {
                        Button {
                            showLivePlayer = true
                        } label: {
                            Label("实况", systemImage: "play.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.cream)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Theme.cream.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showLivePlayer) {
                            LivePhotoPlayerSheet(url: url)
                        }
                    }
                    Spacer()
                    Text(event.isToday ? "今天" : event.recurring ? "每年" : "单次")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(event.isToday ? Theme.cream : Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(event.isToday ? Theme.cinnabar : Theme.cream.opacity(0.94))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.top, 8)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .background(Theme.cream.opacity(0.94))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    private func identity(_ event: Anniversary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(event.recurring ? "纪念日" : "倒数日")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Theme.cinnabar)
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: 22, height: 0.7)
                Text(event.recurring ? "每年今日" : "仅此一次")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                Spacer()
            }
            Text(event.title)
                .font(.system(size: 33, weight: .regular, design: .serif))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .padding(.top, 10)
            Text(startedLine(event))
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.top, 9)
        }
    }

    private func startedLine(_ event: Anniversary) -> String {
        let date = AppDate.dateText(event.date, format: "yyyy年M月d日 EEEE")
        let lunar = event.lunarDate.map { " · 农历\($0.shortLabel)" } ?? ""
        return event.recurring ? "始于 \(date)\(lunar)" : date + lunar
    }

    private func countCard(_ event: Anniversary) -> some View {
        let metric = metric(for: event)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(metric.overline)
                    .font(.system(size: 9.5, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(Theme.muted)
                Spacer()
                unitPicker
            }

            Button {
                withAnimation(.snappy(duration: 0.24)) {
                    unitMode = unitMode.next
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(metric.value)
                            .font(.system(size: countSize(metric.value), weight: .light, design: .serif))
                            .tracking(-1)
                            .foregroundStyle(metric.highlight ? Theme.cinnabar : Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .contentTransition(.numericText())
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .padding(.bottom, 8)
                        }
                    }
                    Text(metric.caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("轻点切换天、周、年月")

            HStack(spacing: 6) {
                Text("轻点数字切换")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.top, 7)

            Rectangle()
                .fill(Theme.line)
                .frame(height: 0.7)
                .padding(.top, 16)
        }
        .padding(18)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.line, lineWidth: 0.8)
        )
    }

    private var unitPicker: some View {
        HStack(spacing: 3) {
            ForEach(CountUnitMode.allCases) { mode in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { unitMode = mode }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(unitMode == mode ? Theme.cream : Theme.muted)
                        .padding(.horizontal, 8)
                        .frame(height: 25)
                        .background(unitMode == mode ? Theme.ink : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("按\(mode.label)显示")
            }
        }
        .padding(3)
        .background(Theme.paperDeep)
        .clipShape(Capsule())
    }

    private func countSize(_ value: String) -> CGFloat {
        if value == "今天" { return 54 }
        if value.count >= 7 { return 38 }
        if value.count >= 5 { return 44 }
        return 72
    }

    private func metric(for event: Anniversary) -> DetailMetric {
        let calendar = AppDate.calendar
        let today = calendar.startOfDay(for: Date())
        let eventDay = calendar.startOfDay(for: event.date)
        let daysBetween = calendar.dateComponents([.day], from: eventDay, to: today).day ?? 0
        let isFuture = daysBetween < 0
        let isToday = event.isToday

        let totalDays: Int
        let overline: String
        if isToday {
            totalDays = event.recurring ? max(1, daysBetween + 1) : 0
            overline = "今天"
        } else if event.recurring {
            if isFuture {
                totalDays = abs(daysBetween)
                overline = "还有"
            } else {
                totalDays = max(1, daysBetween + 1)
                overline = "相伴第"
            }
        } else if isFuture {
            totalDays = abs(daysBetween)
            overline = "还有"
        } else {
            totalDays = max(0, daysBetween)
            overline = "已经"
        }

        let highlight = isToday || isFuture
        let caption = baseCaption(event: event, isToday: isToday, isFuture: isFuture)

        if isToday {
            return DetailMetric(
                overline: "今天",
                value: "今天",
                unit: "",
                caption: caption,
                highlight: true
            )
        }

        switch unitMode {
        case .days:
            return DetailMetric(
                overline: overline,
                value: "\(totalDays)",
                unit: "天",
                caption: caption,
                highlight: highlight
            )
        case .weeks:
            return DetailMetric(
                overline: overline,
                value: "\(totalDays / 7)",
                unit: "周",
                caption: "共 \(totalDays) 天 · \(caption)",
                highlight: highlight
            )
        case .yearsMonths:
            let start = isFuture ? today : eventDay
            let end = isFuture ? eventDay : today
            let parts = calendar.dateComponents([.year, .month], from: start, to: end)
            let years = max(0, parts.year ?? 0)
            let months = max(0, parts.month ?? 0)
            let value: String
            if years > 0 && months > 0 {
                value = "\(years)年\(months)个月"
            } else if years > 0 {
                value = "\(years)年"
            } else if months > 0 {
                value = "\(months)个月"
            } else {
                value = "\(totalDays)天"
            }
            return DetailMetric(
                overline: overline,
                value: value,
                unit: "",
                caption: "共 \(totalDays) 天 · \(caption)",
                highlight: highlight
            )
        }
    }

    private func baseCaption(event: Anniversary, isToday: Bool, isFuture: Bool) -> String {
        if isToday {
            return event.recurring ? "今天，周年快乐。" : "就是今天，愿这一天被好好收藏。"
        }
        if event.recurring {
            return "始于 \(AppDate.dateText(event.date, format: "yyyy年M月d日")) · 下一个周年 \(AppDate.dateText(event.targetDate, format: "yyyy年M月d日"))"
        }
        if isFuture {
            return "期待 · \(AppDate.dateText(event.date, format: "yyyy年M月d日 EEEE"))"
        }
        return "发生于 \(AppDate.dateText(event.date, format: "yyyy年M月d日 EEEE"))"
    }

    private func milestoneSection(_ event: Anniversary) -> some View {
        let items = milestones(for: event)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("时光刻度")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("MILESTONES")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.7)
                    .foregroundStyle(Theme.faint)
            }

            if items.isEmpty {
                Text(emptyMilestoneText(for: event))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(5)
                    .padding(.top, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(item.daysAway == 0 ? Theme.cinnabar : Theme.gold)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 6)
                                if index != items.count - 1 {
                                    Rectangle()
                                        .fill(Theme.line)
                                        .frame(width: 1, height: 38)
                                }
                            }
                            .frame(width: 18)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.years)周年")
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Text(AppDate.dateText(item.date, format: "yyyy年M月d日 EEEE"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.bottom, index == items.count - 1 ? 2 : 13)

                            Spacer(minLength: 8)

                            Text(item.daysAway == 0 ? "今天" : "还有 \(item.daysAway) 天")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(item.daysAway == 0 ? Theme.cinnabar : Theme.inkSoft)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(item.daysAway == 0 ? Theme.cinnabarSoft : Theme.paper)
                                .clipShape(Capsule())
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 9)
                        if index != items.count - 1 {
                            Rectangle()
                                .fill(Theme.line.opacity(0.7))
                                .frame(height: 0.7)
                                .padding(.leading, 30)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.line, lineWidth: 0.8)
                )
                .padding(.top, 12)
            }
        }
    }

    private func emptyMilestoneText(for event: Anniversary) -> String {
        if event.recurring && event.date > Date() {
            return "从这一天开始，周年刻度会在这里慢慢生长。"
        }
        if !event.recurring {
            return "这一页只倒数一次，刻度留给未来的日子。"
        }
        return "纪念开始后，这里会长出一个个温柔的刻度。"
    }

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("写在这天")
                .font(.system(size: 19, weight: .regular, design: .serif))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 0) {
                Text("“")
                    .font(.system(size: 42, design: .serif))
                    .foregroundStyle(Theme.cinnabar.opacity(0.28))
                    .frame(height: 30, alignment: .top)
                Text(note)
                    .font(.system(size: 14.5, design: .serif))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(7)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.line, lineWidth: 0.8)
            )
            .padding(.top, 12)
        }
    }

    private func musicSection(_ event: Anniversary, title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("这一天的声音")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("MUSIC")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.7)
                    .foregroundStyle(Theme.faint)
            }
            MusicAttachmentView(
                name: event.music,
                title: title,
                editable: false
            )
            .padding(.top, 12)
        }
    }

    private func reminderSection(_ event: Anniversary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("这一天的提醒")
                .font(.system(size: 19, weight: .regular, design: .serif))
                .foregroundStyle(Theme.ink)

            Button {
                showingEditor = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.accent(event.accentIndex).opacity(0.16))
                        Image(systemName: event.reminderEnabled ? "bell.fill" : "bell")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.accent(event.accentIndex))
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.reminderEnabled ? "提醒已开启" : "提醒已关闭")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text(reminderDetail(event))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.faint)
                }
                .padding(16)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.line, lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }

    private func reminderDetail(_ event: Anniversary) -> String {
        guard event.reminderEnabled else { return "点按编辑，为这一天开启提醒" }
        let advance = event.reminderDaysBefore == 0 ? "当天" : "提前 \(event.reminderDaysBefore) 天"
        return "\(advance) · \(event.reminderTimeLabel) 提醒"
    }

    private func actions(_ event: Anniversary) -> some View {
        VStack(spacing: 14) {
            Button {
                showingEditor = true
            } label: {
                Label("编辑这一天", systemImage: "square.and.pencil")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("删除这一天", role: .destructive) {
                showDelete = true
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)
        }
    }

    private func footer(for event: Anniversary) -> String {
        if event.isToday {
            return event.recurring ? "愿每一年，都有值得纪念的相逢。" : "愿这一天，被好好收藏。"
        }
        if event.recurring {
            return "愿每一次回望，都有温度。"
        }
        return event.daysUntil > 0 ? "愿所有等待，都有回音。" : "时间会走远，被记住的日子不会。"
    }

    private func milestones(for event: Anniversary) -> [AnniversaryMilestone] {
        guard event.recurring else { return [] }
        let calendar = AppDate.calendar
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: event.date)
        guard start <= today else { return [] }

        let startYear = calendar.component(.year, from: start)
        var year = calendar.component(.year, from: today)
        var candidate = annualDate(for: start, year: year)
        if candidate < today {
            year += 1
            candidate = annualDate(for: start, year: year)
        }

        var result: [AnniversaryMilestone] = []
        while result.count < 3 {
            let years = year - startYear
            if years > 0 {
                let away = calendar.dateComponents([.day], from: today, to: candidate).day ?? 0
                result.append(AnniversaryMilestone(years: years, date: candidate, daysAway: max(0, away)))
            }
            year += 1
            candidate = annualDate(for: start, year: year)
        }
        return result
    }

    private func annualDate(for start: Date, year: Int) -> Date {
        let calendar = AppDate.calendar
        var components = calendar.dateComponents([.month, .day], from: start)
        components.year = year
        if components.month == 2, components.day == 29,
           calendar.date(from: components) == nil {
            components.day = 28
        }
        return calendar.date(from: components) ?? start
    }

    private var missing: some View {
        VStack(spacing: 16) {
            Text("这一天已经不在了")
                .font(.system(size: 21, design: .serif))
                .foregroundStyle(Theme.ink)
            Button("返回首页") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.cinnabar)
        }
    }
}

private enum CountUnitMode: String, CaseIterable, Identifiable {
    case days, weeks, yearsMonths

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days: return "天"
        case .weeks: return "周"
        case .yearsMonths: return "年月"
        }
    }

    var next: CountUnitMode {
        switch self {
        case .days: return .weeks
        case .weeks: return .yearsMonths
        case .yearsMonths: return .days
        }
    }
}

private struct DetailMetric {
    let overline: String
    let value: String
    let unit: String
    let caption: String
    let highlight: Bool
}

private struct AnniversaryMilestone: Identifiable {
    let years: Int
    let date: Date
    let daysAway: Int
    var id: Int { years }
}
