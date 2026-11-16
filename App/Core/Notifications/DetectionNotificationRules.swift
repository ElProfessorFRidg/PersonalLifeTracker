import Foundation

enum DetectionNotificationKind: String, Equatable {
    case arrival
    case departure
}

/// Texte d'une notification.
struct DetectionNotificationText: Equatable {
    let title: String
    let body: String
}

/// Règles pures des notifications de détection (section 45). Foundation seulement.
enum DetectionNotificationRules {

    // MARK: Limites (choix de l'app : la spec demande une fréquence maximale par jour et des heures silencieuses sans chiffres)

    /// Nombre maximal de notifications de détection par jour : 6.
    static let maxPerDay: Int = 6
    /// Début des heures silencieuses : 22:00.
    static let quietStartHour: Int = 22
    /// Fin des heures silencieuses : 05:00 (pas de notification de 22:00 à 04:59).
    static let quietEndHour: Int = 5

    enum Verdict: Equatable {
        case send
        case dailyLimitReached
        case quietHours
    }

    static func isQuietHour(_ date: Date, calendar: Calendar) -> Bool {
        let hour: Int = calendar.component(.hour, from: date)
        return hour >= quietStartHour || hour < quietEndHour
    }

    /// Décide si on peut envoyer maintenant. `sentDates` : les dates des notifications déjà envoyées.
    static func verdict(now: Date, sentDates: [Date], calendar: Calendar) -> Verdict {
        if isQuietHour(now, calendar: calendar) { return .quietHours }
        var today: Int = 0
        for d in sentDates where calendar.isDate(d, inSameDayAs: now) {
            today += 1
        }
        if today >= maxPerDay { return .dailyLimitReached }
        return .send
    }

    // MARK: Zone de doute

    /// Vrai si la borne tombe en zone de doute (:15 à :45), selon la règle de la section 13.
    static func isInDoubtZone(_ date: Date, calendar: Calendar) -> Bool {
        let c: DateComponents = calendar.dateComponents([.hour, .minute], from: date)
        let minutes: Int = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        switch FullHourRounding.normalize(minutesFromMidnight: minutes) {
        case .doubt: return true
        case .rounded: return false
        }
    }

    // MARK: Textes (tutoiement)

    /// "au taf", "en cours", "à Carrefour" (le nom est ajouté entre parenthèses pour taf et cours s'il apporte quelque chose).
    static func placePhraseAt(name: String, type: PlaceType) -> String {
        switch type {
        case .taf: return withName("au taf", name: name, generic: "taf")
        case .cours: return withName("en cours", name: name, generic: "cours")
        case .courses: return "à \(name)"
        }
    }

    /// "du taf", "du cours", "de Carrefour".
    static func placePhraseFrom(name: String, type: PlaceType) -> String {
        switch type {
        case .taf: return withName("du taf", name: name, generic: "taf")
        case .cours: return withName("du cours", name: name, generic: "cours")
        case .courses: return "de \(name)"
        }
    }

    private static func withName(_ phrase: String, name: String, generic: String) -> String {
        let clean: String = PlaceRules.cleanedName(name)
        if clean.isEmpty || PlaceRules.comparisonKey(clean) == generic { return phrase }
        return "\(phrase) (\(clean))"
    }

    /// Texte pour une arrivée ou un départ. Dans la zone de doute, on invite à choisir l'heure au lieu de demander "c'est bon ?".
    static func text(kind: DetectionNotificationKind, placeName: String, placeType: PlaceType,
                     bound: Date, calendar: Calendar) -> DetectionNotificationText {
        let clock: String = Formatting.clock(bound, calendar: calendar)
        let doubt: Bool = isInDoubtZone(bound, calendar: calendar)
        switch kind {
        case .arrival:
            let place: String = placePhraseAt(name: placeName, type: placeType)
            if doubt {
                return DetectionNotificationText(title: "Quelle heure d'arrivée ?",
                                                 body: "Ton arrivée \(place) est vers \(clock). Tu choisis l'heure ?")
            }
            return DetectionNotificationText(title: "Arrivée détectée",
                                             body: "T'es arrivé \(place) à \(clock), c'est bon ?")
        case .departure:
            let place: String = placePhraseFrom(name: placeName, type: placeType)
            if doubt {
                return DetectionNotificationText(title: "Quelle heure de départ ?",
                                                 body: "Ton départ \(place) est vers \(clock). Tu choisis l'heure ?")
            }
            return DetectionNotificationText(title: "Départ détecté",
                                             body: "T'es parti \(place) à \(clock), c'est bon ?")
        }
    }
}
