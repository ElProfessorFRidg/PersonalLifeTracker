import XCTest
@testable import PersonalLifeTracker

final class DiagnosticRulesTests: XCTestCase {
    private let now: Date = nov16(12, 0, 0)

    /// Tout est en ordre : dernier événement il y a une heure, 3 lieux, 3 surveillés.
    private func goodInput() -> DiagInput {
        return DiagInput(location: .always,
                         preciseLocation: true,
                         notificationsAllowed: true,
                         backgroundRefreshAvailable: true,
                         lowPowerMode: false,
                         placeCount: 3,
                         isMonitoring: true,
                         monitoringError: nil,
                         monitoredCount: 3,
                         lastEventDate: now.addingTimeInterval(-3600),
                         now: now)
    }

    private func check(_ id: DiagCheckID, in input: DiagInput) -> DiagCheck {
        let all: [DiagCheck] = DiagnosticRules.checks(input)
        guard let found = all.first(where: { $0.id == id }) else {
            XCTFail("Point absent : \(id)")
            return all[0]
        }
        return found
    }

    func testAllGood() {
        let input: DiagInput = goodInput()
        let checks: [DiagCheck] = DiagnosticRules.checks(input)
        XCTAssertEqual(checks.count, 9)
        XCTAssertTrue(checks.allSatisfy { $0.status == .ok })
        XCTAssertTrue(checks.allSatisfy { $0.fix == .none })
        let summary: DiagSummary = DiagnosticRules.summary(input)
        XCTAssertTrue(summary.isAllGood)
        XCTAssertNil(summary.causeID)
        XCTAssertEqual(summary.title, "Tout est bon")
        XCTAssertEqual(summary.status, .ok)
    }

    func testChecksComeInFixedOrder() {
        let ids: [DiagCheckID] = DiagnosticRules.checks(goodInput()).map { $0.id }
        XCTAssertEqual(ids, [.location, .precise, .notifications, .backgroundRefresh, .lowPower,
                             .places, .monitoring, .monitoredCount, .lastEvent])
    }

    func testLocationDeniedIsTopCauseEvenWithOtherProblems() {
        var input: DiagInput = goodInput()
        input.location = .denied
        input.preciseLocation = nil
        input.notificationsAllowed = false
        input.backgroundRefreshAvailable = false
        input.lowPowerMode = true
        input.isMonitoring = false
        let summary: DiagSummary = DiagnosticRules.summary(input)
        XCTAssertFalse(summary.isAllGood)
        XCTAssertEqual(summary.causeID, .location)
        XCTAssertEqual(summary.status, .blocking)
        XCTAssertEqual(summary.title, "Cause la plus probable : la localisation")
        XCTAssertEqual(check(.location, in: input).fix, .openSettings)
    }

    func testWhenInUseAndRestrictedAndNotDeterminedAreBlocking() {
        for state in [DiagLocationState.whenInUse, .restricted, .notDetermined] {
            var input: DiagInput = goodInput()
            input.location = state
            XCTAssertEqual(check(.location, in: input).status, .blocking, "état \(state)")
        }
    }

    func testBlockingBeatsAnEarlierWarning() {
        var input: DiagInput = goodInput()
        input.preciseLocation = false      // à régler, position 2 de la liste
        input.isMonitoring = false         // bloquant, position 7
        let summary: DiagSummary = DiagnosticRules.summary(input)
        XCTAssertEqual(summary.causeID, .monitoring)
        XCTAssertEqual(summary.status, .blocking)
    }

    func testLowPowerModeIsWarningNotBlocking() {
        var input: DiagInput = goodInput()
        input.lowPowerMode = true
        let checks: [DiagCheck] = DiagnosticRules.checks(input)
        XCTAssertFalse(checks.contains(where: { $0.status == .blocking }))
        XCTAssertEqual(check(.lowPower, in: input).status, .warning)
        let summary: DiagSummary = DiagnosticRules.summary(input)
        XCTAssertFalse(summary.isAllGood)
        XCTAssertEqual(summary.causeID, .lowPower)
        XCTAssertEqual(summary.status, .warning)
    }

    func testTwentyPlacesIsFineTwentyOneWarns() {
        var input: DiagInput = goodInput()
        input.placeCount = 20
        input.monitoredCount = 20
        XCTAssertEqual(check(.monitoredCount, in: input).status, .ok)
        input.placeCount = 21
        let over: DiagCheck = check(.monitoredCount, in: input)
        XCTAssertEqual(over.status, .warning)
        XCTAssertTrue(over.detail.contains("21"))
        XCTAssertTrue(over.detail.contains("20"))
    }

