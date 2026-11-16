import XCTest
import SwiftData
@testable import PersonalLifeTracker

final class PlaceDiscoveryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(_ candidates: inout [DiscoveredPlace], hoursAgo: Double,
                        latitude: Double = 48.85, accuracy: Double = 20, duration: Double = 1200) {
        let arrival = now.addingTimeInterval(-hoursAgo * 3600)
        PlaceDiscoveryRules.record(in: &candidates, latitude: latitude, longitude: 2.35,
                                   accuracy: accuracy, arrival: arrival,
                                   departure: arrival.addingTimeInterval(duration), now: now)
    }

    func testThreeSeparateVisitsProduceOneSuggestion() {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 48)
        record(&candidates, hoursAgo: 24)
        XCTAssertFalse(candidates[0].isReady)
        record(&candidates, hoursAgo: 1)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].isReady)
    }

    func testRepeatedCallbackAndNearbyArrivalDoNotCountTwice() {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 24)
        record(&candidates, hoursAgo: 24)
        record(&candidates, hoursAgo: 23, latitude: 48.8501)
        XCTAssertEqual(candidates[0].arrivals.count, 1)
    }

    func testShortStopsInaccurateAndInvalidCoordinatesAreRejected() {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 2, duration: 599)
        record(&candidates, hoursAgo: 2, accuracy: 101)
        record(&candidates, hoursAgo: 2, latitude: .nan)
        record(&candidates, hoursAgo: 2, latitude: 91)
        record(&candidates, hoursAgo: 2, accuracy: -1)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testDifferentPlacesStaySeparate() {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 24)
        record(&candidates, hoursAgo: 1, latitude: 48.86)
        XCTAssertEqual(candidates.count, 2)
    }

    func testIgnoredPlaceIsNotSuggestedAgainAndSurvivesPersistence() throws {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 48)
        candidates[0].dismissed = true
        let data = try JSONEncoder().encode(candidates)
        candidates = try JSONDecoder().decode([DiscoveredPlace].self, from: data)
        record(&candidates, hoursAgo: 24)
        record(&candidates, hoursAgo: 1)
        XCTAssertTrue(candidates[0].dismissed)
        XCTAssertEqual(candidates[0].arrivals.count, 1)
    }

    func testIncompleteAndFutureVisitsAreRejected() {
        var candidates: [DiscoveredPlace] = []
        PlaceDiscoveryRules.record(in: &candidates, latitude: 48.85, longitude: 2.35, accuracy: 20,
                                   arrival: .distantPast, departure: now, now: now)
        PlaceDiscoveryRules.record(in: &candidates, latitude: 48.85, longitude: 2.35, accuracy: 20,
                                   arrival: now, departure: .distantFuture, now: now)
        record(&candidates, hoursAgo: -1)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testOldVisitsExpireBeforeCounting() {
        var candidates = [DiscoveredPlace(latitude: 48.85, longitude: 2.35,
                                         arrivals: [now.addingTimeInterval(-40 * 86400)])]
        record(&candidates, hoursAgo: 24)
        XCTAssertEqual(candidates[0].arrivals.count, 1)
        XCTAssertFalse(candidates[0].isReady)
    }

    func testPersonalPlacesNeverCreateWorkSessions() {
        for type in [PlaceType.domicile, .autre] {
            let place = DetectionPlace(uid: UUID(), name: type.title, type: type)
            XCTAssertFalse(place.createsSessions)
            XCTAssertEqual(type.defaultActivity, .personal)
            var engine = DetectionEngine()
            _ = engine.handle(.entered(place: place, date: now, accuracy: 10))
            let decisions = engine.handle(.tick(now: now.addingTimeInterval(600)))
            XCTAssertEqual(decisions.count, 1)
            guard let decision = decisions.first, case .noteVisit = decision else {
                XCTFail("Un lieu personnel ne doit pas démarrer de session.")
                continue
            }
            XCTAssertFalse(engine.isSessionRunning)
        }
    }
    @MainActor
    func testVisitsRequireConfirmationAndKnownPlacesAreExcluded() throws {
        let suite = "discovery-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try AppModelContainer.make(inMemory: true)
        let service = PlaceDiscovery(container: container, defaults: defaults)
        for hours in [48.0, 24.0, 1.0] {
            let arrival = now.addingTimeInterval(-hours * 3600)
            service.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 20,
                                arrival: arrival, departure: arrival.addingTimeInterval(1200), now: now)
        }
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Place>()).count, 0)
        let candidate = try XCTUnwrap(service.candidates.first)
        XCTAssertTrue(candidate.isReady)
        XCTAssertTrue(service.confirm(candidate, type: .domicile, name: "Chez moi"))
        XCTAssertTrue(service.confirm(candidate, type: .domicile, name: "Chez moi"))
        let places = try container.mainContext.fetch(FetchDescriptor<Place>())
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.type, .domicile)
        let restored = PlaceDiscovery(container: container, defaults: defaults)
        XCTAssertTrue(try XCTUnwrap(restored.candidates.first).dismissed)
        restored.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 20,
                             arrival: now.addingTimeInterval(-3600), departure: now, now: now)
        XCTAssertEqual(restored.candidates.count, 1)
    }

    @MainActor
    func testDisabledModuleCollectsNothing() throws {
        let suite = "discovery-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        ModuleStore(defaults: defaults).setEnabled("place_discovery", false)
        let container = try AppModelContainer.make(inMemory: true)
        let service = PlaceDiscovery(container: container, defaults: defaults)
        service.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 20,
                            arrival: now.addingTimeInterval(-3600), departure: now, now: now)
        XCTAssertTrue(service.candidates.isEmpty)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Place>()).count, 0)
    }

}
