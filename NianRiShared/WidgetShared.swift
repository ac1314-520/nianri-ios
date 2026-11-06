import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var title: String
    var targetEpochDay: Int
    var subtitle: String
    var recurring: Bool
}

enum WidgetSharedStore {
    static let appGroup = "group.com.nianri.app"
    private static let key = "nianri.widget.snapshot"

    static func save(_ snapshot: WidgetSnapshot?) {
        let defaults = UserDefaults(suiteName: appGroup)
        guard let snapshot else {
            defaults?.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults?.set(data, forKey: key)
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

enum WidgetDay {
    static var today: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let origin = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.dateComponents([.day], from: origin, to: start).day ?? 0
    }

    static func date(_ epochDay: Int) -> Date {
        let calendar = Calendar.current
        let origin = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.date(byAdding: .day, value: epochDay, to: origin) ?? Date()
    }

    static func text(_ epochDay: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date(epochDay))
    }
}