    func testNoEventForThreeDaysWarns() {
        var input: DiagInput = goodInput()
        input.lastEventDate = now.addingTimeInterval(-(3 * 86_400))
        XCTAssertEqual(check(.lastEvent, in: input).status, .warning)
        XCTAssertEqual(DiagnosticRules.summary(input).causeID, .lastEvent)
        // 2 jours 23 h 59 : pas encore.
        input.lastEventDate = now.addingTimeInterval(-(3 * 86_400 - 60))
        XCTAssertEqual(check(.lastEvent, in: input).status, .ok)
    }

    func testNoEventAtAllIsNotAWarning() {
        var input: DiagInput = goodInput()
        input.lastEventDate = nil
        XCTAssertEqual(check(.lastEvent, in: input).status, .ok)
    }

    func testNoPlaceIsBlockingAndMonitoringIsNotDoubleCounted() {
        var input: DiagInput = goodInput()
        input.placeCount = 0
        input.monitoredCount = 0
        input.isMonitoring = false
        XCTAssertEqual(check(.places, in: input).status, .blocking)
        XCTAssertEqual(check(.monitoring, in: input).status, .ok)
        XCTAssertEqual(DiagnosticRules.summary(input).causeID, .places)
    }

    func testMonitoringErrorIsBlockingWithRestartFix() {
        var input: DiagInput = goodInput()
        input.monitoringError = "Trop de régions"
        let monitoring: DiagCheck = check(.monitoring, in: input)
        XCTAssertEqual(monitoring.status, .blocking)
        XCTAssertEqual(monitoring.fix, .restartMonitoring)
        XCTAssertTrue(monitoring.detail.contains("Trop de régions"))
    }

    func testPreciseUnknownWhenLocationNotAuthorized() {
        var input: DiagInput = goodInput()
        input.preciseLocation = nil
        XCTAssertEqual(check(.precise, in: input).status, .warning)
    }

    func testSentencesPerKind() {
        XCTAssertEqual(DiagnosticRules.sentence(forKind: "regionEntered", placeName: "Fac"), "Entrée dans la zone : Fac")
        XCTAssertEqual(DiagnosticRules.sentence(forKind: "regionExited", placeName: "Fac"), "Sortie de la zone : Fac")
        XCTAssertEqual(DiagnosticRules.sentence(forKind: "arrivalConfirmed", placeName: nil), "Arrivée confirmée")
        XCTAssertEqual(DiagnosticRules.sentence(forKind: "departureConfirmed", placeName: "  "), "Départ confirmé")
        XCTAssertEqual(DiagnosticRules.sentence(forKind: "monitoringFailed", placeName: nil), "La surveillance a échoué")
        XCTAssertEqual(DiagnosticRules.sentence(forKind: "nimportequoi", placeName: nil), "Événement inconnu")
    }

    func testEveryKnownKindHasASpecificSentence() {
        let kinds: [String] = ["regionEntered", "regionExited", "arrivalConfirmed", "departureConfirmed",
                               "sessionStarted", "sessionStopped", "ignoredShortVisit", "monitoringStarted",
                               "monitoringFailed", "authorizationChanged", "notificationSent", "userCorrected"]
        for kind in kinds {
            XCTAssertNotEqual(DiagnosticRules.sentence(forKind: kind, placeName: "Taf"), "Événement inconnu", kind)
        }
    }

    func testFamilies() {
        XCTAssertEqual(DiagnosticRules.family(forKind: "regionEntered"), .arrivalsAndDepartures)
        XCTAssertEqual(DiagnosticRules.family(forKind: "departureConfirmed"), .arrivalsAndDepartures)
        XCTAssertEqual(DiagnosticRules.family(forKind: "monitoringFailed"), .errors)
        XCTAssertEqual(DiagnosticRules.family(forKind: "authorizationChanged"), .errors)
        XCTAssertEqual(DiagnosticRules.family(forKind: "notificationSent"), .other)
        XCTAssertEqual(DiagnosticRules.family(forKind: "inconnu"), .other)
    }

    func testAccuracyText() {
        XCTAssertEqual(DiagnosticRules.accuracyText(35.4), "± 35 m")
        XCTAssertEqual(DiagnosticRules.accuracyText(35.6), "± 36 m")
        XCTAssertNil(DiagnosticRules.accuracyText(nil))
        XCTAssertNil(DiagnosticRules.accuracyText(-1))
    }
}
