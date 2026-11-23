import XCTest
import SwiftData
@testable import PersonalLifeTracker

/// Regroupement des arrêts voisins et recouvrement avec les lieux enregistrés.
/// Les distances sont construites à la main : 1 degré de latitude = 6 371 000 x pi / 180 = 111 194,93 m.
final class PlaceSuggestionMergeTests: XCTestCase {
    private let calendar: Calendar = TestCalendar.paris
    private let now: Date = makeDate(TestCalendar.paris, 2026, 11, 23, 12, 0)
    private let metersPerDegree: Double = 111_194.93
    private let baseLatitude: Double = 48.85
    private let longitude: Double = 2.35

    private func candidate(north meters: Double, days: [Int], accuracy: Double = 20,
                           dismissed: Bool = false, duration: TimeInterval = 3600) -> DiscoveredPlace {
        var arrivals: [Date] = []
        var visits: [PlaceVisitObservation] = []
        for day in days {
            let arrival: Date = makeDate(calendar, 2026, 11, day, 9, 0)
            arrivals.append(arrival)
            visits.append(PlaceVisitObservation(arrival: arrival, departure: arrival.addingTimeInterval(duration), accuracy: accuracy))
        }
        var result: DiscoveredPlace = DiscoveredPlace(latitude: baseLatitude + meters / metersPerDegree,
                                                      longitude: longitude, arrivals: arrivals, visits: visits)
        result.dismissed = dismissed
        return result
    }

    private func plan(_ candidates: [DiscoveredPlace], places: [PlaceSnapshot] = [],
                      kind: PlaceType? = nil, learned: Double? = nil) -> PlaceSuggestionPlan {
        return PlaceSuggestionMerge.plan(candidates: candidates, places: places, now: now, calendar: calendar,
                                         learnedDistance: learned,
                                         leaning: { (c: DiscoveredPlace) -> PlaceType? in return kind })
    }

    private func place(north meters: Double, radius: Double, type: PlaceType = .cours) -> PlaceSnapshot {
        return PlaceSnapshot(id: UUID(), name: "Lycée", type: type, latitude: baseLatitude + meters / metersPerDegree,
                             longitude: longitude, radius: radius, alsoWorksHere: false, sessionCount: 0)
    }

    private func meters(_ a: DiscoveredPlace, _ b: DiscoveredPlace) -> Double {
        return PlaceRules.distanceMeters(latitude1: a.latitude, longitude1: a.longitude,
                                         latitude2: b.latitude, longitude2: b.longitude)
    }

    // MARK: Distance de fusion

    func testMergeDistanceStartsAt150AndWidensWithAccuracyUpToCap() {
        XCTAssertEqual(PlaceSuggestionMerge.mergeDistance(accuracyA: 20, accuracyB: 20), 150)
        XCTAssertEqual(PlaceSuggestionMerge.mergeDistance(accuracyA: 60, accuracyB: 60), 220)
        XCTAssertEqual(PlaceSuggestionMerge.mergeDistance(accuracyA: 100, accuracyB: 100), 250)
        XCTAssertEqual(PlaceSuggestionMerge.mergeDistance(accuracyA: 20, accuracyB: 20, learnedDistance: 200), 200)
        XCTAssertEqual(PlaceSuggestionMerge.mergeDistance(accuracyA: 20, accuracyB: 20, learnedDistance: 900), 250)
    }

    // MARK: Deux écoles dans la même rue

