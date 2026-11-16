import XCTest
@testable import PersonalLifeTracker

/// Les valeurs attendues sont écrites à la main (dates ISO 8601 en UTC).
final class DataExportTests: XCTestCase {

    // 2025-03-10T08:00:00Z = 1741593600 ; 2025-03-10T16:30:00Z = 1741624200
    private let start: Date = Date(timeIntervalSince1970: 1_741_593_600)
    private let end: Date = Date(timeIntervalSince1970: 1_741_624_200)

    private func samplePlace() -> ExportedPlace {
        return ExportedPlace(uid: "11111111-1111-1111-1111-111111111111", name: "Boulangerie Dupont", type: "taf",
                             latitude: 48.8566, longitude: 2.3522, radius: 120, address: "12 rue de Rivoli",
                             alsoWorksHere: false, createdAt: start)
    }

    private func sampleSession(placeUID: String?, end: Date?) -> ExportedSession {
        return ExportedSession(uid: "22222222-2222-2222-2222-222222222222", activity: "work", start: start, end: end,
                               chosenStart: nil, chosenEnd: nil, source: "gps", isConfirmed: true, note: "Journée longue",
                               timeZoneID: "Europe/Paris", createdAt: start, placeUID: placeUID)
    }

    func testEncodedJSONContainsHandWrittenValues() throws {
        let doc = DataExport.makeDocument(places: [samplePlace()],
                                          sessions: [sampleSession(placeUID: "11111111-1111-1111-1111-111111111111", end: end)],
                                          exportedAt: end)
        let data = try DataExport.encode(doc)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"start\" : \"2025-03-10T08:00:00Z\""))
        XCTAssertTrue(text.contains("\"end\" : \"2025-03-10T16:30:00Z\""))
        XCTAssertTrue(text.contains("\"formatVersion\" : 1"))
        XCTAssertTrue(text.contains("\"name\" : \"Boulangerie Dupont\""))
    }

    func testDecodingProducedJSONGivesBackTheValues() throws {
        let placeUID = "11111111-1111-1111-1111-111111111111"
        let doc = DataExport.makeDocument(places: [samplePlace()],
                                          sessions: [sampleSession(placeUID: placeUID, end: end)],
                                          exportedAt: end)
        let decoded = try DataExport.decode(try DataExport.encode(doc))
        XCTAssertEqual(decoded.app, "PersonalLifeTracker")
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.places.count, 1)
        XCTAssertEqual(decoded.places[0].name, "Boulangerie Dupont")
        XCTAssertEqual(decoded.places[0].radius, 120, accuracy: 0.0001)
        XCTAssertEqual(decoded.places[0].latitude, 48.8566, accuracy: 0.000001)
        XCTAssertEqual(decoded.sessions.count, 1)
        XCTAssertEqual(decoded.sessions[0].placeUID, placeUID)
        XCTAssertEqual(decoded.sessions[0].start.timeIntervalSince1970, 1_741_593_600, accuracy: 0.5)
        XCTAssertEqual(decoded.sessions[0].end?.timeIntervalSince1970 ?? 0, 1_741_624_200, accuracy: 0.5)
        // 8 h 30 entre le début et la fin.
        let seconds = (decoded.sessions[0].end ?? start).timeIntervalSince(decoded.sessions[0].start)
        XCTAssertEqual(seconds, 30_600, accuracy: 0.5)
    }

    func testOngoingSessionHasNoEndAndNoPlaceAfterRoundTrip() throws {
        let doc = DataExport.makeDocument(places: [], sessions: [sampleSession(placeUID: nil, end: nil)], exportedAt: end)
        let decoded = try DataExport.decode(try DataExport.encode(doc))
        XCTAssertNil(decoded.sessions[0].end)
        XCTAssertNil(decoded.sessions[0].placeUID)
        XCTAssertEqual(decoded.sessions[0].note, "Journée longue")
    }

    func testEmptyExportIsValid() throws {
        let doc = DataExport.makeDocument(places: [], sessions: [], exportedAt: start)
        let decoded = try DataExport.decode(try DataExport.encode(doc))
        XCTAssertEqual(decoded.places.count, 0)
        XCTAssertEqual(decoded.sessions.count, 0)
        XCTAssertEqual(decoded.exportedAt.timeIntervalSince1970, 1_741_593_600, accuracy: 0.5)
    }

    func testTemporaryFileHoldsTheSameJSON() throws {
        let doc = DataExport.makeDocument(places: [samplePlace()], sessions: [], exportedAt: start)
        let url = try DataExport.writeTemporaryFile(doc)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, "PersonalLifeTracker-export.json")
        let data = try Data(contentsOf: url)
        let decoded = try DataExport.decode(data)
        XCTAssertEqual(decoded.places.first?.address, "12 rue de Rivoli")
    }
}
