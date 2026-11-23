import XCTest
@testable import PersonalLifeTracker

/// Fusion de lieux (plan pur) et audit des données existantes. Valeurs calculées à la main (1 degré = 111 194,93 m).
final class PlaceAuditAndMergeTests: XCTestCase {
    private let calendar: Calendar = TestCalendar.paris
    private let now: Date = makeDate(TestCalendar.paris, 2026, 11, 23, 12, 0)
    private let metersPerDegree: Double = 111_194.93
    private let idA: UUID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let idB: UUID = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    private func place(_ id: UUID, name: String = "Lieu", type: PlaceType = .taf, north: Double = 0, radius: Double = 100,
                       sessions: Int = 0, alsoWorks: Bool = false) -> PlaceSnapshot {
        return PlaceSnapshot(id: id, name: name, type: type, latitude: 48.85 + north / metersPerDegree, longitude: 2.35,
                             radius: radius, alsoWorksHere: alsoWorks, sessionCount: sessions)
    }

    private func audit(_ places: [PlaceSnapshot], _ candidates: [DiscoveredPlace] = [], kind: PlaceType? = nil) -> [PlaceAuditProblem] {
        return PlaceSuggestionAudit.audit(places: places, candidates: candidates, now: now, calendar: calendar,
                                          learnedDistance: nil,
                                          leaning: { (c: DiscoveredPlace) -> PlaceType? in return kind })
    }

    private func candidate(north: Double, days: [Int]) -> DiscoveredPlace {
        var arrivals: [Date] = []
        var visits: [PlaceVisitObservation] = []
        for day in days {
            let arrival: Date = makeDate(calendar, 2026, 11, day, 9, 0)
            arrivals.append(arrival)
            visits.append(PlaceVisitObservation(arrival: arrival, departure: arrival.addingTimeInterval(3600), accuracy: 20))
        }
        return DiscoveredPlace(latitude: 48.85 + north / metersPerDegree, longitude: 2.35, arrivals: arrivals, visits: visits)
    }

    // MARK: Plan de fusion

    func testMergePlanKeepsBusiestPlaceAndCoversBothZones() {
        let busy: PlaceSnapshot = place(idA, name: "Fac A", type: .cours, north: 0, radius: 100, sessions: 3)
        let quiet: PlaceSnapshot = place(idB, name: "Fac B", type: .cours, north: 80, radius: 100, sessions: 1)
        guard let plan = PlaceMerge.plan([quiet, busy]) else { return XCTFail("Plan attendu") }
        XCTAssertEqual(plan.keeperID, idA)
        XCTAssertEqual(plan.removedIDs, [idB])
        XCTAssertEqual(plan.name, "Fac A")
        XCTAssertEqual(plan.type, .cours)
        // Centre pondéré 3 contre 1 : à 20 m du premier lieu, 60 m du second. Rayon = 60 + 100 = 160.
        XCTAssertEqual(plan.radius, 160)
        XCTAssertFalse(plan.radiusWasCapped)
        XCTAssertEqual(plan.largestGap, 80, accuracy: 0.5)
        let shift: Double = PlaceRules.distanceMeters(latitude1: plan.latitude, longitude1: plan.longitude,
                                                      latitude2: 48.85, longitude2: 2.35)
        XCTAssertEqual(shift, 20, accuracy: 0.5)
    }

    func testMergePlanCapsRadiusAndBreaksTiesBySmallestIdentifier() {
        let first: PlaceSnapshot = place(idB, north: 0, radius: 250, sessions: 2)
        let second: PlaceSnapshot = place(idA, north: 200, radius: 250, sessions: 2)
        guard let plan = PlaceMerge.plan([first, second]) else { return XCTFail("Plan attendu") }
        XCTAssertEqual(plan.keeperID, idA)
        XCTAssertEqual(plan.radius, PlaceRules.maxRadius)
        XCTAssertTrue(plan.radiusWasCapped)
    }

    func testMergePlanNeedsTwoDistinctPlaces() {
        XCTAssertNil(PlaceMerge.plan([place(idA)]))
        XCTAssertNil(PlaceMerge.plan([place(idA), place(idA)]))
        XCTAssertNil(PlaceMerge.plan([]))
    }

    func testMergeKeepsAlsoWorksHereOnlyForShops() {
        let shop: PlaceSnapshot = place(idA, type: .courses, sessions: 2, alsoWorks: false)
        let shopWork: PlaceSnapshot = place(idB, type: .courses, north: 30, sessions: 1, alsoWorks: true)
        XCTAssertEqual(PlaceMerge.plan([shop, shopWork])?.alsoWorksHere, true)
        let work: PlaceSnapshot = place(idA, type: .taf, sessions: 2, alsoWorks: false)
        XCTAssertEqual(PlaceMerge.plan([work, shopWork])?.alsoWorksHere, false)
    }

    // MARK: Audit

