import XCTest
@testable import PersonalLifeTracker

final class SessionDuplicationTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris

    func testShiftKeepsTimeOfDay() {
        let moved = SessionDuplication.shifted(start: makeDate(paris, 2026, 11, 16, 8, 5),
                                               end: makeDate(paris, 2026, 11, 16, 12, 2),
                                               toDay: makeDate(paris, 2026, 11, 23, 15, 0), calendar: paris)
        XCTAssertEqual(moved?.start, makeDate(paris, 2026, 11, 23, 8, 5))
        XCTAssertEqual(moved?.end, makeDate(paris, 2026, 11, 23, 12, 2))
    }

    func testOvernightSessionEndsTheNextDay() {
        let moved = SessionDuplication.shifted(start: makeDate(paris, 2026, 11, 16, 22, 0),
                                               end: makeDate(paris, 2026, 11, 17, 2, 30),
                                               toDay: makeDate(paris, 2026, 11, 20, 9, 0), calendar: paris)
        XCTAssertEqual(moved?.start, makeDate(paris, 2026, 11, 20, 22, 0))
        XCTAssertEqual(moved?.end, makeDate(paris, 2026, 11, 21, 2, 30))
    }

    func testShiftOntoSpringForwardDayKeepsWallClock() {
        // Dimanche 29 mars 2026 : 02:00 saute à 03:00. 08:00 à 12:00 reste 08:00 à 12:00 sur l'horloge, 4 h réelles.
        let moved = SessionDuplication.shifted(start: makeDate(paris, 2026, 3, 23, 8, 0),
                                               end: makeDate(paris, 2026, 3, 23, 12, 0),
                                               toDay: makeDate(paris, 2026, 3, 29, 10, 0), calendar: paris)
        XCTAssertEqual(moved?.start, makeDate(paris, 2026, 3, 29, 8, 0))
        XCTAssertEqual(moved?.end, makeDate(paris, 2026, 3, 29, 12, 0))
        if let m = moved {
            XCTAssertEqual(m.end.timeIntervalSince(m.start), 4 * 3600, accuracy: 0.5)
        }
    }

    func testOvernightAcrossSpringForwardChangesRealDuration() {
        // 28 mars 23:00 au 29 mars 05:00 : 5 h réelles (une heure disparaît). Dupliqué sur le 28 mars lui-même.
        let moved = SessionDuplication.shifted(start: makeDate(paris, 2026, 3, 21, 23, 0),
                                               end: makeDate(paris, 2026, 3, 22, 5, 0),
                                               toDay: makeDate(paris, 2026, 3, 28, 10, 0), calendar: paris)
        XCTAssertEqual(moved?.start, makeDate(paris, 2026, 3, 28, 23, 0))
        XCTAssertEqual(moved?.end, makeDate(paris, 2026, 3, 29, 5, 0))
        if let m = moved {
            XCTAssertEqual(m.end.timeIntervalSince(m.start), 5 * 3600, accuracy: 0.5)
        }
    }

    func testPlanReadyForToday() {
        let now: Date = makeDate(paris, 2026, 11, 23, 18, 0)
        let outcome = SessionDuplication.planForToday(start: makeDate(paris, 2026, 11, 16, 8, 0),
                                                      end: makeDate(paris, 2026, 11, 16, 12, 0),
                                                      now: now, others: [], calendar: paris)
        XCTAssertEqual(outcome, .ready(start: makeDate(paris, 2026, 11, 23, 8, 0), end: makeDate(paris, 2026, 11, 23, 12, 0)))
        XCTAssertNil(outcome.refusalMessage)
    }

    func testPlanRefusesOngoingSession() {
        let outcome = SessionDuplication.planForToday(start: makeDate(paris, 2026, 11, 16, 8, 0), end: nil,
                                                      now: makeDate(paris, 2026, 11, 23, 18, 0), others: [], calendar: paris)
        XCTAssertEqual(outcome, .notFinished)
        XCTAssertEqual(outcome.refusalMessage, "Arrête d'abord cette session, puis duplique-la.")
    }

    func testPlanRefusesFutureEnd() {
        let outcome = SessionDuplication.planForToday(start: makeDate(paris, 2026, 11, 16, 14, 0),
                                                      end: makeDate(paris, 2026, 11, 16, 18, 0),
                                                      now: makeDate(paris, 2026, 11, 23, 15, 0), others: [], calendar: paris)
        XCTAssertEqual(outcome, .invalid([SessionValidationError.endInFuture]))
    }

    func testPlanRefusesOverlap() {
        let busy = SessionInterval(start: makeDate(paris, 2026, 11, 23, 9, 0), end: makeDate(paris, 2026, 11, 23, 10, 0))
        let outcome = SessionDuplication.planForToday(start: makeDate(paris, 2026, 11, 16, 8, 0),
                                                      end: makeDate(paris, 2026, 11, 16, 12, 0),
                                                      now: makeDate(paris, 2026, 11, 23, 18, 0), others: [busy], calendar: paris)
        XCTAssertEqual(outcome, .invalid([SessionValidationError.overlap]))
    }

    func testBackToBackIsNotAnOverlap() {
        let before = SessionInterval(start: makeDate(paris, 2026, 11, 23, 6, 0), end: makeDate(paris, 2026, 11, 23, 8, 0))
        let outcome = SessionDuplication.planForToday(start: makeDate(paris, 2026, 11, 16, 8, 0),
                                                      end: makeDate(paris, 2026, 11, 16, 12, 0),
                                                      now: makeDate(paris, 2026, 11, 23, 18, 0), others: [before], calendar: paris)
        XCTAssertEqual(outcome, .ready(start: makeDate(paris, 2026, 11, 23, 8, 0), end: makeDate(paris, 2026, 11, 23, 12, 0)))
    }
}
