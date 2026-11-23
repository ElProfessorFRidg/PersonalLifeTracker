import Foundation

// Agrégation de l'onglet Statistiques (prototype 60_stats.html). Logique pure : Foundation, DaySummary, SessionDurations.
// Taf et cours seulement : les courses, trajets et autres ne sont pas comptés dans les totaux (ils restent visibles ailleurs).

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Semaine"
        case .month: return "Mois"
        }
    }
}

/// Une journée du graphique.
struct StatsDay: Equatable {
    let day: Date
    /// Secondes retenues selon la base choisie.
    let workSeconds: Int
    let workExactSeconds: Int
    let studySeconds: Int
    let studyExactSeconds: Int
    /// Une session de taf (ou de cours) tourne ce jour-là.
    let workHasLive: Bool
    let studyHasLive: Bool
    /// Base heures pleines : une borne en zone de doute sans choix (valeur exacte comptée).
    let isProvisional: Bool

    var totalSeconds: Int { return workSeconds + studySeconds }
    var hasLive: Bool { return workHasLive || studyHasLive }
}

/// Totaux et jours d'une période.
struct StatsResult: Equatable {
    let start: Date
    /// Fin exclue (début du lendemain du dernier jour).
    let end: Date
    let days: [StatsDay]
    let workSeconds: Int
    let workExactSeconds: Int
    let studySeconds: Int
    let studyExactSeconds: Int
    let workDayCount: Int
    let studyDayCount: Int
    let hasLive: Bool
    let hasProvisional: Bool

    var isEmpty: Bool { return workExactSeconds == 0 && studyExactSeconds == 0 && !hasLive }
    var maxDaySeconds: Int {
        var m: Int = 0
        for d in days { m = max(m, d.workSeconds + d.studySeconds) }
        return m
    }
}

enum StatsAggregator {

    /// Semaine du lundi au dimanche, ou mois civil, qui contient `reference`. Fin exclue.
    static func range(period: StatsPeriod, reference: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let day: Date = calendar.startOfDay(for: reference)
        switch period {
        case .week:
            let weekday: Int = calendar.component(.weekday, from: day)   // 1 = dimanche, 2 = lundi, ... 7 = samedi
            let sinceMonday: Int = (weekday + 5) % 7                      // lundi 0, dimanche 6
            let start: Date = calendar.date(byAdding: .day, value: -sinceMonday, to: day) ?? day
            let end: Date = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .month:
            let comps: DateComponents = calendar.dateComponents([.year, .month], from: day)
            let start: Date = calendar.date(from: comps) ?? day
            let end: Date = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
        }
    }

    /// Même position une période avant (offset -1) ou après (+1).
    static func shifted(reference: Date, period: StatsPeriod, by offset: Int, calendar: Calendar) -> Date {
        switch period {
        case .week: return calendar.date(byAdding: .day, value: 7 * offset, to: reference) ?? reference
        case .month: return calendar.date(byAdding: .month, value: offset, to: reference) ?? reference
        }
    }

    /// Totaux et jours d'une période. Chaque jour passe par DaySummary.total : une session à cheval sur minuit
    /// ne compte que sa part de chaque jour, une session en cours compte son exact jusqu'à `now`.
    static func aggregate(period: StatsPeriod,
                          reference: Date,
                          inputs: [DaySessionInput],
                          base: CalculationBase,
                          now: Date,
                          calendar: Calendar) -> StatsResult {
        let r: (start: Date, end: Date) = range(period: period, reference: reference, calendar: calendar)
        var days: [StatsDay] = []
        var work: Int = 0
        var workExact: Int = 0
        var study: Int = 0
        var studyExact: Int = 0
        var workDays: Int = 0
        var studyDays: Int = 0
        var live: Bool = false
        var provisional: Bool = false

        var day: Date = r.start
        while day < r.end {
            let w: ActivityDayTotal = DaySummary.total(activity: .work, day: day, inputs: inputs, base: base, now: now, calendar: calendar)
            let s: ActivityDayTotal = DaySummary.total(activity: .education, day: day, inputs: inputs, base: base, now: now, calendar: calendar)
            let dayLive: Bool = w.hasLive || s.hasLive
            let dayProv: Bool = w.isProvisional || s.isProvisional
            days.append(StatsDay(day: day,
                                 workSeconds: w.seconds, workExactSeconds: w.exactSeconds,
                                 studySeconds: s.seconds, studyExactSeconds: s.exactSeconds,
                                 workHasLive: w.hasLive, studyHasLive: s.hasLive, isProvisional: dayProv))
            work += w.seconds
            workExact += w.exactSeconds
            study += s.seconds
            studyExact += s.exactSeconds
            if w.sessionCount > 0 { workDays += 1 }
            if s.sessionCount > 0 { studyDays += 1 }
            if dayLive { live = true }
            if dayProv { provisional = true }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return StatsResult(start: r.start, end: r.end, days: days,
                           workSeconds: work, workExactSeconds: workExact,
                           studySeconds: study, studyExactSeconds: studyExact,
                           workDayCount: workDays, studyDayCount: studyDays,
                           hasLive: live, hasProvisional: provisional)
    }

    /// Moyenne par jour avec session, en secondes (division entière). 0 s'il n'y a aucun jour avec session.
    /// Les jours sans session ne tirent pas la moyenne vers le bas (prototype).
    static func averagePerActiveDay(totalSeconds: Int, activeDays: Int) -> Int {
        if activeDays <= 0 { return 0 }
        return totalSeconds / activeDays
    }

    /// Hauteur de l'axe du graphique en heures : le plus petit multiple de 2 h, d'au moins 2 h, qui contient la barre la plus haute.
    /// 7 h 30 donne 8, 8 h pile donne 8, 8 h 01 donne 10, rien donne 2.
    static func axisHours(maxDaySeconds: Int) -> Int {
        let hoursCeil: Int = (max(0, maxDaySeconds) + 3599) / 3600
        let even: Int = hoursCeil % 2 == 0 ? hoursCeil : hoursCeil + 1
        return max(2, even)
    }

    /// Part de la hauteur du graphique (0 à 1) pour une durée.
    static func barFraction(seconds: Int, axisHours: Int) -> Double {
        if seconds <= 0 || axisHours <= 0 { return 0 }
        return min(1.0, Double(seconds) / Double(axisHours * 3600))
    }

    /// Écart en secondes entre deux totaux, formaté "+1 h 30", "-2 h 00" ou "0 h" (jamais de tiret cadratin).
    static func signedDuration(seconds: Int) -> String {
        if seconds == 0 { return "0 h" }
        let text: String = Formatting.duration(seconds: abs(seconds))
        return (seconds > 0 ? "+" : "-") + text
    }

    /// Phrase pour VoiceOver : une entrée par jour avec du temps.
    static func accessibilitySummary(days: [StatsDay], calendar: Calendar) -> String {
        var parts: [String] = []
        for d in days where d.workSeconds + d.studySeconds > 0 {
            var bits: [String] = []
            if d.workSeconds > 0 { bits.append("taf \(Formatting.duration(seconds: d.workSeconds))") }
            if d.studySeconds > 0 { bits.append("cours \(Formatting.duration(seconds: d.studySeconds))") }
            parts.append("\(Formatting.dayTitle(d.day, calendar: calendar)) : " + bits.joined(separator: ", "))
        }
        if parts.isEmpty { return "Aucune heure sur cette période." }
        return parts.joined(separator: ". ") + "."
    }
}
