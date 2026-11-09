import Foundation
import Combine
import SwiftUI

struct MoodOption: Identifiable, Equatable {
    let key: String
    let label: String
    let color: Color

    var id: String { key }
}

enum MoodCatalog {
    static let all: [MoodOption] = [
        MoodOption(key: "happy", label: "开心", color: Color(hex: 0xB58A5A)),
        MoodOption(key: "calm", label: "平静", color: Color(hex: 0x6F8C70)),
        MoodOption(key: "tired", label: "累了", color: Color(hex: 0x8A7B5B)),
        MoodOption(key: "low", label: "低落", color: Color(hex: 0x6E7890)),
        MoodOption(key: "anxious", label: "焦虑", color: Color(hex: 0xA87076)),
        MoodOption(key: "grateful", label: "感恩", color: Color(hex: 0x8A6B75)),
    ]

    static func option(_ key: String?) -> MoodOption? {
        guard let key else { return nil }
        return all.first { $0.key == key }
    }
}

enum DailyCopy {
    static let all = [
        "认真生活的人，自带光。",
        "把喜欢藏进岁月，把陪伴过成日常。",
        "慢一点，也是在好好生活。",
        "今天也有值得记住的小事。",
        "日子普通，但你把它过得认真。",
        "不必事事圆满，舒服就好。",
        "把小事做好，把今天过好。",
        "风会记得花的香，日子会记得你的认真。",
        "允许自己休息，也是一种前进。",
        "愿今天有小小的惊喜，也有稳稳的安心。",
    ]

    static func today() -> String {
        all[abs(AppDate.today) % all.count]
    }
}

enum PeriodCopy {
    static let all = [
        "身体有自己的节律，慢一点也没关系。",
        "这几天，先把自己放在第一位。",
        "不必逞强，休息也是在好好生活。",
        "记录不是为了焦虑，而是更懂自己。",
        "愿你有热水、有软枕，也有一点点被照顾的感觉。",
        "经期不是需要被纠正的日子，只是需要被温柔对待。",
        "今天的任务只有一个：舒服一点。",
        "累的时候就停一停，日子不会因此落下。",
    ]

    static func today() -> String {
        all[abs(AppDate.today) % all.count]
    }
}

struct LedgerCategoryInfo: Identifiable {
    let name: String
    let color: Color

    var id: String { name }
}

enum LedgerCatalog {
    static let expense: [LedgerCategoryInfo] = [
        LedgerCategoryInfo(name: "餐饮", color: Color(hex: 0xB05238)),
        LedgerCategoryInfo(name: "交通", color: Color(hex: 0x5B7285)),
        LedgerCategoryInfo(name: "购物", color: Color(hex: 0xA07062)),
        LedgerCategoryInfo(name: "日用", color: Color(hex: 0x8A8B5C)),
        LedgerCategoryInfo(name: "娱乐", color: Color(hex: 0x7C6E9E)),
        LedgerCategoryInfo(name: "医疗", color: Color(hex: 0xA96F73)),
        LedgerCategoryInfo(name: "学习", color: Color(hex: 0x5F7C6A)),
        LedgerCategoryInfo(name: "人情", color: Color(hex: 0xB58A5A)),
        LedgerCategoryInfo(name: "住房", color: Color(hex: 0x5E6E7E)),
        LedgerCategoryInfo(name: "通讯", color: Color(hex: 0x6F8A8A)),
        LedgerCategoryInfo(name: "服饰", color: Color(hex: 0x9A6F86)),
        LedgerCategoryInfo(name: "美容", color: Color(hex: 0xB07A7A)),
        LedgerCategoryInfo(name: "宠物", color: Color(hex: 0x8A7B5B)),
        LedgerCategoryInfo(name: "旅行", color: Color(hex: 0x5F7F8F)),
        LedgerCategoryInfo(name: "数码", color: Color(hex: 0x6E6A86)),
        LedgerCategoryInfo(name: "其他", color: Color(hex: 0x8E8780)),
    ]

    static let income: [LedgerCategoryInfo] = [
        LedgerCategoryInfo(name: "工资", color: Color(hex: 0x6F8C70)),
        LedgerCategoryInfo(name: "奖金", color: Color(hex: 0xB58A5A)),
        LedgerCategoryInfo(name: "兼职", color: Color(hex: 0x5B7285)),
        LedgerCategoryInfo(name: "理财", color: Color(hex: 0x7C6E9E)),
        LedgerCategoryInfo(name: "红包", color: Color(hex: 0xB05238)),
        LedgerCategoryInfo(name: "报销", color: Color(hex: 0x6F8A8A)),
        LedgerCategoryInfo(name: "礼金", color: Color(hex: 0xA07062)),
        LedgerCategoryInfo(name: "退款", color: Color(hex: 0x8A8B5C)),
        LedgerCategoryInfo(name: "分红", color: Color(hex: 0x5F7C6A)),
        LedgerCategoryInfo(name: "其他", color: Color(hex: 0x8E8780)),
    ]

    static func categories(income isIncome: Bool) -> [LedgerCategoryInfo] {
        isIncome ? income : expense
    }

    static func normalized(_ name: String, income: Bool) -> String {
        let value = name == "生活" ? "日用" : name
        return categories(income: income).contains { $0.name == value } ? value : "其他"
    }

