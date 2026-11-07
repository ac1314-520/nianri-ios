import Foundation
import Combine
import UIKit
import ImageIO
import Photos
import UniformTypeIdentifiers
import UserNotifications
import WidgetKit

enum CheckInCategory: String, Codable, CaseIterable, Identifiable {
    case daily, love, fan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "日常"
        case .love: return "恋爱"
        case .fan: return "追星"
        }
    }
}

struct Anniversary: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var recurring: Bool = true
    var accentIndex: Int = 0
    var note: String = ""
    var photo: String? = nil
    var music: String? = nil
    var musicTitle: String? = nil
    var lunar: Bool? = nil
    var lunarYear: Int? = nil
    var lunarMonth: Int? = nil
    var lunarDay: Int? = nil
    var lunarLeap: Bool? = nil
    var reminderEnabled: Bool = false
    var reminderDaysBefore: Int = 0
    var reminderMinuteOfDay: Int? = nil
    var manualOrder: Int? = nil

    var reminderHour: Int { (reminderMinuteOfDay ?? 540) / 60 }
    var reminderMinute: Int { (reminderMinuteOfDay ?? 540) % 60 }
    var reminderTimeLabel: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }

    var lunarDate: LunarDate? {
        guard lunar == true,
              let lunarYear, let lunarMonth, let lunarDay else { return nil }
        return LunarDate(
            year: lunarYear,
            month: lunarMonth,
            day: lunarDay,
            leap: lunarLeap ?? false
        )
    }

    var targetDate: Date {
        if let lunarDate {
            if !recurring {
                return LunarCalendar.toSolar(lunarDate) ?? AppDate.calendar.startOfDay(for: date)
            }
            return LunarCalendar.nextOccurrence(of: lunarDate, after: AppDate.calendar.startOfDay(for: Date()))
                ?? AppDate.calendar.startOfDay(for: date)
        }
        let calendar = AppDate.calendar
        if !recurring {
            return calendar.startOfDay(for: date)
        }
        let today = calendar.startOfDay(for: Date())
        let original = calendar.dateComponents([.month, .day], from: date)
        let year = calendar.component(.year, from: today)
        var components = DateComponents()
        components.year = year
        components.month = original.month
        components.day = original.day
        var target = calendar.date(from: components) ?? today
        if target < today {
            components.year = year + 1
            target = calendar.date(from: components) ?? target
        }
        return target
    }

    var daysUntil: Int {
        AppDate.calendar.dateComponents(
            [.day],
            from: AppDate.calendar.startOfDay(for: Date()),
            to: targetDate
        ).day ?? 0
    }

    var daysSince: Int {
        AppDate.calendar.dateComponents(
            [.day],
            from: AppDate.calendar.startOfDay(for: date),
            to: AppDate.calendar.startOfDay(for: Date())
        ).day ?? 0
    }

    var isToday: Bool {
        AppDate.calendar.isDate(targetDate, inSameDayAs: Date())
    }

    var dateLabel: String {
        let solar = AppDate.dateText(date, format: "yyyy.MM.dd")
        if let lunarDate {
            return "\(solar) · 农历\(lunarDate.shortLabel)"
        }
        return solar
    }

    var recurrenceLabel: String {
        if recurring {
            return lunarDate == nil ? "每年今日" : "每年农历"
        }
        return "仅此一次"
    }
}

struct DiaryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var epochDay: Int
    var text: String
    var moodKey: String? = nil
    var createdAt: Date? = nil
    var photo: String? = nil
    var music: String? = nil
    var musicTitle: String? = nil
}

struct CheckInPlan: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var category: CheckInCategory
    var createdDay: Int
    var checkedDays: [Int]

    func isChecked(today: Int) -> Bool {
        checkedDays.contains(today)
    }

    func streak(today: Int) -> Int {
        var day = today
        var count = 0
        while checkedDays.contains(day) {
            count += 1
            day -= 1
        }
        return count
    }
}

struct LedgerEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var epochDay: Int
    var income: Bool
    var amountCents: Int
    var category: String
    var note: String
}

struct PeriodRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var startDay: Int
    var endDay: Int?

    var length: Int? {
        guard let endDay else { return nil }
        return max(1, endDay - startDay + 1)
    }
}

struct WishItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done: Bool
    var createdDay: Int
}

