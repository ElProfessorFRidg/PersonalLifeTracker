import Foundation

// Alerte de planning tardif (section 70). Règles pures : aucune notification ici, seulement la décision
// "montrer le rappel ou rester silencieux, et pourquoi". Elle ne suppose aucune régularité des horaires,
// seulement un rythme de publication du planning.

/// Actions proposées avec le rappel.
enum LatePlanningAction: String, CaseIterable, Equatable {
    case importPhoto
    case notReceivedYet
    case skipThisWeek
    case neverRemind

    var title: String {
        switch self {
        case .importPhoto: return "Importer une photo"
        case .notReceivedYet: return "Pas encore reçu"
        case .skipThisWeek: return "Pas cette semaine"
        case .neverRemind: return "Ne plus me le rappeler"
        }
    }
}

/// Moment habituel de publication du planning de la semaine suivante.
struct LatePlanningSlot: Equatable {
    /// Numéro de jour du calendrier Apple : 1 = dimanche, 2 = lundi ... 7 = samedi.
    let weekday: Int
    /// Minutes depuis minuit.
    let minutes: Int

    init(weekday: Int, minutes: Int) {
        self.weekday = min(7, max(1, weekday))
        self.minutes = min(1439, max(0, minutes))
    }
}

struct LatePlanningSettings: Equatable {
    var isEnabled: Bool
    var slot: LatePlanningSlot?
    /// "Ne plus me le rappeler".
    var neverRemind: Bool

    init(isEnabled: Bool = false, slot: LatePlanningSlot? = nil, neverRemind: Bool = false) {
        self.isEnabled = isEnabled
        self.slot = slot
        self.neverRemind = neverRemind
    }
}

struct LatePlanningContext {
    var now: Date
    var calendar: Calendar
    var settings: LatePlanningSettings
    /// Au moins un créneau prévu existe déjà pour la semaine suivante (import ou saisie).
    var hasPlanningForNextWeek: Bool
    /// Lundi de la semaine que l'utilisateur a marquée "Pas cette semaine".
    var skippedWeekStart: Date?
    /// Dernière fois qu'un rappel a été montré.
    var lastReminderAt: Date?
    /// Congés ou mode vacances.
    var isOnLeaveOrVacation: Bool
    var isExamMode: Bool
    var isQuietHours: Bool

    init(now: Date,
         calendar: Calendar,
         settings: LatePlanningSettings,
         hasPlanningForNextWeek: Bool,
         skippedWeekStart: Date? = nil,
         lastReminderAt: Date? = nil,
         isOnLeaveOrVacation: Bool = false,
         isExamMode: Bool = false,
         isQuietHours: Bool = false) {
        self.now = now
        self.calendar = calendar
        self.settings = settings
        self.hasPlanningForNextWeek = hasPlanningForNextWeek
        self.skippedWeekStart = skippedWeekStart
        self.lastReminderAt = lastReminderAt
        self.isOnLeaveOrVacation = isOnLeaveOrVacation
        self.isExamMode = isExamMode
        self.isQuietHours = isQuietHours
    }
}

enum LatePlanningSilence: Equatable {
    case disabled
    case noSlot
    case beforeDeadline
    case planningPresent
    case skippedWeek
    case leaveOrVacation
    case examMode
    case alreadyRemindedThisWeek
    case quietHours
}

struct LatePlanningReminder: Equatable {
    /// Lundi de la semaine dont le planning manque.
    let nextWeekStart: Date
    let title: String
    let message: String
    let actions: [LatePlanningAction]

    /// Texte complet de la notification douce.
    var notificationBody: String { return title + ", " + message.lowercasedFirst }
}

private extension String {
    var lowercasedFirst: String {
        guard let first = self.first else { return self }
        return String(first).lowercased() + String(self.dropFirst())
    }
}

enum LatePlanningDecision: Equatable {
    case silent(LatePlanningSilence)
    case remind(LatePlanningReminder)
}

enum LatePlanningRules {

