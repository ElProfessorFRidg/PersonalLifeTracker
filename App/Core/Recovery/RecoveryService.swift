import Foundation
import SwiftData
import UIKit

/// Section 131 : indices datés, sans timer ni polling. À appeler quand l'app est réveillée par un événement.
///
/// Appel pour les autres services (région, changement significatif, notification), depuis le thread principal :
///     RecoveryService.recordHeartbeat(lastActivity: Date())
/// Depuis un contexte non isolé : `Task { @MainActor in RecoveryService.recordHeartbeat(lastActivity: Date()) }`.
@MainActor
enum RecoveryService {
    /// Enregistre un indice (heure, monotone, batterie, Mode économie d'énergie, dernière activité).
    /// Garde la dernière activité connue si `lastActivity` est nil.
    static func recordHeartbeat(lastActivity: Date? = nil,
                                now: Date = Date(),
                                defaults: UserDefaults = UserDefaults.standard) {
        let store: RecoveryStore = RecoveryStore(defaults: defaults)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let rawLevel: Float = UIDevice.current.batteryLevel
        let level: Double? = rawLevel < 0 ? nil : Double(rawLevel)
        let previousActivity: Date? = store.loadHeartbeat()?.lastActivity
        let heartbeat = RecoveryHeartbeat(date: now,
                                          uptime: SystemMonotonicClock.uptime(),
                                          batteryLevel: level,
                                          lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                          lastActivity: lastActivity ?? previousActivity)
        store.saveHeartbeat(heartbeat)
    }

    /// À appeler à l'activation, AVANT `recordHeartbeat` : compare le réveil au dernier indice et garde la proposition.
    @discardableResult
    static func evaluateAtWake(context: ModelContext,
                               now: Date = Date(),
                               defaults: UserDefaults = UserDefaults.standard) -> RecoveryDecision {
        let store: RecoveryStore = RecoveryStore(defaults: defaults)
        var running: RecoveryRunningSession? = nil
        if let session = try? SessionService(context: context).runningSession() {
            running = RecoveryRunningSession(id: session.uid, start: session.startDate)
        }
        let decision: RecoveryDecision = RecoveryPlanner.evaluate(last: store.loadHeartbeat(),
                                                                  now: now,
                                                                  nowUptime: SystemMonotonicClock.uptime(),
                                                                  running: running)
        if case .propose(let plan) = decision {
            store.savePending(plan)
        }
        return decision
    }

    /// Passage en arrière-plan : un indice de plus.
    static func sceneWentToBackground(now: Date = Date()) {
        recordHeartbeat(lastActivity: nil, now: now)
    }
}

/// Applique un choix sur la session, avec annulation possible. Les heures ne sont jamais écrites sans confirmation.
@MainActor
enum RecoveryApplier {
    /// Retourne vrai si quelque chose a été fait (y compris "j'étais encore là").
    @discardableResult
    static func apply(choice: RecoveryChoice,
                      plan: RecoveryPlan,
                      customDate: Date? = nil,
                      context: ModelContext,
                      undo: UndoCenter?,
                      defaults: UserDefaults = UserDefaults.standard) -> Bool {
        let store: RecoveryStore = RecoveryStore(defaults: defaults)
        let all: [WorkSession] = (try? context.fetch(FetchDescriptor<WorkSession>())) ?? []
        guard let session = all.first(where: { (s: WorkSession) -> Bool in return s.uid == plan.sessionID }) else {
            store.savePending(nil)
            return false
        }
        if choice == .stillThere {
            store.savePending(nil)
            undo?.register(message: "Session gardée en cours") {
                store.savePending(plan)
            }
            return true
        }
        guard session.endDate == nil else {
            store.savePending(nil)
            return false
        }
        guard let end = RecoveryPlanner.endDate(for: choice, plan: plan, customDate: customDate) else { return false }

        let previousEnd: Date? = session.endDate
        let previousConfirmed: Bool = session.isConfirmed
        let previousNote: String = session.note
        session.endDate = max(end, session.startDate)
        session.isConfirmed = false
        if !session.note.contains(RecoveryText.noteMarker) {
            session.note = session.note.isEmpty ? RecoveryText.noteMarker : session.note + " " + RecoveryText.noteMarker
        }
        try? context.save()
        store.savePending(nil)
        undo?.register(message: "Fin de session reconstituée") {
            session.endDate = previousEnd
            session.isConfirmed = previousConfirmed
            session.note = previousNote
            try? context.save()
            store.savePending(plan)
        }
        return true
    }
}
