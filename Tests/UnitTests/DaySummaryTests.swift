import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues écrites à la main (section 13.1 pour les bornes, heures en UTC, lundi 16 novembre 2026).
final class DaySummaryTests: XCTestCase {
    private let cal = TestCalendar.utc

    private func total(_ activity: ActivityType, day: Date, _ inputs: [DaySessionInput],
                       base: CalculationBase, now: Date) -> ActivityDayTotal {
        return DaySummary.total(activity: activity, day: day, inputs: inputs, base: base, now: now, calendar: cal)
    }

    // MARK: totaux

    func testFullHoursRoundsBothBounds() {
        // 08:05 donne 08:00, 12:02 donne 12:00 : 4 h = 14400 s. Exact : 3 h 57 = 14220 s.
        let s = DaySessionInput(start: nov16(8, 5), end: nov16(12, 2), activity: .education)
        let t = total(.education, day: nov16(12, 0), [s], base: .fullHours, now: nov16(23, 0))
        XCTAssertEqual(t.seconds, 14400)
        XCTAssertEqual(t.exactSeconds, 14220)
        XCTAssertEqual(t.sessionCount, 1)
        XCTAssertFalse(t.isProvisional)
        XCTAssertFalse(t.hasLive)
    }

    func testExactBaseUsesExactSeconds() {
        let s = DaySessionInput(start: nov16(8, 5), end: nov16(12, 2), activity: .education)
        let t = total(.education, day: nov16(12, 0), [s], base: .exact, now: nov16(23, 0))
        XCTAssertEqual(t.seconds, 14220)
        XCTAssertFalse(t.isProvisional)
    }

    func testUnresolvedDoubtShowsExactAndIsProvisional() {
        // 17:56 donne 18:00, 21:20 est en zone de doute sans choix : exact 17:56 à 21:20 = 3 h 24 = 12240 s.
        let s = DaySessionInput(start: nov16(17, 56), end: nov16(21, 20), activity: .work)
        let t = total(.work, day: nov16(12, 0), [s], base: .fullHours, now: nov16(23, 0))
        XCTAssertEqual(t.seconds, 12240)
        XCTAssertTrue(t.isProvisional)
    }

    func testResolvedDoubtUsesChosenHour() {
        // 21:20 résolu en 21:00 : 18:00 à 21:00 = 10800 s.
        let s = DaySessionInput(start: nov16(17, 56), end: nov16(21, 20), activity: .work, chosenEnd: nov16(21, 0))
        let t = total(.work, day: nov16(12, 0), [s], base: .fullHours, now: nov16(23, 0))
        XCTAssertEqual(t.seconds, 10800)
        XCTAssertFalse(t.isProvisional)
    }

    func testSessionCrossingMidnightCountsOnlyItsPartOfTheDay() {
        let s = DaySessionInput(start: nov16(22, 0), end: nov17(2, 0), activity: .work)
        let monday = total(.work, day: nov16(12, 0), [s], base: .fullHours, now: nov17(12, 0))
        let tuesday = total(.work, day: nov17(12, 0), [s], base: .fullHours, now: nov17(12, 0))
        XCTAssertEqual(monday.seconds, 7200)
        XCTAssertEqual(tuesday.seconds, 7200)
        XCTAssertEqual(monday.exactSeconds, 7200)
        XCTAssertEqual(tuesday.exactSeconds, 7200)
    }

    func testRoundedBoundPastMidnightMovesTheHourToNextDay() {
        // 23:50 arrondi à 00:00 le 17, 01:10 arrondi à 01:00 : lundi 0 s retenue (600 s exactes), mardi 3600 s (4200 s exactes).
        let s = DaySessionInput(start: nov16(23, 50), end: nov17(1, 10), activity: .work)
        let monday = total(.work, day: nov16(12, 0), [s], base: .fullHours, now: nov17(12, 0))
        let tuesday = total(.work, day: nov17(12, 0), [s], base: .fullHours, now: nov17(12, 0))
        XCTAssertEqual(monday.seconds, 0)
        XCTAssertEqual(monday.exactSeconds, 600)
        XCTAssertEqual(tuesday.seconds, 3600)
        XCTAssertEqual(tuesday.exactSeconds, 4200)
    }

    func testLiveSessionCountsExactUntilNow() {
        // 17:56 à 19:10 = 1 h 14 = 4440 s, jamais provisoire.
        let s = DaySessionInput(start: nov16(17, 56), end: nil, activity: .work)
        let t = total(.work, day: nov16(12, 0), [s], base: .fullHours, now: nov16(19, 10))
        XCTAssertEqual(t.seconds, 4440)
        XCTAssertEqual(t.exactSeconds, 4440)
        XCTAssertTrue(t.hasLive)
        XCTAssertFalse(t.isProvisional)
    }

    func testTwoSessionsAddUpAndOtherActivitiesAreIgnored() {
        let a = DaySessionInput(start: nov16(8, 0), end: nov16(10, 0), activity: .work)
        let b = DaySessionInput(start: nov16(14, 0), end: nov16(15, 0), activity: .work)
        let c = DaySessionInput(start: nov16(11, 0), end: nov16(12, 0), activity: .education)
        let t = total(.work, day: nov16(12, 0), [a, b, c], base: .fullHours, now: nov16(23, 0))
        XCTAssertEqual(t.seconds, 10800)
        XCTAssertEqual(t.sessionCount, 2)
    }

