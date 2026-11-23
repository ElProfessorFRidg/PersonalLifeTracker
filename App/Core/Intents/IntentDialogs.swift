import Foundation

/// Textes parlés ou affichés par les raccourcis Siri et Raccourcis. Foundation seulement, testé.
/// Tutoiement, pas de tiret cadratin, pas d'emoji.
enum IntentDialogs {
    static let storeUnavailable: String = "Je n'arrive pas à ouvrir tes données. Ouvre l'app puis réessaie."
    static let failure: String = "Ça n'a pas marché. Ouvre l'app puis réessaie."
    static let nothingRunning: String = "Aucune session en cours, rien à arrêter."

    /// "C'est parti, Taf démarré à Supérette du Canal." ou "C'est parti, Taf démarré."
    static func started(activity: ActivityType, placeName: String?) -> String {
        if let name = placeName, !name.isEmpty {
            return "C'est parti, \(activity.title) démarré à \(name)."
        }
        return "C'est parti, \(activity.title) démarré."
    }

    /// "Une session tourne déjà : Taf depuis 17:56. Arrête-la d'abord."
    static func alreadyRunning(activity: ActivityType, since: Date, calendar: Calendar) -> String {
        return "Une session tourne déjà : \(activity.title) depuis \(Formatting.clock(since, calendar: calendar)). Arrête-la d'abord."
    }

    /// "Session arrêtée : Taf, 3 h 04."
    static func stopped(activity: ActivityType, seconds: Int) -> String {
        return "Session arrêtée : \(activity.title), \(Formatting.duration(seconds: seconds))."
    }

    /// "Aujourd'hui : Taf 3 h 04, Cours 3 h 57." ou "Rien de noté aujourd'hui." Ajoute une phrase si une session tourne.
    static func today(workSeconds: Int, studySeconds: Int, isRunning: Bool) -> String {
        var parts: [String] = []
        if workSeconds > 0 { parts.append("Taf \(Formatting.duration(seconds: workSeconds))") }
        if studySeconds > 0 { parts.append("Cours \(Formatting.duration(seconds: studySeconds))") }
        var text: String
        if parts.isEmpty {
            text = isRunning ? "Pas encore d'heure comptée aujourd'hui." : "Rien de noté aujourd'hui."
        } else {
            text = "Aujourd'hui : " + parts.joined(separator: ", ") + "."
        }
        if isRunning { text += " Une session tourne encore." }
        return text
    }
}
