import Foundation
import SwiftData

/// Ce que la carte de l'Accueil affiche. Persisté en JSON dans UserDefaults.
struct ClockAlert: Codable, Equatable {
    var id: UUID
    var detectedAt: Date
    var jump: ClockJump?
    var timeZoneChange: TimeZoneChange?
    var affectedSessionCount: Int
    var isDismissed: Bool
}

struct ClockCheckStore {
    static let observationKey: String = "plt.clock.observation"
    static let alertKey: String = "plt.clock.alert"
    static let toleranceKey: String = "plt.clock.toleranceSeconds"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    func loadObservation() -> ClockObservation? {
        guard let data = defaults.data(forKey: ClockCheckStore.observationKey) else { return nil }
        return try? JSONDecoder().decode(ClockObservation.self, from: data)
    }

    func saveObservation(_ observation: ClockObservation) {
        if let data = try? JSONEncoder().encode(observation) {
            defaults.set(data, forKey: ClockCheckStore.observationKey)
        }
    }

    func loadAlert() -> ClockAlert? {
        guard let data = defaults.data(forKey: ClockCheckStore.alertKey) else { return nil }
        return try? JSONDecoder().decode(ClockAlert.self, from: data)
    }

    func saveAlert(_ alert: ClockAlert?) {
        guard let alert = alert else {
            defaults.removeObject(forKey: ClockCheckStore.alertKey)
            return
        }
        if let data = try? JSONEncoder().encode(alert) {
            defaults.set(data, forKey: ClockCheckStore.alertKey)
        }
    }

    /// Seuil réglable (section 140), défaut 30 secondes. Aucun écran de réglage ici : la valeur se lit seulement.
    var toleranceSeconds: TimeInterval {
        let value: Double = defaults.double(forKey: ClockCheckStore.toleranceKey)
        return value > 0 ? value : ClockChecker.defaultToleranceSeconds
    }

    func dismissAlert() {
        guard var alert = loadAlert() else { return }
        alert.isDismissed = true
        saveAlert(alert)
    }
}

/// Section 140 : prend un indice, le compare au précédent, garde l'alerte et marque les sessions concernées "à vérifier"
/// (`isConfirmed = false`). Les horodatages ne sont jamais réécrits.
///
/// Appel pour les autres services (à chaque événement de détection), depuis le thread principal :
///     ClockCheckService.observe(context: modelContext)
@MainActor
enum ClockCheckService {
    @discardableResult
    static func observe(context: ModelContext?,
                        now: Date = Date(),
                        uptime: TimeInterval = SystemMonotonicClock.uptime(),
                        timeZone: TimeZone = TimeZone.current,
                        defaults: UserDefaults = UserDefaults.standard) -> ClockCheckResult {
        let store: ClockCheckStore = ClockCheckStore(defaults: defaults)
        let current: ClockObservation = ClockChecker.observation(wall: now, uptime: uptime, timeZone: timeZone)
        let result: ClockCheckResult = ClockChecker.compare(previous: store.loadObservation(),
                                                            current: current,
                                                            toleranceSeconds: store.toleranceSeconds)
        store.saveObservation(current)
        if result.isClean { return result }

        var affected: Int = 0
        if let jump = result.jump, let context = context {
            let sessions: [WorkSession] = (try? context.fetch(FetchDescriptor<WorkSession>())) ?? []
            for session in sessions {
                if ClockChecker.isAffected(sessionStart: session.startDate, sessionEnd: session.endDate, jump: jump, now: now) {
                    affected += 1
                    session.isConfirmed = false
                }
            }
            if affected > 0 { try? context.save() }
        }
        store.saveAlert(ClockAlert(id: UUID(),
                                   detectedAt: now,
                                   jump: result.jump,
                                   timeZoneChange: result.timeZoneChange,
                                   affectedSessionCount: affected,
                                   isDismissed: false))
        return result
    }
}
