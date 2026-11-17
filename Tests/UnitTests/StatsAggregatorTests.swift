import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues écrites à la main (UTC). Le lundi 16 novembre 2026 est un lundi (voir TestSupport).
final class StatsAggregatorTests: XCTestCase {
    private let cal: Calendar = TestCalendar.utc

    private func d(_ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        return makeDate(cal, 2026, 11, day, h, min)
    }

    private func input(_ activity: ActivityType, _ start: Date, _ end: Date?) -> DaySessionInput {
        return DaySessionInput(start: start, end: end, activity: activity)
    }

    // MARK: périodes

    func testWeekRangeStartsOnMonday() {
        let wednesday = StatsAggregator.range(period: .week, reference: d(18, 15, 0), calendar: cal)
        XCTAssertEqual(wednesday.start, d(16))
        XCTAssertEqual(wednesday.end, d(23))
        let monday = StatsAggregator.range(period: .week, reference: d(16, 0, 0), calendar: cal)
        XCTAssertEqual(monday.start, d(16))
        let sunday = StatsAggregator.range(period: .week, reference: d(22, 23, 59), calendar: cal)
        XCTAssertEqual(sunday.start, d(16))
        XCTAssertEqual(sunday.end, d(23))
        let previousSunday = StatsAggregator.range(period: .week, reference: d(15, 12, 0), calendar: cal)
        XCTAssertEqual(previousSunday.start, d(9))
    }

    func testMonthRange() {
        let r = StatsAggregator.range(period: .month, reference: d(18, 15, 0), calendar: cal)
        XCTAssertEqual(r.start, d(1))
        XCTAssertEqual(r.end, makeDate(cal, 2026, 12, 1, 0, 0))
    }

    func testShifted() {
        XCTAssertEqual(StatsAggregator.shifted(reference: d(18), period: .week, by: -1, calendar: cal), d(11))
        XCTAssertEqual(StatsAggregator.shifted(reference: d(18), period: .month, by: -1, calendar: cal), makeDate(cal, 2026, 10, 18, 0, 0))
        XCTAssertEqual(StatsAggregator.shifted(reference: d(18), period: .week, by: 1, calendar: cal), d(25))
    }

    // MARK: agrégation

    private func weekInputs() -> [DaySessionInput] {
        return [
            input(.work, d(16, 8, 5), d(16, 12, 2)),        // lundi : 08:00 à 12:00 = 4 h, exact 3 h 57 = 14220 s
            input(.education, d(16, 13, 0), d(16, 15, 0)),  // lundi : 2 h de cours
            input(.work, d(17, 22, 0), d(18, 2, 0)),        // mardi 2 h, mercredi 2 h
            input(.work, d(21, 17, 56), d(21, 21, 20)),     // samedi : fin en zone de doute, exact 3 h 24 = 12240 s
            input(.work, d(15, 8, 0), d(15, 12, 0)),        // dimanche d'avant : hors semaine
            input(.shopping, d(19, 12, 0), d(19, 13, 0))    // courses : jamais comptées
        ]
    }

    func testWeekTotalsFullHours() {
        let r = StatsAggregator.aggregate(period: .week, reference: d(18, 10, 0), inputs: weekInputs(),
                                          base: .fullHours, now: d(22, 12, 0), calendar: cal)
        XCTAssertEqual(r.days.count, 7)
        XCTAssertEqual(r.start, d(16))
        XCTAssertEqual(r.end, d(23))
        // Taf : 14400 (lundi) + 7200 (mardi) + 7200 (mercredi) + 12240 (samedi, exact car doute) = 41040
        XCTAssertEqual(r.workSeconds, 41040)
        // Exact : 14220 + 7200 + 7200 + 12240 = 40860
        XCTAssertEqual(r.workExactSeconds, 40860)
        XCTAssertEqual(r.studySeconds, 7200)
        XCTAssertEqual(r.studyExactSeconds, 7200)
        XCTAssertEqual(r.workDayCount, 4)
        XCTAssertEqual(r.studyDayCount, 1)
        XCTAssertTrue(r.hasProvisional)
        XCTAssertFalse(r.hasLive)
        XCTAssertFalse(r.isEmpty)
        XCTAssertEqual(r.days[0].workSeconds, 14400)
        XCTAssertEqual(r.days[0].studySeconds, 7200)
        XCTAssertEqual(r.days[1].workSeconds, 7200)
        XCTAssertEqual(r.days[2].workSeconds, 7200)
        XCTAssertEqual(r.days[3].totalSeconds, 0)            // jeudi 19 : seulement des courses
        XCTAssertTrue(r.days[5].isProvisional)               // samedi 21
        XCTAssertEqual(r.maxDaySeconds, 21600)               // lundi : 4 h + 2 h
    }

