import Foundation

/// A shortcut use worth counting for the month card.
enum UsageEvent: Equatable {
    /// Hyper + a letter opened or hid this app.
    case app(URL)
    case windowMove
    /// Hyper + a key without a shortcut, sent on as ⌃⌥⇧⌘ + key.
    case hyperKey
}

/// One month of shortcut use: only counts, never which keys were typed.
struct MonthUsage: Codable, Equatable {
    /// Times each app was switched to or hidden, by the app's path.
    var apps: [String: Int] = [:]
    var windowMoves = 0
    var hyperKeys = 0
    /// Days of the month with any use, 1–31.
    var days: Set<Int> = []
    /// Uses per hour of the day, 0–23.
    var hours = [Int](repeating: 0, count: 24)
    /// Uses per weekday, 1 (Sunday) to 7 as in `Calendar`, at index weekday − 1.
    var weekdays = [Int](repeating: 0, count: 7)

    var appSwitches: Int { apps.values.reduce(0, +) }
    var total: Int { appSwitches + windowMoves + hyperKeys }

    /// The most used apps, most first; ties go alphabetically so the card doesn't change between opens.
    func topApps(_ count: Int) -> [(path: String, count: Int)] {
        apps.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(count)
            .map { (path: $0.key, count: $0.value) }
    }

    /// The most days in a row with any use.
    var longestStreak: Int {
        var longest = 0
        var current = 0
        for day in 1...31 {
            current = days.contains(day) ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }

    /// The hour (0–23) with the most use, or nil before any.
    var busiestHour: Int? { Self.busiest(hours) }

    /// The weekday (1 = Sunday … 7) with the most use, or nil before any.
    var busiestWeekday: Int? { Self.busiest(weekdays).map { $0 + 1 } }

    /// The index with the highest count, the earliest on a tie.
    private static func busiest(_ counts: [Int]) -> Int? {
        guard let top = counts.max(), top > 0 else { return nil }
        return counts.firstIndex(of: top)
    }
}

/// Shortcut use by month, kept on this Mac for the month card.
struct UsageLog: Codable, Equatable {
    /// How many months are kept, this one included.
    static let monthsKept = 13

    /// By month, e.g. "2026-10".
    private(set) var months: [String: MonthUsage] = [:]

    mutating func record(_ event: UsageEvent, at date: Date, calendar: Calendar = .current) {
        let key = Self.monthKey(for: date, calendar: calendar)
        var month = months[key] ?? MonthUsage()
        switch event {
        case .app(let appURL): month.apps[appURL.path, default: 0] += 1
        case .windowMove: month.windowMoves += 1
        case .hyperKey: month.hyperKeys += 1
        }
        let parts = calendar.dateComponents([.day, .hour, .weekday], from: date)
        if let day = parts.day { month.days.insert(day) }
        if let hour = parts.hour, month.hours.indices.contains(hour) { month.hours[hour] += 1 }
        if let weekday = parts.weekday, month.weekdays.indices.contains(weekday - 1) { month.weekdays[weekday - 1] += 1 }
        months[key] = month
        prune()
    }

    func month(for date: Date, calendar: Calendar = .current) -> MonthUsage? {
        months[Self.monthKey(for: date, calendar: calendar)]
    }

    /// Months with any use, newest first, as the first day of each month.
    func monthsUsed(calendar: Calendar = .current) -> [Date] {
        months.keys.sorted(by: >).compactMap { key in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
        }
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// Drops the oldest months beyond `monthsKept`. Keys sort by date since they're zero-padded.
    private mutating func prune() {
        for key in months.keys.sorted(by: >).dropFirst(Self.monthsKept) {
            months[key] = nil
        }
    }
}
