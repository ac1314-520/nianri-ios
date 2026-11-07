import WidgetKit
import SwiftUI
import AppIntents
import Foundation
import UIKit

/// 手动倒计时小组件：不依赖 App Group，签名受限时也能显示。
/// 照片通过 App Intent 的 IntentFile 参数带入，日期时间使用系统配置页的日期选择器。
struct NianRiManualIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "念日手动倒计时"
    static var description = IntentDescription("选择标题、日期时间和照片，显示成和 App 内一样的卡片。")

    @Parameter(title: "标题", default: "念日")
    var title: String?

    @Parameter(title: "日期时间", default: Date())
    var date: Date?

    @Parameter(title: "照片", supportedTypeIdentifiers: ["public.image"])
    var photo: IntentFile?
}

struct NianRiManualEntry: TimelineEntry {
    let date: Date
    let title: String
    let targetDate: Date
    let days: Int
    let photoData: Data?
}

struct NianRiManualProvider: AppIntentTimelineProvider {
    typealias Entry = NianRiManualEntry
    typealias Intent = NianRiManualIntent

    func placeholder(in context: Context) -> NianRiManualEntry {
        let target = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return NianRiManualEntry(
            date: Date(),
            title: "值得记住的日子",
            targetDate: target,
            days: 30,
            photoData: nil
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
        let title = (configuration.title ?? "念日").trimmingCharacters(in: .whitespacesAndNewlines)
        let target = configuration.date ?? Date()
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: target)
        ).day ?? 0
        return NianRiManualEntry(
            date: now,
            title: title.isEmpty ? "念日" : title,
            targetDate: target,
            days: days,
            photoData: configuration.photo?.data
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

    private var photo: UIImage? {
        entry.photoData.flatMap { UIImage(data: $0) }
    }

    private var hasPhoto: Bool { photo != nil }

    private var status: String {
        if entry.days > 0 { return "还有 \(entry.days) 天" }
        if entry.days == 0 { return "就是今天" }
        return "已经 \(abs(entry.days)) 天"
    }

    private var countText: String {
        if entry.days == 0 { return "今天" }
        return "\(abs(entry.days))"
    }

    private var countUnit: String {
        entry.days == 0 ? "" : "天"
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: entry.targetDate)
    }

    private var titleColor: Color { hasPhoto ? Color.white : ink }
    private var mutedColor: Color { hasPhoto ? Color.white.opacity(0.78) : muted }
    private var accentColor: Color { hasPhoto ? Color(red: 1, green: 0.85, blue: 0.64) : cinnabar }
    private var countSize: CGFloat {
        switch family {
        case .systemLarge: return 58
        case .systemMedium: return 44
        default: return 36
        }
    }
    private var titleSize: CGFloat {
        switch family {
        case .systemLarge: return 24
        case .systemMedium: return 19
        default: return 15
        }
    }
    private var padding: CGFloat {
        family == .systemLarge ? 22 : 16
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.22), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    paper
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("念日")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)

                    Text(entry.title)
                        .font(.system(size: titleSize, weight: .medium, design: .serif))
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .padding(.top, 7)

                    Spacer(minLength: 4)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(countText)
                            .font(.system(size: countSize, weight: .light, design: .serif))
                            .foregroundStyle(titleColor)
                        if !countUnit.isEmpty {
                            Text(countUnit)
                                .font(.system(size: 10))
                                .foregroundStyle(mutedColor)
                        }
                    }

                    Text(status)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.top, 1)

                    Text(dateText)
                        .font(.system(size: 9))
                        .foregroundStyle(mutedColor)
                        .lineLimit(1)
                        .padding(.top, 3)
                }
                .padding(padding)
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
        .description("选择纪念日、日期时间和照片，做成和 App 内一样的卡片。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
