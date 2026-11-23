import Foundation

/// Persistance des indices et de la proposition en attente (UserDefaults, JSON). Aucun modèle SwiftData.
struct RecoveryStore {
    static let heartbeatKey: String = "plt.recovery.heartbeat"
    static let pendingKey: String = "plt.recovery.pending"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    func loadHeartbeat() -> RecoveryHeartbeat? {
        guard let data = defaults.data(forKey: RecoveryStore.heartbeatKey) else { return nil }
        return try? JSONDecoder().decode(RecoveryHeartbeat.self, from: data)
    }

    func saveHeartbeat(_ heartbeat: RecoveryHeartbeat) {
        if let data = try? JSONEncoder().encode(heartbeat) {
            defaults.set(data, forKey: RecoveryStore.heartbeatKey)
        }
    }

    func loadPending() -> RecoveryPlan? {
        guard let data = defaults.data(forKey: RecoveryStore.pendingKey) else { return nil }
        return try? JSONDecoder().decode(RecoveryPlan.self, from: data)
    }

    func savePending(_ plan: RecoveryPlan?) {
        guard let plan = plan else {
            defaults.removeObject(forKey: RecoveryStore.pendingKey)
            return
        }
        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: RecoveryStore.pendingKey)
        }
    }
}
