import XCTest

final class UsageStatsTests: XCTestCase {
    private let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
    private let slack = URL(fileURLWithPath: "/Applications/Slack.app")
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, hour: Int = 12, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testCountsEachKindOfUse() {
        var log = UsageLog()
        log.record(.app(chrome), at: date(10, 1), calendar: calendar)
        log.record(.app(chrome), at: date(10, 1), calendar: calendar)
        log.record(.app(slack), at: date(10, 2), calendar: calendar)
        log.record(.windowMove, at: date(10, 2), calendar: calendar)
        log.record(.hyperKey, at: date(10, 3), calendar: calendar)

        let october = log.month(for: date(10, 15), calendar: calendar)
        XCTAssertEqual(october?.appSwitches, 3)
        XCTAssertEqual(october?.windowMoves, 1)
        XCTAssertEqual(october?.hyperKeys, 1)
        XCTAssertEqual(october?.total, 5)
        XCTAssertEqual(october?.days, [1, 2, 3])
    }

    func testKeepsMonthsApart() {
        var log = UsageLog()
        log.record(.app(chrome), at: date(9, 30), calendar: calendar)
        log.record(.app(chrome), at: date(10, 1), calendar: calendar)

        XCTAssertEqual(log.month(for: date(9, 1), calendar: calendar)?.appSwitches, 1)
        XCTAssertEqual(log.month(for: date(10, 1), calendar: calendar)?.appSwitches, 1)
        XCTAssertNil(log.month(for: date(11, 1), calendar: calendar))
        XCTAssertEqual(log.monthsUsed(calendar: calendar), [date(10, 1, hour: 0), date(9, 1, hour: 0)])
    }

    func testTopAppsAreMostUsedFirstAndAlphabeticalOnATie() {
        var month = MonthUsage()
        month.apps = ["/B.app": 2, "/A.app": 2, "/C.app": 5, "/D.app": 1]

        XCTAssertEqual(month.topApps(3).map(\.path), ["/C.app", "/A.app", "/B.app"])
        XCTAssertEqual(month.topApps(3).map(\.count), [5, 2, 2])
    }

    func testLongestStreakIsTheMostDaysInARow() {
        var month = MonthUsage()
        XCTAssertEqual(month.longestStreak, 0)
        month.days = [1, 2, 3, 5, 6, 7, 8, 30]
        XCTAssertEqual(month.longestStreak, 4)
    }

    func testBusiestHourAndWeekday() {
        var log = UsageLog()
        XCTAssertNil(log.month(for: date(10, 1), calendar: calendar)?.busiestHour)
        // 27 October 2026 is a Tuesday.
        log.record(.app(chrome), at: date(10, 27, hour: 10), calendar: calendar)
        log.record(.app(chrome), at: date(10, 27, hour: 10), calendar: calendar)
        log.record(.app(chrome), at: date(10, 28, hour: 15), calendar: calendar)

        let october = log.month(for: date(10, 1), calendar: calendar)
        XCTAssertEqual(october?.busiestHour, 10)
        XCTAssertEqual(october?.busiestWeekday, 3)
    }

    func testKeepsOnlyTheLatestMonths() {
        var log = UsageLog()
        for month in 1...12 {
            log.record(.windowMove, at: date(month, 1, year: 2025), calendar: calendar)
        }
        log.record(.windowMove, at: date(1, 1), calendar: calendar)
        log.record(.windowMove, at: date(2, 1), calendar: calendar)

        XCTAssertEqual(log.monthsUsed(calendar: calendar).count, UsageLog.monthsKept)
        XCTAssertNil(log.month(for: date(1, 1, year: 2025), calendar: calendar))
        XCTAssertNotNil(log.month(for: date(2, 1, year: 2025), calendar: calendar))
    }

    func testSurvivesSavingAndLoading() throws {
        var log = UsageLog()
        log.record(.app(chrome), at: date(10, 1), calendar: calendar)
        let loaded = try JSONDecoder().decode(UsageLog.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(loaded, log)
    }
}
