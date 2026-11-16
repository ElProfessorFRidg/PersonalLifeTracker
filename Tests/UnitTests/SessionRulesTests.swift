import XCTest
@testable import PersonalLifeTracker

final class SessionRulesTests: XCTestCase {

    private let utc: Calendar = TestCalendar.utc
    private let paris: Calendar = TestCalendar.paris

    private func item(_ id: UUID = UUID(), _ start: Date, activity: ActivityType = .work,
                      confirmed: Bool = true, doubt: Bool = false) -> SessionListItem {
        return SessionListItem(id: id, start: start, end: nil, activity: activity, isConfirmed: confirmed, hasUnresolvedDoubt: doubt)
    }

    // MARK: Validation

    func testValidSessionHasNoError() {
        let errors = SessionRules.validate(start: nov16(8, 5), end: nov16(12, 2), now: nov16(18, 0), others: [])
        XCTAssertEqual(errors, [])
    }

    func testEndEqualToStartIsRejected() {
        let errors = SessionRules.validate(start: nov16(8, 0), end: nov16(8, 0), now: nov16(18, 0), others: [])
        XCTAssertEqual(errors, [.endNotAfterStart])
    }

    func testEndBeforeStartIsRejected() {
        let errors = SessionRules.validate(start: nov16(12, 0), end: nov16(8, 0), now: nov16(18, 0), others: [])
        XCTAssertEqual(errors, [.endNotAfterStart])
    }

    func testEndInTheFutureIsRejected() {
        let errors = SessionRules.validate(start: nov16(17, 0), end: nov16(19, 0), now: nov16(18, 0), others: [])
        XCTAssertEqual(errors, [.endInFuture])
    }

    func testEndExactlyNowIsAccepted() {
        let errors = SessionRules.validate(start: nov16(17, 0), end: nov16(18, 0), now: nov16(18, 0), others: [])
        XCTAssertEqual(errors, [])
    }

    func testExactly24HoursIsAcceptedAndOneMinuteMoreIsRejected() {
        let now = nov17(12, 0)
        XCTAssertEqual(SessionRules.validate(start: nov16(0, 0), end: nov17(0, 0), now: now, others: []), [])
        XCTAssertEqual(SessionRules.validate(start: nov16(0, 0), end: nov17(0, 1), now: now, others: []), [.tooLong])
    }

    // MARK: Chevauchement

    func testOverlapCases() {
        let existing = [SessionInterval(start: nov16(10, 0), end: nov16(12, 0))]
        let now = nov16(23, 0)
        // Chevauche la fin
        XCTAssertEqual(SessionRules.validate(start: nov16(11, 0), end: nov16(13, 0), now: now, others: existing), [.overlap])
        // Chevauche le début
        XCTAssertEqual(SessionRules.validate(start: nov16(9, 0), end: nov16(10, 30), now: now, others: existing), [.overlap])
        // Contenue
        XCTAssertEqual(SessionRules.validate(start: nov16(10, 30), end: nov16(11, 30), now: now, others: existing), [.overlap])
        // Englobante
        XCTAssertEqual(SessionRules.validate(start: nov16(9, 0), end: nov16(13, 0), now: now, others: existing), [.overlap])
    }

    func testBackToBackSessionsDoNotOverlap() {
        let existing = [SessionInterval(start: nov16(10, 0), end: nov16(12, 0))]
        let now = nov16(23, 0)
        XCTAssertEqual(SessionRules.validate(start: nov16(12, 0), end: nov16(13, 0), now: now, others: existing), [])
        XCTAssertEqual(SessionRules.validate(start: nov16(9, 0), end: nov16(10, 0), now: now, others: existing), [])
    }

    func testMidnightCrossingSessionIsValidAndOverlapsNextDaySession() {
        let now = nov17(12, 0)
        XCTAssertEqual(SessionRules.validate(start: nov16(23, 50), end: nov17(0, 10), now: now, others: []), [])
        let nextDay = [SessionInterval(start: nov17(0, 5), end: nov17(1, 0))]
        XCTAssertEqual(SessionRules.validate(start: nov16(23, 50), end: nov17(0, 10), now: now, others: nextDay), [.overlap])
    }

    // MARK: Date et heure

