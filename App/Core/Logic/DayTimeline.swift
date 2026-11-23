import Foundation

/// Entrée du ruban : une session (fin nil = en cours).
struct DayTimelineInput: Equatable {
    let start: Date
    let end: Date?
    let activity: ActivityType
    let isDoubt: Bool
}

/// Un segment du ruban horaire d'une journée, en heures décimales de 0 à 24 (17:56 donne 17.93).
struct DaySegment: Equatable, Identifiable {
    let id: Int
    let startHour: Double
    let endHour: Double
    let activity: ActivityType
    let isLive: Bool
    let isDoubt: Bool
}

/// Bornes affichées du ruban.
struct HourRange: Equatable {
    let from: Double
    let to: Double
}

/// Découpage d'une journée en segments pour le ruban horaire. Logique pure.
enum DayTimeline {

    /// Segments de la journée `day` (fuseau du calendrier). Une session à cheval sur minuit est coupée :
    /// 22:00 à 02:00 donne 22 à 24 le premier jour et 0 à 2 le lendemain. Les sessions sans durée sont ignorées.
    static func segments(day: Date, inputs: [DayTimelineInput], now: Date, calendar: Calendar) -> [DaySegment] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        var raw: [(start: Date, end: Date, input: DayTimelineInput)] = []
        for input in inputs {
            let rawEnd: Date = input.end ?? now
            if rawEnd <= input.start { continue }
            let s: Date = max(input.start, dayStart)
            let e: Date = min(rawEnd, dayEnd)
            if e <= s { continue }
            raw.append((start: s, end: e, input: input))
        }
        raw.sort { (a, b) -> Bool in
            if a.start != b.start { return a.start < b.start }
            return a.input.activity.rawValue < b.input.activity.rawValue
        }

        var result: [DaySegment] = []
        for (index, item) in raw.enumerated() {
            let seg = DaySegment(
                id: index,
                startHour: hour(of: item.start, dayEnd: dayEnd, calendar: calendar),
                endHour: hour(of: item.end, dayEnd: dayEnd, calendar: calendar),
                activity: item.input.activity,
                isLive: item.input.end == nil,
                isDoubt: item.input.isDoubt
            )
            result.append(seg)
        }
        return result
    }

    private static func hour(of date: Date, dayEnd: Date, calendar: Calendar) -> Double {
        if date >= dayEnd { return 24 }
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    /// Heure décimale de "maintenant" dans la journée `day`, nil si now n'est pas dans cette journée.
    static func nowHour(day: Date, now: Date, calendar: Calendar) -> Double? {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        if now < dayStart || now >= dayEnd { return nil }
        return hour(of: now, dayEnd: dayEnd, calendar: calendar)
    }

    /// Bornes entières du ruban : au moins 6 à 24 par défaut, élargies si un segment sort de cette plage.
    static func visibleRange(segments: [DaySegment], defaultFrom: Double = 6, defaultTo: Double = 24) -> HourRange {
        var from = defaultFrom
        var to = defaultTo
        for s in segments {
            if s.startHour < from { from = s.startHour.rounded(.down) }
            if s.endHour > to { to = s.endHour.rounded(.up) }
        }
        return HourRange(from: max(0, from), to: min(24, to))
    }

    /// Phrase pour VoiceOver : "Cours de 08:05 à 12:02. Taf de 17:56 à maintenant."
    static func summary(segments: [DaySegment]) -> String {
        if segments.isEmpty { return "Aucune session ce jour-là." }
        var parts: [String] = []
        for s in segments {
            let end: String = s.isLive ? "maintenant" : Formatting.clock(hour: s.endHour)
            parts.append("\(s.activity.title) de \(Formatting.clock(hour: s.startHour)) à \(end).")
        }
        return parts.joined(separator: " ")
    }
}
