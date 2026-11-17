import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues écrites à la main depuis la section 13.1 du prompt (règle :00-:14 / :15-:45 / :46-:59).
final class SessionDurationsTests: XCTestCase {
    private let cal = TestCalendar.utc

    // MARK: bornes de la règle d'arrondi

    func testBoundary0614RoundsDownToSixOClock() {
        XCTAssertEqual(SessionDurations.normalizedBound(nov16(6, 14), calendar: cal), .rounded(nov16(6, 0)))
    }

    func testBoundary0615IsDoubt() {
        XCTAssertEqual(SessionDurations.normalizedBound(nov16(6, 15), calendar: cal), .doubt)
    }

    func testBoundary0645IsDoubt() {
        XCTAssertEqual(SessionDurations.normalizedBound(nov16(6, 45), calendar: cal), .doubt)
    }

    func testBoundary0646RoundsUpToSevenOClock() {
        XCTAssertEqual(SessionDurations.normalizedBound(nov16(6, 46), calendar: cal), .rounded(nov16(7, 0)))
    }

    func testBoundaryIgnoresSecondsInsideTheMinute() {
        // 06:14:59 est encore la minute :14 donc arrondi à 06:00:00
        XCTAssertEqual(SessionDurations.normalizedBound(nov16(6, 14, 59), calendar: cal), .rounded(nov16(6, 0)))
    }

    func testBoundary2346RoundsToNextMidnight() {
        XCTAssertEqual(SessionDurations.normalizedBound(nov16(23, 46), calendar: cal), .rounded(nov17(0, 0)))
    }

    // MARK: durées exacte et normalisée

