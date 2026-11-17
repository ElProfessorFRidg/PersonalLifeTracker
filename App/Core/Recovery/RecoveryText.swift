import Foundation

/// Textes de la carte de récupération (français, tutoiement, sans tiret cadratin).
enum RecoveryText {
    /// "Ton téléphone s'est éteint de 14:10 à 16:40 (batterie 4 %)." Le "peut-être" garde l'honnêteté : iOS ne prévient pas.
    static func title(plan: RecoveryPlan, calendar: Calendar) -> String {
        let from: String = Formatting.clock(plan.gapStart, calendar: calendar)
        let to: String = Formatting.clock(plan.gapEnd, calendar: calendar)
        return "Ton téléphone s'est peut-être éteint de \(from) à \(to)."
    }

    static func message(plan: RecoveryPlan, calendar: Calendar) -> String {
        let end: String = Formatting.clock(plan.estimatedEnd, calendar: calendar)
        var text: String = "Ta session était encore en cours."
        if let percent = plan.batteryPercent {
            text += " Dernière trace : batterie à \(percent) %."
        }
        text += " Fin estimée à \(end), tu confirmes ou tu corriges ? Je n'invente rien au-delà de mes traces."
        return text
    }

    static let noteMarker: String = "Fin reconstituée après une extinction du téléphone (estimation)."
}
