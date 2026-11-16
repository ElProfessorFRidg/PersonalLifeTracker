import XCTest
@testable import PersonalLifeTracker

/// Les attendus sont écrits à la main depuis la section 132 et les seuils de notes/detection_help.md.
final class MissAnalysisTests: XCTestCase {
    private let cal: Calendar = TestCalendar.utc

    private let goodCaps: MissCapabilities = MissCapabilities(location: .always,
                                                              preciseLocation: true,
                                                              backgroundRefreshOn: true,
                                                              lowPowerMode: false)

    private func event(_ kind: String, _ date: Date, place: String? = "Taf", accuracy: Double? = nil) -> MissEvent {
        return MissEvent(kindRaw: kind, date: date, placeName: place, accuracy: accuracy)
    }

    /// Session détectée de 14:00 à 19:00, arrivée reçue à 14:01, départ jamais reçu.
    private func input(_ question: MissQuestion,
                       atTime: MissCapabilities?,
                       now: MissCapabilities? = nil,
                       events: [MissEvent]? = nil,
                       radius: Double? = 100,
                       start: Date? = nil,
                       end: Date? = nil,
                       source: String? = "gps") -> MissInput {
        let defaultEvents: [MissEvent] = [event("regionEntered", nov16(14, 1))]
        return MissInput(question: question,
                         windowStart: nov16(13, 0),
                         windowEnd: nov16(20, 30),
                         events: events ?? defaultEvents,
                         atTime: atTime,
                         now: now ?? goodCaps,
                         placeRadius: radius,
                         placeName: "Taf",
                         sessionStart: start ?? nov16(14, 0),
                         sessionEnd: end ?? nov16(19, 0),
                         sessionSourceRaw: source,
                         calendar: cal)
    }

