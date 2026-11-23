import Foundation

/// Mise en forme de l'écran Congés (vue seulement, aucune règle métier).
enum CongesFormat {
    private static func frFormatter(_ pattern: String) -> DateFormatter {
        let f: DateFormatter = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = pattern
        return f
    }

    /// "12,5" ou "12", sans unité.
    static func number(_ value: Double) -> String {
        let f: NumberFormatter = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "12,5 jours", "1 jour", "0 jour".
    static func days(_ value: Double) -> String {
        let unit: String = abs(value) < 2 ? "jour" : "jours"
        return "\(number(value)) \(unit)"
    }

    /// "9 nov. 2026"
    static func date(_ date: Date) -> String {
        return frFormatter("d MMM yyyy").string(from: date)
    }

    /// "31 mai 2027"
    static func longDate(_ date: Date) -> String {
        return frFormatter("d MMMM yyyy").string(from: date)
    }

    /// "du 9 nov. 2026 au 11 nov. 2026", ou "le 9 nov. 2026" pour un seul jour.
    static func range(start: Date, end: Date, calendar: Calendar) -> String {
        if calendar.isDate(start, inSameDayAs: end) {
            return "le \(date(start))"
        }
        return "du \(date(start)) au \(date(end))"
    }

    static let monthNames: [String] = [
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre"
    ]

    static func monthName(_ month: Int) -> String {
        if month >= 1 && month <= 12 { return monthNames[month - 1] }
        return ""
    }

    /// Lit "2,5" ou "2.5". nil si vide ou illisible.
    static func parseDecimal(_ text: String) -> Double? {
        let trimmed: String = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}
