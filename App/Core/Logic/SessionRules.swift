import Foundation

/// Règles pures des écrans Sessions (Foundation seulement) : validation d'une saisie, chevauchements,
/// regroupement par jour, filtres, "à confirmer", propositions de la zone de doute (section 13.1).

/// Un intervalle de temps occupé par une session (la fin d'une session en cours est remplacée par "maintenant" par l'appelant).
struct SessionInterval: Equatable {
    let start: Date
    let end: Date
}

/// Erreurs de validation d'une session saisie ou corrigée à la main.
enum SessionValidationError: Equatable {
    case endNotAfterStart
    case endInFuture
    case tooLong
    case overlap

    /// Message affiché sous le formulaire (tutoiement, sans tiret cadratin).
    var message: String {
        switch self {
        case .endNotAfterStart: return "Le départ est avant l'arrivée. Corrige une des deux heures."
        case .endInFuture: return "Cette session finit dans le futur. Mets des heures déjà passées."
        case .tooLong: return "Plus de 24 h d'affilée, ça fait beaucoup. Vérifie les heures."
        case .overlap: return "Ça chevauche une autre session. Corrige les heures ou supprime l'autre."
        }
    }
}

/// Données minimales d'une session pour la liste (le modèle SwiftData est converti par la vue).
struct SessionListItem: Equatable {
    let id: UUID
    let start: Date
    let end: Date?
    let activity: ActivityType
    let isConfirmed: Bool
    let hasUnresolvedDoubt: Bool
}

enum SessionFilter: String, CaseIterable, Identifiable {
    case all
    case work
    case education
    case shopping
    case toConfirm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Tout"
        case .work: return "Taf"
        case .education: return "Cours"
        case .shopping: return "Courses"
        case .toConfirm: return "À confirmer"
        }
    }
}

struct SessionDayGroup: Equatable {
    /// Début de journée dans le calendrier utilisé.
    let day: Date
    /// Sessions du jour, la plus récente d'abord.
    let items: [SessionListItem]
}

enum SessionBoundKind: Equatable {
    case start
    case end
}

/// Une heure pleine proposée dans la zone de doute.
struct DoubtOption: Equatable {
    let hour: Date
    /// Vrai si l'heure pleine est avant l'heure exacte (donc "N min après" l'heure pleine).
    let hourIsBeforeExact: Bool
    /// Écart en minutes entre l'heure exacte et cette heure pleine (1 à 59).
    let minutesApart: Int
    /// Durée normalisée résultante en secondes, l'autre borne étant résolue (ou exacte à défaut).
    let resultingSeconds: Int
}

enum SessionRules {

    /// Durée maximale d'une session saisie (choix de l'app, la spec ne fixe pas de plafond) : 24 h.
    static let maxDurationSeconds: Int = 24 * 3600

    // MARK: Chevauchement

    /// Deux intervalles se chevauchent si chacun commence avant la fin de l'autre. Deux sessions bout à bout ne se chevauchent pas.
    static func overlaps(_ a: SessionInterval, _ b: SessionInterval) -> Bool {
        return a.start < b.end && b.start < a.end
    }

    static func hasOverlap(_ candidate: SessionInterval, with others: [SessionInterval]) -> Bool {
        for other in others {
            if overlaps(candidate, other) { return true }
        }
        return false
    }

    // MARK: Validation

    /// Valide une session passée. `others` : les autres sessions (sans celle qu'on corrige).
    static func validate(start: Date, end: Date, now: Date, others: [SessionInterval]) -> [SessionValidationError] {
        var errors: [SessionValidationError] = []
        if end <= start {
            errors.append(.endNotAfterStart)
            return errors
        }
        if end > now {
            errors.append(.endInFuture)
        }
        if end.timeIntervalSince(start) > Double(maxDurationSeconds) {
            errors.append(.tooLong)
        }
        if hasOverlap(SessionInterval(start: start, end: end), with: others) {
            errors.append(.overlap)
        }
        return errors
    }

    // MARK: Date et heure

    /// Jour de `day` à l'heure et la minute de `time` (secondes à zéro), décalé de `dayOffset` jours.
    static func combine(day: Date, time: Date, dayOffset: Int = 0, calendar: Calendar) -> Date {
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year
        c.month = d.month
        c.day = d.day
        c.hour = t.hour
        c.minute = t.minute
        c.second = 0
        guard let base = calendar.date(from: c) else { return day }
        if dayOffset == 0 { return base }
        return calendar.date(byAdding: .day, value: dayOffset, to: base) ?? base
    }

