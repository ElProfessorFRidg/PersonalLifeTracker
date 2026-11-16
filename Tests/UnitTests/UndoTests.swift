import XCTest
import SwiftData
@testable import PersonalLifeTracker

/// UndoCenter (toast, historique) et restauration dans une base en mémoire.
@MainActor
final class UndoTests: XCTestCase {
    // MARK: UndoCenter

    func testRegisterShowsToastAndSecondActionReplacesIt() {
        let center: UndoCenter = UndoCenter(toastDuration: 60)
        var log: [String] = []
        center.register(message: "Session supprimée") { log.append("A") }
        XCTAssertEqual(center.current?.message, "Session supprimée")
        center.register(message: "Lieu supprimé") { log.append("B") }
        XCTAssertEqual(center.current?.message, "Lieu supprimé")

        center.performUndo()
        XCTAssertEqual(log, ["B"])
        XCTAssertNil(center.current)
        XCTAssertEqual(center.history.map { $0.message }, ["Lieu supprimé", "Session supprimée"])
        XCTAssertEqual(center.history.map { $0.isUndone }, [true, false])
    }

    func testReplacedActionStaysUndoableFromHistoryOnlyOnce() {
        let center: UndoCenter = UndoCenter(toastDuration: 60)
        var count: Int = 0
        center.register(message: "A") { count += 1 }
        let firstID: UUID = center.history[0].id
        center.register(message: "B") { }
        XCTAssertTrue(center.undo(recordID: firstID))
        XCTAssertFalse(center.undo(recordID: firstID))
        XCTAssertEqual(count, 1)
        XCTAssertEqual(center.current?.message, "B")
    }

    func testStaleExpiryDoesNotCloseNewerToast() {
        let center: UndoCenter = UndoCenter(toastDuration: 60)
        center.register(message: "A") { }
        let oldID: UUID = center.history[0].id
        center.register(message: "B") { }
        center.expire(id: oldID)
        XCTAssertEqual(center.current?.message, "B")
        center.expire(id: center.history[0].id)
        XCTAssertNil(center.current)
    }

    func testToastDisappearsAfterItsDuration() async throws {
        let center: UndoCenter = UndoCenter(toastDuration: 0.05)
        center.register(message: "A") { }
        XCTAssertNotNil(center.current)
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertNil(center.current)
        XCTAssertEqual(center.history.count, 1)
    }

    func testDisabledCenterRecordsNothing() {
        let center: UndoCenter = UndoCenter(toastDuration: 60)
        center.isEnabled = false
        center.register(message: "A") { }
        XCTAssertNil(center.current)
        XCTAssertTrue(center.history.isEmpty)
    }

    func testHistoryKeepsTwentyMostRecent() {
        let center: UndoCenter = UndoCenter(toastDuration: 60)
        var undone: [Int] = []
        for i in 1...21 {
            center.register(message: "Action \(i)") { undone.append(i) }
        }
        XCTAssertEqual(center.history.count, 20)
        XCTAssertEqual(center.history.first?.message, "Action 21")
        XCTAssertEqual(center.history.last?.message, "Action 2")
        // L'action 1 est sortie de l'historique : plus annulable.
        XCTAssertEqual(undone, [])
    }

    func testHistoryDropsEntriesOlderThanSevenDays() {
        var clock: Date = makeDate(TestCalendar.utc, 2026, 11, 1, 10, 0)
        let center: UndoCenter = UndoCenter(toastDuration: 60, now: { return clock })
        center.register(message: "Vieille") { }
        clock = makeDate(TestCalendar.utc, 2026, 11, 9, 10, 0)
        center.register(message: "Récente") { }
        XCTAssertEqual(center.history.map { $0.message }, ["Récente"])
    }

    // MARK: Restauration (base en mémoire)

    private func fetchSessions(_ context: ModelContext) throws -> [WorkSession] {
        return try context.fetch(FetchDescriptor<WorkSession>())
    }

    private func fetchPlaces(_ context: ModelContext) throws -> [Place] {
        return try context.fetch(FetchDescriptor<Place>())
    }

    func testRestoreDeletedSessionKeepsEveryValue() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let place: Place = Place(name: "Supérette", type: .taf, latitude: 48.85, longitude: 2.35, radius: 120)
        context.insert(place)
        let session: WorkSession = WorkSession(activity: .work, start: nov16(17, 56), end: nov16(22, 3),
                                               place: place, source: .gps, isConfirmed: false, note: "caisse")
        session.chosenEnd = nov16(22, 0)
        session.timeZoneID = "Europe/Paris"
        context.insert(session)
        try context.save()
        let originalUID: UUID = session.uid
        let originalCreatedAt: Date = session.createdAt

        let copy: ExportedSession = UndoSnapshots.exportedSession(session)
        context.delete(session)
        try context.save()
        XCTAssertEqual(try fetchSessions(context).count, 0)

