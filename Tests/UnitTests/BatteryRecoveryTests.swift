import XCTest
import SwiftData
@testable import PersonalLifeTracker

/// Section 131 : RecoveryPlanner (pur), stockage et application d'un choix. Valeurs écrites à la main.
@MainActor
final class BatteryRecoveryTests: XCTestCase {
    private let sessionID: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func running(start: Date = nov16(9, 0)) -> RecoveryRunningSession {
        return RecoveryRunningSession(id: sessionID, start: start)
    }

    private func hint(at date: Date, uptime: TimeInterval = 50_000, battery: Double? = 0.04) -> RecoveryHeartbeat {
        return RecoveryHeartbeat(date: date, uptime: uptime, batteryLevel: battery, lowPowerMode: false, lastActivity: nil)
    }

    // MARK: Pas de proposition

    func testNoHeartbeatMeansNothing() {
        let d = RecoveryPlanner.evaluate(last: nil, now: nov16(16, 40), nowUptime: 120, running: running())
        XCTAssertEqual(d, .nothing(.noHeartbeat))
    }

    func testNoRunningSessionMeansNothingEvenWithRebootAndLowBattery() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10)), now: nov16(16, 40), nowUptime: 120, running: nil)
        XCTAssertEqual(d, .nothing(.noRunningSession))
    }

    func testNoRebootMeansNothing() {
        // Le monotone a continué de monter (60 000 > 50 000) : l'app a seulement été tuée ou suspendue.
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10)), now: nov16(16, 40), nowUptime: 60_000, running: running())
        XCTAssertEqual(d, .nothing(.noRestartDetected))
    }

    func testEqualUptimeIsNotAReboot() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10)), now: nov16(16, 40), nowUptime: 50_000, running: running())
        XCTAssertEqual(d, .nothing(.noRestartDetected))
    }

    // MARK: Seuil du trou (5 minutes)

    func testGapOneSecondBelowThresholdIsIgnored() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10, 0)), now: nov16(14, 14, 59), nowUptime: 30, running: running())
        XCTAssertEqual(d, .nothing(.gapTooShort))
    }

    func testGapExactlyAtThresholdIsProposed() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10, 0)), now: nov16(14, 15, 0), nowUptime: 30, running: running())
        guard case .propose = d else {
            XCTFail("un trou de 5 min exactement doit être proposé, reçu \(d)")
            return
        }
    }

    // MARK: Seuil de batterie (10 %)

    func testBatteryAtTenPercentIsProposedAndAboveIsNot() {
        let at10 = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10), battery: 0.10), now: nov16(16, 40), nowUptime: 120, running: running())
        guard case .propose(let plan) = at10 else {
            XCTFail("10 % doit être considéré comme très bas")
            return
        }
        XCTAssertEqual(plan.batteryPercent, 10)
        let at11 = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10), battery: 0.11), now: nov16(16, 40), nowUptime: 120, running: running())
        XCTAssertEqual(at11, .nothing(.batteryNotLow))
    }

    func testUnknownBatteryIsNotProposed() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10), battery: nil), now: nov16(16, 40), nowUptime: 120, running: running())
        XCTAssertEqual(d, .nothing(.batteryNotLow))
    }

    // MARK: Contenu de la proposition

    func testProposalForSessionRunningAcrossTheGap() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10), battery: 0.04), now: nov16(16, 40), nowUptime: 120, running: running(start: nov16(9, 0)))
        guard case .propose(let plan) = d else {
            XCTFail("une proposition était attendue")
            return
        }
        XCTAssertEqual(plan.sessionID, sessionID)
        XCTAssertEqual(plan.gapStart, nov16(14, 10))
        XCTAssertEqual(plan.gapEnd, nov16(16, 40))
        XCTAssertEqual(plan.batteryPercent, 4)
        XCTAssertEqual(plan.estimatedEnd, nov16(14, 10), "la fin estimée est le dernier indice, pas plus tard")
        XCTAssertEqual(plan.customLower, nov16(14, 10))
        XCTAssertEqual(plan.customUpper, nov16(16, 40))
        XCTAssertEqual(plan.choices, [.endAtLastHint, .stillThere, .custom])
    }

    func testEstimatedEndNeverBeforeSessionStart() {
        // Indice à 14:10 mais session démarrée à 15:00 (démarrage manuel sans indice depuis) : on ne remonte pas avant le début.
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10)), now: nov16(16, 40), nowUptime: 120, running: running(start: nov16(15, 0)))
        guard case .propose(let plan) = d else {
            XCTFail("une proposition était attendue")
            return
        }
        XCTAssertEqual(plan.estimatedEnd, nov16(15, 0))
        XCTAssertEqual(plan.customLower, nov16(15, 0))
    }

    // MARK: Heures proposées

    func testEndDateForEachChoice() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10)), now: nov16(16, 40), nowUptime: 120, running: running())
        guard case .propose(let plan) = d else {
            XCTFail("une proposition était attendue")
            return
        }
        XCTAssertEqual(RecoveryPlanner.endDate(for: .endAtLastHint, plan: plan), nov16(14, 10))
        XCTAssertNil(RecoveryPlanner.endDate(for: .stillThere, plan: plan), "j'étais encore là ne fixe aucune heure")
        XCTAssertNil(RecoveryPlanner.endDate(for: .custom, plan: plan), "sans heure choisie, rien n'est inventé")
        XCTAssertEqual(RecoveryPlanner.endDate(for: .custom, plan: plan, customDate: nov16(15, 30)), nov16(15, 30))
        XCTAssertEqual(RecoveryPlanner.endDate(for: .custom, plan: plan, customDate: nov16(14, 10)), nov16(14, 10))
        XCTAssertEqual(RecoveryPlanner.endDate(for: .custom, plan: plan, customDate: nov16(16, 40)), nov16(16, 40))
        XCTAssertNil(RecoveryPlanner.endDate(for: .custom, plan: plan, customDate: nov16(14, 9, 59)), "avant la dernière trace")
        XCTAssertNil(RecoveryPlanner.endDate(for: .custom, plan: plan, customDate: nov16(16, 40, 1)), "après le réveil")
    }

    func testTitleText() {
        let d = RecoveryPlanner.evaluate(last: hint(at: nov16(14, 10)), now: nov16(16, 40), nowUptime: 120, running: running())
        guard case .propose(let plan) = d else {
            XCTFail("une proposition était attendue")
            return
        }
        XCTAssertEqual(RecoveryText.title(plan: plan, calendar: TestCalendar.utc), "Ton téléphone s'est peut-être éteint de 14:10 à 16:40.")
    }

    // MARK: Stockage

    func testStoreRoundTrip() {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let store = RecoveryStore(defaults: iso.defaults)
        XCTAssertNil(store.loadHeartbeat())
        XCTAssertNil(store.loadPending())
        let h = hint(at: nov16(14, 10), uptime: 1234.5, battery: 0.04)
        store.saveHeartbeat(h)
        XCTAssertEqual(store.loadHeartbeat(), h)
        guard case .propose(let plan) = RecoveryPlanner.evaluate(last: h, now: nov16(16, 40), nowUptime: 1, running: running()) else {
            XCTFail("une proposition était attendue")
            return
        }
        store.savePending(plan)
        XCTAssertEqual(store.loadPending(), plan)
        store.savePending(nil)
        XCTAssertNil(store.loadPending())
    }

    // MARK: Application d'un choix

    private func makePlan(for session: WorkSession) -> RecoveryPlan {
        let h = hint(at: nov16(14, 10))
        let r = RecoveryRunningSession(id: session.uid, start: session.startDate)
        guard case .propose(let plan) = RecoveryPlanner.evaluate(last: h, now: nov16(16, 40), nowUptime: 1, running: r) else {
            XCTFail("une proposition était attendue")
            return RecoveryPlan(sessionID: session.uid, sessionStart: session.startDate, gapStart: nov16(14, 10), gapEnd: nov16(16, 40),
                                batteryPercent: 4, estimatedEnd: nov16(14, 10), customLower: nov16(14, 10), customUpper: nov16(16, 40), choices: [])
        }
        return plan
    }

    func testApplyEndAtLastHintMarksSessionToConfirmAndCanBeUndone() throws {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let session = WorkSession(activity: .work, start: nov16(9, 0), end: nil, source: .manual, isConfirmed: true, note: "")
        context.insert(session)
        try context.save()
        let plan = makePlan(for: session)
        let store = RecoveryStore(defaults: iso.defaults)
        store.savePending(plan)
        let undo = UndoCenter(toastDuration: 60)

        let done = RecoveryApplier.apply(choice: .endAtLastHint, plan: plan, context: context, undo: undo, defaults: iso.defaults)

        XCTAssertTrue(done)
        XCTAssertEqual(session.endDate, nov16(14, 10))
        XCTAssertFalse(session.isConfirmed, "l'heure reconstituée est à confirmer")
        XCTAssertEqual(session.note, RecoveryText.noteMarker)
        XCTAssertEqual(session.startDate, nov16(9, 0), "le début n'est jamais touché")
        XCTAssertNil(store.loadPending())

        undo.performUndo()

        XCTAssertNil(session.endDate)
        XCTAssertTrue(session.isConfirmed)
        XCTAssertEqual(session.note, "")
        XCTAssertEqual(store.loadPending(), plan)
        _ = container
    }

    func testApplyStillThereChangesNothing() throws {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let session = WorkSession(activity: .work, start: nov16(9, 0), end: nil, source: .manual, isConfirmed: true, note: "")
        context.insert(session)
        let plan = makePlan(for: session)
        let store = RecoveryStore(defaults: iso.defaults)
        store.savePending(plan)

        let done = RecoveryApplier.apply(choice: .stillThere, plan: plan, context: context, undo: nil, defaults: iso.defaults)

        XCTAssertTrue(done)
        XCTAssertNil(session.endDate)
        XCTAssertTrue(session.isConfirmed)
        XCTAssertNil(store.loadPending())
        _ = container
    }

    func testApplyCustomOutsideRangeIsRefused() throws {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let session = WorkSession(activity: .work, start: nov16(9, 0), end: nil, source: .manual, isConfirmed: true, note: "")
        context.insert(session)
        let plan = makePlan(for: session)

        let done = RecoveryApplier.apply(choice: .custom, plan: plan, customDate: nov16(17, 0), context: context, undo: nil, defaults: iso.defaults)

        XCTAssertFalse(done)
        XCTAssertNil(session.endDate)
        _ = container
    }
}