    func testSessionOfAnotherDayIsNotCounted() {
        let s = DaySessionInput(start: nov16(8, 0), end: nov16(10, 0), activity: .work)
        let t = total(.work, day: nov17(12, 0), [s], base: .fullHours, now: nov17(12, 0))
        XCTAssertEqual(t.seconds, 0)
        XCTAssertEqual(t.sessionCount, 0)
    }

    func testOverlapsDay() {
        XCTAssertTrue(DaySummary.overlapsDay(start: nov16(22, 0), end: nov17(2, 0), day: nov17(9, 0), now: nov17(12, 0), calendar: cal))
        XCTAssertFalse(DaySummary.overlapsDay(start: nov16(8, 0), end: nov16(10, 0), day: nov17(9, 0), now: nov17(12, 0), calendar: cal))
        // fin exactement à minuit : rien le lendemain
        XCTAssertFalse(DaySummary.overlapsDay(start: nov16(22, 0), end: nov17(0, 0), day: nov17(9, 0), now: nov17(12, 0), calendar: cal))
        // en cours depuis hier soir
        XCTAssertTrue(DaySummary.overlapsDay(start: nov16(22, 0), end: nil, day: nov17(9, 0), now: nov17(1, 0), calendar: cal))
    }

    // MARK: textes des tuiles

    func testTileValue() {
        let empty = ActivityDayTotal(seconds: 0, exactSeconds: 0, sessionCount: 0, isProvisional: false, hasLive: false)
        let three = ActivityDayTotal(seconds: 10800, exactSeconds: 11040, sessionCount: 1, isProvisional: false, hasLive: false)
        XCTAssertEqual(DaySummary.tileValue(empty), "0 h")
        XCTAssertEqual(DaySummary.tileValue(three), "3 h 00")
    }

    func testTileNotes() {
        let empty = ActivityDayTotal(seconds: 0, exactSeconds: 0, sessionCount: 0, isProvisional: false, hasLive: false)
        let doubt = ActivityDayTotal(seconds: 12240, exactSeconds: 12240, sessionCount: 1, isProvisional: true, hasLive: false)
        let rounded = ActivityDayTotal(seconds: 10800, exactSeconds: 11040, sessionCount: 1, isProvisional: false, hasLive: false)
        let live = ActivityDayTotal(seconds: 4440, exactSeconds: 4440, sessionCount: 1, isProvisional: false, hasLive: true)
        let two = ActivityDayTotal(seconds: 7200, exactSeconds: 7200, sessionCount: 2, isProvisional: false, hasLive: false)
        XCTAssertEqual(DaySummary.tileNote(empty, base: .fullHours), "Rien pour l'instant")
        XCTAssertEqual(DaySummary.tileNote(doubt, base: .fullHours), "À confirmer, exact 3 h 24")
        XCTAssertEqual(DaySummary.tileNote(rounded, base: .fullHours), "Heures pleines, exact 3 h 04")
        XCTAssertEqual(DaySummary.tileNote(live, base: .fullHours), "En cours")
        XCTAssertEqual(DaySummary.tileNote(two, base: .exact), "2 sessions")
    }

    // MARK: carte Maintenant

    private func candidate(_ id: UUID, _ start: Date, _ end: Date?, doubt: Bool) -> NowCandidate {
        return NowCandidate(id: id, start: start, end: end, hasUnresolvedDoubt: doubt)
    }

    func testNoSessionAtAllIsFirstDay() {
        XCTAssertEqual(DaySummary.decideNow(candidates: []), .firstDay)
    }

    func testRunningSessionWinsOverDoubt() {
        let running = UUID()
        let doubt = UUID()
        let list = [candidate(doubt, nov16(8, 0), nov16(10, 20), doubt: true),
                    candidate(running, nov16(17, 56), nil, doubt: false)]
        XCTAssertEqual(DaySummary.decideNow(candidates: list), .confirmRunning(running))
    }

    func testMostRecentRunningSessionIsChosen() {
        let older = UUID()
        let newer = UUID()
        let list = [candidate(older, nov16(8, 0), nil, doubt: false),
                    candidate(newer, nov16(9, 0), nil, doubt: false)]
        XCTAssertEqual(DaySummary.decideNow(candidates: list), .confirmRunning(newer))
    }

    func testFinishedSessionWithDoubtAsksForTheHour() {
        let a = UUID()
        let b = UUID()
        let ok = UUID()
        let list = [candidate(a, nov16(8, 0), nov16(10, 20), doubt: true),
                    candidate(b, nov16(13, 0), nov16(15, 30), doubt: true),
                    candidate(ok, nov16(16, 0), nov16(17, 0), doubt: false)]
        XCTAssertEqual(DaySummary.decideNow(candidates: list), .chooseDoubt(b))
    }

    func testFinishedSessionsWithoutDoubtAreCalm() {
        let list = [candidate(UUID(), nov16(8, 0), nov16(10, 0), doubt: false)]
        XCTAssertEqual(DaySummary.decideNow(candidates: list), .calm)
    }
}