    func testWeekTotalsExactBase() {
        let r = StatsAggregator.aggregate(period: .week, reference: d(18, 10, 0), inputs: weekInputs(),
                                          base: .exact, now: d(22, 12, 0), calendar: cal)
        XCTAssertEqual(r.workSeconds, 40860)
        XCTAssertEqual(r.workExactSeconds, 40860)
        XCTAssertFalse(r.hasProvisional)
    }

    func testMonthHasThirtyDaysAndCountsWholeMonth() {
        let r = StatsAggregator.aggregate(period: .month, reference: d(18, 10, 0), inputs: weekInputs(),
                                          base: .fullHours, now: d(22, 12, 0), calendar: cal)
        XCTAssertEqual(r.days.count, 30)
        // Même taf que la semaine plus le dimanche 15 : 4 h = 14400, soit 41040 + 14400
        XCTAssertEqual(r.workSeconds, 55440)
        XCTAssertEqual(r.workDayCount, 5)
    }

    func testLiveSessionIsExactAndFlagged() {
        let live = [input(.work, d(16, 10, 0), nil)]
        let r = StatsAggregator.aggregate(period: .week, reference: d(16, 12, 30), inputs: live,
                                          base: .fullHours, now: d(16, 12, 30), calendar: cal)
        XCTAssertEqual(r.workSeconds, 9000)                  // 10:00 à 12:30 = 2 h 30
        XCTAssertTrue(r.hasLive)
        XCTAssertTrue(r.days[0].workHasLive)
        XCTAssertFalse(r.days[0].studyHasLive)
        XCTAssertFalse(r.isEmpty)
    }

    func testEmptyPeriod() {
        let r = StatsAggregator.aggregate(period: .week, reference: d(18), inputs: [],
                                          base: .fullHours, now: d(18, 12, 0), calendar: cal)
        XCTAssertTrue(r.isEmpty)
        XCTAssertEqual(r.workSeconds, 0)
        XCTAssertEqual(r.maxDaySeconds, 0)
        XCTAssertEqual(r.days.count, 7)
    }

    func testOnlyShoppingIsEmpty() {
        let r = StatsAggregator.aggregate(period: .week, reference: d(18), inputs: [input(.shopping, d(19, 12, 0), d(19, 13, 0))],
                                          base: .fullHours, now: d(22, 12, 0), calendar: cal)
        XCTAssertTrue(r.isEmpty)
    }

    // MARK: échelle du graphique

    func testAxisHours() {
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 0), 2)
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 1), 2)
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 7200), 2)
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 7201), 4)
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 21600), 6)
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 27000), 8)    // 7 h 30
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 28800), 8)    // 8 h pile
        XCTAssertEqual(StatsAggregator.axisHours(maxDaySeconds: 28801), 10)   // 8 h 00 min 01 s
    }

    func testBarFraction() {
        XCTAssertEqual(StatsAggregator.barFraction(seconds: 7200, axisHours: 8), 0.25, accuracy: 1e-9)
        XCTAssertEqual(StatsAggregator.barFraction(seconds: 28800, axisHours: 8), 1.0, accuracy: 1e-9)
        XCTAssertEqual(StatsAggregator.barFraction(seconds: 3600, axisHours: 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(StatsAggregator.barFraction(seconds: 0, axisHours: 8), 0.0, accuracy: 1e-9)
        XCTAssertEqual(StatsAggregator.barFraction(seconds: 40000, axisHours: 8), 1.0, accuracy: 1e-9)
    }

    // MARK: moyennes, écarts, accessibilité

    func testAverageAndSignedDuration() {
        XCTAssertEqual(StatsAggregator.averagePerActiveDay(totalSeconds: 41040, activeDays: 4), 10260)
        XCTAssertEqual(StatsAggregator.averagePerActiveDay(totalSeconds: 0, activeDays: 0), 0)
        XCTAssertEqual(StatsAggregator.signedDuration(seconds: 5400), "+1 h 30")
        XCTAssertEqual(StatsAggregator.signedDuration(seconds: -7200), "-2 h 00")
        XCTAssertEqual(StatsAggregator.signedDuration(seconds: 0), "0 h")
    }

    func testAccessibilitySummary() {
        let r = StatsAggregator.aggregate(period: .week, reference: d(16), inputs: [input(.work, d(16, 8, 0), d(16, 12, 0))],
                                          base: .fullHours, now: d(22, 12, 0), calendar: cal)
        XCTAssertEqual(StatsAggregator.accessibilitySummary(days: r.days, calendar: cal), "lundi 16 novembre : taf 4 h 00.")
        let empty = StatsAggregator.aggregate(period: .week, reference: d(16), inputs: [],
                                              base: .fullHours, now: d(22, 12, 0), calendar: cal)
        XCTAssertEqual(StatsAggregator.accessibilitySummary(days: empty.days, calendar: cal), "Aucune heure sur cette période.")
    }
}
