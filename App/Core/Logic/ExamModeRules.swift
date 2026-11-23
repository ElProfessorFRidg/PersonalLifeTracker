import Foundation

/// Une épreuve : titre et instant de début.
struct ExamEntry: Equatable, Codable, Identifiable {
    var id: UUID
    var title: String
    var start: Date

    init(id: UUID = UUID(), title: String, start: Date) {
        self.id = id
        self.title = title
        self.start = start
    }
}

/// La période d'examens définie par l'utilisateur (révisions, bac blanc, bac). Jours inclus.
struct ExamPeriod: Equatable, Codable {
    var title: String
    var startDay: Date
    var endDay: Date
    var exams: [ExamEntry]

    init(title: String, startDay: Date, endDay: Date, exams: [ExamEntry] = []) {
        self.title = title
        self.startDay = startDay
        self.endDay = endDay
        self.exams = exams
    }
}

/// Où en est-on par rapport à la période.
enum ExamPhase: Equatable {
    /// Pas encore commencée : nombre de jours avant le premier jour.
    case upcoming(daysUntilStart: Int)
    case active
    case over
}

/// Familles de messages que l'app envoie, pour décider lesquelles se taisent pendant le mode examens.
enum ExamNotificationClass: Equatable {
    /// Ce qui protège une donnée ou un choix en cours (confirmer une session détectée) : jamais coupé.
    case essential
    /// Rappels, suggestions de travail, alertes de confort : coupés pendant la période.
    case reminder
}

/// Règles pures du mode examens (section 31). Aucun message culpabilisant : le mode ne fait que se taire.
enum ExamModeRules {

    /// Un compte à rebours n'apparaît sur l'Accueil que dans les 14 jours avant la période (choix de l'app).
    static let countdownLeadDays: Int = 14

    // MARK: Période

    static func validate(startDay: Date, endDay: Date, calendar: Calendar) -> Bool {
        return calendar.startOfDay(for: endDay) >= calendar.startOfDay(for: startDay)
    }

    /// La période couvre ce jour (bornes incluses, comparaison par jour).
    static func covers(_ period: ExamPeriod, day: Date, calendar: Calendar) -> Bool {
        let d: Date = calendar.startOfDay(for: day)
        return d >= calendar.startOfDay(for: period.startDay) && d <= calendar.startOfDay(for: period.endDay)
    }

    static func phase(of period: ExamPeriod, now: Date, calendar: Calendar) -> ExamPhase {
        let today: Date = calendar.startOfDay(for: now)
        let start: Date = calendar.startOfDay(for: period.startDay)
        let end: Date = calendar.startOfDay(for: period.endDay)
        if today < start {
            return .upcoming(daysUntilStart: SchoolCalendarRules.daysBetween(today, start, calendar: calendar))
        }
        if today > end { return .over }
        return .active
    }

    static func isActive(_ period: ExamPeriod?, now: Date, calendar: Calendar) -> Bool {
        guard let period = period else { return false }
        return phase(of: period, now: now, calendar: calendar) == .active
    }

    // MARK: Épreuves

    /// La prochaine épreuve dont le début n'est pas passé, la plus proche d'abord.
    static func nextExam(in period: ExamPeriod, now: Date) -> ExamEntry? {
        let sorted: [ExamEntry] = period.exams.sorted { (a: ExamEntry, b: ExamEntry) -> Bool in return a.start < b.start }
        for e in sorted where e.start >= now { return e }
        return nil
    }

    /// Jours calendaires entre aujourd'hui et le jour de l'épreuve (0 = aujourd'hui).
    static func daysUntil(_ exam: ExamEntry, now: Date, calendar: Calendar) -> Int {
        return SchoolCalendarRules.daysBetween(now, exam.start, calendar: calendar)
    }

    // MARK: Effets

    /// Vrai si les suggestions de travail et rappels se taisent ce jour-là.
    static func quietsSuggestions(_ period: ExamPeriod?, now: Date, calendar: Calendar) -> Bool {
        return isActive(period, now: now, calendar: calendar)
    }

    /// Pendant la période, seuls les messages essentiels passent.
    static func allows(_ kind: ExamNotificationClass, period: ExamPeriod?, now: Date, calendar: Calendar) -> Bool {
        switch kind {
        case .essential:
            return true
        case .reminder:
            return !isActive(period, now: now, calendar: calendar)
        }
    }

    /// Les objectifs d'heures de travail sont suspendus un jour couvert par la période.
    static func goalsSuspended(_ period: ExamPeriod?, day: Date, calendar: Calendar) -> Bool {
        guard let period = period else { return false }
        return covers(period, day: day, calendar: calendar)
    }

    /// Annotation pour les statistiques : explique une baisse d'heures. Nil hors période.
    static func statsNote(_ period: ExamPeriod?, day: Date, calendar: Calendar) -> String? {
        guard let period = period else { return nil }
        if !covers(period, day: day, calendar: calendar) { return nil }
        let name: String = period.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Période d'examens" : "Période d'examens : \(name)"
    }

    // MARK: Textes de la carte

    /// Texte du compte à rebours de la période. Nil si la période est finie ou trop lointaine.
    static func periodText(_ period: ExamPeriod, now: Date, calendar: Calendar) -> String? {
        switch phase(of: period, now: now, calendar: calendar) {
        case .over:
            return nil
        case .active:
            return "Période d'examens en cours"
        case .upcoming(let days):
            if days > countdownLeadDays { return nil }
            if days == 1 { return "La période commence demain" }
            return "La période commence dans \(days) jours"
        }
    }

    /// "Maths : aujourd'hui à 08:00", "Maths : demain à 14:00", "Maths : dans 5 jours".
    static func examText(_ exam: ExamEntry, now: Date, calendar: Calendar) -> String {
        let days: Int = daysUntil(exam, now: now, calendar: calendar)
        let clock: String = Formatting.clock(exam.start, calendar: calendar)
        let name: String = exam.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let label: String = name.isEmpty ? "Épreuve" : name
        if days <= 0 { return "\(label) : aujourd'hui à \(clock)" }
        if days == 1 { return "\(label) : demain à \(clock)" }
        return "\(label) : dans \(days) jours"
    }

    // MARK: Pas aujourd'hui

    /// La carte est cachée si l'utilisateur a choisi "Pas aujourd'hui" ce même jour.
    static func isSkipped(skippedDay: String?, now: Date, calendar: Calendar) -> Bool {
        guard let skippedDay = skippedDay else { return false }
        return skippedDay == SchoolCalendarRules.dayText(now, calendar: calendar)
    }
}
