import Foundation

/// Règles pures des lieux (sections 10 et 11). Foundation seulement : testable sans interface.
enum PlaceRules {
    /// Rayon minimal en mètres (la spec ne fixe pas de bornes : choix de l'app).
    static let minRadius: Double = 50
    /// Rayon maximal en mètres.
    static let maxRadius: Double = 300
    /// Rayon par défaut (section 10).
    static let defaultRadius: Double = 100
    /// Rayon moyen de la Terre en mètres, utilisé pour la formule de haversine.
    static let earthRadius: Double = 6_371_000

    // MARK: Nom

    enum NameIssue: Equatable {
        case empty
        case duplicate

        var message: String {
            switch self {
            case .empty: return "Donne un nom à ce lieu."
            case .duplicate: return "Tu as déjà un lieu avec ce nom. Choisis-en un autre."
            }
        }
    }

    /// Nom nettoyé : espaces et retours à la ligne retirés aux extrémités, espaces multiples réduits.
    static func cleanedName(_ name: String) -> String {
        let parts: [String] = name
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    /// Clé de comparaison : sans casse ni accents.
    static func comparisonKey(_ name: String) -> String {
        return cleanedName(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Problème éventuel sur un nom. `existingNames` : les noms des autres lieux (sans celui qu'on modifie).
    static func nameIssue(_ name: String, existingNames: [String]) -> NameIssue? {
        let key: String = comparisonKey(name)
        if key.isEmpty { return .empty }
        for other in existingNames where comparisonKey(other) == key {
            return .duplicate
        }
        return nil
    }

    // MARK: Rayon

    /// Ramène un rayon dans les bornes. Une valeur non finie (NaN) donne le rayon par défaut.
    static func clampRadius(_ radius: Double) -> Double {
        if radius.isNaN { return defaultRadius }
        return min(max(radius, minRadius), maxRadius)
    }

    static func isRadiusValid(_ radius: Double) -> Bool {
        return !radius.isNaN && radius >= minRadius && radius <= maxRadius
    }

    // MARK: Coordonnées

    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        if latitude.isNaN || longitude.isNaN { return false }
        return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }

    /// Distance en mètres entre deux points (formule de haversine, Terre sphérique de 6 371 km de rayon).
    static func distanceMeters(latitude1: Double, longitude1: Double, latitude2: Double, longitude2: Double) -> Double {
        let toRad: Double = Double.pi / 180
        let phi1: Double = latitude1 * toRad
        let phi2: Double = latitude2 * toRad
        let dPhi: Double = (latitude2 - latitude1) * toRad
        let dLambda: Double = (longitude2 - longitude1) * toRad
        let sinHalfPhi: Double = sin(dPhi / 2)
        let sinHalfLambda: Double = sin(dLambda / 2)
        let a: Double = sinHalfPhi * sinHalfPhi + cos(phi1) * cos(phi2) * sinHalfLambda * sinHalfLambda
        let c: Double = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadius * c
    }

    /// Vrai si le point est dans le cercle (bord compris).
    static func isInside(latitude: Double, longitude: Double,
                         centerLatitude: Double, centerLongitude: Double, radius: Double) -> Bool {
        let d: Double = distanceMeters(latitude1: latitude, longitude1: longitude,
                                       latitude2: centerLatitude, longitude2: centerLongitude)
        return d <= radius
    }

    // MARK: Chevauchement

    struct Zone: Equatable {
        let name: String
        let latitude: Double
        let longitude: Double
        let radius: Double
    }

    /// Vrai si les deux zones se recouvrent (distance entre centres strictement plus petite que la somme des rayons).
    static func overlaps(_ a: Zone, _ b: Zone) -> Bool {
        let d: Double = distanceMeters(latitude1: a.latitude, longitude1: a.longitude,
                                       latitude2: b.latitude, longitude2: b.longitude)
        return d < a.radius + b.radius
    }

    /// Noms des lieux dont la zone chevauche la zone proposée.
    static func overlappingNames(_ candidate: Zone, among others: [Zone]) -> [String] {
        return others.filter { overlaps(candidate, $0) }.map { $0.name }
    }

    /// Phrase d'avertissement, nil s'il n'y a aucun chevauchement.
    static func overlapWarning(names: [String]) -> String? {
        if names.isEmpty { return nil }
        if names.count == 1 {
            return "Cette zone touche celle de \(names[0]). Je risque d'hésiter entre les deux. Réduis le rayon ou décale l'épingle."
        }
        return "Cette zone touche celles de \(names.joined(separator: ", ")). Je risque d'hésiter entre ces lieux. Réduis le rayon ou décale l'épingle."
    }
}

/// Une visite vue par les stats d'un lieu (copie des champs utiles d'une session).
struct PlaceVisitInput {
    let start: Date
    let end: Date?
    let chosenStart: Date?
    let chosenEnd: Date?
}

/// Stats du mois d'un lieu, calculées avec la logique existante de SessionDurations.
enum PlaceStats {
    struct Month: Equatable {
        let visits: Int
        let seconds: Int
        /// Vrai si une visite a un doute non résolu (durée provisoire, exacte).
        let hasProvisional: Bool
    }

    static func month(visits: [PlaceVisitInput], now: Date, base: CalculationBase, calendar: Calendar) -> Month {
        guard let interval = calendar.dateInterval(of: .month, for: now) else {
            return Month(visits: 0, seconds: 0, hasProvisional: false)
        }
        var count: Int = 0
        var seconds: Int = 0
        var provisional: Bool = false
        for v in visits where v.start >= interval.start && v.start < interval.end {
            count += 1
            let end: Date = v.end ?? now
            if end < v.start { continue }
            let r = SessionDurations.retained(base: base, start: v.start, end: end,
                                              chosenStart: v.chosenStart, chosenEnd: v.chosenEnd, calendar: calendar)
            seconds += r.seconds
            if r.isProvisional { provisional = true }
        }
        return Month(visits: count, seconds: seconds, hasProvisional: provisional)
    }
}

/// Textes de dates pour les lieux.
enum PlaceFormat {
    static func lastVisit(_ date: Date?, now: Date, calendar: Calendar) -> String {
        guard let date = date else { return "Pas encore de visite" }
        let clock: String = Formatting.clock(date, calendar: calendar)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Dernière visite : aujourd'hui, \(clock)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Dernière visite : hier, \(clock)"
        }
        return "Dernière visite : \(Formatting.dayTitle(date, calendar: calendar)), \(clock)"
    }
}

extension PlaceFormat {
    /// "Aujourd'hui", "Hier" ou "lundi 16 novembre" (première lettre en majuscule).
    static func dayLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Aujourd'hui" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Hier"
        }
        let text: String = Formatting.dayTitle(date, calendar: calendar)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