    func testTwoSchoolBuilding80mApartBecomeOneSuggestion() {
        let first: DiscoveredPlace = candidate(north: 0, days: [16, 17, 18])
        let second: DiscoveredPlace = candidate(north: 80, days: [19, 20])
        let result: PlaceSuggestionPlan = plan([first, second], kind: .cours)
        XCTAssertEqual(result.suggestions.count, 1)
        guard let item = result.suggestions.first else { return }
        XCTAssertEqual(item.memberIDs.count, 2)
        XCTAssertEqual(item.suggestion.arrivals.count, 5)
        XCTAssertEqual(item.suggestion.visits?.count, 5)
        // Centre pondéré 3 contre 2 : à 32 m du premier bâtiment, 48 m du second. Rayon = 48 + 40 = 88, arrondi à 90.
        let distanceToFirst: Double = PlaceRules.distanceMeters(latitude1: item.suggestion.latitude, longitude1: item.suggestion.longitude,
                                                                latitude2: first.latitude, longitude2: first.longitude)
        XCTAssertEqual(distanceToFirst, 32, accuracy: 0.5)
        XCTAssertEqual(item.radius, 90)
        XCTAssertEqual(item.suggestion.id, first.id)
    }

    func testBuildingsMoreThan250mApartStaySeparate() {
        let result: PlaceSuggestionPlan = plan([candidate(north: 0, days: [16, 17]),
                                                candidate(north: 400, days: [18, 19])], kind: .cours)
        XCTAssertEqual(result.suggestions.count, 2)
    }

    func testAccuracyWidensTheMergeDistance() {
        // 200 m : séparés si les fixes sont précis (limite 150), réunis si chacun annonce 60 m (limite 220).
        let precise: PlaceSuggestionPlan = plan([candidate(north: 0, days: [16, 17], accuracy: 20),
                                                 candidate(north: 200, days: [18, 19], accuracy: 20)], kind: .cours)
        XCTAssertEqual(precise.suggestions.count, 2)
        let noisy: PlaceSuggestionPlan = plan([candidate(north: 0, days: [16, 17], accuracy: 60),
                                               candidate(north: 200, days: [18, 19], accuracy: 60)], kind: .cours)
        XCTAssertEqual(noisy.suggestions.count, 1)
        // 300 m : même avec 100 m de précision, le plafond de 250 m les garde séparés.
        let capped: PlaceSuggestionPlan = plan([candidate(north: 0, days: [16, 17], accuracy: 100),
                                                candidate(north: 300, days: [18, 19], accuracy: 100)], kind: .cours)
        XCTAssertEqual(capped.suggestions.count, 2)
    }

    func testLearnedMergeDistanceWidensTheLimit() {
        let candidates: [DiscoveredPlace] = [candidate(north: 0, days: [16, 17]), candidate(north: 200, days: [18, 19])]
        XCTAssertEqual(plan(candidates, kind: .cours).suggestions.count, 2)
        XCTAssertEqual(plan(candidates, kind: .cours, learned: 220).suggestions.count, 1)
    }

    func testDifferentKindsStaySeparateUnlessSameBuilding() {
        let school: DiscoveredPlace = candidate(north: 0, days: [16, 17])
        let shop100: DiscoveredPlace = candidate(north: 100, days: [18, 19])
        let shop40: DiscoveredPlace = candidate(north: 40, days: [18, 19])
        let kinds: (DiscoveredPlace) -> PlaceType? = { (c: DiscoveredPlace) -> PlaceType? in
            return c.latitude > 48.85 ? .courses : .cours
        }
        let apart: PlaceSuggestionPlan = PlaceSuggestionMerge.plan(candidates: [school, shop100], places: [], now: now,
                                                                   calendar: calendar, learnedDistance: nil, leaning: kinds)
        XCTAssertEqual(apart.suggestions.count, 2)
        // A 40 m, c'est le même bâtiment vu par le GPS : réunis quel que soit le type.
        let same: PlaceSuggestionPlan = PlaceSuggestionMerge.plan(candidates: [school, shop40], places: [], now: now,
                                                                  calendar: calendar, learnedDistance: nil, leaning: kinds)
        XCTAssertEqual(same.suggestions.count, 1)
    }

    func testTwoSingleDayStopsNextToEachOtherAddUpToASuggestion() {
        let one: DiscoveredPlace = candidate(north: 0, days: [18], duration: 900)
        let two: DiscoveredPlace = candidate(north: 70, days: [19], duration: 900)
        XCTAssertEqual(plan([one], kind: nil).suggestions.count, 0)
        XCTAssertEqual(plan([one, two], kind: nil).suggestions.count, 1)
    }

