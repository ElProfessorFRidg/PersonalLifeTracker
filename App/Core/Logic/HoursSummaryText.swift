import Foundation

/// Texte partageable des heures d'une semaine ou d'un mois (module share_summary). Foundation seulement.
/// Une ligne par jour avec du temps, puis les totaux dans la base de calcul choisie. Jamais d'argent.
/// Les noms de jours et de mois sont écrits ici (pas de DateFormatter) pour un résultat identique partout.
enum HoursSummaryText {
    private static let weekdayNames: [String] = ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
    private static let shortMonthNames: [String] = ["janv.", "févr.", "mars", "avr.", "mai", "juin",
                                                    "juil.", "août", "sept.", "oct.", "nov.", "déc."]
    private static let longMonthNames: [String] = ["janvier", "février", "mars", "avril", "mai", "juin",
                                                   "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

    /// "lun. 16 nov."
    static func dayLabel(_ day: Date, calendar: Calendar) -> String {
        let weekday: Int = calendar.component(.weekday, from: day)
        let dom: Int = calendar.component(.day, from: day)
        let month: Int = calendar.component(.month, from: day)
        let w: String = weekdayNames[max(0, min(6, weekday - 1))]
        let m: String = shortMonthNames[max(0, min(11, month - 1))]
        return "\(w) \(dom) \(m)"
    }

    private static func title(period: StatsPeriod, start: Date, end: Date, calendar: Calendar) -> String {
        switch period {
        case .week:
            let last: Date = calendar.date(byAdding: .day, value: -1, to: end) ?? end
            let year: Int = calendar.component(.year, from: last)
            return "Mes heures, du \(dayLabel(start, calendar: calendar)) au \(dayLabel(last, calendar: calendar)) \(year)"
        case .month:
            let month: Int = calendar.component(.month, from: start)
            let year: Int = calendar.component(.year, from: start)
            return "Mes heures, \(longMonthNames[max(0, min(11, month - 1))]) \(year)"
        }
    }

    private static func parts(work: Int, study: Int) -> String {
        var bits: [String] = []
        if work > 0 { bits.append("Taf \(Formatting.duration(seconds: work))") }
        if study > 0 { bits.append("Cours \(Formatting.duration(seconds: study))") }
        return bits.joined(separator: " · ")
    }

    /// Texte complet pour la période qui contient `reference`.
    static func build(period: StatsPeriod,
                      reference: Date,
                      inputs: [DaySessionInput],
                      base: CalculationBase,
                      now: Date,
                      calendar: Calendar) -> String {
        let result: StatsResult = StatsAggregator.aggregate(period: period, reference: reference, inputs: inputs,
                                                            base: base, now: now, calendar: calendar)
        var lines: [String] = [title(period: period, start: result.start, end: result.end, calendar: calendar)]
        if result.isEmpty {
            lines.append("Aucune heure sur cette période.")
            return lines.joined(separator: "\n")
        }
        for d in result.days where d.workSeconds + d.studySeconds > 0 {
            var line: String = "\(dayLabel(d.day, calendar: calendar)) : \(parts(work: d.workSeconds, study: d.studySeconds))"
            if d.isProvisional { line += " (à confirmer)" }
            if d.hasLive { line += " (en cours)" }
            lines.append(line)
        }
        var total: String = "Total : \(parts(work: result.workSeconds, study: result.studySeconds))"
        if result.hasProvisional { total += " (à confirmer)" }
        lines.append(total)
        lines.append(base == .fullHours ? "Base de calcul : heures pleines" : "Base de calcul : heure exacte")
        return lines.joined(separator: "\n")
    }
}
