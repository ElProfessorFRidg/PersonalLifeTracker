import XCTest
import SwiftData
@testable import PersonalLifeTracker

final class SessionServiceTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try AppModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    func testStartCreatesManualRunningSession() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        let place = Place(name: "Supérette du Canal", type: .taf)
        context.insert(place)

        let started = try service.start(activity: .work, place: place, now: nov16(17, 56))

        XCTAssertEqual(started.activity, .work)
        XCTAssertEqual(started.source, .manual)
        XCTAssertEqual(started.startDate, nov16(17, 56), "l'heure exacte est gardée telle quelle")
        XCTAssertNil(started.endDate)
        XCTAssertTrue(started.isOngoing)
        XCTAssertEqual(started.place?.name, "Supérette du Canal")
        let stored = try context.fetch(FetchDescriptor<WorkSession>())
        XCTAssertEqual(stored.count, 1)
    }

    func testStartRefusesASecondRunningSession() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        _ = try service.start(activity: .work, now: nov16(9, 0))

        XCTAssertThrowsError(try service.start(activity: .education, now: nov16(10, 0))) { error in
            XCTAssertEqual(error as? SessionServiceError, SessionServiceError.alreadyRunning)
        }
        let stored = try context.fetch(FetchDescriptor<WorkSession>())
        XCTAssertEqual(stored.count, 1)
    }

    func testStopSetsEndDateAndReturnsTheSession() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        let started = try service.start(activity: .education, now: nov16(8, 5))

        let stopped = try service.stop(started, now: nov16(12, 2))

        XCTAssertTrue(stopped === started)
        XCTAssertEqual(stopped.endDate, nov16(12, 2))
        XCTAssertEqual(stopped.startDate, nov16(8, 5))
        XCTAssertFalse(stopped.isOngoing)
        XCTAssertNil(try service.runningSession())
    }

    func testStopTwiceFails() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        let started = try service.start(activity: .work, now: nov16(9, 0))
        _ = try service.stop(started, now: nov16(10, 0))

        XCTAssertThrowsError(try service.stop(started, now: nov16(11, 0))) { error in
            XCTAssertEqual(error as? SessionServiceError, SessionServiceError.notRunning)
        }
        XCTAssertEqual(started.endDate, nov16(10, 0), "la fin n'est pas écrasée")
    }

    func testStopNeverEndsBeforeStart() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        let started = try service.start(activity: .work, now: nov16(9, 0))
        let stopped = try service.stop(started, now: nov16(8, 0))
        XCTAssertEqual(stopped.endDate, nov16(9, 0))
    }

    func testCanStartAgainAfterStop() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        let first = try service.start(activity: .work, now: nov16(9, 0))
        _ = try service.stop(first, now: nov16(10, 0))

        let second = try service.start(activity: .education, now: nov16(11, 0))

        XCTAssertTrue(second.isOngoing)
        let running = try service.runningSession()
        XCTAssertTrue(running === second)
    }

    func testStopRunningWithNothingRunningReturnsNil() throws {
        let context = try makeContext()
        let service = SessionService(context: context)
        let result = try service.stopRunning(now: nov16(9, 0))
        XCTAssertNil(result)
    }
}
