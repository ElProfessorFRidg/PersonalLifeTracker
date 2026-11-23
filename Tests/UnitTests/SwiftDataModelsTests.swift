import XCTest
import SwiftData
@testable import PersonalLifeTracker

final class SwiftDataModelsTests: XCTestCase {
    func testCreateAndFetchPlaceAndSession() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        let place = Place(name: "Supérette du Canal", type: .taf, latitude: 48.8566, longitude: 2.3522, radius: 100)
        context.insert(place)
        let start = nov16(17, 56)
        let end = nov16(22, 3)
        let session = WorkSession(activity: .work, start: start, end: end, place: place, source: .gps, isConfirmed: false, note: "caisse")
        context.insert(session)
        try context.save()

        let places = try context.fetch(FetchDescriptor<Place>())
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].name, "Supérette du Canal")
        XCTAssertEqual(places[0].type, .taf)
        XCTAssertEqual(places[0].radius, 100)

        let sessions = try context.fetch(FetchDescriptor<WorkSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].place?.name, "Supérette du Canal")
        XCTAssertEqual(sessions[0].activity, .work)
        XCTAssertEqual(sessions[0].source, .gps)
        XCTAssertFalse(sessions[0].isConfirmed)
        XCTAssertEqual(sessions[0].note, "caisse")
        XCTAssertEqual(sessions[0].startDate, start, "l'heure exacte est gardée telle quelle")
        XCTAssertEqual(sessions[0].endDate, end)
        XCTAssertNil(sessions[0].chosenStart)
        XCTAssertNil(sessions[0].chosenEnd)
        XCTAssertEqual(places[0].sessions.count, 1)
    }

    func testUpgradingEachLegacyDiskSchemaKeepsPlacesAndHistory() throws {
        // beta.1 did not use SwiftData. These are the exact model sets from the later beta tags.
        let schemas: [(String, [any PersistentModel.Type])] = [
            ("beta.2", [Place.self, WorkSession.self]),
            ("beta.3", [Place.self, WorkSession.self, DetectionEvent.self]),
            ("beta.4", [Place.self, WorkSession.self, DetectionEvent.self, PlaceSample.self,
                        Employer.self, Contract.self, PayRate.self])
        ]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let placeID = UUID()
        let sessionID = UUID()
        let start = nov16(17, 56)
        let end = nov16(22, 3)

        for (version, models) in schemas {
            let storeURL = directory.appendingPathComponent(version + ".store")
            // Release the legacy container before reopening its unchanged store URL.
            do {
                let legacySchema = Schema(models)
                let configuration = ModelConfiguration(schema: legacySchema, url: storeURL)
                let legacyContainer = try ModelContainer(for: legacySchema, configurations: [configuration])
                let legacyContext = ModelContext(legacyContainer)
                let place = Place(name: "Supérette du Canal", type: .courses, latitude: 48.8566, longitude: 2.3522,
                                  radius: 85, address: "12 rue du Canal", alsoWorksHere: true)
                place.uid = placeID
                let session = WorkSession(activity: .work, start: start, end: end, place: place,
                                          source: .gps, isConfirmed: true, note: "caisse")
                session.uid = sessionID
                legacyContext.insert(place)
                legacyContext.insert(session)
                if version != "beta.2" {
                    legacyContext.insert(DetectionEvent(kind: .arrivalConfirmed, date: start, placeName: place.name,
                                                        placeUID: placeID, detail: "Arrivée confirmée"))
                }
                try legacyContext.save()
            }

            let updated = try AppModelContainer.make(storeURL: storeURL)
            let context = ModelContext(updated)
            let places = try context.fetch(FetchDescriptor<Place>())
            let sessions = try context.fetch(FetchDescriptor<WorkSession>())
            let events = try context.fetch(FetchDescriptor<DetectionEvent>())
            XCTAssertEqual(places.count, 1, version)
            XCTAssertEqual(sessions.count, 1, version)
            let place = try XCTUnwrap(places.first, version)
            let session = try XCTUnwrap(sessions.first, version)
            XCTAssertEqual(place.uid, placeID, version)
            XCTAssertEqual(place.address, "12 rue du Canal", version)
            XCTAssertEqual(place.type, .courses, version)
            XCTAssertEqual(place.radius, 85, version)
            XCTAssertTrue(place.alsoWorksHere, version)
            XCTAssertEqual(place.sessions.map(\.uid), [sessionID], version)
            XCTAssertEqual(session.uid, sessionID, version)
            XCTAssertEqual(session.place?.uid, placeID, version)
            XCTAssertEqual(session.activity, .work, version)
            XCTAssertEqual(session.startDate, start, version)
            XCTAssertEqual(session.endDate, end, version)
            XCTAssertEqual(session.note, "caisse", version)
            if version == "beta.2" {
                XCTAssertTrue(events.isEmpty, version)
            } else {
                XCTAssertEqual(events.count, 1, version)
                XCTAssertEqual(events.first?.kind, .arrivalConfirmed, version)
                XCTAssertEqual(events.first?.placeUID, placeID, version)
            }
        }
    }

    func testChosenTimesArePersisted() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let session = WorkSession(activity: .education, start: nov16(8, 0), end: nov16(17, 30))
        session.chosenEnd = nov16(18, 0)
        context.insert(session)
        try context.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<WorkSession>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].endDate, nov16(17, 30))
        XCTAssertEqual(fetched[0].chosenEnd, nov16(18, 0))
    }

    func testDeletingAPlaceKeepsItsSessions() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let place = Place(name: "Fac de lettres", type: .cours)
        context.insert(place)
        context.insert(WorkSession(activity: .education, start: nov16(8, 5), end: nov16(12, 2), place: place))
        try context.save()

        context.delete(place)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Place>()).count, 0)
        let sessions = try context.fetch(FetchDescriptor<WorkSession>())
        XCTAssertEqual(sessions.count, 1, "supprimer un lieu ne supprime pas les sessions")
        XCTAssertNil(sessions[0].place)
    }

    func testPlaceTypeMapsToActivity() {
        XCTAssertEqual(PlaceType.taf.defaultActivity, .work)
        XCTAssertEqual(PlaceType.cours.defaultActivity, .education)
        XCTAssertEqual(PlaceType.courses.defaultActivity, .shopping)
    }

    func testUnknownStoredRawValuesFallBackSafely() {
        let place = Place(name: "X", type: .cours)
        place.typeRaw = "inconnu"
        XCTAssertEqual(place.type, .autre)
        XCTAssertFalse(DetectionPlace(uid: place.uid, name: place.name, type: place.type).createsSessions)
        let s = WorkSession(activity: .work, start: nov16(9, 0))
        s.activityRaw = "inconnu"
        XCTAssertEqual(s.activity, .unknown)
    }
}