    /// "17:56:12" dans le calendrier donné.
    static func clockWithSeconds(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return "\(two(c.hour ?? 0)):\(two(c.minute ?? 0)):\(two(c.second ?? 0))"
    }

    /// "2 h 42 min 05 s", "12 min 03 s", "45 s".
    static func durationWithSeconds(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return "\(h) h \(two(m)) min \(two(r)) s" }
        if m > 0 { return "\(m) min \(two(r)) s" }
        return "\(r) s"
    }

    private static func two(_ n: Int) -> String {
        return n < 10 ? "0\(n)" : "\(n)"
    }

    // MARK: Liste

    /// Vrai si la session attend l'utilisateur : non confirmée, ou une borne en zone de doute sans choix.
    static func needsConfirmation(_ item: SessionListItem) -> Bool {
        return !item.isConfirmed || item.hasUnresolvedDoubt
    }

    static func matches(_ item: SessionListItem, filter: SessionFilter) -> Bool {
        switch filter {
        case .all: return true
        case .work: return item.activity == .work
        case .education: return item.activity == .education
        case .shopping: return item.activity == .shopping
        case .toConfirm: return needsConfirmation(item)
        }
    }

    static func filter(_ items: [SessionListItem], by filter: SessionFilter) -> [SessionListItem] {
        return items.filter { matches($0, filter: filter) }
    }

    /// Regroupe par jour de début (dans le calendrier donné), jours et sessions du plus récent au plus ancien.
    static func groupByDay(_ items: [SessionListItem], calendar: Calendar) -> [SessionDayGroup] {
        let sorted = items.sorted { (a: SessionListItem, b: SessionListItem) -> Bool in
            if a.start != b.start { return a.start > b.start }
            return a.id.uuidString < b.id.uuidString
        }
        var groups: [SessionDayGroup] = []
        var currentDay: Date? = nil
        var current: [SessionListItem] = []
        for item in sorted {
            let day = calendar.startOfDay(for: item.start)
            if let cd = currentDay, cd == day {
                current.append(item)
            } else {
                if let cd = currentDay {
                    groups.append(SessionDayGroup(day: cd, items: current))
                }
                currentDay = day
                current = [item]
            }
        }
        if let cd = currentDay {
            groups.append(SessionDayGroup(day: cd, items: current))
        }
        return groups
    }

    /// "Aujourd'hui, lundi 16 novembre", "Hier, dimanche 15 novembre", "Samedi 14 novembre".
    static func dayLabel(day: Date, now: Date, calendar: Calendar) -> String {
        let title = Formatting.dayTitle(day, calendar: calendar)
        if calendar.isDate(day, inSameDayAs: now) {
            return "Aujourd'hui, " + title
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Hier, " + title
        }
        return String(title.prefix(1)).uppercased() + String(title.dropFirst())
    }

    // MARK: Zone de doute

    /// Les deux heures pleines proposées pour une borne, avec la durée normalisée qui en résulte.
    /// Liste vide si la borne n'est pas en zone de doute (:00 à :14 et :46 à :59 sont arrondis tout seuls).
    static func doubtOptions(bound: SessionBoundKind,
                             start: Date,
                             end: Date,
                             chosenStart: Date?,
                             chosenEnd: Date?,
                             calendar: Calendar) -> [DoubtOption] {
        let exact: Date = (bound == .start) ? start : end
        guard let choices = SessionDurations.doubtChoices(for: exact, calendar: calendar) else { return [] }
        let minute = SessionDurations.minuteOfDay(exact, calendar: calendar) % 60
        let candidates: [(Date, Bool, Int)] = [
            (choices.floor, true, minute),
            (choices.ceil, false, 60 - minute)
        ]
        var options: [DoubtOption] = []
        for candidate in candidates {
            let hour = candidate.0
            let s: Date
            let e: Date
            switch bound {
            case .start:
                s = hour
                e = SessionDurations.resolvedBound(exact: end, chosen: chosenEnd, calendar: calendar) ?? end
            case .end:
                s = SessionDurations.resolvedBound(exact: start, chosen: chosenStart, calendar: calendar) ?? start
                e = hour
            }
            let seconds = max(0, Int(e.timeIntervalSince(s).rounded()))
            options.append(DoubtOption(hour: hour, hourIsBeforeExact: candidate.1, minutesApart: candidate.2, resultingSeconds: seconds))
        }
        return options
    }
}
