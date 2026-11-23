import XCTest
@testable import PersonalLifeTracker

final class PlanningMessageParserTests: XCTestCase {
    func testReadsAWeekOfMessageShiftsAndLeavesDaysOffUnchanged() {
        let calendar = TestCalendar.paris
        let week = makeDate(calendar, 2026, 11, 20, 11, 0)
        let text = """
        Ven. : de 6h à 10h
        Samedi 8h–12h / 14h–18h
        22/11 14h00/19h00
        Lundi OFF
        """
        let result = PlanningMessageParser.read(text, week: week, calendar: calendar)
        XCTAssertEqual(result.entries.map { calendar.component(.day, from: $0.day) }, [20, 21, 22])
        XCTAssertEqual(result.entries.flatMap(\.ranges).map(\.startMinutes), [360, 480, 840, 840])
        XCTAssertEqual(result.entries.flatMap(\.ranges).map(\.endMinutes), [600, 720, 1080, 1140])
        XCTAssertEqual(result.skippedLines, [])
    }

    func testSeparatesUnreadableLinesAndMarksAnOvernightShift() {
        let calendar = TestCalendar.paris
        let week = makeDate(calendar, 2026, 11, 20, 11, 0)
        let text = """
        Dimanche 22–02
        Vendredi 6–9 / 14–88
        29/11 8h–12h
        Samedi 8h–12h Marc
        """
        let result = PlanningMessageParser.read(text, week: week, calendar: calendar)
        XCTAssertEqual(result.entries.flatMap(\.ranges), [
            ShiftTimeRange(startMinutes: 1320, endMinutes: 1560, crossesMidnight: true)
        ])
        XCTAssertEqual(result.skippedLines, ["Vendredi 6–9 / 14–88", "29/11 8h–12h", "Samedi 8h–12h Marc"])
    }
}