struct WorkbenchData: Codable, Equatable {
    var diary: [DiaryEntry] = []
    var plans: [CheckInPlan] = []
    var ledger: [LedgerEntry] = []
    var periods: [PeriodRecord] = []
    var wishes: [WishItem] = []
    var moods: [String: String] = [:]
    var cycleLength: Int = 28

    func mood(on day: Int) -> String? {
        moods[String(day)]
    }

    func diary(on day: Int) -> DiaryEntry? {
        diary.filter { $0.epochDay == day }
            .max { lhs, rhs in
                (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
            }
    }

    var latestPeriod: PeriodRecord? {
        periods.max { $0.startDay < $1.startDay }
    }
}

struct AppData: Codable, Equatable {
    var anniversaries: [Anniversary] = []
    var workbench = WorkbenchData()
    var weatherCity: String = "上海"
}

final class NianRiStore: ObservableObject {
    @Published private(set) var data: AppData
    private let dataURL: URL
    private let photosURL: URL
    private let audioURL: URL
    private let imageCache = NSCache<NSString, UIImage>()

    init() {
        let manager = FileManager.default
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = support.appendingPathComponent("NianRi", isDirectory: true)
        try? manager.createDirectory(at: root, withIntermediateDirectories: true)
        photosURL = root.appendingPathComponent("Photos", isDirectory: true)
        try? manager.createDirectory(at: photosURL, withIntermediateDirectories: true)
        audioURL = root.appendingPathComponent("Audio", isDirectory: true)
        try? manager.createDirectory(at: audioURL, withIntermediateDirectories: true)
        dataURL = root.appendingPathComponent("data.json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let raw = try? Data(contentsOf: dataURL),
           let decoded = try? decoder.decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData()
        }
        publishWidget()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: dataURL, options: [.atomic])
        publishWidget()
    }

