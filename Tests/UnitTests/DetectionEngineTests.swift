import XCTest
@testable import PersonalLifeTracker

final class DetectionEngineTests: XCTestCase {

    private let taf = DetectionPlace(uid: UUID(), name: "Supérette du Canal", type: .taf)
    private let lycee = DetectionPlace(uid: UUID(), name: "Lycée Pasteur", type: .cours)
    private let courses = DetectionPlace(uid: UUID(), name: "Carrefour", type: .courses)

    // Les seuils sont ceux de notes/core_geofence.md : 5 min de présence, 3 min de grâce.

    func testNormalArrivalThenDeparture() {
        var engine = DetectionEngine()
        XCTAssertEqual(engine.handle(.entered(place: taf, date: nov16(17, 56, 12), accuracy: 30)), [])
        // 4 min 59 s plus tard : pas encore compté.
        XCTAssertEqual(engine.handle(.tick(date: nov16(18, 1, 11))), [])
        // 5 min pile : arrivée comptée à l'heure exacte d'entrée, jamais à l'heure du tick.
        let arrival = engine.handle(.tick(date: nov16(18, 1, 12)))
        XCTAssertEqual(arrival, [
            .startSession(place: taf, date: nov16(17, 56, 12), isUncertain: false),
            .askConfirmation(place: taf, bound: .arrival, date: nov16(17, 56, 12))
        ])
        XCTAssertTrue(engine.isSessionRunning)

        XCTAssertEqual(engine.handle(.exited(place: taf, date: nov16(22, 3, 40))), [])
        // 2 min 59 s après la sortie : la session tourne encore.
        XCTAssertEqual(engine.handle(.tick(date: nov16(22, 6, 39))), [])
        let departure = engine.handle(.tick(date: nov16(22, 6, 40)))
        XCTAssertEqual(departure, [
            .stopSession(place: taf, date: nov16(22, 3, 40)),
            .askConfirmation(place: taf, bound: .departure, date: nov16(22, 3, 40))
        ])
        XCTAssertFalse(engine.isSessionRunning)
    }