    func testIgnoredNeighbourHidesTheNewBuildingAndCountsAsIgnored() {
        let refused: DiscoveredPlace = candidate(north: 0, days: [16, 17], dismissed: true)
        let neighbour: DiscoveredPlace = candidate(north: 90, days: [18, 19])
        let result: PlaceSuggestionPlan = plan([refused, neighbour], kind: .cours)
        XCTAssertTrue(result.suggestions.isEmpty)
        XCTAssertEqual(result.ignoredCount, 1)
    }

    func testCombineKeepsBusiestIdAndMarksMembers() {
        let big: DiscoveredPlace = candidate(north: 0, days: [16, 17, 18])
        let small: DiscoveredPlace = candidate(north: 60, days: [19])
        guard let combined = PlaceSuggestionMerge.combine([small, big]) else { return XCTFail("Fusion attendue") }
        XCTAssertEqual(combined.id, big.id)
        XCTAssertEqual(combined.mergedIDs, [small.id, big.id])
        XCTAssertEqual(combined.arrivals.count, 4)
        XCTAssertFalse(combined.dismissed)
        XCTAssertNil(PlaceSuggestionMerge.combine([big])?.mergedIDs)
        XCTAssertNil(PlaceSuggestionMerge.combine([]))
    }

    // MARK: Lieux déjà enregistrés

    func testSuggestionInsideExistingPlaceIsNeverProposed() {
        // Zone de 100 m ; le candidat est à 30 m (rayon 50) : 30 + 50 <= 100 + 30, couvert.
        let result: PlaceSuggestionPlan = plan([candidate(north: 30, days: [18, 19])], places: [place(north: 0, radius: 100)])
        XCTAssertTrue(result.suggestions.isEmpty)
        XCTAssertTrue(result.enlargements.isEmpty)
    }

    func testPartiallyOverlappingSuggestionProposesToEnlargeTheExistingPlace() {
        // Lieu de 100 m ; candidat à 140 m (rayon 50) : 140 < 100 + 50 + 30, les zones se touchent.
        // Zone englobante : (140 + 100 + 50) / 2 = 145 m, centre déplacé de 45 m vers le candidat, rayon arrondi à 150.
        let existing: PlaceSnapshot = place(north: 0, radius: 100)
        let result: PlaceSuggestionPlan = plan([candidate(north: 140, days: [18, 19])], places: [existing])
        XCTAssertTrue(result.suggestions.isEmpty)
        XCTAssertEqual(result.enlargements.count, 1)
        guard let proposal = result.enlargements.first else { return }
        XCTAssertEqual(proposal.shape.placeID, existing.id)
        XCTAssertEqual(proposal.shape.radius, 150)
        let moved: Double = PlaceRules.distanceMeters(latitude1: proposal.shape.latitude, longitude1: proposal.shape.longitude,
                                                      latitude2: existing.latitude, longitude2: existing.longitude)
        XCTAssertEqual(moved, 45, accuracy: 0.5)
    }

    func testFarSuggestionIsFreeAndOverlapWithoutRoomIsHidden() {
        let free: PlaceSuggestionPlan = plan([candidate(north: 400, days: [18, 19])], places: [place(north: 0, radius: 100)])
        XCTAssertEqual(free.suggestions.count, 1)
        // Lieu de 280 m, candidat à 300 m : les zones se touchent mais l'englobante (315 m) dépasse le maximum de 300 m.
        let hidden: PlaceSuggestionPlan = plan([candidate(north: 300, days: [18, 19])], places: [place(north: 0, radius: 280)])
        XCTAssertTrue(hidden.suggestions.isEmpty)
        XCTAssertTrue(hidden.enlargements.isEmpty)
    }

