import WidgetKit
import SwiftUI
import AppIntents
import Foundation

/// 手动倒计时小组件：不依赖 App Group，签名受限时也能显示。
struct NianRiManualIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "念日手动倒计时"
    static var description = IntentDescription("填写标题和日期，桌面每天自动更新倒计时。")

    @Parameter(title: "标题")
    var title: String?

    @Parameter(title: "日期")
    var date: Date?
}

struct NianRiManualEntry: TimelineEntry {
    let date: Date
    let title: String
    let targetDate: Date?
    let days: Int
}

struct NianRiManualProvider: AppIntentTimelineProvider {
    typealias Entry = NianRiManualEntry
    typealias Intent = NianRiManualIntent

    func placeholder(in context: Context) -> NianRiManualEntry {
        let target = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        return NianRiManualEntry(
            date: Date(),
            title: "值得记住的日子",
            targetDate: target,
            days: 30
        )
    }

    func snapshot(for configuration: NianRiManualIntent, in context: Context) async -> NianRiManualEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: NianRiManualIntent, in context: Context) async -> Timeline<NianRiManualEntry> {
        let now = Date()
        let calendar = Calendar.current
        let nextMidnight = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        return Timeline(entries: [entry(for: configuration, now: now)], policy: .after(nextMidnight))
    }

    private func entry(for configuration: NianRiManualIntent, now: Date = Date()) -> NianRiManualEntry {
        let calendar = Calendar.current
        let title = configuration.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = configuration.date.map { calendar.startOfDay(for: $0) }
        let days: Int
        if let target {
            days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: target
            ).day ?? 0
        } else {
            days = 0
        }
        return NianRiManualEntry(
            date: now,
            title: (title?.isEmpty == false ? title! : "念日"),
            targetDate: target,
            days: days
        )
    }
}

struct NianRiManualWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NianRiManualEntry

    private let paper = Color(red: 0.965, green: 0.945, blue: 0.91)
    private let ink = Color(red: 0.153, green: 0.137, blue: 0.118)
    private let muted = Color(red: 0.486, green: 0.455, blue: 0.408)
    private let cinnabar = Color(red: 0.69, green: 0.32, blue: 0.22)

    private var status: String {
        guard entry.targetDate != nil else { return "长按编辑，填写日期" }
        if entry.days > 0 { return "还有 \(entry.days) 天" }
        if entry.days == 0 { return "就是今天" }
        return "已经 \(abs(entry.days)) 天"
    }

    private var dateText: String {
        guard let target = entry.targetDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: target)
    }

    var body: some View {
        Group {
            if entry.targetDate == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("念日")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(muted)
                    Text("手动倒计时")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(ink)
                    Spacer()
                    Text("长按小组件\n编辑标题和日期")
                        .font(.system(size: 10))
                        .foregroundStyle(cinnabar)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if family == .systemMedium {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("念日")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(muted)
                        Text(entry.title)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(ink)
                            .lineLimit(2)
                        Spacer()
                        Text(dateText)
                            .font(.system(size: 9))
                            .foregroundStyle(muted)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(abs(entry.days))")
                                .font(.system(size: 42, weight: .light, design: .serif))
                                .foregroundStyle(ink)
                            Text("天")
                                .font(.system(size: 10))
                                .foregroundStyle(muted)
                        }
                        Text(status)
                            .font(.system(size: 10))
                            .foregroundStyle(cinnabar)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("念日")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(muted)
                    Text(entry.title)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(abs(entry.days))")
                            .font(.system(size: 34, weight: .light, design: .serif))
                            .foregroundStyle(ink)
                        Text("天")
                            .font(.system(size: 9))
                            .foregroundStyle(muted)
                    }
                    Text(status)
                        .font(.system(size: 9))
                        .foregroundStyle(cinnabar)
                    Text(dateText)
                        .font(.system(size: 8))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .widgetURL(URL(string: "nianri://home"))
        .containerBackground(for: .widget) {
            paper
        }
    }
}

struct NianRiManualWidget: Widget {
    let kind = "NianRiManualWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NianRiManualIntent.self,
            provider: NianRiManualProvider()
        ) { entry in
            NianRiManualWidgetView(entry: entry)
        }
        .configurationDisplayName("念日 · 手动倒计时")
        .description("自己填写标题和日期，每天自动更新，不依赖 App Group。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
