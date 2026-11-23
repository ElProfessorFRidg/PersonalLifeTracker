import Foundation

/// Durées d'une session sur les trois bases de la section 13.1. Logique pure, sans SwiftUI ni SwiftData.
/// Les durées sont des écarts d'instants réels : une session à cheval sur minuit ou sur un changement
/// d'heure donne la durée réelle en secondes.
enum SessionDurations {

    /// Une borne (début ou fin) après application de la règle des heures pleines.
    enum Bound: Equatable {
        case rounded(Date)   // :00 à :14 et :46 à :59, heure pleine la plus proche
        case doubt           // :15 à :45, l'utilisateur choisit
    }

    /// Les deux heures pleines proposées dans la zone de doute.
    struct DoubtChoices: Equatable {
        let floor: Date   // heure pleine précédente
        let ceil: Date    // heure pleine suivante
    }

    // MARK: Base exacte

    /// Durée exacte en secondes (jamais négative).
    static func exactSeconds(start: Date, end: Date) -> Int {
        return max(0, Int(end.timeIntervalSince(start).rounded()))
    }

    // MARK: Base normalisée

    static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func minuteStart(_ date: Date, calendar: Calendar) -> Date {
        return calendar.dateInterval(of: .minute, for: date)?.start ?? date
    }

    /// Applique FullHourRounding à un instant. Le résultat arrondi est un instant réel (à la minute pile).
    static func normalizedBound(_ date: Date, calendar: Calendar) -> Bound {
        let m = minuteOfDay(date, calendar: calendar)
        switch FullHourRounding.normalize(minutesFromMidnight: m) {
        case .rounded(let target):
            let delta = Double((target - m) * 60)
            return .rounded(minuteStart(date, calendar: calendar).addingTimeInterval(delta))
        case .doubt:
            return .doubt
        }
    }

    /// Les deux heures pleines à proposer si l'instant est en zone de doute, sinon nil.
    static func doubtChoices(for date: Date, calendar: Calendar) -> DoubtChoices? {
        let m = minuteOfDay(date, calendar: calendar)
        guard case .doubt = FullHourRounding.normalize(minutesFromMidnight: m) else { return nil }
        let floorDate = minuteStart(date, calendar: calendar).addingTimeInterval(Double(-(m % 60) * 60))
        return DoubtChoices(floor: floorDate, ceil: floorDate.addingTimeInterval(3600))
    }

    /// Borne retenue : l'arrondi hors zone de doute, le choix de l'utilisateur dans la zone de doute (nil sans choix).
    /// Un choix enregistré pour une borne qui n'est pas en zone de doute est ignoré.
    static func resolvedBound(exact: Date, chosen: Date?, calendar: Calendar) -> Date? {
        switch normalizedBound(exact, calendar: calendar) {
        case .rounded(let d): return d
        case .doubt: return chosen
        }
    }

    /// Vrai si le début ou la fin est en zone de doute sans choix de l'utilisateur.
    static func hasUnresolvedDoubt(start: Date, end: Date?, chosenStart: Date?, chosenEnd: Date?, calendar: Calendar) -> Bool {
        if resolvedBound(exact: start, chosen: chosenStart, calendar: calendar) == nil { return true }
        if let e = end, resolvedBound(exact: e, chosen: chosenEnd, calendar: calendar) == nil { return true }
        return false
    }

    /// Durée normalisée en secondes, nil tant qu'une borne en zone de doute n'a pas de choix.
    static func normalizedSeconds(start: Date, end: Date, chosenStart: Date?, chosenEnd: Date?, calendar: Calendar) -> Int? {
        guard let s = resolvedBound(exact: start, chosen: chosenStart, calendar: calendar),
              let e = resolvedBound(exact: end, chosen: chosenEnd, calendar: calendar) else { return nil }
        return max(0, Int(e.timeIntervalSince(s).rounded()))
    }

    /// Durée normalisée en minutes entières (tronquée), nil si une borne reste à choisir.
    static func normalizedMinutes(start: Date, end: Date, chosenStart: Date?, chosenEnd: Date?, calendar: Calendar) -> Int? {
        guard let s = normalizedSeconds(start: start, end: end, chosenStart: chosenStart, chosenEnd: chosenEnd, calendar: calendar) else { return nil }
        return s / 60
    }

    // MARK: Base retenue

    /// Durée selon la base retenue. En heures pleines avec doute non résolu, retombe sur l'exact et `isProvisional` vaut vrai.
    static func retained(base: CalculationBase, start: Date, end: Date, chosenStart: Date?, chosenEnd: Date?, calendar: Calendar) -> (seconds: Int, isProvisional: Bool) {
        let exact = exactSeconds(start: start, end: end)
        switch base {
        case .exact:
            return (exact, false)
        case .fullHours:
            if let n = normalizedSeconds(start: start, end: end, chosenStart: chosenStart, chosenEnd: chosenEnd, calendar: calendar) {
                return (n, false)
            }
            return (exact, true)
        }
    }
}
