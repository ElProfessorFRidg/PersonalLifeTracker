import Foundation

/// Aides communes aux écrans Planning : calendrier explicite et conversions modèle vers logique pure.
enum PlanningSupport {

    /// Calendrier grégorien dans le fuseau courant, semaine du lundi (gérée par PlanningRules).
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        c.locale = Locale(identifier: "fr_FR")
        return c
    }

    static func currentWeekStart() -> Date {
        return PlanningRules.weekStart(for: Date(), calendar: calendar)
    }

    /// "lun. 16"
    static func dayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEE d"
        return f.string(from: date)
    }

    /// "16 novembre"
    static func dayMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }

    /// Écart fait moins prévu, en phrase.
    static func differenceText(minutes: Int) -> String {
        if minutes == 0 { return "Pile comme prévu" }
        if minutes > 0 { return "\(Formatting.duration(minutes: minutes)) de plus que prévu" }
        return "\(Formatting.duration(minutes: -minutes)) de moins que prévu"
    }

    /// "08:00 à 12:00"
    static func range(start: Date, end: Date) -> String {
        return "\(Formatting.clock(start, calendar: calendar)) à \(Formatting.clock(end, calendar: calendar))"
    }

    /// Sessions réelles qui touchent le jour, activités comptées seulement.
    static func realSlots(sessions: [WorkSession], day: Date, now: Date) -> [RealSlot] {
        let cal: Calendar = calendar
        let from: Date = cal.startOfDay(for: day)
        let to: Date = cal.date(byAdding: .day, value: 1, to: from) ?? from.addingTimeInterval(86400)
        var result: [RealSlot] = []
        for s in sessions {
            if !PlanningRules.countedActivities.contains(s.activity) { continue }
            let end: Date = s.endDate ?? now
            if s.startDate < to && end > from {
                result.append(RealSlot(start: s.startDate, end: s.endDate, activity: s.activity))
            }
        }
        return result
    }

    static func leaveKindTitle(_ raw: String) -> String {
        switch raw {
        case "paid": return "Congé payé"
        case "unpaid": return "Congé sans solde"
        case "sick": return "Maladie"
        default: return "Congé"
        }
    }
}

extension PlannedShift {
    var planSlot: PlanSlot {
        return PlanSlot(id: uid, start: start, end: end, activity: activity)
    }
}

extension WorkSession {
    var planRealSlot: RealSlot {
        return RealSlot(start: startDate, end: endDate, activity: activity)
    }
}
