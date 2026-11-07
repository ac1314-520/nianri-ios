import WidgetKit
import SwiftUI

struct NianRiWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let days: Int
}

struct NianRiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NianRiWidgetEntry {
        NianRiWidgetEntry(date: Date(), snapshot: sample, days: 100)
    }

    func getSnapshot(in context: Context, completion: @escaping (NianRiWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NianRiWidgetEntry>) -> Void) {
        let current = entry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [current], policy: .after(next)))
    }

    private var sample: WidgetSnapshot {
        WidgetSnapshot(
            title: "我们相遇的那一天",
            targetEpochDay: WidgetDay.today + 100,
            subtitle: "每年 5月20日",
            recurring: true
        )
    }

    private func entry() -> NianRiWidgetEntry {
        let snapshot = WidgetSharedStore.load()
        let days = snapshot.map { $0.targetEpochDay - WidgetDay.today } ?? 0
        return NianRiWidgetEntry(date: Date(), snapshot: snapshot, days: days)
    }
}

struct NianRiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NianRiWidgetEntry

    private var title: String { entry.snapshot?.title ?? "念日" }
    private var subtitle: String { entry.snapshot?.subtitle ?? "打开念日，写下一个日子" }
    private var absoluteDays: Int { abs(entry.days) }
    private var dayText: String {
        if entry.snapshot == nil { return "还没有纪念日" }
        if entry.days > 0 { return "还有 \(entry.days) 天" }
        if entry.days == 0 { return "就是今天" }
        return "已经 \(absoluteDays) 天"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: -2) {
                        Text("\(absoluteDays)")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                        Text(entry.days < 0 ? "已走过" : "天")
                            .font(.system(size: 8))
                    }
                    .widgetAccentable()
                }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.tint)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .lineLimit(1)
                        Text(dayText)
                            .font(.system(size: 11, weight: .semibold))
                        Text(subtitle)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Text("念日 · \(title) · \(dayText)")
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Text("念日")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(widgetMuted)
                    Text(title)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(widgetInk)
                        .lineLimit(2)
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(absoluteDays)")
                            .font(.system(size: 34, weight: .light, design: .serif))
                            .foregroundStyle(widgetInk)
                        Text("天")
                            .font(.system(size: 9))
                            .foregroundStyle(widgetMuted)
                    }
                    Text(entry.days < 0 ? "已经走过" : dayText)
                        .font(.system(size: 9))
                        .foregroundStyle(widgetCinnabar)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetURL(URL(string: "nianri://home"))
        .containerBackground(for: .widget) {
            if family == .systemSmall {
                widgetPaper
            } else {
                Color.clear
            }
        }
    }

    private var widgetPaper: Color { Color(red: 0.965, green: 0.945, blue: 0.91) }
    private var widgetInk: Color { Color(red: 0.153, green: 0.137, blue: 0.118) }
    private var widgetMuted: Color { Color(red: 0.486, green: 0.455, blue: 0.408) }
    private var widgetCinnabar: Color { Color(red: 0.69, green: 0.32, blue: 0.22) }
}

struct NianRiWidget: Widget {
    let kind = "NianRiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NianRiWidgetProvider()) { entry in
            NianRiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("念日倒计时")
        .description("把下一个值得记住的日子，放到桌面或锁屏。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct NianRiWidgetBundle: WidgetBundle {
    var body: some Widget {
        NianRiManualWidget()
    }
}
