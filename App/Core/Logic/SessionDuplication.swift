import Foundation

/// Résultat d'une demande de duplication.
enum SessionDuplicationOutcome: Equatable {
    /// Les nouvelles bornes sont valides.
    case ready(start: Date, end: Date)
    /// La session d'origine tourne encore : pas de fin à copier.
    case notFinished
    /// Les nouvelles bornes sont refusées par SessionRules.
    case invalid([SessionValidationError])

    /// Phrase à afficher quand la duplication est refusée, nil sinon.
    var refusalMessage: String? {
        switch self {
        case .ready:
            return nil
        case .notFinished:
            return "Arrête d'abord cette session, puis duplique-la."
        case .invalid(let errors):
            return errors.map { (e: SessionValidationError) -> String in e.message }.joined(separator: " ")
        }
    }
}

/// Duplication d'une session sur un autre jour, à la même heure. Logique pure (Foundation).
enum SessionDuplication {

    /// Même heure et même minute de début et de fin sur le jour `day`. Une fin le lendemain du début reste le lendemain.
    /// L'heure est celle du calendrier donné, donc correcte un jour de changement d'heure (la durée réelle peut varier d'une heure).
    /// nil si la fin tombe avant ou au début après décalage.
    static func shifted(start: Date, end: Date, toDay day: Date, calendar: Calendar) -> (start: Date, end: Date)? {
        let startDay: Date = calendar.startOfDay(for: start)
        let endDay: Date = calendar.startOfDay(for: end)
        let offset: Int = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        let newStart: Date = SessionRules.combine(day: day, time: start, calendar: calendar)
        let newEnd: Date = SessionRules.combine(day: day, time: end, dayOffset: max(0, offset), calendar: calendar)
        if newEnd <= newStart { return nil }
        return (newStart, newEnd)
    }

    /// Duplication vers le jour de `now` : décale, puis valide (futur, chevauchement, durée) avec SessionRules.
    static func planForToday(start: Date, end: Date?, now: Date, others: [SessionInterval], calendar: Calendar) -> SessionDuplicationOutcome {
        guard let end = end else { return .notFinished }
        guard let moved = shifted(start: start, end: end, toDay: now, calendar: calendar) else {
            return .invalid([SessionValidationError.endNotAfterStart])
        }
        let errors: [SessionValidationError] = SessionRules.validate(start: moved.start, end: moved.end, now: now, others: others)
        if !errors.isEmpty { return .invalid(errors) }
        return .ready(start: moved.start, end: moved.end)
    }
}