        try UndoSnapshots.restoreSession(copy, context: context)
        let sessions: [WorkSession] = try fetchSessions(context)
        XCTAssertEqual(sessions.count, 1)
        let back: WorkSession = sessions[0]
        XCTAssertEqual(back.uid, originalUID)
        XCTAssertEqual(back.startDate, nov16(17, 56))
        XCTAssertEqual(back.endDate, nov16(22, 3))
        XCTAssertEqual(back.chosenEnd, nov16(22, 0))
        XCTAssertNil(back.chosenStart)
        XCTAssertEqual(back.activity, .work)
        XCTAssertEqual(back.source, .gps)
        XCTAssertFalse(back.isConfirmed)
        XCTAssertEqual(back.note, "caisse")
        XCTAssertEqual(back.timeZoneID, "Europe/Paris")
        XCTAssertEqual(back.createdAt, originalCreatedAt)
        XCTAssertEqual(back.place?.name, "Supérette")
    }

    func testRestoreSessionTwiceDoesNotDuplicate() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let session: WorkSession = WorkSession(activity: .education, start: nov16(8, 0), end: nov16(10, 0))
        context.insert(session)
        try context.save()
        let copy: ExportedSession = UndoSnapshots.exportedSession(session)
        context.delete(session)
        try context.save()
        try UndoSnapshots.restoreSession(copy, context: context)
        try UndoSnapshots.restoreSession(copy, context: context)
        XCTAssertEqual(try fetchSessions(context).count, 1)
    }

    func testRestoreDeletedPlaceRelinksItsSessions() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let place: Place = Place(name: "Fac", type: .cours, latitude: 45.0, longitude: 4.0, radius: 250,
                                 address: "Rue X", alsoWorksHere: false)
        context.insert(place)
        let s1: WorkSession = WorkSession(activity: .education, start: nov16(8, 0), end: nov16(10, 0), place: place)
        let s2: WorkSession = WorkSession(activity: .education, start: nov17(8, 0), end: nov17(9, 0), place: place)
        context.insert(s1)
        context.insert(s2)
        try context.save()
        let placeUID: UUID = place.uid

        let placeCopy: ExportedPlace = UndoSnapshots.exportedPlace(place)
        let sessionCopies: [ExportedSession] = place.sessions.map { UndoSnapshots.exportedSession($0) }
        XCTAssertEqual(sessionCopies.count, 2)
        context.delete(place)
        try context.save()
        XCTAssertEqual(try fetchPlaces(context).count, 0)
        XCTAssertEqual(try fetchSessions(context).count, 2)
        for s in try fetchSessions(context) { XCTAssertNil(s.place) }

        try UndoSnapshots.restorePlace(placeCopy, sessions: sessionCopies, context: context)
        let places: [Place] = try fetchPlaces(context)
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].uid, placeUID)
        XCTAssertEqual(places[0].name, "Fac")
        XCTAssertEqual(places[0].type, .cours)
        XCTAssertEqual(places[0].radius, 250)
        XCTAssertEqual(places[0].address, "Rue X")
        let sessions: [WorkSession] = try fetchSessions(context)
        XCTAssertEqual(sessions.count, 2)
        for s in sessions { XCTAssertEqual(s.place?.uid, placeUID) }
    }

    func testReplaceAllRestoresTheSnapshotState() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let place: Place = Place(name: "Taf", type: .taf)
        context.insert(place)
        let kept: WorkSession = WorkSession(activity: .work, start: nov16(9, 0), end: nov16(12, 0), place: place)
        context.insert(kept)
        try context.save()
        let keptUID: UUID = kept.uid
        let before: ExportDocument = try UndoSnapshots.currentDocument(context: context, now: nov16(12, 30))
        XCTAssertEqual(before.places.count, 1)
        XCTAssertEqual(before.sessions.count, 1)

        // Après l'instantané : une session en plus, et le lieu change de nom.
        context.insert(WorkSession(activity: .work, start: nov17(9, 0), end: nov17(10, 0)))
        place.name = "Autre nom"
        try context.save()
        XCTAssertEqual(try fetchSessions(context).count, 2)

        try UndoSnapshots.replaceAll(with: before, context: context)
        let sessions: [WorkSession] = try fetchSessions(context)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].uid, keptUID)
        XCTAssertEqual(sessions[0].place?.name, "Taf")
        let places: [Place] = try fetchPlaces(context)
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].name, "Taf")
    }

    // MARK: Instantané quotidien

    func testDailySnapshotIsSkippedWhenEmptyThenOncePerDay() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let dir: URL = FileManager.default.temporaryDirectory.appendingPathComponent("PLTUndo-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let store: SnapshotStore = SnapshotStore(directory: dir)
        let paris: Calendar = TestCalendar.paris

        XCTAssertNil(UndoSnapshots.takeDailySnapshotIfDue(context: context, store: store,
                                                          now: makeDate(paris, 2026, 11, 16, 9, 0), calendar: paris))
        XCTAssertEqual(store.list().count, 0)

        context.insert(Place(name: "Taf", type: .taf))
        try context.save()
        let first: SnapshotInfo? = UndoSnapshots.takeDailySnapshotIfDue(context: context, store: store,
                                                                        now: makeDate(paris, 2026, 11, 16, 9, 0), calendar: paris)
        XCTAssertEqual(first?.placeCount, 1)
        XCTAssertNil(UndoSnapshots.takeDailySnapshotIfDue(context: context, store: store,
                                                          now: makeDate(paris, 2026, 11, 16, 23, 59), calendar: paris))
        let next: SnapshotInfo? = UndoSnapshots.takeDailySnapshotIfDue(context: context, store: store,
                                                                       now: makeDate(paris, 2026, 11, 17, 0, 10), calendar: paris)
        XCTAssertNotNil(next)
        XCTAssertEqual(store.list().count, 2)
    }
}
