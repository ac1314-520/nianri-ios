import Foundation

struct LunarDate: Codable, Equatable {
    var year: Int
    var month: Int
    var day: Int
    var leap: Bool = false

    var shortLabel: String {
        "\(leap ? "闰" : "")\(LunarCalendar.monthName(month))\(LunarCalendar.dayName(day))"
    }

    var fullLabel: String { "\(year)年\(shortLabel)" }
}

/// 用 Foundation 的中国日历换算公历/农历。
/// 年份标签仍用公历年份（2024 年农历），不暴露 60 年循环。
enum LunarCalendar {
    private static let chinese: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()

    private static var newYearCache: [Int: Date] = [:]

    private static let monthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月",
    ]
    private static let dayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
    ]

    static func monthName(_ month: Int) -> String {
        monthNames.indices.contains(month - 1) ? monthNames[month - 1] : "\(month)月"
    }

    static func dayName(_ day: Int) -> String {
        dayNames.indices.contains(day - 1) ? dayNames[day - 1] : "\(day)"
    }

    static func chineseNewYear(_ year: Int) -> Date? {
        if let cached = newYearCache[year] { return cached }
        guard year >= 1900, year <= 2100 else { return nil }
        guard let jan1 = gregorian.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return nil
        }
        for offset in 0..<60 {
            guard let date = gregorian.date(byAdding: .day, value: offset, to: jan1) else { continue }
            let parts = chinese.dateComponents([.month, .day], from: date)
            if parts.month == 1, parts.day == 1 {
                newYearCache[year] = date
                return date
            }
        }
        return nil
    }

    static func fromSolar(_ date: Date) -> LunarDate? {
        let solarYear = gregorian.component(.year, from: date)
        guard solarYear >= 1900, solarYear <= 2100 else { return nil }
        guard let cny = chineseNewYear(solarYear) else { return nil }
        let lunarYear = date >= cny ? solarYear : solarYear - 1
        let parts = chinese.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return nil }
        return LunarDate(
            year: lunarYear,
            month: month,
            day: day,
            leap: parts.isLeapMonth ?? false
        )
    }

    static func toSolar(_ lunar: LunarDate) -> Date? {
        guard lunar.year >= 1900, lunar.year <= 2100,
              (1...12).contains(lunar.month), (1...30).contains(lunar.day),
              let cny = chineseNewYear(lunar.year) else { return nil }
        let cycleYear = chinese.component(.year, from: cny)
        var parts = DateComponents()
        parts.year = cycleYear
        parts.month = lunar.month
        parts.day = lunar.day
        parts.isLeapMonth = lunar.leap
        guard let date = chinese.date(from: parts),
              let check = fromSolar(date),
              check.year == lunar.year,
              check.month == lunar.month,
              check.day == lunar.day,
              check.leap == lunar.leap else { return nil }
        return date
    }

    static func leapMonth(of year: Int) -> Int? {
        for month in 1...12 {
            if toSolar(LunarDate(year: year, month: month, day: 1, leap: true)) != nil {
                return month
            }
        }
        return nil
    }

    static func daysInMonth(year: Int, month: Int, leap: Bool) -> Int {
        (29...30).last { toSolar(LunarDate(year: year, month: month, day: $0, leap: leap)) != nil } ?? 29
    }

    static func nextOccurrence(of lunar: LunarDate, after date: Date) -> Date? {
        let startYear = fromSolar(date)?.year ?? gregorian.component(.year, from: date)
        for year in startYear...min(2100, startYear + 30) {
            guard let candidate = toSolar(LunarDate(
                year: year,
                month: lunar.month,
                day: lunar.day,
                leap: lunar.leap
            )) else { continue }
            if candidate >= date { return candidate }
        }
        if lunar.leap {
            var regular = lunar
            regular.leap = false
            return nextOccurrence(of: regular, after: date)
        }
        return nil
    }
}
