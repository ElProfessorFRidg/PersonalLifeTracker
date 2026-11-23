import Foundation

/// Un intervalle occupé (travail, cours, trajet, session réelle, créneau prévu).
struct StudyBusy: Equatable {
    let start: Date
    let end: Date
}

/// Une épreuve connue, pour repérer les créneaux d'avant épreuve.
struct StudyExam: Equatable {
    let title: String
    let start: Date
}

/// Réglages du calcul. Toutes les valeurs sont des choix de l'app, sauf la durée minimale (45 min, section 34).
struct StudySlotConfig: Equatable {
    /// Durée minimale d'un créneau proposé, configurable. Défaut de la spec : 45 minutes.
    var minMinutes: Int = StudySlotsRules.defaultMinMinutes
    /// Heures calmes : on ne propose rien avant 08:00 (minutes depuis minuit). Choix de l'app.
    var dayStartMinutes: Int = StudySlotsRules.defaultDayStartMinutes
    /// Ni après 21:00. Choix de l'app.
    var dayEndMinutes: Int = StudySlotsRules.defaultDayEndMinutes
    /// Marge gardée avant et après chaque occupation (trajet, souffle). Choix de l'app.
    var marginMinutes: Int = StudySlotsRules.defaultMarginMinutes
    /// Un bloc proposé ne dépasse pas cette durée. Choix de l'app.
    var maxBlockMinutes: Int = StudySlotsRules.defaultMaxBlockMinutes
    /// Pause entre deux blocs d'un même trou. Choix de l'app.
    var breakMinutes: Int = StudySlotsRules.defaultBreakMinutes
    /// Nombre de jours regardés, aujourd'hui compris. Choix de l'app.
    var horizonDays: Int = StudySlotsRules.defaultHorizonDays
    /// Durée supposée d'une épreuve dont on ne connaît que le début. Choix de l'app.
    var examMinutes: Int = StudySlotsRules.defaultExamMinutes

    init() {}
}

/// Un créneau de révision proposé.
struct StudySlot: Equatable, Identifiable {
    let start: Date
    let end: Date
    /// Titre de la prochaine épreuve après ce créneau, si connue.
    let examTitle: String?
    /// Jours calendaires entre ce créneau et cette épreuve.
    let daysToExam: Int?

    var id: TimeInterval { return start.timeIntervalSince1970 }
    var minutes: Int { return Int(end.timeIntervalSince(start)) / 60 }
}

/// Règles pures des créneaux libres de révision (section 34). Foundation seulement.
enum StudySlotsRules {
    static let defaultMinMinutes: Int = 45
    static let defaultDayStartMinutes: Int = 8 * 60
    static let defaultDayEndMinutes: Int = 21 * 60
    static let defaultMarginMinutes: Int = 15
    static let defaultMaxBlockMinutes: Int = 120
    static let defaultBreakMinutes: Int = 15
    static let defaultHorizonDays: Int = 7
    static let defaultExamMinutes: Int = 120

    /// Note écrite sur le créneau prévu quand l'utilisateur réserve.
    static let reservedNote: String = "Révision"
    /// Source du créneau prévu créé.
    static let reservedSource: String = "manual"

    /// Fusionne les intervalles qui se touchent ou se chevauchent. Entrée quelconque, sortie triée.
    static func merged(_ intervals: [StudyBusy]) -> [StudyBusy] {
        let sorted: [StudyBusy] = intervals.filter { $0.end > $0.start }
            .sorted { (a: StudyBusy, b: StudyBusy) -> Bool in return a.start < b.start }
        var result: [StudyBusy] = []
        for item in sorted {
            if let last = result.last, item.start <= last.end {
                if item.end > last.end {
                    result[result.count - 1] = StudyBusy(start: last.start, end: item.end)
                }
            } else {
                result.append(item)
            }
        }
        return result
    }

    /// Trous libres de [from, to) une fois les occupations (élargies de la marge) retirées.
    static func freeIntervals(from: Date, to: Date, busy: [StudyBusy], marginMinutes: Int) -> [StudyBusy] {
        if to <= from { return [] }
        let margin: TimeInterval = TimeInterval(max(0, marginMinutes) * 60)
        var widened: [StudyBusy] = []
        for b in busy {
            let s: Date = b.start.addingTimeInterval(-margin)
            let e: Date = b.end.addingTimeInterval(margin)
            if e > from && s < to { widened.append(StudyBusy(start: s, end: e)) }
        }
        var result: [StudyBusy] = []
        var cursor: Date = from
        for b in merged(widened) {
            if b.start > cursor {
                result.append(StudyBusy(start: cursor, end: min(b.start, to)))
            }
            if b.end > cursor { cursor = b.end }
            if cursor >= to { break }
        }
        if cursor < to { result.append(StudyBusy(start: cursor, end: to)) }
        return result.filter { $0.end > $0.start }
    }

