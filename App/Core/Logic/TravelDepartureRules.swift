import Foundation

/// Mode de transport du trajet (section 35).
enum TravelMode: String, CaseIterable, Identifiable {
    case walking
    case driving
    case transit

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .walking: return "À pied"
        case .driving: return "Voiture"
        case .transit: return "Transports"
        }
    }

    var symbolName: String {
        switch self {
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        case .transit: return "tram.fill"
        }
    }
}

/// D'où vient l'estimation du temps de trajet.
enum TravelEstimateSource: String, Equatable {
    /// MKDirections (Plans), avec le trafic quand l'API le permet.
    case mapKit
    /// Distance à vol d'oiseau, hors ligne ou si MKDirections échoue.
    case straightLine
    /// Durée par défaut du réglage, quand la position est inconnue (localisation refusée).
    case fallback

    var title: String {
        switch self {
        case .mapKit: return "estimation Plans"
        case .straightLine: return "estimation à vol d'oiseau"
        case .fallback: return "durée par défaut"
        }
    }
}

struct TravelEstimate: Equatable {
    let seconds: Int
    let source: TravelEstimateSource
}

/// Prise de poste ou de cours connue, avec son lieu (le trajet n'a de sens qu'avec un lieu).
struct TravelShift: Equatable, Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let placeUID: UUID
    let activity: ActivityType
}

/// Règles pures du module Trajet et "Pars maintenant" : Foundation seulement, testables sans MapKit.
enum TravelDepartureRules {

    // MARK: Constantes (origine entre parenthèses)

    /// Marge de sécurité par défaut, en minutes. Origine : spec 35 (défaut 10 minutes).
    static let defaultMarginMinutes: Int = 10
    static let maxMarginMinutes: Int = 60
    /// La carte apparaît X minutes avant l'heure de départ. Origine : mon choix (la spec 35 ne donne pas de fenêtre).
    static let defaultWindowMinutes: Int = 60
    static let maxWindowMinutes: Int = 180
    /// Seuls les créneaux qui commencent dans les X prochaines heures sont considérés. Origine : mon choix.
    static let horizonHours: Int = 12
    /// Durée de trajet par défaut sans position ni réseau. Origine : mon choix.
    static let defaultFallbackTravelMinutes: Int = 20
    static let maxFallbackTravelMinutes: Int = 180
    /// Pas de nouvelle requête MKDirections avant 10 minutes (spec 35 : requêtes limitées et mises en cache).
    static let minRefreshSeconds: TimeInterval = 600
    /// Vitesses moyennes de l'estimation à vol d'oiseau, en m/s. Origine : mon choix.
    /// 5 km/h à pied, 30 km/h en voiture (ville), 20 km/h en transports (attentes comprises).
    static let walkingSpeed: Double = 5.0 / 3.6
    static let drivingSpeed: Double = 30.0 / 3.6
    static let transitSpeed: Double = 20.0 / 3.6
    /// Un trajet réel est plus long que la ligne droite. Origine : mon choix.
    static let detourFactor: Double = 1.3
    /// Rayon moyen de la Terre en mètres (haversine).
    static let earthRadiusMeters: Double = 6_371_000
    /// Pas de notification planifiée si le départ est dans moins de 60 s.
    static let minNotificationLeadSeconds: TimeInterval = 60

    // MARK: Distance et estimation

