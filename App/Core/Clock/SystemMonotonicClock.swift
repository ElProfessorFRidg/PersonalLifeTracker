import Foundation

/// Horloge monotone du système (section 140 : "temps de fonctionnement depuis le démarrage").
/// CLOCK_MONOTONIC_RAW continue de compter pendant la veille et repart de zéro au redémarrage.
/// API d'heure de démarrage du système : à déclarer dans le manifeste de confidentialité (sections 6, 131, 140).
enum SystemMonotonicClock {
    static func uptime() -> TimeInterval {
        let nanoseconds: UInt64 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        if nanoseconds == 0 {
            return ProcessInfo.processInfo.systemUptime
        }
        return TimeInterval(nanoseconds) / 1_000_000_000
    }
}