    func testSameKindPlaceWithinMergeDistanceIsEnlargedEvenWithoutTouchingZones() {
        // Lieu de 50 m, candidat à 140 m (rayon 50) : 140 >= 50 + 50 + 30 donc zones séparées,
        // mais même type (école) à moins de 150 m : on propose d'agrandir. Englobante : (140 + 50 + 50) / 2 = 120 m.
        let existing: PlaceSnapshot = place(north: 0, radius: 50, type: .cours)
        let result: PlaceSuggestionPlan = plan([candidate(north: 140, days: [18, 19])], places: [existing], kind: .cours)
        XCTAssertEqual(result.enlargements.count, 1)
        XCTAssertEqual(result.enlargements.first?.shape.radius, 120)
        let other: PlaceSuggestionPlan = plan([candidate(north: 140, days: [18, 19])], places: [existing], kind: .courses)
        XCTAssertEqual(other.suggestions.count, 1)
    }

    // MARK: Découverte complète

    @MainActor
    func testDiscoveryShowsOneSuggestionForTwoBuildingsAndConfirmCreatesOnePlace() throws {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let discovery: PlaceDiscovery = PlaceDiscovery(container: container, defaults: defaults)
        let clock: Date = Date(timeIntervalSince1970: 1_800_000_000)
        let secondLatitude: Double = baseLatitude + 80 / metersPerDegree
        for hours in [72.0, 48.0] {
            let arrival: Date = clock.addingTimeInterval(-hours * 3600)
            discovery.recordVisit(latitude: baseLatitude, longitude: longitude, accuracy: 20,
                                  arrival: arrival, departure: arrival.addingTimeInterval(3600), now: clock)
        }
        for hours in [24.0, 5.0] {
            let arrival: Date = clock.addingTimeInterval(-hours * 3600)
            discovery.recordVisit(latitude: secondLatitude, longitude: longitude, accuracy: 20,
                                  arrival: arrival, departure: arrival.addingTimeInterval(3600), now: clock)
        }
        XCTAssertEqual(discovery.candidates.count, 2)
        let suggestions: [DiscoveredPlace] = discovery.suggestions(excluding: [], now: clock)
        XCTAssertEqual(suggestions.count, 1)
        guard let suggestion = suggestions.first else { return }
        XCTAssertEqual(suggestion.arrivals.count, 4)
        XCTAssertTrue(discovery.confirm(suggestion, type: .cours, name: "Lycée Pasteur"))
        let places: [Place] = try container.mainContext.fetch(FetchDescriptor<Place>())
        XCTAssertEqual(places.count, 1)
        // Chaque bâtiment est à 40 m du centre : rayon 40 + 40 = 80.
        XCTAssertEqual(places.first?.radius, 80)
        XCTAssertTrue(discovery.candidates.allSatisfy { (c: DiscoveredPlace) -> Bool in return c.dismissed })
        XCTAssertTrue(discovery.suggestions(excluding: places, now: clock).isEmpty)
        XCTAssertEqual(discovery.kindStore.memory.lessons.count, 1)
        XCTAssertEqual(discovery.kindStore.memory.lessons.first?.chosen, "cours")
    }

    @MainActor
    func testConsolidateDuplicatesMergesStoredCandidates() throws {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let discovery: PlaceDiscovery = PlaceDiscovery(container: container, defaults: defaults)
        let clock: Date = Date(timeIntervalSince1970: 1_800_000_000)
        for (hours, offset) in [(72.0, 0.0), (48.0, 0.0), (24.0, 80.0), (5.0, 80.0)] {
            let arrival: Date = clock.addingTimeInterval(-hours * 3600)
            discovery.recordVisit(latitude: baseLatitude + offset / metersPerDegree, longitude: longitude, accuracy: 20,
                                  arrival: arrival, departure: arrival.addingTimeInterval(3600), now: clock)
        }
        XCTAssertEqual(discovery.candidates.count, 2)
        XCTAssertEqual(discovery.consolidateDuplicates(now: clock), 1)
        XCTAssertEqual(discovery.candidates.count, 1)
        XCTAssertEqual(discovery.candidates.first?.arrivals.count, 4)
        XCTAssertNil(discovery.candidates.first?.mergedIDs)
    }
}