    static func option(_ name: String, income: Bool) -> LedgerCategoryInfo {
        let normalizedName = normalized(name, income: income)
        return categories(income: income).first { $0.name == normalizedName }
            ?? LedgerCategoryInfo(name: "其他", color: Color(hex: 0x8E8780))
    }
}

struct WeatherSnapshot: Codable, Equatable {
    var city: String
    var temperature: Double
    var code: Int
    var max: Double
    var min: Double
    var updatedAt: Date
    var latitude: Double? = nil
    var longitude: Double? = nil
}

struct WeatherPlace: Decodable, Identifiable, Equatable {
    let name: String
    let admin1: String?
    let admin2: String?
    let latitude: Double
    let longitude: Double

    var id: String { "\(name)|\(admin2 ?? "")|\(latitude)|\(longitude)" }

    var displayName: String {
        var parts = [name]
        if let admin2, !admin2.isEmpty, admin2 != name { parts.append(admin2) }
        if let admin1, !admin1.isEmpty, admin1 != name, admin1 != admin2 { parts.append(admin1) }
        return parts.joined(separator: " · ")
    }
}

final class WeatherStore: ObservableObject {
    @Published var snapshot: WeatherSnapshot?
    @Published var loading = false
    @Published var error: String?
    @Published var searchResults: [WeatherPlace] = []
    @Published var searching = false

    private let key = "nianri.ios.weather"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) {
            snapshot = decoded
        }
    }

    var isStale: Bool {
        guard let updatedAt = snapshot?.updatedAt else { return true }
        return Date().timeIntervalSince(updatedAt) > 30 * 60
    }

    @MainActor
    func search(_ query: String) async {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            searchResults = []
            return
        }
        searching = true
        error = nil
        defer { searching = false }
        do {
            searchResults = try await geocode(clean, count: 10)
            if searchResults.isEmpty {
                error = "没有找到这个地点，试试「区名 + 城市」。"
            }
        } catch {
            self.error = "地点搜索失败，检查网络后再试。"
        }
    }

    @MainActor
    func configure(city: String) async {
        let clean = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        loading = true
        error = nil
        do {
            let places = try await geocode(clean, count: 10)
            guard let place = places.first else {
                error = "没有找到这个城市，换个写法试试。"
                loading = false
                return
            }
            await configure(place: place)
        } catch {
            self.error = "天气暂时不可用，检查网络后再试。"
            loading = false
        }
    }

    @MainActor
    func configure(place: WeatherPlace) async {
        loading = true
        error = nil
        do {
            let forecast = try await forecast(latitude: place.latitude, longitude: place.longitude)
            guard let current = forecast.current,
                  let daily = forecast.daily,
                  let temp = current.temperature_2m,
                  let code = current.weather_code,
                  let maxValue = daily.temperature_2m_max?.first,
                  let minValue = daily.temperature_2m_min?.first else {
                error = "暂时没有拿到天气数据。"
                loading = false
                return
            }
            let value = WeatherSnapshot(
                city: place.displayName,
                temperature: temp,
                code: code,
                max: maxValue,
                min: minValue,
                updatedAt: Date(),
                latitude: place.latitude,
                longitude: place.longitude
            )
            snapshot = value
            if let data = try? JSONEncoder().encode(value) {
                UserDefaults.standard.set(data, forKey: key)
            }
            loading = false
        } catch {
            self.error = "天气暂时不可用，检查网络后再试。"
            loading = false
        }
    }

    @MainActor
    func refresh() async {
        if let snapshot, let latitude = snapshot.latitude, let longitude = snapshot.longitude {
            await configure(place: WeatherPlace(
                name: snapshot.city,
                admin1: nil,
                admin2: nil,
                latitude: latitude,
                longitude: longitude
            ))
        } else if let city = snapshot?.city, !city.isEmpty {
            await configure(city: city)
        }
    }

    private func geocode(_ city: String, count: Int) async throws -> [WeatherPlace] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: city),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(GeoResponse.self, from: data)
        return decoded.results ?? []
    }

    private func forecast(latitude: Double, longitude: Double) async throws -> ForecastResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }
}

private struct GeoResponse: Decodable {
    let results: [WeatherPlace]?
}

private struct ForecastResponse: Decodable {
    let current: Current?
    let daily: Daily?
}

private struct Current: Decodable {
    let temperature_2m: Double?
    let weather_code: Int?
}

private struct Daily: Decodable {
    let temperature_2m_max: [Double]?
    let temperature_2m_min: [Double]?
}

extension WeatherSnapshot {
    var summary: String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "晴间多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55, 56, 57: return "毛毛雨"
        case 61, 63, 65, 66, 67: return "雨"
        case 71, 73, 75, 77: return "雪"
        case 80, 81, 82: return "阵雨"
        case 85, 86: return "阵雪"
        case 95, 96, 99: return "雷雨"
        default: return "多云"
        }
    }

    var tip: String {
        switch code {
        case 0, 1, 2: return "光线很好，适合慢慢走。"
        case 3, 45, 48: return "云层很软，记得带件外套。"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82: return "出门记得带伞，路上慢一点。"
        case 71, 73, 75, 77, 85, 86: return "有雪，注意保暖和路滑。"
        case 95, 96, 99: return "有雷雨，尽量待在室内。"
        default: return "照顾好自己，慢慢来。"
        }
    }
}
