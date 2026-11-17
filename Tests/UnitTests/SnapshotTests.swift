import XCTest
@testable import PersonalLifeTracker

/// Règles pures des instantanés et fichiers JSON. Valeurs attendues écrites à la main.
final class SnapshotTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris
    private let utc: Calendar = TestCalendar.utc

    // MARK: isDue

    func testDueWhenNoSnapshotExists() {
        XCTAssertTrue(SnapshotPlan.isDue(lastSnapshot: nil, now: nov16(10, 0), calendar: utc))
    }

    func testNotDueTheSameDay() {
        let last: Date = makeDate(paris, 2026, 11, 16, 0, 5)
        let now: Date = makeDate(paris, 2026, 11, 16, 23, 59)
        XCTAssertFalse(SnapshotPlan.isDue(lastSnapshot: last, now: now, calendar: paris))
    }

    func testDueJustAfterMidnightEvenWithin40Minutes() {
        let last: Date = makeDate(paris, 2026, 11, 16, 23, 30)
        let now: Date = makeDate(paris, 2026, 11, 17, 0, 10)
        XCTAssertTrue(SnapshotPlan.isDue(lastSnapshot: last, now: now, calendar: paris))
    }

    func testDueDependsOnTheCalendarTimeZone() {
        // 23:30 UTC le 16 = 00:30 à Paris le 17. 10:00 UTC le 17 = 11:00 à Paris le 17.
        let last: Date = makeDate(utc, 2026, 11, 16, 23, 30)
        let now: Date = makeDate(utc, 2026, 11, 17, 10, 0)
        XCTAssertFalse(SnapshotPlan.isDue(lastSnapshot: last, now: now, calendar: paris))
        XCTAssertTrue(SnapshotPlan.isDue(lastSnapshot: last, now: now, calendar: utc))
    }

    // MARK: Âge et élagage

    func testAgeInDaysAcrossFallBackDST() {
        // Retour à l'heure d'hiver à Paris le dimanche 25 octobre 2026 : jour de 25 h, l'âge reste 2 jours.
        let entry: Date = makeDate(paris, 2026, 10, 24, 12, 0)
        let now: Date = makeDate(paris, 2026, 10, 26, 0, 30)
        XCTAssertEqual(SnapshotPlan.ageInDays(of: entry, now: now, calendar: paris), 2)
    }

    func testPruneOlderThanRetentionOldestFirst() {
        let now: Date = makeDate(utc, 2026, 11, 16, 12, 0)
        let today: SnapshotEntry = SnapshotEntry(fileName: "a", createdAt: makeDate(utc, 2026, 11, 16, 8, 0))
        let age13: SnapshotEntry = SnapshotEntry(fileName: "b", createdAt: makeDate(utc, 2026, 11, 3, 8, 0))
        let age14: SnapshotEntry = SnapshotEntry(fileName: "c", createdAt: makeDate(utc, 2026, 11, 2, 23, 59))
        let age27: SnapshotEntry = SnapshotEntry(fileName: "d", createdAt: makeDate(utc, 2026, 10, 20, 8, 0))
        let pruned: [SnapshotEntry] = SnapshotPlan.entriesToPrune([today, age14, age13, age27], now: now,
                                                                  retentionDays: 14, maxCount: 30, calendar: utc)
        XCTAssertEqual(pruned, [age27, age14])
    }

    func testNewestIsNeverPrunedEvenWhenVeryOld() {
        let now: Date = makeDate(utc, 2026, 11, 16, 12, 0)
        let old: SnapshotEntry = SnapshotEntry(fileName: "old", createdAt: makeDate(utc, 2026, 9, 1, 8, 0))
        let older: SnapshotEntry = SnapshotEntry(fileName: "older", createdAt: makeDate(utc, 2026, 8, 1, 8, 0))
        let pruned: [SnapshotEntry] = SnapshotPlan.entriesToPrune([old, older], now: now,
                                                                  retentionDays: 14, maxCount: 30, calendar: utc)
        XCTAssertEqual(pruned, [older])
        XCTAssertEqual(SnapshotPlan.entriesToPrune([old], now: now, retentionDays: 14, maxCount: 30, calendar: utc), [])
    }

    func testPruneKeepsOnlyMaxCountMostRecent() {
        let now: Date = makeDate(utc, 2026, 11, 16, 12, 0)
        var entries: [SnapshotEntry] = []
        for day in 12...16 {
            entries.append(SnapshotEntry(fileName: "d\(day)", createdAt: makeDate(utc, 2026, 11, day, 8, 0)))
        }
        let pruned: [SnapshotEntry] = SnapshotPlan.entriesToPrune(entries, now: now,
                                                                  retentionDays: 14, maxCount: 3, calendar: utc)
        XCTAssertEqual(pruned.map { $0.fileName }, ["d12", "d13"])
    }

    func testPruneOfNothingIsNothing() {
        XCTAssertEqual(SnapshotPlan.entriesToPrune([], now: nov16(12, 0), retentionDays: 14, maxCount: 30, calendar: utc), [])
    }

    func testDefaultsFromSpec() {
        XCTAssertEqual(SnapshotPlan.defaultRetentionDays, 14)
    }

    func testCountTexts() {
        XCTAssertEqual(SnapshotFormat.summary(places: 1, sessions: 12), "1 lieu, 12 sessions")
        XCTAssertEqual(SnapshotFormat.summary(places: 0, sessions: 1), "0 lieu, 1 session")
        XCTAssertEqual(SnapshotFormat.summary(places: 3, sessions: 0), "3 lieux, 0 session")
    }

    // MARK: Fichiers JSON

    private func makeTempDirectory() -> URL {
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent("PLTSnapshots-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func sampleDocument(at date: Date) -> ExportDocument {
        let place: ExportedPlace = ExportedPlace(uid: "11111111-1111-1111-1111-111111111111", name: "Supérette du Canal",
                                                 type: "taf", latitude: 48.8566, longitude: 2.3522, radius: 100,
                                                 address: "1 quai", alsoWorksHere: false,
                                                 createdAt: makeDate(utc, 2026, 11, 1, 9, 0))
        let closed: ExportedSession = ExportedSession(uid: "22222222-2222-2222-2222-222222222222", activity: "work",
                                                      start: makeDate(utc, 2026, 11, 15, 17, 56),
                                                      end: makeDate(utc, 2026, 11, 15, 22, 3),
                                                      chosenStart: nil, chosenEnd: makeDate(utc, 2026, 11, 15, 22, 0),
                                                      source: "gps", isConfirmed: false, note: "caisse",
                                                      timeZoneID: "Europe/Paris",
                                                      createdAt: makeDate(utc, 2026, 11, 15, 22, 4),
                                                      placeUID: "11111111-1111-1111-1111-111111111111")
        let ongoing: ExportedSession = ExportedSession(uid: "33333333-3333-3333-3333-333333333333", activity: "education",
                                                       start: makeDate(utc, 2026, 11, 16, 8, 0), end: nil,
                                                       chosenStart: nil, chosenEnd: nil,
                                                       source: "manual", isConfirmed: true, note: "",
                                                       timeZoneID: "UTC",
                                                       createdAt: makeDate(utc, 2026, 11, 16, 8, 1), placeUID: nil)
        return DataExport.makeDocument(places: [place], sessions: [closed, ongoing], exportedAt: date)
    }

    func testWriteListAndLoadRoundTrip() throws {
        let store: SnapshotStore = SnapshotStore(directory: makeTempDirectory())
        let document: ExportDocument = sampleDocument(at: makeDate(utc, 2026, 11, 16, 9, 0))
        let info: SnapshotInfo = try store.write(document)
        XCTAssertEqual(info.placeCount, 1)
        XCTAssertEqual(info.sessionCount, 2)
        XCTAssertGreaterThan(info.byteSize, 0)

        let listed: [SnapshotInfo] = store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed[0], info)
        XCTAssertEqual(listed[0].createdAt, makeDate(utc, 2026, 11, 16, 9, 0))

        let loaded: ExportDocument = try store.load(fileName: info.fileName)
        XCTAssertEqual(loaded, document)
    }

    func testListIsNewestFirstAndDeleteRemovesTheFile() throws {
        let store: SnapshotStore = SnapshotStore(directory: makeTempDirectory())
        let older: SnapshotInfo = try store.write(sampleDocument(at: makeDate(utc, 2026, 11, 14, 9, 0)))
        let newer: SnapshotInfo = try store.write(sampleDocument(at: makeDate(utc, 2026, 11, 16, 9, 0)))
        XCTAssertEqual(store.list().map { $0.fileName }, [newer.fileName, older.fileName])
        try store.delete(fileName: newer.fileName)
        XCTAssertEqual(store.list().map { $0.fileName }, [older.fileName])
    }

    func testListOfMissingDirectoryIsEmptyAndGarbageIsIgnored() throws {
        let dir: URL = makeTempDirectory()
        let store: SnapshotStore = SnapshotStore(directory: dir)
        XCTAssertEqual(store.list(), [])
        _ = try store.write(sampleDocument(at: makeDate(utc, 2026, 11, 16, 9, 0)))
        try Data("pas du json".utf8).write(to: dir.appendingPathComponent("snapshot-1-bad.json"))
        XCTAssertEqual(store.list().count, 1)
    }

    func testStorePruneRemovesOldFilesAndKeepsToday() throws {
        let store: SnapshotStore = SnapshotStore(directory: makeTempDirectory())
        _ = try store.write(sampleDocument(at: makeDate(utc, 2026, 10, 20, 9, 0)))
        _ = try store.write(sampleDocument(at: makeDate(utc, 2026, 11, 2, 9, 0)))
        let today: SnapshotInfo = try store.write(sampleDocument(at: makeDate(utc, 2026, 11, 16, 9, 0)))
        let removed: Int = store.prune(now: makeDate(utc, 2026, 11, 16, 12, 0), calendar: utc)
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(store.list().map { $0.fileName }, [today.fileName])
    }
}
