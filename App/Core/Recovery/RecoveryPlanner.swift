import Foundation

// Section 131 (module battery_recovery), logique pure (Foundation seulement).
// Règle implémentée : "Au prochain lancement, si une session était en cours, qu'un redémarrage est détecté entre
// les derniers indices et le premier événement suivant, et que le dernier niveau de batterie était très bas,
// l'app propose : 'Ton tel s'est peut-être éteint vers 21:40 (batterie 4 %)...'. La fin est une estimation bornée
// entre le dernier indice et le premier événement après redémarrage, marquée incertaine et reconstituée,
// jamais inventée au-delà des traces."

/// Un indice daté (section 131) : heure, niveau de batterie, Mode économie d'énergie, dernière activité détectée.
struct RecoveryHeartbeat: Codable, Equatable {
    /// Heure murale de l'indice.
    var date: Date
    /// Horloge monotone en secondes (comptée pendant la veille), remise à zéro par un redémarrage.
    var uptime: TimeInterval
    /// Niveau de batterie de 0 à 1, nil si inconnu.
    var batteryLevel: Double?
    var lowPowerMode: Bool
    /// Dernière activité détectée (région, changement significatif...), nil si aucune.
    var lastActivity: Date?
}

/// La session en cours au moment de l'évaluation.
struct RecoveryRunningSession: Codable, Equatable {
    var id: UUID
    var start: Date
}

/// Choix proposés à l'utilisateur.
enum RecoveryChoice: String, Codable, Equatable {
    /// Fin de session au dernier indice (estimation, marquée incertaine).
    case endAtLastHint
    /// "J'étais encore là" : la session continue, rien n'est modifié.
    case stillThere
    /// L'utilisateur choisit lui-même une heure dans la plage bornée.
    case custom
}

/// Proposition de récupération. Rien n'est appliqué sans confirmation.
struct RecoveryPlan: Codable, Equatable {
    var sessionID: UUID
    var sessionStart: Date
    /// Dernier indice connu : début du trou.
    var gapStart: Date
    /// Premier événement après le redémarrage : fin du trou.
    var gapEnd: Date
    var batteryPercent: Int?
    /// Fin estimée proposée : le dernier indice, jamais avant le début de la session.
    var estimatedEnd: Date
    /// Plage dans laquelle une heure choisie à la main est acceptée.
    var customLower: Date
    var customUpper: Date
    var choices: [RecoveryChoice]
}

enum RecoveryNoPlanReason: Equatable {
    case noHeartbeat
    case noRunningSession
    case noRestartDetected
    case gapTooShort
    case batteryNotLow
}

enum RecoveryDecision: Equatable {
    case nothing(RecoveryNoPlanReason)
    case propose(RecoveryPlan)
}

enum RecoveryPlanner {
    /// "très bas" : la spec ne donne pas de chiffre, 10 % est un choix de l'implémentation (exemple de la spec : 4 %).
    static let defaultLowBatteryThreshold: Double = 0.10
    /// Trou minimal : la spec ne donne pas de durée, 5 minutes est un choix de l'implémentation (évite le bruit).
    static let defaultMinimumGap: TimeInterval = 300

    /// Évalue s'il faut proposer une récupération.
    /// - Parameters:
    ///   - last: dernier indice enregistré avant ce réveil.
    ///   - now: heure murale du premier événement après le redémarrage.
    ///   - nowUptime: horloge monotone à `now`. Plus petite que celle du dernier indice = redémarrage.
    ///   - running: session en cours, nil s'il n'y en a pas.
    static func evaluate(last: RecoveryHeartbeat?,
                         now: Date,
                         nowUptime: TimeInterval,
                         running: RecoveryRunningSession?,
                         lowBatteryThreshold: Double = RecoveryPlanner.defaultLowBatteryThreshold,
                         minimumGap: TimeInterval = RecoveryPlanner.defaultMinimumGap) -> RecoveryDecision {
        guard let hint = last else { return .nothing(.noHeartbeat) }
        guard let session = running else { return .nothing(.noRunningSession) }
        if !(nowUptime < hint.uptime) { return .nothing(.noRestartDetected) }
        let gap: TimeInterval = now.timeIntervalSince(hint.date)
        if gap < minimumGap { return .nothing(.gapTooShort) }
        guard let level = hint.batteryLevel, level <= lowBatteryThreshold else { return .nothing(.batteryNotLow) }

        // Bornes : jamais avant le début de la session, jamais après le réveil.
        let lower: Date = max(hint.date, session.start)
        let upper: Date = max(lower, now)
        let percent: Int = Int((level * 100).rounded())
        let plan = RecoveryPlan(sessionID: session.id,
                                sessionStart: session.start,
                                gapStart: hint.date,
                                gapEnd: now,
                                batteryPercent: percent,
                                estimatedEnd: lower,
                                customLower: lower,
                                customUpper: upper,
                                choices: [.endAtLastHint, .stillThere, .custom])
        return .propose(plan)
    }

    /// Heure de fin que donne un choix, nil si le choix ne change pas la session (ou si l'heure libre sort de la plage).
    static func endDate(for choice: RecoveryChoice, plan: RecoveryPlan, customDate: Date? = nil) -> Date? {
        switch choice {
        case .endAtLastHint:
            return plan.estimatedEnd
        case .stillThere:
            return nil
        case .custom:
            guard let date = customDate else { return nil }
            if date < plan.customLower || date > plan.customUpper { return nil }
            return date
        }
    }
}
