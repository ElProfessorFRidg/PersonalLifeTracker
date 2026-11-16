import Foundation

/// Textes du contrôle de l'horloge (français, tutoiement, sans tiret cadratin).
enum ClockText {
    /// "4 min", "1 h 05", "45 s".
    static func magnitude(seconds: TimeInterval) -> String {
        let total: Int = Int(abs(seconds).rounded())
        if total < 60 { return "\(total) s" }
        if total < 3600 { return "\(total / 60) min" }
        let minutes: Int = (total % 3600) / 60
        return "\(total / 3600) h " + (minutes < 10 ? "0\(minutes)" : "\(minutes)")
    }

    static func jumpTitle(_ jump: ClockJump) -> String {
        return "Ton horloge semble décalée de \(magnitude(seconds: jump.shiftSeconds))"
    }

    static func jumpMessage(_ jump: ClockJump, affected: Int) -> String {
        let way: String = jump.direction == .forward ? "avancé" : "reculé"
        var text: String = "Entre deux de mes repères, l'heure du téléphone a \(way) de \(magnitude(seconds: jump.shiftSeconds)) par rapport au temps écoulé. "
        text += "Je ne peux pas savoir quelle heure est la bonne. Active Réglages, Général, Date et heure, Réglage automatique pour la remettre d'équerre."
        if affected > 0 {
            text += affected == 1 ? " 1 session est marquée à vérifier." : " \(affected) sessions sont marquées à vérifier."
        }
        text += " Je ne modifie aucune heure sans ton accord."
        return text
    }

    static func zoneTitle(_ change: TimeZoneChange) -> String {
        switch change.kind {
        case .daylightSaving:
            return "Changement d'heure détecté"
        case .zone:
            return "Changement de fuseau horaire détecté"
        }
    }

    static func zoneMessage(_ change: TimeZoneChange) -> String {
        switch change.kind {
        case .daylightSaving:
            return "Le décalage avec UTC est passé de \(offset(change.fromOffsetSeconds)) à \(offset(change.toOffsetSeconds)). Tes heures exactes ne bougent pas, seule leur lecture change."
        case .zone:
            return "Ton téléphone est passé de \(change.fromID) à \(change.toID) (\(offset(change.fromOffsetSeconds)) puis \(offset(change.toOffsetSeconds))). Tes heures exactes ne bougent pas, chaque session garde son fuseau."
        }
    }

    /// "UTC+1", "UTC+5:30", "UTC-3".
    static func offset(_ seconds: Int) -> String {
        let sign: String = seconds < 0 ? "-" : "+"
        let absolute: Int = abs(seconds)
        let hours: Int = absolute / 3600
        let minutes: Int = (absolute % 3600) / 60
        if minutes == 0 { return "UTC\(sign)\(hours)" }
        return "UTC\(sign)\(hours):" + (minutes < 10 ? "0\(minutes)" : "\(minutes)")
    }
}