    func testCombineKeepsDayAndTimeAndZeroesSeconds() {
        let combined = SessionRules.combine(day: nov16(3, 0), time: nov17(9, 41, 30), calendar: utc)
        XCTAssertEqual(combined, nov16(9, 41, 0))
    }

    func testCombineWithDayOffsetCrossesMidnight() {
        let combined = SessionRules.combine(day: nov16(3, 0), time: nov16(1, 10), dayOffset: 1, calendar: utc)
        XCTAssertEqual(combined, nov17(1, 10, 0))
    }

    func testClockWithSeconds() {
        XCTAssertEqual(SessionRules.clockWithSeconds(nov16(17, 56, 12), calendar: utc), "17:56:12")
        XCTAssertEqual(SessionRules.clockWithSeconds(nov16(0, 5, 9), calendar: utc), "00:05:09")
    }

    func testDurationWithSeconds() {
        XCTAssertEqual(SessionRules.durationWithSeconds(2 * 3600 + 42 * 60 + 5), "2 h 42 min 05 s")
        XCTAssertEqual(SessionRules.durationWithSeconds(12 * 60 + 3), "12 min 03 s")
        XCTAssertEqual(SessionRules.durationWithSeconds(45), "45 s")
        XCTAssertEqual(SessionRules.durationWithSeconds(3600), "1 h 00 min 00 s")
    }

    // MARK: Liste

    func testNeedsConfirmation() {
        XCTAssertFalse(SessionRules.needsConfirmation(item(nov16(8, 0))))
        XCTAssertTrue(SessionRules.needsConfirmation(item(nov16(8, 0), confirmed: false)))
        XCTAssertTrue(SessionRules.needsConfirmation(item(nov16(8, 0), doubt: true)))
        XCTAssertTrue(SessionRules.needsConfirmation(item(nov16(8, 0), confirmed: false, doubt: true)))
    }

    func testFilters() {
        let work = item(nov16(8, 0), activity: .work)
        let study = item(nov16(9, 0), activity: .education)
        let shop = item(nov16(10, 0), activity: .shopping, confirmed: false)
        let other = item(nov16(11, 0), activity: .personal, doubt: true)
        let all = [work, study, shop, other]
        XCTAssertEqual(SessionRules.filter(all, by: .all).count, 4)
        XCTAssertEqual(SessionRules.filter(all, by: .work), [work])
        XCTAssertEqual(SessionRules.filter(all, by: .education), [study])
        XCTAssertEqual(SessionRules.filter(all, by: .shopping), [shop])
        XCTAssertEqual(SessionRules.filter(all, by: .toConfirm), [shop, other])
    }

