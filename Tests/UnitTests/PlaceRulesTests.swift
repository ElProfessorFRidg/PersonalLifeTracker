import XCTest
@testable import PersonalLifeTracker

final class PlaceRulesTests: XCTestCase {
    // 1 degré de latitude = 6 371 000 m x pi / 180 = 111 194,93 m (calcul à la main).
    private let metersPerDegree: Double = 111_194.93

    func testNameEmptyAndWhitespaceRejected() {
        XCTAssertEqual(PlaceRules.nameIssue("", existingNames: []), .empty)
        XCTAssertEqual(PlaceRules.nameIssue("  \n ", existingNames: ["Taf"]), .empty)
    }

    func testNameDuplicateIgnoresCaseAccentsAndSpaces() {
        XCTAssertEqual(PlaceRules.nameIssue("  fac  de LETTRES ", existingNames: ["Fac de lettres"]), .duplicate)
        XCTAssertEqual(PlaceRules.nameIssue("Marché", existingNames: ["marche"]), .duplicate)
    }

    func testNameValidWhenDifferent() {
        XCTAssertNil(PlaceRules.nameIssue("Supérette", existingNames: ["Fac", "Marché"]))
    }

    func testCleanedNameCollapsesSpaces() {
        XCTAssertEqual(PlaceRules.cleanedName("  Le   Canal \n"), "Le Canal")
    }

    func testClampRadius() {
        XCTAssertEqual(PlaceRules.clampRadius(10), 50)
        XCTAssertEqual(PlaceRules.clampRadius(500), 300)
        XCTAssertEqual(PlaceRules.clampRadius(120), 120)
        XCTAssertEqual(PlaceRules.clampRadius(Double.nan), 100)
    }

    func testRadiusValidityBounds() {
        XCTAssertTrue(PlaceRules.isRadiusValid(50))
        XCTAssertTrue(PlaceRules.isRadiusValid(300))
        XCTAssertFalse(PlaceRules.isRadiusValid(49.9))
        XCTAssertFalse(PlaceRules.isRadiusValid(300.1))
    }

    func testCoordinateValidity() {
        XCTAssertTrue(PlaceRules.isValidCoordinate(latitude: 48.85, longitude: 2.35))
        XCTAssertFalse(PlaceRules.isValidCoordinate(latitude: 91, longitude: 0))
        XCTAssertFalse(PlaceRules.isValidCoordinate(latitude: 0, longitude: -181))
        XCTAssertFalse(PlaceRules.isValidCoordinate(latitude: Double.nan, longitude: 0))
    }

    func testDistanceSamePointIsZero() {
        XCTAssertEqual(PlaceRules.distanceMeters(latitude1: 48.85, longitude1: 2.35, latitude2: 48.85, longitude2: 2.35), 0, accuracy: 0.001)
    }

    func testDistanceOneDegreeOfLatitude() {
        let d = PlaceRules.distanceMeters(latitude1: 0, longitude1: 0, latitude2: 1, longitude2: 0)
        XCTAssertEqual(d, metersPerDegree, accuracy: 1)
    }

    func testDistanceOneDegreeOfLongitudeAtEquator() {
        let d = PlaceRules.distanceMeters(latitude1: 0, longitude1: 10, latitude2: 0, longitude2: 11)
        XCTAssertEqual(d, metersPerDegree, accuracy: 1)
    }

    func testDistanceOneDegreeOfLongitudeAtSixtyNorthIsHalf() {
        // cos(60 degrés) = 0,5 : la moitié de 111 194,93 m, soit 55 597,46 m.
        let d = PlaceRules.distanceMeters(latitude1: 60, longitude1: 5, latitude2: 60, longitude2: 6)
        XCTAssertEqual(d, 55_597.46, accuracy: 30)
    }

    func testDistanceParisLyonAbout392Km() {
        let d = PlaceRules.distanceMeters(latitude1: 48.8566, longitude1: 2.3522, latitude2: 45.7640, longitude2: 4.8357)
        XCTAssertEqual(d, 392_000, accuracy: 3_000)
    }

    func testDistanceIsSymmetric() {
        let ab = PlaceRules.distanceMeters(latitude1: 10, longitude1: 20, latitude2: 11, longitude2: 22)
        let ba = PlaceRules.distanceMeters(latitude1: 11, longitude1: 22, latitude2: 10, longitude2: 20)
        XCTAssertEqual(ab, ba, accuracy: 0.001)
    }

    func testIsInsideRadius() {
        // 0,0005 degré de latitude = 55,6 m.
        XCTAssertTrue(PlaceRules.isInside(latitude: 0.0005, longitude: 0, centerLatitude: 0, centerLongitude: 0, radius: 100))
        // 0,001 degré = 111,2 m, hors d'un rayon de 100 m.
        XCTAssertFalse(PlaceRules.isInside(latitude: 0.001, longitude: 0, centerLatitude: 0, centerLongitude: 0, radius: 100))
        XCTAssertTrue(PlaceRules.isInside(latitude: 0.001, longitude: 0, centerLatitude: 0, centerLongitude: 0, radius: 112))
    }

