import Foundation

/// Un créneau prévu, sous forme pure (sans SwiftData).
struct PlanSlot: Equatable, Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let activity: ActivityType
}

/// Un créneau réellement fait (fin nil = en cours).
struct RealSlot: Equatable {
    let start: Date
    let end: Date?
    let activity: ActivityType
}

/// Prévu contre réel pour un jour.
struct DayComparison: Equatable {
    let day: Date
    let plannedMinutes: Int
    let doneMinutes: Int
    /// fait moins prévu : négatif = moins que prévu.
    let differenceMinutes: Int
}

enum ShiftValidation: Equatable {
    case valid
    case endNotAfterStart
    case tooLong
}

/// Règles du planning variable (section 91). Logique pure : Foundation seulement.
/// Les semaines vont du lundi au dimanche. Un créneau appartient à la semaine de son début.
enum PlanningRules {

    /// Activités comptées dans les totaux prévu et fait.
    static let countedActivities: [ActivityType] = [.work, .education]
    /// Durée maximale d'un créneau : 24 h.
    static let maxShiftSeconds: TimeInterval = 24 * 3600

    // MARK: Semaines

    /// Lundi 00:00 de la semaine contenant `date`, dans le calendrier donné.
    static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let dayStart: Date = calendar.startOfDay(for: date)
        let weekday: Int = calendar.component(.weekday, from: dayStart) // 1 = dimanche
        let offset: Int = (weekday + 5) % 7                              // lundi 0 ... dimanche 6
        return calendar.date(byAdding: .day, value: -offset, to: dayStart) ?? dayStart
    }

    /// Les 7 débuts de jour de la semaine commençant à `weekStart`.
    static func days(ofWeekStarting weekStart: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: i, to: weekStart) {
                result.append(d)
            }
        }
        return result
    }

    /// Début de la semaine décalée de `weeks` semaines.
    static func shiftWeek(_ weekStart: Date, by weeks: Int, calendar: Calendar) -> Date {
        return calendar.date(byAdding: .day, value: 7 * weeks, to: weekStart) ?? weekStart
    }

    /// Créneaux dont le début tombe dans la semaine, triés par début.
    static func slots(inWeekStarting weekStart: Date, slots: [PlanSlot], calendar: Calendar) -> [PlanSlot] {
        let weekEnd: Date = shiftWeek(weekStart, by: 1, calendar: calendar)
        var result: [PlanSlot] = []
        for s in slots {
            if s.start >= weekStart && s.start < weekEnd { result.append(s) }
        }
        result.sort { (a, b) -> Bool in return a.start < b.start }
        return result
    }

    /// Créneaux qui touchent le jour (même coupés à minuit), toutes activités, triés par début.
    static func slots(onDay day: Date, slots: [PlanSlot], calendar: Calendar) -> [PlanSlot] {
        let b = dayBounds(day, calendar: calendar)
        var result: [PlanSlot] = []
        for s in slots {
            if s.start < b.to && s.end > b.from { result.append(s) }
        }
        result.sort { (a, c) -> Bool in return a.start < c.start }
        return result
    }

    /// "Du 16 au 22 novembre" ou "Du 30 novembre au 6 décembre".
    static func weekTitle(weekStart: Date, calendar: Calendar) -> String {
        let days: [Date] = self.days(ofWeekStarting: weekStart, calendar: calendar)
        guard let first = days.first, let last = days.last else { return "" }
        let d1: Int = calendar.component(.day, from: first)
        let d2: Int = calendar.component(.day, from: last)
        let m1: String = monthName(first, calendar: calendar)
        let m2: String = monthName(last, calendar: calendar)
        if m1 == m2 { return "Du \(d1) au \(d2) \(m2)" }
        return "Du \(d1) \(m1) au \(d2) \(m2)"
    }

    private static func monthName(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    // MARK: Minutes

    /// Minutes entières de l'intersection de [start, end) avec [from, to).
    static func clippedMinutes(start: Date, end: Date, from: Date, to: Date) -> Int {
        let s: Date = max(start, from)
        let e: Date = min(end, to)
        if e <= s { return 0 }
        return Int(e.timeIntervalSince(s)) / 60
    }

    private static func dayBounds(_ day: Date, calendar: Calendar) -> (from: Date, to: Date) {
        let from: Date = calendar.startOfDay(for: day)
        let to: Date = calendar.date(byAdding: .day, value: 1, to: from) ?? from.addingTimeInterval(86400)
        return (from, to)
    }

    /// Minutes prévues un jour (créneaux à cheval sur minuit coupés). Seules les activités comptées.
    static func plannedMinutes(day: Date, slots: [PlanSlot], calendar: Calendar) -> Int {
        let b = dayBounds(day, calendar: calendar)
        var total: Int = 0
        for s in slots where countedActivities.contains(s.activity) {
            total += clippedMinutes(start: s.start, end: s.end, from: b.from, to: b.to)
        }
        return total
    }

    /// Minutes prévues sur les 7 jours de la semaine.
    static func plannedMinutes(weekStarting weekStart: Date, slots: [PlanSlot], calendar: Calendar) -> Int {
        var total: Int = 0
        for d in days(ofWeekStarting: weekStart, calendar: calendar) {
            total += plannedMinutes(day: d, slots: slots, calendar: calendar)
        }
        return total
    }

    /// Minutes faites un jour. Une session en cours compte jusqu'à `now`.
    static func doneMinutes(day: Date, real: [RealSlot], now: Date, calendar: Calendar) -> Int {
        let b = dayBounds(day, calendar: calendar)
        var total: Int = 0
        for r in real where countedActivities.contains(r.activity) {
            let end: Date = r.end ?? now
            total += clippedMinutes(start: r.start, end: end, from: b.from, to: b.to)
        }
        return total
    }

    static func doneMinutes(weekStarting weekStart: Date, real: [RealSlot], now: Date, calendar: Calendar) -> Int {
        var total: Int = 0
        for d in days(ofWeekStarting: weekStart, calendar: calendar) {
            total += doneMinutes(day: d, real: real, now: now, calendar: calendar)
        }
        return total
    }

    /// Prévu contre réel, jour par jour. Différence = fait moins prévu.
    static func comparison(weekStarting weekStart: Date, slots: [PlanSlot], real: [RealSlot],
                           now: Date, calendar: Calendar) -> [DayComparison] {
        var result: [DayComparison] = []
        for d in days(ofWeekStarting: weekStart, calendar: calendar) {
            let p: Int = plannedMinutes(day: d, slots: slots, calendar: calendar)
            let r: Int = doneMinutes(day: d, real: real, now: now, calendar: calendar)
            result.append(DayComparison(day: d, plannedMinutes: p, doneMinutes: r, differenceMinutes: r - p))
        }
        return result
    }

    // MARK: Validation et chevauchement

    /// Fin strictement après le début (passer minuit est permis), durée d'au plus 24 h.
    static func validate(start: Date, end: Date) -> ShiftValidation {
        if end <= start { return .endNotAfterStart }
        if end.timeIntervalSince(start) > maxShiftSeconds { return .tooLong }
        return .valid
    }

    /// Créneaux existants qui chevauchent [start, end). Deux créneaux qui se touchent ne se chevauchent pas.
    static func overlapping(start: Date, end: Date, in slots: [PlanSlot], excluding id: UUID?) -> [PlanSlot] {
        var result: [PlanSlot] = []
        for s in slots {
            if let id = id, s.id == id { continue }
            if s.start < end && start < s.end { result.append(s) }
        }
        return result
    }

    // MARK: Copie de semaine

    /// Copie les créneaux de la semaine source vers la semaine cible : mêmes jours de semaine, mêmes heures
    /// affichées (le décalage se fait en jours calendaires, donc correct à travers un changement d'heure).
    /// Nouveaux identifiants. Les créneaux hors de la semaine source sont ignorés.
    static func copyWeek(slots: [PlanSlot], fromWeekStart: Date, toWeekStart: Date, calendar: Calendar) -> [PlanSlot] {
        let dayDelta: Int = calendar.dateComponents([.day], from: fromWeekStart, to: toWeekStart).day ?? 0
        let source: [PlanSlot] = self.slots(inWeekStarting: fromWeekStart, slots: slots, calendar: calendar)
        var result: [PlanSlot] = []
        for s in source {
            guard let newStart = calendar.date(byAdding: .day, value: dayDelta, to: s.start),
                  let newEnd = calendar.date(byAdding: .day, value: dayDelta, to: s.end) else { continue }
            result.append(PlanSlot(id: UUID(), start: newStart, end: newEnd, activity: s.activity))
        }
        return result
    }

    // MARK: Congés

    /// Vrai si `day` est entre `startDay` et `endDay` inclus (comparaison par jour).
    static func leaveCovers(day: Date, startDay: Date, endDay: Date, calendar: Calendar) -> Bool {
        let d: Date = calendar.startOfDay(for: day)
        let s: Date = calendar.startOfDay(for: startDay)
        let e: Date = calendar.startOfDay(for: endDay)
        return d >= s && d <= e
    }
}