    func testAuditFlagsTwoNearbyPlacesOfSameTypeAsDuplicates() {
        let problems: [PlaceAuditProblem] = audit([place(idA, name: "Lycée A", type: .cours, north: 0, radius: 50),
                                                   place(idB, name: "Lycée B", type: .cours, north: 100, radius: 50)])
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems.first?.fix, .mergePlaces(ids: [idA, idB]))
        XCTAssertTrue(problems.first?.id.hasPrefix("dup-places-") == true)
        XCTAssertEqual(problems.first?.fixTitle, "Fusionner")
    }

    func testAuditIgnoresFarApartOrDifferentTypeOrHomes() {
        XCTAssertTrue(audit([place(idA, type: .cours, north: 0, radius: 50), place(idB, type: .cours, north: 400, radius: 50)]).isEmpty)
        XCTAssertTrue(audit([place(idA, type: .cours, north: 0, radius: 50), place(idB, type: .taf, north: 100, radius: 50)]).isEmpty)
        XCTAssertTrue(audit([place(idA, type: .domicile, north: 0, radius: 50), place(idB, type: .domicile, north: 100, radius: 50)]).isEmpty)
    }

    func testAuditProposesShrinkingOverlappingZonesOfDifferentTypes() {
        // 120 m d'écart, 100 m chacun : chevauchement de 80 m, on retire 40 + 5 = 45 m de chaque rayon, soit 55 arrondi à 60.
        let problems: [PlaceAuditProblem] = audit([place(idA, type: .cours, north: 0, radius: 100),
                                                   place(idB, type: .taf, north: 120, radius: 100)])
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems.first?.fix, .shrinkZones(changes: [PlaceZoneChange(placeID: idA, radius: 60),
                                                                  PlaceZoneChange(placeID: idB, radius: 60)]))
        // Si un rayon passerait sous le minimum de 50 m, pas de correction en un geste.
        // Exemple : 80 m d'écart, 60 m chacun, chevauchement de 40 m, on retirerait 25 m : 35 m, sous le minimum.
        XCTAssertTrue(audit([place(idA, type: .cours, north: 0, radius: 60), place(idB, type: .taf, north: 80, radius: 60)]).isEmpty)
    }

    func testAuditFlagsSchoolNameRegisteredAsWork() {
        let wrong: [PlaceAuditProblem] = audit([place(idA, name: "Lycée Pasteur", type: .taf, north: 0, radius: 100)])
        XCTAssertEqual(wrong.count, 1)
        XCTAssertEqual(wrong.first?.fix, .changeType(placeID: idA, to: .cours))
        XCTAssertEqual(wrong.first?.fixTitle, "Passer en Cours")
        XCTAssertTrue(audit([place(idA, name: "Lycée Pasteur", type: .cours)]).isEmpty)
        // Cinq sessions : l'utilisateur a prouvé son choix, on ne le contredit pas sur un nom.
        XCTAssertTrue(audit([place(idA, name: "Lycée Pasteur", type: .taf, sessions: 5)]).isEmpty)
        // Magasin où l'on travaille aussi : jamais signalé.
        XCTAssertTrue(audit([place(idA, name: "Carrefour Market", type: .courses, alsoWorks: true)]).isEmpty)
    }

    func testAuditFlagsDuplicateSuggestionsAndOffersToEnlargeExistingPlace() {
        let twins: [DiscoveredPlace] = [candidate(north: 0, days: [16, 17]), candidate(north: 80, days: [18, 19])]
        let duplicates: [PlaceAuditProblem] = audit([], twins, kind: .cours)
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates.first?.fixTitle, "Regrouper")
        XCTAssertEqual(audit([], [candidate(north: 0, days: [16, 17]), candidate(north: 400, days: [18, 19])], kind: .cours).count, 0)

        let existing: PlaceSnapshot = place(idA, name: "Fac", type: .cours, north: 0, radius: 100)
        let overlapping: [PlaceAuditProblem] = audit([existing], [candidate(north: 140, days: [18, 19])])
        XCTAssertEqual(overlapping.count, 1)
        XCTAssertEqual(overlapping.first?.fixTitle, "Agrandir")
        if case .enlargePlace(let shape, let ids)? = overlapping.first?.fix {
            XCTAssertEqual(shape.radius, 150)
            XCTAssertEqual(ids.count, 1)
        } else {
            XCTFail("Un agrandissement était attendu")
        }
    }

    func testAuditProblemsAreSortedByPriorityThenId() {
        let twins: [DiscoveredPlace] = [candidate(north: 0, days: [16, 17]), candidate(north: 80, days: [18, 19])]
        let problems: [PlaceAuditProblem] = audit([place(idA, name: "A", type: .cours, north: 5000, radius: 50),
                                                   place(idB, name: "B", type: .cours, north: 5100, radius: 50)], twins, kind: .cours)
        XCTAssertEqual(problems.map { (p: PlaceAuditProblem) -> Int in return p.priority }, [0, 1])
    }
}
