import XCTest
@testable import PersonalLifeTracker

final class PlanningPhotoLayoutTests: XCTestCase {
    func testNumberedWeekWithMorningAndAfternoonColumnsProducesOnlyTheSelectedShifts() {
        let calendar = TestCalendar.paris
        // Reproduction géométrique anonymisée du tableau, sans photo ni noms réels.
        func line(_ string: String, _ x: Double, _ y: Double) -> OCRTextLine {
            OCRTextLine(text: string, minX: x - 0.026, minY: y, width: 0.052, height: 0.017)
        }
        let weekdays = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
        var lines = [line("Semaine 48/2026", 0.52, 0.03), line("Non publiée", 0.52, 0.063),
                     line("Autre salarié", 0.08, 0.32), line("Camille", 0.08, 0.44),
                     line("Exemple", 0.08, 0.458)]
        for (index, weekday) in weekdays.enumerated() {
            let center = 0.19 + Double(index) * 0.12
            lines += [
                line(weekday, center, 0.18),
                line("Matin", center - 0.03, 0.24), line("Après-midi", center + 0.03, 0.24),
                line("08:00-12:00", center - 0.03, 0.32), line("Repos", center + 0.03, 0.32),
                line(index == 4 ? "07:00-12:00" : "Repos", center - 0.03, 0.44),
                line(index == 5 ? "14:00-22:00" : "Repos", center + 0.03, 0.44)
            ]
        }
        let reference = makeDate(calendar, 2026, 11, 30, 12, 0)
        let options = ScheduleParseOptions(names: ["Camille Exemple"], referenceDate: reference, calendar: calendar)
        let result = ScheduleTextParser.parse(lines: lines, options: options)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.chosenRowIndex.map { result.rowNames[$0] }, "Camille Exemple")
        XCTAssertEqual(result.weekStart, makeDate(calendar, 2026, 11, 23, 0, 0))
        XCTAssertEqual(result.shifts.map { calendar.component(.day, from: $0.day) }, [27, 28])
        XCTAssertEqual(result.shifts.map(\.startMinutes), [420, 840])
        XCTAssertEqual(result.shifts.map(\.endMinutes), [720, 1320])
        XCTAssertEqual(result.restDays.count, 5)
        XCTAssertTrue(result.unreadable.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("Non publiée") })
    }
}