    static let reminderTitle: String = "Le planning de la semaine prochaine est pas encore là"
    static let reminderMessage: String = "Tu l'as reçu ?"

    /// Lundi (début de journée) de la semaine qui contient `date`.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let weekdayIndex = (calendar.component(.weekday, from: date) + 5) % 7
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -weekdayIndex, to: day) ?? day
    }

    /// Lundi de la semaine suivante.
    static func nextWeekStart(after date: Date, calendar: Calendar) -> Date {
        let start = weekStart(of: date, calendar: calendar)
        return calendar.date(byAdding: .day, value: 7, to: start) ?? start
    }

    /// Échéance de la semaine courante : jour et heure habituels de publication.
    static func deadline(for slot: LatePlanningSlot, now: Date, calendar: Calendar) -> Date {
        let start = weekStart(of: now, calendar: calendar)
        let slotIndex = (slot.weekday + 5) % 7
        let day = calendar.date(byAdding: .day, value: slotIndex, to: start) ?? start
        let base = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: slot.minutes / 60, minute: slot.minutes % 60, second: 0, of: base)
            ?? base.addingTimeInterval(Double(slot.minutes) * 60)
    }

    /// Faut-il rappeler à l'utilisateur que le planning de la semaine prochaine manque ?
    static func decide(_ context: LatePlanningContext) -> LatePlanningDecision {
        let settings = context.settings
        if !settings.isEnabled || settings.neverRemind { return .silent(.disabled) }
        guard let slot = settings.slot else { return .silent(.noSlot) }

        let cal = context.calendar
        let due = deadline(for: slot, now: context.now, calendar: cal)
        if context.now < due { return .silent(.beforeDeadline) }
        if context.hasPlanningForNextWeek { return .silent(.planningPresent) }

        let next = nextWeekStart(after: context.now, calendar: cal)
        if let skipped = context.skippedWeekStart, cal.isDate(skipped, inSameDayAs: next) {
            return .silent(.skippedWeek)
        }
        if context.isOnLeaveOrVacation { return .silent(.leaveOrVacation) }
        if context.isExamMode { return .silent(.examMode) }
        if let last = context.lastReminderAt,
           cal.isDate(weekStart(of: last, calendar: cal), inSameDayAs: weekStart(of: context.now, calendar: cal)) {
            return .silent(.alreadyRemindedThisWeek)
        }
        if context.isQuietHours { return .silent(.quietHours) }

        let reminder = LatePlanningReminder(nextWeekStart: next,
                                            title: reminderTitle,
                                            message: reminderMessage,
                                            actions: LatePlanningAction.allCases)
        return .remind(reminder)
    }

    /// Moment de publication appris à partir des dates d'import des plannings de la semaine suivante.
    /// Il faut au moins 3 imports, dont 3 le même jour de la semaine et 60 % du total. L'heure est la médiane,
    /// arrondie au quart d'heure inférieur.
    static func suggestedSlot(importDates: [Date], calendar: Calendar) -> LatePlanningSlot? {
        if importDates.count < 3 { return nil }
        var counts: [Int: Int] = [:]
        for date in importDates {
            let weekday = calendar.component(.weekday, from: date)
            counts[weekday] = (counts[weekday] ?? 0) + 1
        }
        var bestWeekday = 0
        var bestCount = 0
        for (weekday, count) in counts {
            if count > bestCount || (count == bestCount && weekday < bestWeekday) {
                bestWeekday = weekday
                bestCount = count
            }
        }
        if bestCount < 3 { return nil }
        if Double(bestCount) < 0.6 * Double(importDates.count) { return nil }
        var minutes: [Int] = []
        for date in importDates where calendar.component(.weekday, from: date) == bestWeekday {
            minutes.append(calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date))
        }
        minutes.sort()
        let median = minutes[minutes.count / 2]
        let rounded = (median / 15) * 15
        return LatePlanningSlot(weekday: bestWeekday, minutes: rounded)
    }
}
