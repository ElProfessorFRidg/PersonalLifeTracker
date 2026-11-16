import Foundation
import SwiftData

/// Point d'entrée unique pour RootView : les vérifications des modules battery_recovery et clock_check.
@MainActor
enum LifecycleChecks {
    /// L'app devient active. Ordre important : on compare au dernier indice AVANT d'en écrire un nouveau.
    static func sceneBecameActive(context: ModelContext, batteryRecoveryOn: Bool, clockCheckOn: Bool, now: Date = Date()) {
        if batteryRecoveryOn {
            RecoveryService.evaluateAtWake(context: context, now: now)
            RecoveryService.recordHeartbeat(lastActivity: nil, now: now)
        }
        if clockCheckOn {
            ClockCheckService.observe(context: context, now: now)
        }
    }

    /// L'app part en arrière-plan : un indice de plus.
    static func sceneWentToBackground(context: ModelContext, batteryRecoveryOn: Bool, clockCheckOn: Bool, now: Date = Date()) {
        if batteryRecoveryOn {
            RecoveryService.sceneWentToBackground(now: now)
        }
        if clockCheckOn {
            ClockCheckService.observe(context: context, now: now)
        }
    }
}
