import Foundation
import SwiftUI
import UIKit

enum Theme {
    // Palette follows the Claude DESIGN.md direction: warm cream canvas,
    // coral voltage, warm ink, hairline borders, almost no shadow.
    static let paper = Color(hex: 0xFAF9F5)
    static let paperDeep = Color(hex: 0xF5F0E8)
    static let cream = Color(hex: 0xFFFDF9)
    static let ink = Color(hex: 0x141413)
    static let inkSoft = Color(hex: 0x3D3D3A)
    static let muted = Color(hex: 0x6C6A64)
    static let faint = Color(hex: 0x8E8B82)
    static let line = Color(hex: 0xE6DFD8)
    static let cinnabar = Color(hex: 0xCC785C)
    static let cinnabarDeep = Color(hex: 0xA9583E)
    static let cinnabarSoft = Color(hex: 0xF3E3DB)
    static let gold = Color(hex: 0xC49A5A)
    static let sage = Color(hex: 0x6F8C70)
    static let rose = Color(hex: 0xA87076)
    static let roseSoft = Color(hex: 0xF3E4E1)

    static let accents: [Color] = [
        Color(hex: 0xCC785C), Color(hex: 0x6F8C70), Color(hex: 0x5B7285),
        Color(hex: 0xB58A5A), Color(hex: 0x8A6B75), Color(hex: 0x505966),
        Color(hex: 0xA07062), Color(hex: 0x5F7C6A), Color(hex: 0x6E6A86),
        Color(hex: 0x8A7B5B), Color(hex: 0x7C6E9E), Color(hex: 0x6F8A8A),
    ]

    static func accent(_ index: Int) -> Color {
        accents[max(0, min(index, accents.count - 1))]
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    func nianriCard(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.line, lineWidth: 0.8)
            )
            .shadow(color: Theme.ink.opacity(0.025), radius: 8, x: 0, y: 3)
    }

    func nianriScreen() -> some View {
        self.background(Theme.paper.ignoresSafeArea())
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content.nianriCard(padding: padding)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Theme.cream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 0.8))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.cinnabar)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SwipeDeleteRow<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.cinnabar)
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text("删除")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.cream)
            .padding(.trailing, 20)

            content
                .offset(x: offset)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            offset = max(-120, min(0, value.translation.width))
                        }
                        .onEnded { value in
                            if value.translation.width < -60 {
                                withAnimation(.easeInOut(duration: 0.18)) { offset = -500 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                    offset = 0
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.18)) { offset = 0 }
                            }
                        }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct CircleCheck: View {
    let checked: Bool
    var color: Color = Theme.cinnabar
    var size: CGFloat = 25

    var body: some View {
        ZStack {
            Circle()
                .fill(checked ? color : Color.clear)
            Circle()
                .stroke(checked ? Color.clear : Theme.line, lineWidth: 1)
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(Theme.cream)
            }
        }
        .frame(width: size, height: size)
    }
}

struct PhotoView: View {
    @EnvironmentObject private var store: NianRiStore
    let filename: String?
    var cornerRadius: CGFloat = 22
    var fitWide = true

    var body: some View {
        GeometryReader { proxy in
            if let filename, store.isAnimatedPhoto(filename), let url = store.photoURL(for: filename) {
                AnimatedPhotoView(url: url)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else if let image = store.image(filename) {
                if fitWide && image.size.width > image.size.height * 1.12 {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.24))

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Theme.cinnabarDeep, Theme.accents[3], Theme.ink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .stroke(Theme.cream.opacity(0.18), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .offset(x: 82, y: -46)
                    Circle()
                        .fill(Theme.cream.opacity(0.1))
                        .frame(width: 76, height: 76)
                        .offset(x: 120, y: 70)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

enum AppDate {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        return calendar
    }()

    private static let formatterCache = NSCache<NSString, DateFormatter>()

    private static func formatter(_ format: String) -> DateFormatter {
        let key = format as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }

    static var today: Int {
        epochDay(Date())
    }

    static func epoch(_ date: Date) -> Int {
        epochDay(date)
    }

    static func epochDay(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        let origin = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.dateComponents([.day], from: origin, to: start).day ?? 0
    }

    static func date(epochDay: Int) -> Date {
        let origin = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.date(byAdding: .day, value: epochDay, to: origin) ?? Date()
    }

    static func dayText(_ day: Int, format: String = "M月d日") -> String {
        formatter(format).string(from: date(epochDay: day))
    }

    static func dateText(_ date: Date, format: String = "M月d日") -> String {
        formatter(format).string(from: date)
    }

    static func todayText(_ format: String = "yyyy年M月d日 EEEE") -> String {
        dateText(Date(), format: format)
    }

    static func monthLabel(_ date: Date) -> String {
        dateText(date, format: "yyyy 年 M 月")
    }

    static func startOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func monthDayCount(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static func firstWeekdayOffset(_ date: Date) -> Int {
        let first = startOfMonth(date)
        let weekday = calendar.component(.weekday, from: first)
        return (weekday + 5) % 7
    }

    static func sameMonth(_ date: Date, _ other: Date) -> Bool {
        calendar.isDate(date, equalTo: other, toGranularity: .month)
    }

    static func dayOfWeek(_ date: Date) -> String {
        dateText(date, format: "EEEE")
    }
}

func money(_ cents: Int) -> String {
    let sign = cents < 0 ? "-" : ""
    let absolute = abs(cents)
    return "\(sign)¥\(String(format: "%.2f", Double(absolute) / 100))"
}

func plainMoney(_ cents: Int) -> String {
    String(format: "%.2f", Double(cents) / 100)
}

extension Int {
    var dayDate: Date { AppDate.date(epochDay: self) }
}
