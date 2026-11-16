import Foundation

// Section 140 (module clock_check), logique pure (Foundation seulement).
// Règle implémentée : "dans une même session de démarrage, la différence d'heure murale entre deux indices doit
// correspondre à la différence monotone, sinon l'heure a été modifiée ou resynchronisée (seuil réglable, défaut
// 30 secondes). Changements de fuseau ou d'heure d'été détectés et notés. Sessions concernées marquées à vérifier.
// L'app détecte des incohérences, elle ne peut pas prouver l'heure vraie sans source externe."
// Non implémenté ici : la dérive par rapport à l'horodatage des positions (b), à vérifier sur appareil réel.

/// Un indice daté : heure murale ET horloge monotone (comptée pendant la veille, remise à zéro au redémarrage).
struct ClockObservation: Codable, Equatable {
    var wall: Date
    var uptime: TimeInterval
    var timeZoneID: String
    /// Décalage UTC en secondes à `wall` (change avec l'heure d'été).
    var utcOffsetSeconds: Int
}

enum ClockJumpDirection: String, Codable, Equatable {
    case forward
    case backward
}

/// Saut d'horloge : `shiftSeconds` positif = l'heure a avancé, négatif = elle a reculé.
struct ClockJump: Codable, Equatable {
    var shiftSeconds: TimeInterval
    var direction: ClockJumpDirection
    /// Fenêtre entre les deux indices (bornes triées) : les sessions qui la traversent sont à vérifier.
    var windowStart: Date
    var windowEnd: Date
}

enum TimeZoneChangeKind: String, Codable, Equatable {
    /// Même fuseau, décalage UTC différent : changement d'heure d'été ou d'hiver.
    case daylightSaving
    /// Fuseau différent (voyage, réglage).
    case zone
}

struct TimeZoneChange: Codable, Equatable {
    var kind: TimeZoneChangeKind
    var fromID: String
    var toID: String
    var fromOffsetSeconds: Int
    var toOffsetSeconds: Int
}

struct ClockCheckResult: Equatable {
    /// Redémarrage entre les deux indices : la comparaison monotone n'est pas possible, résultat "inconnu", pas un saut.
    var rebootDetected: Bool
    var jump: ClockJump?
    var timeZoneChange: TimeZoneChange?

    var isClean: Bool { return jump == nil && timeZoneChange == nil }
}

enum ClockChecker {
    /// Seuil par défaut de la spec : 30 secondes.
    static let defaultToleranceSeconds: TimeInterval = 30

    static func compare(previous: ClockObservation?,
                        current: ClockObservation,
                        toleranceSeconds: TimeInterval = ClockChecker.defaultToleranceSeconds) -> ClockCheckResult {
        guard let before = previous else {
            return ClockCheckResult(rebootDetected: false, jump: nil, timeZoneChange: nil)
        }
        let zone: TimeZoneChange? = timeZoneChange(previous: before, current: current)
        // Un redémarrage remet l'horloge monotone à zéro : on ne peut rien conclure, jamais un saut.
        if current.uptime < before.uptime {
            return ClockCheckResult(rebootDetected: true, jump: nil, timeZoneChange: zone)
        }
        let wallDelta: TimeInterval = current.wall.timeIntervalSince(before.wall)
        let monotonicDelta: TimeInterval = current.uptime - before.uptime
        let shift: TimeInterval = wallDelta - monotonicDelta
        var jump: ClockJump? = nil
        if abs(shift) > toleranceSeconds {
            let low: Date = min(before.wall, current.wall)
            let high: Date = max(before.wall, current.wall)
            jump = ClockJump(shiftSeconds: shift,
                             direction: shift > 0 ? .forward : .backward,
                             windowStart: low,
                             windowEnd: high)
        }
        return ClockCheckResult(rebootDetected: false, jump: jump, timeZoneChange: zone)
    }

    static func timeZoneChange(previous: ClockObservation, current: ClockObservation) -> TimeZoneChange? {
        let sameID: Bool = previous.timeZoneID == current.timeZoneID
        let sameOffset: Bool = previous.utcOffsetSeconds == current.utcOffsetSeconds
        if sameID && sameOffset { return nil }
        return TimeZoneChange(kind: sameID ? .daylightSaving : .zone,
                              fromID: previous.timeZoneID,
                              toID: current.timeZoneID,
                              fromOffsetSeconds: previous.utcOffsetSeconds,
                              toOffsetSeconds: current.utcOffsetSeconds)
    }

    /// Une session est concernée par un saut si elle chevauche la fenêtre entre les deux indices.
    /// Session en cours : fin = `now`. On ne modifie jamais ses horodatages, on la marque seulement "à vérifier".
    static func isAffected(sessionStart: Date, sessionEnd: Date?, jump: ClockJump, now: Date) -> Bool {
        let end: Date = sessionEnd ?? now
        return sessionStart <= jump.windowEnd && end >= jump.windowStart
    }

    /// Observation à partir de valeurs système, pour le fuseau donné.
    static func observation(wall: Date, uptime: TimeInterval, timeZone: TimeZone) -> ClockObservation {
        return ClockObservation(wall: wall,
                                uptime: uptime,
                                timeZoneID: timeZone.identifier,
                                utcOffsetSeconds: timeZone.secondsFromGMT(for: wall))
    }
}