    /// Distance à vol d'oiseau en mètres (formule de haversine).
    static func straightLineMeters(fromLatitude lat1: Double, fromLongitude lon1: Double,
                                   toLatitude lat2: Double, toLongitude lon2: Double) -> Double {
        let toRad: Double = Double.pi / 180
        let dLat: Double = (lat2 - lat1) * toRad
        let dLon: Double = (lon2 - lon1) * toRad
        let a: Double = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLon / 2) * sin(dLon / 2)
        let c: Double = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
        return earthRadiusMeters * c
    }

    static func speed(for mode: TravelMode) -> Double {
        switch mode {
        case .walking: return walkingSpeed
        case .driving: return drivingSpeed
        case .transit: return transitSpeed
        }
    }

    /// Durée estimée en secondes : distance x détour / vitesse, arrondie à la seconde.
    static func straightLineSeconds(meters: Double, mode: TravelMode) -> Int {
        if meters <= 0 { return 0 }
        return Int((meters * detourFactor / speed(for: mode)).rounded())
    }

    /// Choisit la meilleure estimation disponible : MapKit, sinon vol d'oiseau, sinon durée par défaut.
    static func resolve(mapKitSeconds: Int?, distanceMeters: Double?, mode: TravelMode, fallbackMinutes: Int) -> TravelEstimate {
        if let seconds = mapKitSeconds, seconds > 0 {
            return TravelEstimate(seconds: seconds, source: .mapKit)
        }
        if let meters = distanceMeters {
            return TravelEstimate(seconds: straightLineSeconds(meters: meters, mode: mode), source: .straightLine)
        }
        return TravelEstimate(seconds: max(0, fallbackMinutes) * 60, source: .fallback)
    }

    // MARK: Départ

    /// Heure de départ : début du créneau moins le trajet moins la marge.
    static func departure(shiftStart: Date, travelSeconds: Int, marginMinutes: Int) -> Date {
        return shiftStart.addingTimeInterval(-Double(max(0, travelSeconds)) - Double(max(0, marginMinutes)) * 60)
    }

    /// Prochain créneau avec lieu : le premier qui commence après `now`, dans l'horizon. Nil sinon.
    /// Seuls le travail et les cours comptent.
    static func nextShift(shifts: [TravelShift], now: Date) -> TravelShift? {
        let limit: Date = now.addingTimeInterval(Double(horizonHours) * 3600)
        let candidates: [TravelShift] = shifts.filter { (s: TravelShift) -> Bool in
            let counted: Bool = s.activity == .work || s.activity == .education
            return counted && s.start > now && s.start <= limit
        }
        let sorted: [TravelShift] = candidates.sorted { (a: TravelShift, b: TravelShift) -> Bool in
            if a.start != b.start { return a.start < b.start }
            return a.id.uuidString < b.id.uuidString
        }
        return sorted.first
    }

    /// Vrai si la carte doit s'afficher : le créneau n'a pas commencé et on est à moins de `windowMinutes` du départ
    /// (ou déjà après l'heure de départ).
    static func isInWindow(now: Date, shiftStart: Date, departure: Date, windowMinutes: Int) -> Bool {
        if now >= shiftStart { return false }
        return now >= departure.addingTimeInterval(-Double(max(0, windowMinutes)) * 60)
    }

    /// Vrai si l'utilisateur est déjà sur place (distance inférieure ou égale au rayon du lieu).
    static func isOnSite(distanceMeters: Double?, radius: Double) -> Bool {
        guard let d = distanceMeters else { return false }
        return d <= radius
    }

    /// Minutes de retard probables si l'utilisateur part à `now` (0 si à l'heure), arrondies à la minute supérieure.
    static func lateMinutes(now: Date, travelSeconds: Int, shiftStart: Date) -> Int {
        let arrival: Date = now.addingTimeInterval(Double(max(0, travelSeconds)))
        let late: Double = arrival.timeIntervalSince(shiftStart)
        if late <= 0 { return 0 }
        return Int((late / 60).rounded(.up))
    }

    /// Heure d'arrivée probable si l'utilisateur part à `now`.
    static func arrival(now: Date, travelSeconds: Int) -> Date {
        return now.addingTimeInterval(Double(max(0, travelSeconds)))
    }

    /// Nouvelle requête MKDirections autorisée seulement si la dernière date de plus de `minRefreshSeconds`.
    static func shouldRefresh(lastFetch: Date?, now: Date) -> Bool {
        guard let last = lastFetch else { return true }
        return now.timeIntervalSince(last) >= minRefreshSeconds
    }

    /// Date de la notification : l'heure de départ, si elle est assez loin dans le futur. Nil sinon.
    static func notificationDate(departure: Date, now: Date) -> Date? {
        if departure.timeIntervalSince(now) < minNotificationLeadSeconds { return nil }
        return departure
    }

    // MARK: Textes

    static func minutesCeil(_ seconds: Int) -> Int {
        return (max(0, seconds) + 59) / 60
    }

    /// "Pars à 17:28".
    static func headline(departure: Date, calendar: Calendar) -> String {
        return "Pars à \(Formatting.clock(departure, calendar: calendar))"
    }

    /// Corps de la notification (exemple de la spec 35).
    static func notificationBody(departure: Date, travelSeconds: Int, shiftStart: Date, activity: ActivityType, calendar: Calendar) -> String {
        let noun: String = activity == .education ? "ton cours" : "ton poste"
        return "Faut y aller, il est \(Formatting.clock(departure, calendar: calendar)). "
            + "T'as \(minutesCeil(travelSeconds)) min de route et tu prends \(noun) à \(Formatting.clock(shiftStart, calendar: calendar))."
    }

    /// Phrase de retard probable, sans promettre une précision que l'API ne garantit pas.
    static func lateText(arrival: Date, calendar: Calendar) -> String {
        return "Tu vas arriver vers \(Formatting.clock(arrival, calendar: calendar)), prévient ton chef ?"
    }
}
