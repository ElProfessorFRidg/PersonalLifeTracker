import XCTest
@testable import PersonalLifeTracker

final class HoursSummaryTextTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris

    private func input(_ activity: ActivityType, _ start: Date, _ end: Date,
                       chosenEnd: Date? = nil) -> DaySessionInput {
        return DaySessionInput(start: start, end: end, activity: activity, chosenStart: nil, chosenEnd: chosenEnd)
    }

    private var now: Date { return makeDate(paris, 2026, 11, 23, 12, 0) }

    func testWeekInExactBase() {
        let inputs: [DaySessionInput] = [
            input(.work, makeDate(paris, 2026, 11, 16, 8, 0), makeDate(paris, 2026, 11, 16, 11, 4)),
            input(.education, makeDate(paris, 2026, 11, 16, 13, 0), makeDate(paris, 2026, 11, 16, 16, 57)),
            input(.work, makeDate(paris, 2026, 11, 18, 9, 0), makeDate(paris, 2026, 11, 18, 12, 30))
        ]
        let text: String = HoursSummaryText.build(period: .week, reference: makeDate(paris, 2026, 11, 18, 10, 0),
                                                  inputs: inputs, base: .exact, now: now, calendar: paris)
        let expected: String = [
            "Mes heures, du lun. 16 nov. au dim. 22 nov. 2026",
            "lun. 16 nov. : Taf 3 h 04 · Cours 3 h 57",
            "mer. 18 nov. : Taf 3 h 30",
            "Total : Taf 6 h 34 · Cours 3 h 57",
            "Base de calcul : heure exacte"
        ].joined(separator: "\n")
        XCTAssertEqual(text, expected)
    }

    func testWeekInFullHoursWithChoiceAndUnresolvedDoubt() {
        let inputs: [DaySessionInput] = [
            // 11:04 arrondi à 11:00 : 3 h 00
            input(.work, makeDate(paris, 2026, 11, 16, 8, 0), makeDate(paris, 2026, 11, 16, 11, 4)),
            // 12:30 en zone de doute, choix 13:00 : 4 h 00
            input(.work, makeDate(paris, 2026, 11, 18, 9, 0), makeDate(paris, 2026, 11, 18, 12, 30),
                  chosenEnd: makeDate(paris, 2026, 11, 18, 13, 0)),
            // 12:30 sans choix : valeur exacte 3 h 30, à confirmer
            input(.work, makeDate(paris, 2026, 11, 19, 9, 0), makeDate(paris, 2026, 11, 19, 12, 30))
        ]
        let text: String = HoursSummaryText.build(period: .week, reference: makeDate(paris, 2026, 11, 17, 10, 0),
                                                  inputs: inputs, base: .fullHours, now: now, calendar: paris)
        let expected: String = [
            "Mes heures, du lun. 16 nov. au dim. 22 nov. 2026",
            "lun. 16 nov. : Taf 3 h 00",
            "mer. 18 nov. : Taf 4 h 00",
            "jeu. 19 nov. : Taf 3 h 30 (à confirmer)",
            "Total : Taf 10 h 30 (à confirmer)",
            "Base de calcul : heures pleines"
        ].joined(separator: "\n")
        XCTAssertEqual(text, expected)
    }

    func testMonthIgnoresOtherMonths() {
        let inputs: [DaySessionInput] = [
            input(.work, makeDate(paris, 2026, 10, 30, 8, 0), makeDate(paris, 2026, 10, 30, 10, 0)),
            input(.work, makeDate(paris, 2026, 11, 2, 8, 0), makeDate(paris, 2026, 11, 2, 10, 0))
        ]
        let text: String = HoursSummaryText.build(period: .month, reference: makeDate(paris, 2026, 11, 20, 10, 0),
                                                  inputs: inputs, base: .exact, now: now, calendar: paris)
        let expected: String = [
            "Mes heures, novembre 2026",
            "lun. 2 nov. : Taf 2 h 00",
            "Total : Taf 2 h 00",
            "Base de calcul : heure exacte"
        ].joined(separator: "\n")
        XCTAssertEqual(text, expected)
    }

    func testEmptyPeriod() {
        let text: String = HoursSummaryText.build(period: .month, reference: makeDate(paris, 2026, 11, 20, 10, 0),
                                                  inputs: [], base: .exact, now: now, calendar: paris)
        XCTAssertEqual(text, "Mes heures, novembre 2026\nAucune heure sur cette période.")
    }

    func testDaylightSavingDayCountsRealElapsedTime() {
        // Dimanche 29 mars 2026 : 02:00 saute à 03:00, donc 01:00 à 04:00 ne dure que 2 h.
        let inputs: [DaySessionInput] = [
            input(.work, makeDate(paris, 2026, 3, 29, 1, 0), makeDate(paris, 2026, 3, 29, 4, 0))
        ]
        let text: String = HoursSummaryText.build(period: .week, reference: makeDate(paris, 2026, 3, 25, 10, 0),
                                                  inputs: inputs, base: .exact, now: now, calendar: paris)
        XCTAssertTrue(text.hasPrefix("Mes heures, du lun. 23 mars au dim. 29 mars 2026\n"))
        XCTAssertTrue(text.contains("dim. 29 mars : Taf 2 h 00"))
    }

    func testNeverMentionsMoney() {
        let inputs: [DaySessionInput] = [
            input(.work, makeDate(paris, 2026, 11, 16, 8, 0), makeDate(paris, 2026, 11, 16, 10, 0))
        ]
        let text: String = HoursSummaryText.build(period: .week, reference: makeDate(paris, 2026, 11, 16, 10, 0),
                                                  inputs: inputs, base: .fullHours, now: now, calendar: paris)
        XCTAssertFalse(text.contains("€"))
        XCTAssertFalse(text.contains("brut"))
    }
}