    /// Découpe un trou en blocs d'au plus `maxBlockMinutes`, séparés d'une pause. Un bloc plus court que le minimum est abandonné.
    static func blocks(in gap: StudyBusy, config: StudySlotConfig) -> [StudyBusy] {
        let minSeconds: TimeInterval = TimeInterval(max(1, config.minMinutes) * 60)
        let maxSeconds: TimeInterval = TimeInterval(max(1, config.maxBlockMinutes) * 60)
        let breakSeconds: TimeInterval = TimeInterval(max(0, config.breakMinutes) * 60)
        var result: [StudyBusy] = []
        var cursor: Date = gap.start
        while gap.end.timeIntervalSince(cursor) >= minSeconds {
            let length: TimeInterval = min(maxSeconds, gap.end.timeIntervalSince(cursor))
            let blockEnd: Date = cursor.addingTimeInterval(length)
            result.append(StudyBusy(start: cursor, end: blockEnd))
            cursor = blockEnd.addingTimeInterval(breakSeconds)
        }
        return result
    }

    /// Créneaux proposés dans les `horizonDays` jours à partir de `now`. Aujourd'hui, rien avant `now`.
    /// Les heures calmes sont lues en heure affichée (08:00 reste 08:00 un jour de changement d'heure).
    static func slots(now: Date, busy: [StudyBusy], exams: [StudyExam], config: StudySlotConfig, calendar: Calendar) -> [StudySlot] {
        var result: [StudySlot] = []
        let today: Date = calendar.startOfDay(for: now)
        let sortedExams: [StudyExam] = exams.sorted { (a: StudyExam, b: StudyExam) -> Bool in return a.start < b.start }
        var allBusy: [StudyBusy] = busy
        for e in exams {
            allBusy.append(StudyBusy(start: e.start, end: e.start.addingTimeInterval(TimeInterval(max(0, config.examMinutes) * 60))))
        }
        let days: Int = max(0, config.horizonDays)
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard let open = wallClock(day: day, minutes: config.dayStartMinutes, calendar: calendar),
                  let close = wallClock(day: day, minutes: config.dayEndMinutes, calendar: calendar) else { continue }
            let from: Date = max(open, now)
            for gap in freeIntervals(from: from, to: close, busy: allBusy, marginMinutes: config.marginMinutes) {
                for block in blocks(in: gap, config: config) {
                    var title: String? = nil
                    var distance: Int? = nil
                    for e in sortedExams where e.start >= block.end {
                        title = e.title
                        distance = SchoolCalendarRules.daysBetween(block.start, e.start, calendar: calendar)
                        break
                    }
                    result.append(StudySlot(start: block.start, end: block.end, examTitle: title, daysToExam: distance))
                }
            }
        }
        return result
    }

    /// Instant "heure affichée" (par exemple 08:00) du jour donné.
    static func wallClock(day: Date, minutes: Int, calendar: Calendar) -> Date? {
        let clamped: Int = max(0, min(minutes, 24 * 60 - 1))
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: day)
    }

    // MARK: Textes

    /// "Aujourd'hui", "Demain" ou "lundi 16 novembre".
    static func dayLabel(_ day: Date, now: Date, calendar: Calendar) -> String {
        let diff: Int = SchoolCalendarRules.daysBetween(now, day, calendar: calendar)
        if diff == 0 { return "Aujourd'hui" }
        if diff == 1 { return "Demain" }
        return Formatting.dayTitle(day, calendar: calendar)
    }

    /// "Avant Maths, dans 2 jours" (nil sans épreuve).
    static func examHint(_ slot: StudySlot) -> String? {
        guard let title = slot.examTitle, let days = slot.daysToExam else { return nil }
        let name: String = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let label: String = name.isEmpty ? "ton épreuve" : name
        if days <= 0 { return "Avant \(label), aujourd'hui" }
        if days == 1 { return "Avant \(label), demain" }
        return "Avant \(label), dans \(days) jours"
    }
}