    func testShortVisitIsIgnored() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: taf, date: nov16(9, 0, 0), accuracy: nil))
        let decisions = engine.handle(.exited(place: taf, date: nov16(9, 4, 59)))
        XCTAssertEqual(decisions, [.ignoreShortVisit(place: taf, entered: nov16(9, 0, 0), exited: nov16(9, 4, 59))])
        // Plus rien à attendre : un tick tardif ne crée pas de session.
        XCTAssertEqual(engine.handle(.tick(date: nov16(10, 0, 0))), [])
        XCTAssertFalse(engine.hasPendingWork)
    }

    func testExactlyMinimumDwellOnExitCountsAsArrival() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: taf, date: nov16(9, 0, 0), accuracy: nil))
        let decisions = engine.handle(.exited(place: taf, date: nov16(9, 5, 0)))
        XCTAssertEqual(decisions, [
            .startSession(place: taf, date: nov16(9, 0, 0), isUncertain: false),
            .askConfirmation(place: taf, bound: .arrival, date: nov16(9, 0, 0))
        ])
        // La sortie est en attente du délai de grâce.
        XCTAssertEqual(engine.nextDeadline(), nov16(9, 8, 0))
    }

    func testExitGlitchInsideGraceDelayKeepsSession() {
        var engine = DetectionEngine()
        engine.syncRunningSession(isRunning: true, place: taf)
        XCTAssertEqual(engine.handle(.exited(place: taf, date: nov16(14, 0, 0))), [])
        let back = engine.handle(.entered(place: taf, date: nov16(14, 1, 30), accuracy: 20))
        XCTAssertEqual(back, [.departureCancelled(place: taf, date: nov16(14, 1, 30))])
        // Longtemps après : la session n'est pas arrêtée.
        XCTAssertEqual(engine.handle(.tick(date: nov16(15, 0, 0))), [])
        XCTAssertTrue(engine.isSessionRunning)
    }

    func testExitWithoutEntryAndNoSessionDoesNothing() {
        var engine = DetectionEngine()
        let decisions = engine.handle(.exited(place: taf, date: nov16(8, 0, 0)))
        XCTAssertEqual(decisions, [.ignoreExitWithoutEntry(place: taf, date: nov16(8, 0, 0))])
        XCTAssertEqual(engine.handle(.tick(date: nov16(9, 0, 0))), [])
    }

    func testExitAfterRelaunchStopsSessionStartedBefore() {
        // L'app a été relancée : le moteur est neuf, mais la base contient une session en cours dans ce lieu.
        var engine = DetectionEngine()
        engine.syncRunningSession(isRunning: true, place: taf)
        XCTAssertEqual(engine.handle(.exited(place: taf, date: nov16(20, 0, 0))), [])
        let decisions = engine.handle(.tick(date: nov16(20, 3, 0)))
        XCTAssertEqual(decisions.first, .stopSession(place: taf, date: nov16(20, 0, 0)))
    }

    func testCoursesPlaceIsNotedWithoutSession() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: courses, date: nov16(11, 0, 0), accuracy: 15))
        let decisions = engine.handle(.tick(date: nov16(11, 6, 0)))
        XCTAssertEqual(decisions, [.noteVisit(place: courses, entered: nov16(11, 0, 0))])
        XCTAssertFalse(engine.isSessionRunning)
        // La sortie ne produit ni arrêt ni demande.
        XCTAssertEqual(engine.handle(.exited(place: courses, date: nov16(11, 30, 0))), [])
        XCTAssertEqual(engine.handle(.tick(date: nov16(12, 0, 0))), [])
    }

    func testCoursesAlsoWorksHereStillCreatesNoSession() {
        let mixed = DetectionPlace(uid: UUID(), name: "Intermarché", type: .courses, alsoWorksHere: true)
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: mixed, date: nov16(11, 0, 0), accuracy: nil))
        let decisions = engine.handle(.tick(date: nov16(11, 10, 0)))
        XCTAssertEqual(decisions, [.noteVisit(place: mixed, entered: nov16(11, 0, 0))])
    }

    func testSecondPlaceWhileSessionRunningDoesNotStartAnotherSession() {
        var engine = DetectionEngine()
        engine.syncRunningSession(isRunning: true, place: taf)
        _ = engine.handle(.entered(place: lycee, date: nov16(10, 0, 0), accuracy: 10))
        let decisions = engine.handle(.tick(date: nov16(10, 6, 0)))
        XCTAssertEqual(decisions, [.skipBecauseSessionRunning(place: lycee, date: nov16(10, 0, 0))])
        XCTAssertEqual(engine.runningPlace, taf)
    }

    func testSecondPlaceAfterFirstSessionStoppedStartsNormally() {
        var engine = DetectionEngine()
        engine.syncRunningSession(isRunning: true, place: taf)
        _ = engine.handle(.exited(place: taf, date: nov16(12, 0, 0)))
        _ = engine.handle(.entered(place: lycee, date: nov16(12, 10, 0), accuracy: 10))
        // Un seul tick après les deux délais : départ traité avant l'arrivée.
        let decisions = engine.handle(.tick(date: nov16(12, 16, 0)))
        XCTAssertEqual(decisions, [
            .stopSession(place: taf, date: nov16(12, 0, 0)),
            .askConfirmation(place: taf, bound: .departure, date: nov16(12, 0, 0)),
            .startSession(place: lycee, date: nov16(12, 10, 0), isUncertain: false),
            .askConfirmation(place: lycee, bound: .arrival, date: nov16(12, 10, 0))
        ])
    }

    func testManualSessionBlocksDetection() {
        var engine = DetectionEngine()
        // Session manuelle sans lieu.
        engine.syncRunningSession(isRunning: true, place: nil)
        _ = engine.handle(.entered(place: taf, date: nov16(8, 0, 0), accuracy: nil))
        let decisions = engine.handle(.tick(date: nov16(8, 6, 0)))
        XCTAssertEqual(decisions, [.skipBecauseSessionRunning(place: taf, date: nov16(8, 0, 0))])
    }

    func testPoorAccuracyMarksArrivalUncertain() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: taf, date: nov16(7, 0, 0), accuracy: 100.5))
        let decisions = engine.handle(.tick(date: nov16(7, 5, 0)))
        XCTAssertEqual(decisions.first, .startSession(place: taf, date: nov16(7, 0, 0), isUncertain: true))
    }

    func testAccuracyExactlyAtLimitIsTrusted() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: taf, date: nov16(7, 0, 0), accuracy: 100))
        let decisions = engine.handle(.tick(date: nov16(7, 5, 0)))
        XCTAssertEqual(decisions.first, .startSession(place: taf, date: nov16(7, 0, 0), isUncertain: false))
    }

    func testDuplicateEntryEventDoesNotRestartDwell() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: taf, date: nov16(7, 0, 0), accuracy: nil))
        _ = engine.handle(.entered(place: taf, date: nov16(7, 3, 0), accuracy: nil))
        let decisions = engine.handle(.tick(date: nov16(7, 5, 0)))
        XCTAssertEqual(decisions.first, .startSession(place: taf, date: nov16(7, 0, 0), isUncertain: false))
    }

    func testNextDeadlineIsEarliestPending() {
        var engine = DetectionEngine()
        XCTAssertNil(engine.nextDeadline())
        _ = engine.handle(.entered(place: lycee, date: nov16(9, 0, 0), accuracy: nil))
        XCTAssertEqual(engine.nextDeadline(), nov16(9, 5, 0))
    }

    func testRegionSelectionKeepsNearestTwentyAndSkipsInvalid() {
        var candidates: [RegionCandidate] = []
        // 25 lieux alignés sur un méridien, de plus en plus loin de (48.0, 2.0).
        for i in 0..<25 {
            candidates.append(RegionCandidate(uid: UUID(), latitude: 48.0 + Double(i) * 0.01, longitude: 2.0))
        }
        candidates.append(RegionCandidate(uid: UUID(), latitude: 200, longitude: 2.0))
        let selected = RegionSelection.select(candidates, referenceLatitude: 48.0, referenceLongitude: 2.0)
        XCTAssertEqual(selected.count, 20)
        let expected: [UUID] = candidates[0..<20].map { $0.uid }
        XCTAssertEqual(selected, expected)
    }

    func testRegionSelectionFarReferencePicksOtherEnd() {
        var candidates: [RegionCandidate] = []
        for i in 0..<25 {
            candidates.append(RegionCandidate(uid: UUID(), latitude: 48.0 + Double(i) * 0.01, longitude: 2.0))
        }
        // Référence près du dernier lieu : on garde les 20 derniers.
        let selected = RegionSelection.select(candidates, referenceLatitude: 48.24, referenceLongitude: 2.0)
        XCTAssertEqual(Set(selected), Set(candidates[5..<25].map { $0.uid }))
    }
}