    private func publishWidget() {
        let next = data.anniversaries.min { $0.targetDate < $1.targetDate }
        guard let next else {
            WidgetSharedStore.save(nil)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let subtitle: String
        if let lunar = next.lunarDate {
            subtitle = next.recurring ? "每年农历\(lunar.shortLabel)" : "农历\(lunar.shortLabel)"
        } else {
            subtitle = next.recurring
                ? "每年 \(AppDate.dateText(next.date, format: "M月d日"))"
                : AppDate.dateText(next.date, format: "yyyy年M月d日")
        }
        WidgetSharedStore.save(
            WidgetSnapshot(
                title: next.title,
                targetEpochDay: AppDate.epochDay(next.targetDate),
                subtitle: subtitle,
                recurring: next.recurring
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    func update(_ transform: (inout AppData) -> Void) {
        transform(&data)
        save()
    }

    func updateWorkbench(_ transform: (inout WorkbenchData) -> Void) {
        transform(&data.workbench)
        save()
    }

    func addAnniversary(_ event: Anniversary) {
        var newEvent = event
        if data.anniversaries.contains(where: { $0.manualOrder != nil }) {
            newEvent.manualOrder = (data.anniversaries.compactMap(\.manualOrder).max() ?? -1) + 1
        }
        data.anniversaries.append(newEvent)
        save()
    }

    func setHomeOrder(_ ids: [UUID]) {
        for (index, id) in ids.enumerated() {
            guard let eventIndex = data.anniversaries.firstIndex(where: { $0.id == id }) else { continue }
            data.anniversaries[eventIndex].manualOrder = index
        }
        save()
    }

    func updateAnniversary(_ event: Anniversary) {
        guard let index = data.anniversaries.firstIndex(where: { $0.id == event.id }) else { return }
        data.anniversaries[index] = event
        save()
    }

    func deleteAnniversary(_ event: Anniversary) {
        removeAnniversary(event, deletePhoto: true)
    }

    func removeAnniversary(_ event: Anniversary, deletePhoto: Bool) {
        data.anniversaries.removeAll { $0.id == event.id }
        if deletePhoto, let photo = event.photo {
            self.deletePhoto(photo)
        }
        if let music = event.music {
            deleteAudio(music)
        }
        save()
    }

    func savePhoto(_ raw: Data) -> String? {
        // GIF/WebP 动图必须保留原始数据，不能压成静态 JPEG。
        let isGif = raw.count >= 4
            && raw[0] == 0x47 && raw[1] == 0x49 && raw[2] == 0x46 && raw[3] == 0x38
        let isWebP = raw.count >= 12
            && raw[0] == 0x52 && raw[1] == 0x49 && raw[2] == 0x46 && raw[3] == 0x46
            && raw[8] == 0x57 && raw[9] == 0x45 && raw[10] == 0x42 && raw[11] == 0x50
        if isGif || isWebP {
            let ext = isGif ? "gif" : "webp"
            let name = UUID().uuidString + "." + ext
            do {
                try raw.write(to: photosURL.appendingPathComponent(name), options: [.atomic])
                if let first = UIImage(data: raw) {
                    imageCache.setObject(first, forKey: name as NSString)
                }
                return name
            } catch {
                return nil
            }
        }
        guard let image = UIImage(data: raw) else { return nil }
        let maxSide: CGFloat = 1800
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.84) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: photosURL.appendingPathComponent(name), options: [.atomic])
            imageCache.setObject(resized, forKey: name as NSString)
            return name
        } catch {
            return nil
        }
    }

    func requestPhotoLibraryAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited { return true }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    func originalImageData(for asset: PHAsset) async -> Data? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo }) else {
            return await imageData(for: asset)
        }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            var data = Data()
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { chunk in data.append(chunk) },
                completionHandler: { error in
                    continuation.resume(returning: error == nil && !data.isEmpty ? data : nil)
                }
            )
        }
    }

    func imageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    func photoURL(for name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        let url = photosURL.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isAnimatedPhoto(_ name: String?) -> Bool {
        guard let name else { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        return ext == "gif" || ext == "webp"
    }

    func image(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        let key = name as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: photosURL.appendingPathComponent(name).path) else {
            return nil
        }
        imageCache.setObject(image, forKey: key)
        return image
    }

    func deletePhoto(_ name: String?) {
        guard let name else { return }
        imageCache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: photosURL.appendingPathComponent(name))
    }

    func saveAudio(from source: URL, suggestedTitle: String?) -> (name: String, title: String)? {
        let access = source.startAccessingSecurityScopedResource()
        defer {
            if access { source.stopAccessingSecurityScopedResource() }
        }
        let ext = source.pathExtension.lowercased()
        let allowed = ["mp3", "m4a", "m4b", "aac", "wav", "ogg", "oga", "opus",
                       "flac", "amr", "aiff", "aif", "wma", "mid", "midi",
                       "mp4", "webm", "3gp", "spx", "mka", "mp2", "ac3"]
        guard allowed.contains(ext) else { return nil }
        let name = UUID().uuidString + "." + ext
        let target = audioURL.appendingPathComponent(name)
        do {
            let data = try Data(contentsOf: source)
            guard data.count > 0, data.count <= 80 * 1024 * 1024 else { return nil }
            try data.write(to: target, options: [.atomic])
            let rawTitle = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (rawTitle?.isEmpty == false ? rawTitle! : source.deletingPathExtension().lastPathComponent)
            return (name, title.isEmpty ? "这一天的声音" : title)
        } catch {
            return nil
        }
    }

    func audioURL(for name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        let url = audioURL.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func deleteAudio(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: audioURL.appendingPathComponent(name))
    }

    var homeEvents: [Anniversary] {
        let manual = data.anniversaries
            .filter { $0.manualOrder != nil }
            .sorted { ($0.manualOrder ?? 0) < ($1.manualOrder ?? 0) }
        let automatic = data.anniversaries
            .filter { $0.manualOrder == nil }
            .sorted { lhs, rhs in
                if lhs.daysUntil != rhs.daysUntil { return lhs.daysUntil < rhs.daysUntil }
                return lhs.date < rhs.date
            }
        return manual + automatic
    }
}

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedule(events: [Anniversary]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for event in events where event.reminderEnabled {
            let calendar = AppDate.calendar
            guard let reminderDate = calendar.date(
                byAdding: .day,
                value: -event.reminderDaysBefore,
                to: event.targetDate
            ) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            components.hour = event.reminderHour
            components.minute = event.reminderMinute
            components.second = 0
            guard let fireDate = calendar.date(from: components), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "念日 · \(event.title)"
            content.body = event.reminderDaysBefore == 0
                ? "今天就是这一天。"
                : "还有 \(event.reminderDaysBefore) 天。"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "nianri-\(event.id.uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request, withCompletionHandler: nil)
        }
    }
}
