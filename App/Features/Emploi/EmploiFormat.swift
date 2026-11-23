import Foundation

/// Mise en forme et saisie pour l'écran Emploi (vue seulement, pas de règle métier).
enum EmploiFormat {
    private static func frFormatter(_ pattern: String) -> DateFormatter {
        let f: DateFormatter = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = pattern
        return f
    }

    /// "1 sept. 2026"
    static func date(_ date: Date) -> String {
        return frFormatter("d MMM yyyy").string(from: date)
    }

    /// "9 déc."
    static func shortDate(_ date: Date) -> String {
        return frFormatter("d MMM").string(from: date)
    }

    /// "13" ou "13,5", sans unité (pour les champs de saisie).
    static func plain(_ value: Double) -> String {
        let f: NumberFormatter = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "13 h par semaine"
    static func weeklyHours(_ value: Double) -> String {
        return "\(plain(value)) h par semaine"
    }

    /// Lit "12,02" ou "12.02". nil si vide ou illisible.
    static func parseDecimal(_ text: String) -> Double? {
        let trimmed: String = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let normalized: String = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    static func days(_ n: Int) -> String {
        return n <= 1 ? "\(n) jour" : "\(n) jours"
    }
}
