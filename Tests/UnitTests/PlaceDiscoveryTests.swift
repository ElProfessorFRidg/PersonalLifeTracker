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

    func testTwoSeparateDaysProduceOneSuggestionAndThirdAddsEvidence() {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 48, duration: 900)
        XCTAssertFalse(PlaceDiscoveryRules.acceptsSuggestion(candidates[0], now: now, calendar: TestCalendar.paris))
        record(&candidates, hoursAgo: 24, duration: 900)
        XCTAssertTrue(PlaceDiscoveryRules.acceptsSuggestion(candidates[0], now: now, calendar: TestCalendar.paris))
        record(&candidates, hoursAgo: 1)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].arrivals.count, 3)
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
                                         arrivals: [now.addingTimeInterval(-46 * 86400)])]
        record(&candidates, hoursAgo: 24, duration: 900)
        XCTAssertEqual(candidates[0].arrivals.count, 1)
        XCTAssertFalse(PlaceDiscoveryRules.acceptsSuggestion(candidates[0], now: now, calendar: TestCalendar.paris))
    }

    func testPersonalPlacesNeverCreateWorkSessions() {
        for type in [PlaceType.domicile, .sport, .sortie, .autre] {
            let place = DetectionPlace(uid: UUID(), name: type.title, type: type)
            XCTAssertFalse(place.createsSessions)
            XCTAssertEqual(type.defaultActivity, .personal)
            var engine = DetectionEngine()
            _ = engine.handle(.entered(place: place, date: now, accuracy: 10))
            let decisions = engine.handle(.tick(date: now.addingTimeInterval(600)))
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
        XCTAssertEqual(candidate.arrivals.count, 3)
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

    func testFridaySaturdayAndSundayMorningSuggestWorkWithoutMisclassifyingHome() {
        let calendar = TestCalendar.paris
        let now = makeDate(calendar, 2026, 11, 23, 12, 0)
        var candidates: [DiscoveredPlace] = []
        for day in [20, 21, 22] {
            let shift = makeDate(calendar, 2026, 11, day, 6, 0)
            PlaceDiscoveryRules.record(in: &candidates, latitude: 48.85, longitude: 2.35,
                                       accuracy: 20, arrival: shift, departure: shift.addingTimeInterval(4 * 3600), now: now)
            let evening = makeDate(calendar, 2026, 11, day, 22, 0)
            let morning = makeDate(calendar, 2026, 11, day + 1, 5, 30)
            PlaceDiscoveryRules.record(in: &candidates, latitude: 48.87, longitude: 2.35,
                                       accuracy: 20, arrival: evening, departure: morning, now: now)
            for hour in [12, 16] {
                let daytime = makeDate(calendar, 2026, 11, day, hour, 0)
                PlaceDiscoveryRules.record(in: &candidates, latitude: 48.87, longitude: 2.35,
                                           accuracy: 20, arrival: daytime, departure: daytime.addingTimeInterval(900), now: now)
            }
        }
        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates.map { PlaceDiscoveryRules.recommendation($0, now: now, calendar: calendar)?.type },
                       [.taf, .domicile])
    }

    func testNearbyAccurateBuildingsRemainSeparateAndNewVisitCanBeReviewed() {
        var candidates: [DiscoveredPlace] = []
        record(&candidates, hoursAgo: 5, latitude: 48.85, duration: 1800)
        record(&candidates, hoursAgo: 2, latitude: 48.85055, duration: 900)
        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates.filter {
            PlaceDiscoveryRules.acceptsSuggestion($0, now: now, calendar: TestCalendar.paris)
        }.map(\.latitude), [48.85])
    }

    func testNoisierFixesAcrossThreeDaysStillGroupTheSameWorkplace() throws {
        let calendar = TestCalendar.paris
        let now = makeDate(calendar, 2026, 11, 23, 12, 0)
        var candidates: [DiscoveredPlace] = []
        let fixes: [(day: Int, latitude: Double, accuracy: Double)] = [
            (20, 48.85, 15), (21, 48.8506, 85), (22, 48.8495, 80)
        ]
        for fix in fixes {
            let start = makeDate(calendar, 2026, 11, fix.day, 8, 0)
            PlaceDiscoveryRules.record(in: &candidates, latitude: fix.latitude, longitude: 2.35,
                                       accuracy: fix.accuracy, arrival: start,
                                       departure: start.addingTimeInterval(5 * 3600), now: now)
        }
        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidate.arrivals.count, 3)
        XCTAssertTrue(PlaceDiscoveryRules.acceptsSuggestion(candidate, now: now, calendar: calendar))
        XCTAssertEqual(PlaceDiscoveryRules.recommendation(candidate, now: now, calendar: calendar)?.type, .taf)
    }

    func testSchoolMapEvidenceWinsOverLongDaytimeVisits() throws {
        var candidates: [DiscoveredPlace] = []
        for hours in [72.0, 48.0, 24.0] {
            record(&candidates, hoursAgo: hours, duration: 5 * 3600)
        }
        var school = try XCTUnwrap(candidates.first)
        school.context = DiscoveredPlaceContext(name: "Lycée", address: nil, category: .cours)
        XCTAssertEqual(PlaceDiscoveryRules.recommendation(school, now: now, calendar: TestCalendar.paris)?.type, .cours)
    }

    func testOrdinaryWeekdayVisitsRemainUncategorizedWithoutMapEvidence() {
        let calendar = TestCalendar.paris
        let now = makeDate(calendar, 2026, 11, 20, 18, 0)
        var candidates: [DiscoveredPlace] = []
        for day in [16, 17, 18] {
            let arrival = makeDate(calendar, 2026, 11, day, 8, 15)
            PlaceDiscoveryRules.record(in: &candidates, latitude: 48.85, longitude: 2.35,
                                       accuracy: 20, arrival: arrival, departure: arrival.addingTimeInterval(6 * 3600), now: now)
        }
        XCTAssertEqual(candidates.count, 1)
        XCTAssertNil(candidates.first.flatMap { PlaceDiscoveryRules.recommendation($0, now: now, calendar: calendar) })
    }

    func testLegacyArrivalsDecodeAndStillQualifyWithoutInventedDurations() throws {
        struct OldCandidate: Encodable {
            let id = UUID()
            let latitude = 48.85
            let longitude = 2.35
            let arrivals: [Date]
            let dismissed = false
        }
        let previous = OldCandidate(arrivals: [now.addingTimeInterval(-48 * 3600), now.addingTimeInterval(-24 * 3600)])
        let data = try JSONEncoder().encode(previous)
        let candidate = try JSONDecoder().decode(DiscoveredPlace.self, from: data)
        XCTAssertEqual(candidate.id, previous.id)
        XCTAssertEqual(candidate.arrivals, previous.arrivals)
        XCTAssertTrue(PlaceDiscoveryRules.acceptsSuggestion(candidate, now: now, calendar: TestCalendar.paris))
        XCTAssertTrue(PlaceDiscoveryRules.observations(candidate, now: now).isEmpty)
        XCTAssertNil(PlaceDiscoveryRules.recommendation(candidate, now: now, calendar: TestCalendar.paris))
    }

    @MainActor
    func testStoredLegacyArrivalCombinesWithNewVisitsAndCanGainDeparture() throws {
        struct LegacyStop: Encodable {
            let id: UUID
            let latitude = 48.85
            let longitude = 2.35
            let arrivals: [Date]
            let dismissed = false
        }

        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try AppModelContainer.make(inMemory: true)
        let older = now.addingTimeInterval(-72 * 3600)
        let replayed = now.addingTimeInterval(-48 * 3600)
        let legacy = LegacyStop(id: UUID(), arrivals: [older, replayed])
        defaults.set(try JSONEncoder().encode([legacy]), forKey: "plt.discovery.stops.v1")

        let discovery = PlaceDiscovery(container: container, defaults: defaults)
        let old = try XCTUnwrap(discovery.suggestions(excluding: [], now: now).first)
        XCTAssertEqual(old.id, legacy.id)
        XCTAssertTrue(discovery.observations(for: old, now: now).isEmpty)

        let replayedDeparture = replayed.addingTimeInterval(50 * 60)
        discovery.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 20,
                              arrival: replayed, departure: replayedDeparture, now: now)
        let newArrival = now.addingTimeInterval(-3600)
        discovery.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 25,
                              arrival: newArrival, departure: newArrival.addingTimeInterval(900), now: now)
        let restored = PlaceDiscovery(container: container, defaults: defaults)
        let merged = try XCTUnwrap(restored.suggestions(excluding: [], now: now).first)
        XCTAssertEqual(merged.id, legacy.id)
        XCTAssertEqual(merged.arrivals, [older, replayed, newArrival])
        XCTAssertEqual(restored.observations(for: merged, now: now).map(\.arrival), [replayed, newArrival])
        XCTAssertEqual(restored.observations(for: merged, now: now).first?.departure, replayedDeparture)
    }

    @MainActor
    func testArrivalOnlySurvivesRelaunchAndJoinsDepartureOnly() throws {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try AppModelContainer.make(inMemory: true)
        let arrival = now.addingTimeInterval(-3600)
        let initial = PlaceDiscovery(container: container, defaults: defaults)
        initial.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 20,
                            arrival: arrival, departure: .distantFuture, now: now)
        XCTAssertTrue(initial.candidates.isEmpty)

        let restored = PlaceDiscovery(container: container, defaults: defaults)
        for _ in 0..<2 {
            restored.recordVisit(latitude: 48.8501, longitude: 2.35, accuracy: 35,
                                 arrival: .distantPast, departure: now, now: now)
        }
        let candidate = try XCTUnwrap(restored.suggestions(excluding: [], now: now).first)
        XCTAssertEqual(restored.observations(for: candidate, now: now).map(\.duration), [3600])
        XCTAssertEqual(candidate.latitude, 48.85)
    }

    @MainActor
    func testImpreciseDepartureCompletesMatchingAccurateArrivalOnly() throws {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try AppModelContainer.make(inMemory: true)
        let discovery = PlaceDiscovery(container: container, defaults: defaults)
        let arrival = now.addingTimeInterval(-5 * 3600)
        discovery.recordVisit(latitude: 48.85, longitude: 2.35, accuracy: 20,
                              arrival: arrival, departure: .distantFuture, now: now)
        XCTAssertTrue(discovery.hasRecentArrivalAwaitingDeparture(now: now))
        discovery.recordVisit(latitude: 48.8505, longitude: 2.35, accuracy: 150,
                              arrival: arrival.addingTimeInterval(20 * 60), departure: now, now: now)
        XCTAssertTrue(discovery.candidates.isEmpty)
        discovery.recordVisit(latitude: 48.8505, longitude: 2.35, accuracy: 150,
                              arrival: arrival, departure: now, now: now)
        let candidate = try XCTUnwrap(discovery.suggestions(excluding: [], now: now).first)
        XCTAssertEqual(candidate.latitude, 48.85)
        XCTAssertEqual(discovery.observations(for: candidate, now: now).map(\.duration), [5 * 3600])
        XCTAssertFalse(discovery.hasRecentArrivalAwaitingDeparture(now: now))
    }

    @MainActor
    func testLargeSavedZoneDoesNotSuppressAnotherBuildingAndClearingRemovesSuggestions() throws {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try AppModelContainer.make(inMemory: true)
        let existing = Place(name: "Chez moi", type: .domicile, latitude: 48.85, longitude: 2.35, radius: 200)
        container.mainContext.insert(existing)
        try container.mainContext.save()
        let discovery = PlaceDiscovery(container: container, defaults: defaults)
        let arrival = now.addingTimeInterval(-3600)
        discovery.recordVisit(latitude: 48.85055, longitude: 2.35, accuracy: 20,
                              arrival: arrival, departure: now, now: now)
        let suggestion = try XCTUnwrap(discovery.suggestions(excluding: [existing], now: now).first)
        discovery.clearHistory()
        XCTAssertFalse(discovery.confirm(suggestion, type: .sport, name: "Salle"))
        let restored = PlaceDiscovery(container: container, defaults: defaults)
        XCTAssertTrue(restored.suggestions(excluding: [existing], now: now).isEmpty)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Place>()).map(\.name), ["Chez moi"])
    }

}
