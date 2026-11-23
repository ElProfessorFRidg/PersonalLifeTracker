import XCTest
@testable import PersonalLifeTracker

final class SendHoursReminderRulesTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris
    private let lastDay18: SendHoursReminderSettings = SendHoursReminderSettings.standard

    func testDefaultIsLastDayAtSixPM() {
        XCTAssertEqual(SendHoursReminderSettings.standard, SendHoursReminderSettings(dayOfMonth: 0, hour: 18, minute: 0))
    }

    func testNextFireIsLastDayOfThirtyDayMonth() {
        let next = SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 4, 5, 10, 0), settings: lastDay18, calendar: paris)
        XCTAssertEqual(next, makeDate(paris, 2026, 4, 30, 18, 0))
    }

    func testNextFireIsLastDayOfThirtyOneDayMonth() {
        let next = SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 10, 5, 10, 0), settings: lastDay18, calendar: paris)
        XCTAssertEqual(next, makeDate(paris, 2026, 10, 31, 18, 0))
    }

    func testNextFireInFebruaryOf28And29Days() {
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2027, 2, 10, 9, 0), settings: lastDay18, calendar: paris),
                       makeDate(paris, 2027, 2, 28, 18, 0))
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2028, 2, 10, 9, 0), settings: lastDay18, calendar: paris),
                       makeDate(paris, 2028, 2, 29, 18, 0))
    }

    func testFireMomentItselfMovesToNextMonth() {
        let atFire: Date = makeDate(paris, 2026, 11, 30, 18, 0)
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: atFire, settings: lastDay18, calendar: paris),
                       makeDate(paris, 2026, 12, 31, 18, 0))
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 11, 30, 19, 0), settings: lastDay18, calendar: paris),
                       makeDate(paris, 2026, 12, 31, 18, 0))
    }

    func testYearChange() {
        let next = SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 12, 31, 19, 0), settings: lastDay18, calendar: paris)
        XCTAssertEqual(next, makeDate(paris, 2027, 1, 31, 18, 0))
    }

    func testFixedDayBeforeAndAfterInTheMonth() {
        let s = SendHoursReminderSettings(dayOfMonth: 15, hour: 9, minute: 30)
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 11, 10, 8, 0), settings: s, calendar: paris),
                       makeDate(paris, 2026, 11, 15, 9, 30))
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 11, 20, 8, 0), settings: s, calendar: paris),
                       makeDate(paris, 2026, 12, 15, 9, 30))
    }

    func testDay31FallsBackToLastDayOfShortMonths() {
        let s = SendHoursReminderSettings(dayOfMonth: 31, hour: 18, minute: 0)
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2027, 2, 1, 8, 0), settings: s, calendar: paris),
                       makeDate(paris, 2027, 2, 28, 18, 0))
        XCTAssertEqual(SendHoursReminderRules.nextFireDate(after: makeDate(paris, 2026, 4, 1, 8, 0), settings: s, calendar: paris),
                       makeDate(paris, 2026, 4, 30, 18, 0))
    }

    func testUpcomingThreeDatesCrossTheYear() {
        let dates: [Date] = SendHoursReminderRules.upcomingFireDates(after: makeDate(paris, 2026, 11, 23, 10, 0), count: 3,
                                                                     settings: lastDay18, calendar: paris)
        let expected: [Date] = [makeDate(paris, 2026, 11, 30, 18, 0),
                                makeDate(paris, 2026, 12, 31, 18, 0),
                                makeDate(paris, 2027, 1, 31, 18, 0)]
        XCTAssertEqual(dates, expected)
    }

    func testUpcomingWithZeroCountIsEmpty() {
        XCTAssertEqual(SendHoursReminderRules.upcomingFireDates(after: makeDate(paris, 2026, 11, 23, 10, 0), count: 0,
                                                                settings: lastDay18, calendar: paris), [])
    }

    func testClampingOfOutOfRangeValues() {
        let s = SendHoursReminderSettings(dayOfMonth: 45, hour: 30, minute: 70).clamped
        XCTAssertEqual(s, SendHoursReminderSettings(dayOfMonth: 31, hour: 23, minute: 59))
        let negative = SendHoursReminderSettings(dayOfMonth: -3, hour: -1, minute: -5).clamped
        XCTAssertEqual(negative, SendHoursReminderSettings(dayOfMonth: 0, hour: 0, minute: 0))
    }

    func testBodyHasNoNumberAndNoEmDash() {
        XCTAssertNil(SendHoursReminderRules.body.rangeOfCharacter(from: CharacterSet.decimalDigits))
        XCTAssertFalse(SendHoursReminderRules.body.contains("\u{2014}"))
        XCTAssertEqual(SendHoursReminderRules.body, "C'est le moment d'envoyer tes heures.")
    }

    func testStoredSettingsDefaultAndRoundTrip() {
        let made = makeIsolatedDefaults()
        defer { made.defaults.removePersistentDomain(forName: made.name) }
        let scheduler = SendHoursReminderScheduler(defaults: made.defaults)
        XCTAssertEqual(scheduler.settings, SendHoursReminderSettings.standard)
        scheduler.save(SendHoursReminderSettings(dayOfMonth: 25, hour: 20, minute: 15))
        XCTAssertEqual(scheduler.settings, SendHoursReminderSettings(dayOfMonth: 25, hour: 20, minute: 15))
        scheduler.save(SendHoursReminderSettings(dayOfMonth: 99, hour: 99, minute: 99))
        XCTAssertEqual(scheduler.settings, SendHoursReminderSettings(dayOfMonth: 31, hour: 23, minute: 59))
    }
}
