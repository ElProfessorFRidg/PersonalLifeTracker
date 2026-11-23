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

    func testRepeatedExitKeepsFirstDepartureAndItsGracePeriod() {
        var engine = DetectionEngine()
        engine.syncRunningSession(isRunning: true, place: taf)
        let firstExit = nov16(20, 0)
        _ = engine.handle(.exited(place: taf, date: firstExit))
        _ = engine.handle(.exited(place: taf, date: nov16(20, 2)))
        XCTAssertEqual(engine.handle(.tick(date: nov16(20, 3))).first,
                       .stopSession(place: taf, date: firstExit))
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

    func testOnlyARecentAccurateFixCanContradictARegionEntry() {
        let workplace = PlaceRules.Zone(name: "Taf", latitude: 48, longitude: 2, radius: 100)
        let now = nov16(11, 0)
        let precise = RegionFix(latitude: 48.0014, longitude: 2, accuracy: 10, timestamp: now)
        let imprecise = RegionFix(latitude: 48.0014, longitude: 2, accuracy: 50, timestamp: now)
        let stale = RegionFix(latitude: 48.0014, longitude: 2, accuracy: 10, timestamp: nov16(10, 59))

        XCTAssertTrue(precise.isRecent(at: now))
        XCTAssertFalse(stale.isRecent(at: now))
        XCTAssertTrue(precise.clearlyOutside(workplace))
        XCTAssertFalse(imprecise.clearlyOutside(workplace))
    }

    func testOverlappingHomeAndWorkUseDistinctPrecisePositions() {
        let workplace = PlaceRules.Zone(name: "Taf", latitude: 48, longitude: 2, radius: 100)
        let home = PlaceRules.Zone(name: "Domicile", latitude: 48.00065, longitude: 2, radius: 100)
        let now = nov16(11, 0)
        let atHome = RegionFix(latitude: home.latitude, longitude: 2, accuracy: 10, timestamp: now)
        let atWork = RegionFix(latitude: workplace.latitude, longitude: 2, accuracy: 10, timestamp: now)
        let between = RegionFix(latitude: 48.00032, longitude: 2, accuracy: 10, timestamp: now)

        XCTAssertFalse(atHome.clearlyOutside(workplace))
        XCTAssertTrue(atHome.favorsHome(home, over: workplace))
        XCTAssertFalse(atWork.favorsHome(home, over: workplace))
        XCTAssertFalse(between.favorsHome(home, over: workplace))
    }

    // MARK: Fin de visite dans un lieu de courses où l'on travaille aussi (classification, section 11)

    func testDualUseVisitEndEmitsVisitEndedWithExactTimes() {
        let mixed = DetectionPlace(uid: UUID(), name: "Intermarché", type: .courses, alsoWorksHere: true)
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: mixed, date: nov16(11, 0, 0), accuracy: nil))
        XCTAssertEqual(engine.handle(.tick(date: nov16(11, 6, 0))), [.noteVisit(place: mixed, entered: nov16(11, 0, 0))])
        XCTAssertTrue(engine.handle(.exited(place: mixed, date: nov16(13, 30, 15))).isEmpty)
        XCTAssertTrue(engine.handle(.exited(place: mixed, date: nov16(13, 31))).isEmpty)
        XCTAssertTrue(engine.handle(.tick(date: nov16(13, 33, 14))).isEmpty)
        XCTAssertEqual(engine.handle(.tick(date: nov16(13, 33, 15))),
                       [.visitEnded(place: mixed, entered: nov16(11, 0), exited: nov16(13, 30, 15))])
    }

    func testSaturdayMorningShiftSurvivesRestartAndKeepsOriginalArrival() throws {
        let mixed = DetectionPlace(uid: UUID(), name: "Supermarché", type: .courses, alsoWorksHere: true)
        let entered = makeDate(TestCalendar.paris, 2026, 11, 21, 6, 40)
        let timeAfterDwell = makeDate(TestCalendar.paris, 2026, 11, 21, 6, 45)
        let restart = makeDate(TestCalendar.paris, 2026, 11, 21, 10, 59)
        let exited = makeDate(TestCalendar.paris, 2026, 11, 21, 11, 0)

        var before = DetectionEngine()
        _ = before.handle(.entered(place: mixed, date: entered, accuracy: 30))
        XCTAssertEqual(before.handle(.tick(date: timeAfterDwell)), [.noteVisit(place: mixed, entered: entered)])
        let data = try JSONEncoder().encode(before.openMixedVisits)
        let saved = try JSONDecoder().decode([UUID: OpenMixedVisit].self, from: data)
        var after = DetectionEngine()
        after.restoreMixedVisits(saved, places: [mixed], now: restart)

        XCTAssertEqual(after.handle(.tick(date: restart)), [])
        XCTAssertTrue(after.handle(.exited(place: mixed, date: exited)).isEmpty)
        let duringGrace = exited.addingTimeInterval(30)
        let persisted = try JSONEncoder().encode(after.openMixedVisits)
        var reloaded = DetectionEngine()
        reloaded.restoreMixedVisits(try JSONDecoder().decode([UUID: OpenMixedVisit].self, from: persisted),
                                    places: [mixed], now: duringGrace)
        reloaded.syncRunningSession(isRunning: false, place: nil)
        XCTAssertEqual(reloaded.handle(.tick(date: exited.addingTimeInterval(180))),
                       [.visitEnded(place: mixed, entered: entered, exited: exited)])
        after = reloaded
        XCTAssertEqual(after.openMixedVisits, [:])
    }

    func testExpiredMixedVisitDoesNotBlockNextRealArrival() {
        let mixed = DetectionPlace(uid: UUID(), name: "Supermarché", type: .courses, alsoWorksHere: true)
        let entered = nov17(9, 0)
        var engine = DetectionEngine()
        engine.restoreMixedVisits([mixed.uid: OpenMixedVisit(entered: nov16(8, 0), dwellConfirmed: true)],
                                  places: [mixed], now: entered)
        _ = engine.handle(.entered(place: mixed, date: entered, accuracy: 30))
        XCTAssertEqual(engine.handle(.tick(date: nov17(9, 5))), [.noteVisit(place: mixed, entered: entered)])
    }

    func testDualUseExitBeforeTickNotesThenEnds() {
        let mixed = DetectionPlace(uid: UUID(), name: "Intermarché", type: .courses, alsoWorksHere: true)
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: mixed, date: nov16(11, 0, 0), accuracy: nil))
        let decisions = engine.handle(.exited(place: mixed, date: nov16(11, 10, 0)))
        XCTAssertEqual(decisions, [
            .noteVisit(place: mixed, entered: nov16(11, 0, 0))
        ])
        XCTAssertEqual(engine.handle(.tick(date: nov16(11, 13))),
                       [.visitEnded(place: mixed, entered: nov16(11, 0), exited: nov16(11, 10))])
    }

    func testPinpointInsideDuringShelfStockingKeepsMixedVisitContinuous() {
        let store = DetectionPlace(uid: UUID(), name: "Supermarché", type: .courses, alsoWorksHere: true)
        let zone = PlaceRules.Zone(name: store.name, latitude: 48, longitude: 2, radius: 100)
        let entered = nov16(7, 0)
        let falseExit = nov16(9, 0)
        let observed = nov16(9, 1)
        let actualExit = nov16(12, 0)
        let innerAisle = RegionFix(latitude: 48.0004, longitude: 2, accuracy: 15, timestamp: observed)
        let fuzzy = RegionFix(latitude: 48, longitude: 2, accuracy: 95, timestamp: observed)
        XCTAssertTrue(innerAisle.clearlyInside(zone))
        XCTAssertFalse(fuzzy.clearlyInside(zone))

        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: store, date: entered, accuracy: 15))
        _ = engine.handle(.tick(date: nov16(7, 5)))
        XCTAssertTrue(engine.handle(.exited(place: store, date: falseExit)).isEmpty)
        engine.syncRunningSession(isRunning: false, place: nil)
        XCTAssertTrue(engine.handle(.presenceVerified(place: store, date: nov16(8, 59))).isEmpty)
        XCTAssertEqual(engine.handle(.presenceVerified(place: store, date: innerAisle.timestamp)),
                       [.departureCancelled(place: store, date: observed)])
        XCTAssertTrue(engine.handle(.tick(date: nov16(9, 4))).isEmpty)
        _ = engine.handle(.exited(place: store, date: actualExit))
        XCTAssertEqual(engine.handle(.tick(date: nov16(12, 3))),
                       [.visitEnded(place: store, entered: entered, exited: actualExit)])
    }

    func testDualUseShortPassageIsStillIgnored() {
        let mixed = DetectionPlace(uid: UUID(), name: "Intermarché", type: .courses, alsoWorksHere: true)
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: mixed, date: nov16(11, 0, 0), accuracy: nil))
        let decisions = engine.handle(.exited(place: mixed, date: nov16(11, 4, 59)))
        XCTAssertEqual(decisions, [.ignoreShortVisit(place: mixed, entered: nov16(11, 0, 0), exited: nov16(11, 4, 59))])
    }

    func testPlainCoursesVisitEndEmitsNoVisitEnded() {
        var engine = DetectionEngine()
        _ = engine.handle(.entered(place: courses, date: nov16(11, 0, 0), accuracy: nil))
        _ = engine.handle(.tick(date: nov16(11, 6, 0)))
        XCTAssertEqual(engine.handle(.exited(place: courses, date: nov16(12, 0, 0))), [])
    }
}
