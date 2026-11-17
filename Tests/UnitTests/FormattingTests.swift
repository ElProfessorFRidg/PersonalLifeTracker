import XCTest
@testable import PersonalLifeTracker

final class FormattingTests: XCTestCase {
    func testDurationFormatsFromSpecExamples() {
        XCTAssertEqual(Formatting.duration(minutes: 184), "3 h 04")
        XCTAssertEqual(Formatting.duration(minutes: 25), "25 min")
    }

    func testDurationEdgeCases() {
        XCTAssertEqual(Formatting.duration(minutes: 0), "0 min")
        XCTAssertEqual(Formatting.duration(minutes: 59), "59 min")
        XCTAssertEqual(Formatting.duration(minutes: 60), "1 h 00")
        XCTAssertEqual(Formatting.duration(minutes: 240), "4 h 00")
        XCTAssertEqual(Formatting.duration(minutes: -5), "0 min")
    }

    func testDurationFromSecondsTruncatesToTheMinute() {
        // 3 h 04 min 59 s = 11099 s
        XCTAssertEqual(Formatting.duration(seconds: 11099), "3 h 04")
        XCTAssertEqual(Formatting.duration(seconds: 59), "0 min")
    }

    func testClockFromMinutes() {
        XCTAssertEqual(Formatting.clock(minutesFromMidnight: 485), "08:05")
        XCTAssertEqual(Formatting.clock(minutesFromMidnight: 0), "00:00")
        XCTAssertEqual(Formatting.clock(minutesFromMidnight: 1440), "24:00")
        XCTAssertEqual(Formatting.clock(hour: 17.5), "17:30")
    }

    func testClockFromDateUsesCalendarTimeZone() {
        XCTAssertEqual(Formatting.clock(nov16(17, 56), calendar: TestCalendar.utc), "17:56")
        // 17:56 UTC en novembre est 18:56 à Paris (heure d'hiver, UTC+1).
        XCTAssertEqual(Formatting.clock(nov16(17, 56), calendar: TestCalendar.paris), "18:56")
    }

    func testTimer() {
        XCTAssertEqual(Formatting.timer(seconds: 4447), "1:14:07")
        XCTAssertEqual(Formatting.timer(seconds: 847), "14:07")
        XCTAssertEqual(Formatting.timer(seconds: 7), "0:07")
    }

    func testMargin() {
        XCTAssertEqual(Formatting.margin(minutes: 3), "à plus ou moins 3 min")
    }

    func testDayTitleInFrench() {
        XCTAssertEqual(Formatting.dayTitle(nov16(12, 0), calendar: TestCalendar.utc), "lundi 16 novembre")
    }
}