    func testGroupByDaySortsNewestFirst() {
        let a = item(nov16(8, 0))
        let b = item(nov16(14, 0))
        let c = item(nov17(9, 0))
        let groups = SessionRules.groupByDay([a, b, c], calendar: utc)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].day, makeDate(utc, 2026, 11, 17, 0, 0))
        XCTAssertEqual(groups[0].items, [c])
        XCTAssertEqual(groups[1].day, makeDate(utc, 2026, 11, 16, 0, 0))
        XCTAssertEqual(groups[1].items, [b, a])
    }

    func testGroupByDayUsesTheCalendarTimeZone() {
        // 16 novembre 23:30 UTC = 17 novembre 00:30 à Paris (UTC+1 en novembre).
        let late = item(nov16(23, 30))
        let early = item(nov16(10, 0))
        let groups = SessionRules.groupByDay([late, early], calendar: paris)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].items, [late])
        XCTAssertEqual(groups[0].day, makeDate(paris, 2026, 11, 17, 0, 0))
        XCTAssertEqual(groups[1].items, [early])
    }

    func testGroupByDayOfEmptyListIsEmpty() {
        XCTAssertEqual(SessionRules.groupByDay([], calendar: utc), [])
    }

    func testDayLabels() {
        let now = nov16(12, 0)
        XCTAssertEqual(SessionRules.dayLabel(day: makeDate(utc, 2026, 11, 16, 0, 0), now: now, calendar: utc), "Aujourd'hui, lundi 16 novembre")
        XCTAssertEqual(SessionRules.dayLabel(day: makeDate(utc, 2026, 11, 15, 0, 0), now: now, calendar: utc), "Hier, dimanche 15 novembre")
        XCTAssertEqual(SessionRules.dayLabel(day: makeDate(utc, 2026, 11, 14, 0, 0), now: now, calendar: utc), "Samedi 14 novembre")
    }

    // MARK: Zone de doute

    func testBoundaryAt0614IsNotADoubt() {
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(6, 14), end: nov16(10, 0),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options, [])
    }

    func testBoundaryAt0615IsADoubt() {
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(6, 15), end: nov16(10, 0),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].hour, nov16(6, 0))
        XCTAssertTrue(options[0].hourIsBeforeExact)
        XCTAssertEqual(options[0].minutesApart, 15)
        XCTAssertEqual(options[0].resultingSeconds, 4 * 3600)
        XCTAssertEqual(options[1].hour, nov16(7, 0))
        XCTAssertFalse(options[1].hourIsBeforeExact)
        XCTAssertEqual(options[1].minutesApart, 45)
        XCTAssertEqual(options[1].resultingSeconds, 3 * 3600)
    }

    func testBoundaryAt0645IsADoubt() {
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(6, 45), end: nov16(10, 0),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].minutesApart, 45)
        XCTAssertEqual(options[1].minutesApart, 15)
        XCTAssertEqual(options[0].resultingSeconds, 4 * 3600)
        XCTAssertEqual(options[1].resultingSeconds, 3 * 3600)
    }

    func testBoundaryAt0646IsNotADoubt() {
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(6, 46), end: nov16(10, 0),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options, [])
    }

    func testEndInDoubtProposesTwoHoursAndKeepsRoundedStart() {
        // Arrivée 17:56:12 comptée 18:00, départ 20:38:05 en doute : 20:00 donne 2 h, 21:00 donne 3 h.
        let options = SessionRules.doubtOptions(bound: .end, start: nov16(17, 56, 12), end: nov16(20, 38, 5),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].hour, nov16(20, 0))
        XCTAssertEqual(options[0].minutesApart, 38)
        XCTAssertEqual(options[0].resultingSeconds, 2 * 3600)
        XCTAssertEqual(options[1].hour, nov16(21, 0))
        XCTAssertEqual(options[1].minutesApart, 22)
        XCTAssertEqual(options[1].resultingSeconds, 3 * 3600)
    }

    func testStartInDoubtProposesTwoHoursWithRoundedEnd() {
        // Arrivée 17:32 en doute, départ 21:00:00 : 17:00 donne 4 h, 18:00 donne 3 h.
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(17, 32), end: nov16(21, 0),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].hour, nov16(17, 0))
        XCTAssertEqual(options[0].minutesApart, 32)
        XCTAssertEqual(options[0].resultingSeconds, 4 * 3600)
        XCTAssertEqual(options[1].hour, nov16(18, 0))
        XCTAssertEqual(options[1].minutesApart, 28)
        XCTAssertEqual(options[1].resultingSeconds, 3 * 3600)
    }

    func testEndOptionsUseTheChosenStart() {
        // Début 17:32 en doute, choisi à 18:00 ; fin 20:38 : 20:00 donne 2 h, 21:00 donne 3 h.
        let options = SessionRules.doubtOptions(bound: .end, start: nov16(17, 32), end: nov16(20, 38),
                                                chosenStart: nov16(18, 0), chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options[0].resultingSeconds, 2 * 3600)
        XCTAssertEqual(options[1].resultingSeconds, 3 * 3600)
    }

    func testDoubtAcrossMidnight() {
        // Début 22:30 (doute), fin le lendemain 01:10 arrondie à 01:00 : 22:00 donne 3 h, 23:00 donne 2 h.
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(22, 30), end: nov17(1, 10),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].hour, nov16(22, 0))
        XCTAssertEqual(options[0].resultingSeconds, 3 * 3600)
        XCTAssertEqual(options[1].hour, nov16(23, 0))
        XCTAssertEqual(options[1].resultingSeconds, 2 * 3600)
    }

    func testNoDoubtAt2350AcrossMidnight() {
        // 23:50 est arrondi à minuit : pas de choix à proposer.
        let options = SessionRules.doubtOptions(bound: .start, start: nov16(23, 50), end: nov17(8, 0),
                                                chosenStart: nil, chosenEnd: nil, calendar: utc)
        XCTAssertEqual(options, [])
    }
}