    func testBackgroundRefreshOffIsTopCauseOfMissedDeparture() {
        var caps: MissCapabilities = goodCaps
        caps.backgroundRefreshOn = false
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: caps))
        XCTAssertEqual(result.verdict, .causes)
        XCTAssertEqual(result.topCause?.id, .backgroundRefreshOff)
        XCTAssertEqual(result.topCause?.confidence, .high)
        XCTAssertEqual(result.topCause?.fix?.title, "Autoriser l'actualisation en arrière-plan")
        XCTAssertTrue(result.usesHistoricalCapabilities)
    }

    func testWhenInUseLocationIsReportedWithPassToAlwaysFix() {
        var caps: MissCapabilities = goodCaps
        caps.location = .whenInUse
        let result: MissResult = MissAnalysis.analyze(input(.missedArrival, atTime: caps))
        XCTAssertEqual(result.topCause?.id, .locationWhenInUse)
        XCTAssertEqual(result.topCause?.fix?.kind, .openSettings)
        XCTAssertEqual(result.topCause?.fix?.title, "Passer sur Toujours")
    }

    func testWhenInUseBeatsBackgroundRefreshForMissedDeparture() {
        var caps: MissCapabilities = goodCaps
        caps.location = .whenInUse
        caps.backgroundRefreshOn = false
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: caps))
        XCTAssertEqual(result.causes.map { $0.id }, [.locationWhenInUse, .backgroundRefreshOff])
    }

    func testPoorAccuracyAgainstSmallRadiusProposesWidening() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 1), accuracy: 120)]
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: goodCaps, events: events, radius: 60))
        XCTAssertEqual(result.causes.map { $0.id }, [.poorAccuracy, .smallRadius])
        XCTAssertEqual(result.topCause?.fix?.kind, .widenRadius(40))
        XCTAssertEqual(result.topCause?.fix?.title, "Agrandir le rayon de 40 m")
        XCTAssertTrue(result.topCause?.explanation.contains("120 m") ?? false)
        XCTAssertTrue(result.topCause?.explanation.contains("60 m") ?? false)
    }

    func testWideningIsCappedByMaximumRadius() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 1), accuracy: 250)]
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: goodCaps, events: events, radius: 290))
        XCTAssertEqual(result.topCause?.id, .poorAccuracy)
        XCTAssertEqual(result.topCause?.fix?.kind, .widenRadius(10))
    }

    func testGoodAccuracyIsNotBlamed() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 1), accuracy: 20)]
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: goodCaps, events: events, radius: 100))
        XCTAssertEqual(result.verdict, .nothingFound)
        XCTAssertEqual(result.causes.map { $0.id }, [.weakSignal])
    }

    func testNoEventsAndNoHistoryGivesIDontKnow() {
        var nowCaps: MissCapabilities = goodCaps
        nowCaps.backgroundRefreshOn = false
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: nil, now: nowCaps, events: []))
        XCTAssertEqual(result.verdict, .unknown)
        XCTAssertTrue(result.causes.isEmpty)
        XCTAssertEqual(result.bannerTitle, "Je ne sais pas")
        XCTAssertFalse(result.usesHistoricalCapabilities)
        // Les points vérifiés restent visibles, avec le réglage d'aujourd'hui.
        let bg: MissCheck? = result.checks.first(where: { $0.id == .backgroundRefresh })
        XCTAssertEqual(bg?.status, .blocking)
    }

    func testEventsOutsideTheWindowAreIgnored() {
        let events: [MissEvent] = [event("regionEntered", nov16(8, 0)), event("regionExited", nov16(23, 0))]
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: nil, events: events))
        XCTAssertEqual(result.verdict, .unknown)
    }

    func testEventsOfAnotherPlaceAreIgnored() {
        let events: [MissEvent] = [event("monitoringFailed", nov16(15, 0), place: "Supérette")]
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: nil, events: events))
        XCTAssertEqual(result.verdict, .unknown)
    }

    func testManualSessionIsNeverBlamedOnDetection() {
        var caps: MissCapabilities = goodCaps
        caps.backgroundRefreshOn = false
        caps.location = .denied
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: caps, source: "manual"))
        XCTAssertEqual(result.verdict, .manualSession)
        XCTAssertTrue(result.causes.isEmpty)
        XCTAssertEqual(result.bannerTitle, "Cette session, c'est toi qui l'as saisie")
    }

    func testManualSessionWithoutAnyEventStaysManualAndNotUnknown() {
        let result: MissResult = MissAnalysis.analyze(input(.wrongHour, atTime: nil, events: [], source: "manual"))
        XCTAssertEqual(result.verdict, .manualSession)
    }

    func testRankingIsStableAndSortedByScore() {
        var caps: MissCapabilities = goodCaps
        caps.location = .whenInUse
        caps.backgroundRefreshOn = false
        caps.lowPowerMode = true
        let first: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: caps, radius: 60))
        let second: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: caps, radius: 60))
        XCTAssertEqual(first, second)
        // Scores attendus pour un départ manqué : 90, 85, 55, 50.
        XCTAssertEqual(first.causes.map { $0.id }, [.locationWhenInUse, .backgroundRefreshOff, .lowPowerMode, .smallRadius])
        XCTAssertEqual(first.causes.map { $0.score }, [90, 85, 55, 50])
    }

    func testTieIsBrokenByDeclarationOrder() {
        // Heure décalée : "Pendant l'utilisation" et "GPS imprécis" valent tous les deux 60.
        var caps: MissCapabilities = goodCaps
        caps.location = .whenInUse
        let events: [MissEvent] = [event("regionEntered", nov16(14, 1), accuracy: 150)]
        let result: MissResult = MissAnalysis.analyze(input(.wrongHour, atTime: caps, events: events, radius: 100))
        XCTAssertEqual(result.causes.map { $0.id }, [.locationWhenInUse, .poorAccuracy])
        XCTAssertEqual(result.causes.map { $0.score }, [60, 60])
    }

    func testTodaysSettingLowersConfidenceAndSaysSo() {
        var nowCaps: MissCapabilities = goodCaps
        nowCaps.backgroundRefreshOn = false
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: nil, now: nowCaps))
        XCTAssertEqual(result.verdict, .causes)
        XCTAssertEqual(result.topCause?.id, .backgroundRefreshOff)
        XCTAssertEqual(result.topCause?.confidence, .medium)
        XCTAssertFalse(result.usesHistoricalCapabilities)
        XCTAssertTrue(result.topCause?.explanation.contains("réglage d'aujourd'hui") ?? false)
    }

    func testMonitoringErrorInJournalIsHighConfidenceWithRestartFix() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 1)), event("monitoringFailed", nov16(16, 5), place: nil)]
        let result: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: nil, events: events))
        XCTAssertEqual(result.topCause?.id, .monitoringFailed)
        XCTAssertEqual(result.topCause?.confidence, .high)
        XCTAssertEqual(result.topCause?.fix?.kind, .restartMonitoring)
        XCTAssertTrue(result.topCause?.explanation.contains("16:05") ?? false)
    }

    func testLateEventExplainsWrongHour() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 12))]
        let result: MissResult = MissAnalysis.analyze(input(.wrongHour, atTime: goodCaps, events: events))
        XCTAssertEqual(result.topCause?.id, .delayedDelivery)
        XCTAssertTrue(result.topCause?.explanation.contains("12 min") ?? false)
    }

    func testFourMinutesLateIsNotCalledLate() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 4))]
        let result: MissResult = MissAnalysis.analyze(input(.wrongHour, atTime: goodCaps, events: events))
        XCTAssertEqual(result.verdict, .nothingFound)
    }

    func testShortSessionCreatedForNothingLooksLikeAPassBy() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 0)), event("regionExited", nov16(14, 5))]
        let result: MissResult = MissAnalysis.analyze(input(.createdForNothing, atTime: goodCaps, events: events,
                                                            start: nov16(14, 0), end: nov16(14, 5)))
        XCTAssertEqual(result.topCause?.id, .briefPass)
    }

    func testLongSessionIsNotCalledAPassBy() {
        let events: [MissEvent] = [event("regionEntered", nov16(14, 0)), event("regionExited", nov16(14, 10))]
        let result: MissResult = MissAnalysis.analyze(input(.createdForNothing, atTime: goodCaps, events: events,
                                                            start: nov16(14, 0), end: nov16(14, 10)))
        XCTAssertNil(result.causes.first(where: { $0.id == .briefPass }))
    }

    func testBackgroundRefreshIsNotBlamedForCreatedForNothing() {
        var caps: MissCapabilities = goodCaps
        caps.backgroundRefreshOn = false
        let result: MissResult = MissAnalysis.analyze(input(.createdForNothing, atTime: caps))
        XCTAssertNil(result.causes.first(where: { $0.id == .backgroundRefreshOff }))
    }

    func testBackgroundRefreshCheckIsBlockingForMissedDepartureButWarningForWrongHour() {
        var caps: MissCapabilities = goodCaps
        caps.backgroundRefreshOn = false
        let miss: MissResult = MissAnalysis.analyze(input(.missedDeparture, atTime: caps))
        let wrong: MissResult = MissAnalysis.analyze(input(.wrongHour, atTime: caps))
        XCTAssertEqual(miss.checks.first(where: { $0.id == .backgroundRefresh })?.status, .blocking)
        XCTAssertEqual(wrong.checks.first(where: { $0.id == .backgroundRefresh })?.status, .warning)
    }

    func testChecksAreAlwaysTheSevenPointsInFixedOrder() {
        let result: MissResult = MissAnalysis.analyze(input(.missedArrival, atTime: goodCaps))
        XCTAssertEqual(result.checks.map { $0.id },
                       [.location, .precise, .backgroundRefresh, .lowPower, .radius, .accuracy, .journal])
    }

    func testWindowAroundSession() {
        let w: (start: Date, end: Date) = MissAnalysis.window(sessionStart: nov16(14, 0), sessionEnd: nov16(19, 0), now: nov16(23, 0))
        XCTAssertEqual(w.start, nov16(13, 0))
        XCTAssertEqual(w.end, nov16(20, 30))
        let open: (start: Date, end: Date) = MissAnalysis.window(sessionStart: nov16(14, 0), sessionEnd: nil, now: nov16(16, 0))
        XCTAssertEqual(open.end, nov16(17, 30))
    }
}