    func testOverlapDetected() {
        // Centres a 111,2 m : 60 + 60 = 120 recouvre, 50 + 50 = 100 non.
        let a = PlaceRules.Zone(name: "A", latitude: 0, longitude: 0, radius: 60)
        let b = PlaceRules.Zone(name: "B", latitude: 0.001, longitude: 0, radius: 60)
        XCTAssertTrue(PlaceRules.overlaps(a, b))
        let c = PlaceRules.Zone(name: "C", latitude: 0, longitude: 0, radius: 50)
        let d = PlaceRules.Zone(name: "D", latitude: 0.001, longitude: 0, radius: 50)
        XCTAssertFalse(PlaceRules.overlaps(c, d))
    }

    func testOverlappingNamesAndWarning() {
        let candidate = PlaceRules.Zone(name: "Nouveau", latitude: 0, longitude: 0, radius: 100)
        let near = PlaceRules.Zone(name: "Proche", latitude: 0.001, longitude: 0, radius: 100)
        let far = PlaceRules.Zone(name: "Loin", latitude: 1, longitude: 0, radius: 100)
        let names = PlaceRules.overlappingNames(candidate, among: [near, far])
        XCTAssertEqual(names, ["Proche"])
        XCTAssertNil(PlaceRules.overlapWarning(names: []))
        XCTAssertEqual(PlaceRules.overlapWarning(names: ["Proche"]),
                       "Cette zone touche celle de Proche. Je risque d'hésiter entre les deux. Réduis le rayon ou décale l'épingle.")
    }

    // MARK: Stats du mois

    func testMonthStatsFullHours() {
        let cal = TestCalendar.utc
        let now = nov16(22, 0)
        let visits: [PlaceVisitInput] = [
            // 17:56 devient 18:00, 21:00 reste 21:00 : 3 h = 10 800 s.
            PlaceVisitInput(start: nov16(17, 56), end: nov16(21, 0), chosenStart: nil, chosenEnd: nil),
            // 9 novembre, 08:00 à 12:00 : 4 h = 14 400 s.
            PlaceVisitInput(start: makeDate(cal, 2026, 11, 9, 8, 0), end: makeDate(cal, 2026, 11, 9, 12, 0), chosenStart: nil, chosenEnd: nil),
            // Octobre : hors du mois.
            PlaceVisitInput(start: makeDate(cal, 2026, 10, 30, 8, 0), end: makeDate(cal, 2026, 10, 30, 12, 0), chosenStart: nil, chosenEnd: nil)
        ]
        let m = PlaceStats.month(visits: visits, now: now, base: .fullHours, calendar: cal)
        XCTAssertEqual(m.visits, 2)
        XCTAssertEqual(m.seconds, 25_200)
        XCTAssertFalse(m.hasProvisional)
    }

    func testMonthStatsExactBase() {
        let cal = TestCalendar.utc
        let visits: [PlaceVisitInput] = [
            PlaceVisitInput(start: nov16(17, 56), end: nov16(21, 0), chosenStart: nil, chosenEnd: nil)
        ]
        let m = PlaceStats.month(visits: visits, now: nov16(22, 0), base: .exact, calendar: cal)
        // 3 h 04 = 11 040 s.
        XCTAssertEqual(m.seconds, 11_040)
    }

    func testMonthStatsDoubtWithoutChoiceIsProvisional() {
        let cal = TestCalendar.utc
        // 20:38 est en zone de doute : sans choix, on retombe sur l'exact (17:56 a 20:38 = 2 h 42 = 9 720 s).
        let visits: [PlaceVisitInput] = [
            PlaceVisitInput(start: nov16(17, 56), end: nov16(20, 38), chosenStart: nil, chosenEnd: nil)
        ]
        let m = PlaceStats.month(visits: visits, now: nov16(22, 0), base: .fullHours, calendar: cal)
        XCTAssertEqual(m.seconds, 9_720)
        XCTAssertTrue(m.hasProvisional)
    }

    func testLastVisitText() {
        let cal = TestCalendar.utc
        let now = nov16(22, 0)
        XCTAssertEqual(PlaceFormat.lastVisit(nil, now: now, calendar: cal), "Pas encore de visite")
        XCTAssertEqual(PlaceFormat.lastVisit(nov16(17, 56), now: now, calendar: cal), "Dernière visite : aujourd'hui, 17:56")
        XCTAssertEqual(PlaceFormat.lastVisit(makeDate(cal, 2026, 11, 15, 8, 5), now: now, calendar: cal), "Dernière visite : hier, 08:05")
    }

    func testDayLabel() {
        let cal = TestCalendar.utc
        let now = nov16(22, 0)
        XCTAssertEqual(PlaceFormat.dayLabel(nov16(8, 0), now: now, calendar: cal), "Aujourd'hui")
        XCTAssertEqual(PlaceFormat.dayLabel(makeDate(cal, 2026, 11, 15, 8, 0), now: now, calendar: cal), "Hier")
        XCTAssertEqual(PlaceFormat.dayLabel(makeDate(cal, 2026, 11, 14, 8, 0), now: now, calendar: cal), "Samedi 14 novembre")
    }
}