    func testSpecExample1756To2203() {
        // Section 13.1 : exact 247 min, normalisé 240 min.
        XCTAssertEqual(SessionDurations.exactSeconds(start: nov16(17, 56), end: nov16(22, 3)), 247 * 60)
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(17, 56), end: nov16(22, 3),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal), 240)
    }

    func testStartAt0614CountsFromSixOClock() {
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(6, 14), end: nov16(10, 0),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal), 240)
    }

    func testStartAt0646CountsFromSevenOClock() {
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(6, 46), end: nov16(10, 0),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal), 180)
    }

    func testEndAt1246RoundsUpAndSecondsAreDropped() {
        // 08:00:50 -> 12:46:30 : exact 4 h 45 min 40 s = 17140 s, normalisé 08:00 -> 13:00 = 300 min.
        XCTAssertEqual(SessionDurations.exactSeconds(start: nov16(8, 0, 50), end: nov16(12, 46, 30)), 17140)
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(8, 0, 50), end: nov16(12, 46, 30),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal), 300)
    }

    func testNegativeIntervalGivesZeroExact() {
        XCTAssertEqual(SessionDurations.exactSeconds(start: nov16(10, 0), end: nov16(9, 0)), 0)
    }

    // MARK: zone de doute

    func testDoubtWithoutChoiceHasNoNormalizedDuration() {
        XCTAssertNil(SessionDurations.normalizedMinutes(start: nov16(8, 0), end: nov16(17, 30),
                                                        chosenStart: nil, chosenEnd: nil, calendar: cal))
        XCTAssertTrue(SessionDurations.hasUnresolvedDoubt(start: nov16(8, 0), end: nov16(17, 30),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal))
    }

    func testDoubtEndChosenDownGivesNineHours() {
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(8, 0), end: nov16(17, 30),
                                                          chosenStart: nil, chosenEnd: nov16(17, 0), calendar: cal), 540)
        XCTAssertFalse(SessionDurations.hasUnresolvedDoubt(start: nov16(8, 0), end: nov16(17, 30),
                                                           chosenStart: nil, chosenEnd: nov16(17, 0), calendar: cal))
    }

    func testDoubtEndChosenUpGivesTenHours() {
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(8, 0), end: nov16(17, 30),
                                                          chosenStart: nil, chosenEnd: nov16(18, 0), calendar: cal), 600)
    }

    func testDoubtOnStartWithChoice() {
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(7, 30), end: nov16(12, 0),
                                                          chosenStart: nov16(8, 0), chosenEnd: nil, calendar: cal), 240)
    }

    func testDoubtOnBothBoundsWithChoices() {
        // 08:20 choisi 08:00, 17:40 choisi 18:00 : 10 h.
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(8, 20), end: nov16(17, 40),
                                                          chosenStart: nov16(8, 0), chosenEnd: nov16(18, 0), calendar: cal), 600)
    }

    func testChoiceIsIgnoredWhenBoundIsNotInDoubtZone() {
        // 08:00 n'est pas en doute : un ancien choix à 09:00 ne doit rien changer.
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(8, 0), end: nov16(12, 0),
                                                          chosenStart: nov16(9, 0), chosenEnd: nil, calendar: cal), 240)
    }

    func testDoubtChoicesAt1730() {
        let choices = SessionDurations.doubtChoices(for: nov16(17, 30), calendar: cal)
        XCTAssertEqual(choices, SessionDurations.DoubtChoices(floor: nov16(17, 0), ceil: nov16(18, 0)))
    }

    func testNoDoubtChoicesOutsideDoubtZone() {
        XCTAssertNil(SessionDurations.doubtChoices(for: nov16(17, 50), calendar: cal))
        XCTAssertNil(SessionDurations.doubtChoices(for: nov16(17, 14), calendar: cal))
    }

    // MARK: minuit et changement d'heure

    func testSessionCrossingMidnight() {
        // 22:00 -> 02:00 le lendemain : 4 h réelles.
        XCTAssertEqual(SessionDurations.exactSeconds(start: nov16(22, 0), end: nov17(2, 0)), 4 * 3600)
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(22, 0), end: nov17(2, 0),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal), 240)
    }

    func testNormalizationAcrossMidnightCollapsesToZero() {
        // 23:50 -> 00:10 : exact 20 min, mais 23:50 devient 00:00 et 00:10 devient 00:00.
        XCTAssertEqual(SessionDurations.exactSeconds(start: nov16(23, 50), end: nov17(0, 10)), 20 * 60)
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: nov16(23, 50), end: nov17(0, 10),
                                                          chosenStart: nil, chosenEnd: nil, calendar: cal), 0)
    }

    func testSpringForwardNightIsTwoRealHours() {
        // Paris, nuit du 28 au 29 mars 2026 : à 02:00 il est 03:00. De 01:00 à 04:00 locales il s'écoule 2 h.
        let paris = TestCalendar.paris
        let start = makeDate(paris, 2026, 3, 29, 1, 0)
        let end = makeDate(paris, 2026, 3, 29, 4, 0)
        XCTAssertEqual(SessionDurations.exactSeconds(start: start, end: end), 7200)
        XCTAssertEqual(SessionDurations.normalizedMinutes(start: start, end: end,
                                                          chosenStart: nil, chosenEnd: nil, calendar: paris), 120)
    }

    // MARK: base retenue

    func testRetainedFullHoursFallsBackToExactWhileDoubtIsOpen() {
        let r = SessionDurations.retained(base: .fullHours, start: nov16(8, 0), end: nov16(17, 30),
                                          chosenStart: nil, chosenEnd: nil, calendar: cal)
        XCTAssertEqual(r.seconds, 34200)
        XCTAssertTrue(r.isProvisional)
    }

    func testRetainedFullHoursUsesChoice() {
        let r = SessionDurations.retained(base: .fullHours, start: nov16(8, 0), end: nov16(17, 30),
                                          chosenStart: nil, chosenEnd: nov16(18, 0), calendar: cal)
        XCTAssertEqual(r.seconds, 36000)
        XCTAssertFalse(r.isProvisional)
    }

    func testRetainedExactIgnoresRounding() {
        let r = SessionDurations.retained(base: .exact, start: nov16(17, 56), end: nov16(22, 3),
                                          chosenStart: nil, chosenEnd: nil, calendar: cal)
        XCTAssertEqual(r.seconds, 14820)
        XCTAssertFalse(r.isProvisional)
    }

    // MARK: modèle de session

    func testWorkSessionKeepsExactTimesAndComputesDurations() {
        let s = WorkSession(activity: .education, start: nov16(17, 56), end: nov16(22, 3))
        s.timeZoneID = "UTC"
        XCTAssertEqual(s.startDate, nov16(17, 56))
        XCTAssertEqual(s.exactSeconds(now: nov16(23, 0)), 14820)
        XCTAssertEqual(s.normalizedMinutes(now: nov16(23, 0)), 240)
        XCTAssertFalse(s.hasUnresolvedDoubt)
    }

    func testOngoingWorkSessionUsesNow() {
        let s = WorkSession(activity: .work, start: nov16(17, 56))
        s.timeZoneID = "UTC"
        XCTAssertTrue(s.isOngoing)
        XCTAssertEqual(s.exactSeconds(now: nov16(19, 10)), 74 * 60)
    }

    func testWorkSessionDoubtResolvedByChosenEnd() {
        let s = WorkSession(activity: .work, start: nov16(8, 0), end: nov16(17, 30))
        s.timeZoneID = "UTC"
        XCTAssertTrue(s.hasUnresolvedDoubt)
        XCTAssertNil(s.normalizedMinutes(now: nov16(20, 0)))
        s.chosenEnd = nov16(18, 0)
        XCTAssertFalse(s.hasUnresolvedDoubt)
        XCTAssertEqual(s.normalizedMinutes(now: nov16(20, 0)), 600)
        XCTAssertEqual(s.endDate, nov16(17, 30), "l'heure exacte reste intacte")
    }
}
