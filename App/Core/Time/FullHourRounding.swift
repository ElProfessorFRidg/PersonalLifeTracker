import Foundation

/// Résultat de la normalisation en heure pleine (section 13.1 du prompt).
enum HourNormalization: Equatable {
    case rounded(minutes: Int)      // minutes depuis minuit, multiple de 60 (peut valoir 1440)
    case doubt(exactMinutes: Int)   // zone :15 à :45 : l'utilisateur choisit
}

enum FullHourRounding {
    /// :00 à :14 -> heure courante, :46 à :59 -> heure suivante, :15 à :45 -> doute.
    /// Précondition : 0 <= m < 1440.
    static func normalize(minutesFromMidnight m: Int) -> HourNormalization {
        precondition((0..<1440).contains(m), "minutes hors d'une journée")
        let hour = m / 60
        switch m % 60 {
        case 0...14: return .rounded(minutes: hour * 60)
        case 46...59: return .rounded(minutes: (hour + 1) * 60)
        default: return .doubt(exactMinutes: m)
        }
    }

    /// Durée normalisée entre deux instants de la même journée. nil si l'un des deux est en zone de doute.
    static func normalizedDuration(startMinutes: Int, endMinutes: Int) -> Int? {
        guard case .rounded(let s) = normalize(minutesFromMidnight: startMinutes),
              case .rounded(let e) = normalize(minutesFromMidnight: endMinutes) else { return nil }
        return e - s
    }
}
