import Foundation

// Équilibrage des heures du contrat (module contract_hours). Logique pure : Foundation seulement.
// Spec section 106 (équilibrage, compteurs, projection, suggestions) et section 109 (alerte de proximité du quota).
// L'app informe, elle ne dit jamais un droit : classement des heures et repos compensateur restent "à vérifier".

// MARK: - Entrées

/// Une session vue par le calcul. `minutes` est la durée retenue selon la base de calcul (section 13.1),
/// nil si une borne est en zone de doute sans choix (la session est alors "à confirmer", jamais comptée).
struct HoursSessionInput: Equatable {
    let start: Date
    /// nil = session en cours (la fin vaut `today`).
    let end: Date?
    let minutes: Int?
    let isConfirmed: Bool

    init(start: Date, end: Date?, minutes: Int?, isConfirmed: Bool = true) {
        self.start = start
        self.end = end
        self.minutes = minutes
        self.isConfirmed = isConfirmed
    }
}

/// Un créneau planifié (106.2). Liste vide pour l'instant côté écran.
struct HoursPlannedShift: Equatable {
    let start: Date
    let end: Date
}

/// Le contrat vu par le calcul : minutes par semaine (13 h = 780) et dates (la date de fin est incluse).
struct HoursContractInput: Equatable {
    let weeklyMinutes: Int
    let start: Date
    let end: Date?
}

/// 106.4 : ce qui se passe réellement pour l'utilisateur. Par défaut l'app ne présume rien.
enum HoursCarryRule: String, CaseIterable {
    case unknown
    case carried
    case smoothedMonth
    case paid
    case notCarried

    var title: String {
        switch self {
        case .unknown: return "À renseigner"
        case .carried: return "Reporté sur la période suivante"
        case .smoothedMonth: return "Lissé sur le mois"
        case .paid: return "Payé en heures en plus"
        case .notCarried: return "Non reporté"
        }
    }

    var detail: String {
        switch self {
        case .unknown: return "Je ne sais pas encore, je compte sans reporter."
        case .carried: return "Le trop et le manque passent d'une semaine à l'autre."
        case .smoothedMonth: return "Le trop et le manque se compensent dans le même mois."
        case .paid: return "Le trop est payé en plus, il ne reste rien d'avance."
        case .notCarried: return "Chaque semaine repart de zéro."
        }
    }
}

// MARK: - Sorties

enum WeekStatus: Equatable {
    case inContract
    case under
    case over
    /// Semaine en cours, rien de prévu : pas encore un manque.
    case inProgress
    /// Une session de la semaine attend une confirmation : le total n'est pas définitif.
    case toConfirm
}

struct WeekBalance: Equatable {
    /// Lundi 00:00 (calendrier explicite).
    let weekStart: Date
    /// Lundi suivant 00:00, exclu. Une semaine de changement d'heure fait 167 h ou 169 h.
    let weekEnd: Date
    let isoYear: Int
    let isoWeek: Int
    /// Année et mois du jeudi de la semaine (202611 pour novembre 2026) : le mois ISO d'une semaine à cheval.
    let monthKey: Int
    /// Quota de la semaine, proratisé au nombre de jours couverts par le contrat si la semaine est partielle.
    let quotaMinutes: Int
    let isPartial: Bool
    let doneMinutes: Int
    /// Créneaux planifiés encore à venir (à partir de maintenant), 0 pour une semaine finie.
    let plannedRemainingMinutes: Int
    let projectedMinutes: Int
    /// Sessions de la semaine à confirmer (exclues du total).
    let pendingCount: Int
    let isCurrent: Bool
    let isComplete: Bool
    /// Jours du contrat encore devant toi dans la semaine, aujourd'hui compris.
    let remainingDays: Int
    let status: WeekStatus
    /// Lundi à dimanche.
    let dayDone: [Int]
    let dayPlanned: [Int]

    /// Projection moins quota. Pour une semaine finie, c'est le réalisé moins le quota.
    var deltaMinutes: Int { return projectedMinutes - quotaMinutes }
}

/// 106.4 : compteurs. Le repos compensateur n'est pas calculé : il dépend de la convention (pack absent), "à renseigner".
struct HoursCounters: Equatable {
    let rule: HoursCarryRule
    let advanceMinutes: Int
    let catchUpMinutes: Int
    /// Heures en plus qui seraient payées (règle "payé en heures en plus"), sur le mois.
    let paidExtraMinutes: Int
    /// Semaines finies prises en compte, et semaines laissées de côté car des sessions sont à confirmer.
    let weeksCounted: Int
    let weeksSkippedPending: Int
}

/// 106.6 : distribution réelle sur les dernières semaines pleines et finies.
struct HoursDistribution: Equatable {
    let weeksCount: Int
    let averageMinutes: Int
    let minMinutes: Int
    let maxMinutes: Int
    let overCount: Int
    /// Dépassement fréquent (au moins la moitié des semaines, sur 4 semaines ou plus) : signalé doucement.
    let recurrentOver: Bool
}

enum ContractPeriodState: Equatable {
    case notStarted
    case running
    case ended
}

struct ContractHoursReport: Equatable {
    let state: ContractPeriodState
    /// De la première semaine du contrat à la semaine courante (ou la dernière du contrat), dans l'ordre.
    let weeks: [WeekBalance]
    let current: WeekBalance?
    let counters: HoursCounters
    let distribution: HoursDistribution?
}

/// 109 : niveau d'alerte de proximité d'une limite.
enum QuotaAlertLevel: Equatable {
    case off
    /// Il reste `remainingMinutes` (>0) et un seuil activé est franchi.
    case remaining(minutes: Int)
    case reached
    case exceeded(overMinutes: Int)
}

/// 106.3 et 106.7 : ce que l'app propose, toujours sans décider à ta place.
enum HoursSuggestion: Equatable {
    case nothingToChange
    /// Au-dessus du contrat : classement à vérifier (106.5).
    case explainOver(minutes: Int)
    /// Il manque `minutes` : "il te faut X h sur les jours restants".
    case placeMissing(minutes: Int, days: Int)
}

// MARK: - Calcul

enum ContractHoursBalance {

    // MARK: Semaines (ISO 8601, lundi)

    /// Lundi 00:00 de la semaine qui contient `date`. Indépendant du réglage `firstWeekday` du calendrier.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let day: Date = calendar.startOfDay(for: date)
        let weekday: Int = calendar.component(.weekday, from: day)
        let offset: Int = (weekday + 5) % 7
        return addDays(-offset, to: day, calendar: calendar)
    }

    /// Année et numéro ISO de la semaine : celle du jeudi (la semaine du 28 déc. 2026 est la 53 de 2026,
    /// celle du 4 janv. 2027 est la 1 de 2027).
    static func isoWeek(weekStart: Date, calendar: Calendar) -> (year: Int, week: Int) {
        let thursday: Date = addDays(3, to: weekStart, calendar: calendar)
        let year: Int = calendar.component(.year, from: thursday)
        let ordinal: Int = calendar.ordinality(of: .day, in: .year, for: thursday) ?? 1
        return (year, (ordinal - 1) / 7 + 1)
    }

    static func monthKey(weekStart: Date, calendar: Calendar) -> Int {
        let thursday: Date = addDays(3, to: weekStart, calendar: calendar)
        let year: Int = calendar.component(.year, from: thursday)
        let month: Int = calendar.component(.month, from: thursday)
        return year * 100 + month
    }

    static func addDays(_ n: Int, to date: Date, calendar: Calendar) -> Date {
        return calendar.date(byAdding: .day, value: n, to: date) ?? date.addingTimeInterval(Double(n) * 86400)
    }

    // MARK: Découpe d'une durée sur des bornes

    private static func overlaps(start: Date, end: Date, from: Date, to: Date) -> Bool {
        if end > start {
            return end > from && start < to
        }
        return start >= from && start < to
    }

    /// Part de `minutes` (durée retenue de la session) qui tombe dans [from, to[, répartie au prorata du temps réel.
    /// Les parts d'une session découpée en plusieurs intervalles consécutifs s'additionnent exactement à `minutes`.
    static func share(minutes: Int, start: Date, end: Date, from: Date, to: Date) -> Int {
        let total: Double = end.timeIntervalSince(start)
        if total <= 0 {
            return (start >= from && start < to) ? minutes : 0
        }
        let a: Date = min(max(from, start), end)
        let b: Date = min(max(to, start), end)
        let cumA: Int = Int((Double(minutes) * a.timeIntervalSince(start) / total).rounded())
        let cumB: Int = Int((Double(minutes) * b.timeIntervalSince(start) / total).rounded())
        return cumB - cumA
    }

    private static func overlapMinutes(_ s: Date, _ e: Date, _ from: Date, _ to: Date) -> Int {
        let a: Date = max(s, from)
        let b: Date = min(e, to)
        if b > a {
            return Int(b.timeIntervalSince(a) / 60)
        }
        return 0
    }

    // MARK: Rapport

    /// Rapport complet du contrat à la date `today`.
    /// Règle de la semaine partielle (choix hors spec, voir notes/contract_hours.md) : le quota est proratisé
    /// au nombre de jours couverts par le contrat sur 7, arrondi à la minute.
    static func report(contract: HoursContractInput,
                       sessions: [HoursSessionInput],
                       planned: [HoursPlannedShift],
                       today: Date,
                       rule: HoursCarryRule,
                       calendar: Calendar) -> ContractHoursReport {
        let firstDay: Date = calendar.startOfDay(for: contract.start)
        var lastDay: Date? = nil
        if let e = contract.end {
            lastDay = calendar.startOfDay(for: e)
        }
        let todayStart: Date = calendar.startOfDay(for: today)

        if todayStart < firstDay {
            return ContractHoursReport(state: .notStarted, weeks: [], current: nil,
                                       counters: emptyCounters(rule), distribution: nil)
        }

        var state: ContractPeriodState = .running
        var reference: Date = todayStart
        if let last = lastDay, last < todayStart {
            state = .ended
            reference = last
        }

        let firstWeek: Date = weekStart(of: firstDay, calendar: calendar)
        let lastWeek: Date = weekStart(of: reference, calendar: calendar)
        var weeks: [WeekBalance] = []
        var ws: Date = firstWeek
        var guardCount: Int = 0
        while ws <= lastWeek && guardCount < 600 {
            let w: WeekBalance = makeWeek(weekStart: ws, firstDay: firstDay, lastDay: lastDay,
                                          weeklyMinutes: contract.weeklyMinutes,
                                          sessions: sessions, planned: planned,
                                          today: today, todayStart: todayStart, calendar: calendar)
            weeks.append(w)
            ws = addDays(7, to: ws, calendar: calendar)
            guardCount += 1
        }

        var current: WeekBalance? = nil
        if let lastWeekBalance = weeks.last, lastWeekBalance.isCurrent {
            current = lastWeekBalance
        }
        return ContractHoursReport(state: state,
                                   weeks: weeks,
                                   current: current,
                                   counters: counters(weeks: weeks, rule: rule),
                                   distribution: distribution(weeks: weeks))
    }

    private static func emptyCounters(_ rule: HoursCarryRule) -> HoursCounters {
        return HoursCounters(rule: rule, advanceMinutes: 0, catchUpMinutes: 0, paidExtraMinutes: 0,
                             weeksCounted: 0, weeksSkippedPending: 0)
    }

    private static func makeWeek(weekStart ws: Date,
                                 firstDay: Date,
                                 lastDay: Date?,
                                 weeklyMinutes: Int,
                                 sessions: [HoursSessionInput],
                                 planned: [HoursPlannedShift],
                                 today: Date,
                                 todayStart: Date,
                                 calendar: Calendar) -> WeekBalance {
        var bounds: [Date] = []
        for i in 0...7 {
            bounds.append(addDays(i, to: ws, calendar: calendar))
        }
        let weekEnd: Date = bounds[7]
        let isComplete: Bool = weekEnd <= today
        let isCurrent: Bool = !isComplete && ws <= today

        var covered: Int = 0
        var remainingDays: Int = 0
        for i in 0..<7 {
            let d: Date = bounds[i]
            var inside: Bool = d >= firstDay
            if let last = lastDay, d > last {
                inside = false
            }
            if inside {
                covered += 1
                if d >= todayStart {
                    remainingDays += 1
                }
            }
        }
        let isPartial: Bool = covered < 7
        var quota: Int = weeklyMinutes
        if isPartial {
            quota = Int((Double(weeklyMinutes) * Double(covered) / 7.0).rounded())
        }

        var dayDone: [Int] = [Int](repeating: 0, count: 7)
        var pending: Int = 0
        for s in sessions {
            if s.start > today { continue }
            let effectiveEnd: Date = s.end ?? today
            if !overlaps(start: s.start, end: effectiveEnd, from: ws, to: weekEnd) { continue }
            if !s.isConfirmed {
                pending += 1
                continue
            }
            guard let m = s.minutes else {
                pending += 1
                continue
            }
            for i in 0..<7 {
                dayDone[i] += share(minutes: m, start: s.start, end: effectiveEnd, from: bounds[i], to: bounds[i + 1])
            }
        }
        var done: Int = 0
        for v in dayDone {
            done += v
        }

        var dayPlanned: [Int] = [Int](repeating: 0, count: 7)
        var plannedRemaining: Int = 0
        for p in planned where p.end > p.start {
            for i in 0..<7 {
                dayPlanned[i] += overlapMinutes(p.start, p.end, bounds[i], bounds[i + 1])
            }
            if !isComplete {
                plannedRemaining += overlapMinutes(p.start, p.end, max(today, ws), weekEnd)
            }
        }

        let projected: Int = done + plannedRemaining
        let status: WeekStatus
        if pending > 0 {
            status = .toConfirm
        } else if isCurrent && plannedRemaining == 0 && done < quota {
            status = .inProgress
        } else if projected == quota {
            status = .inContract
        } else if projected < quota {
            status = .under
        } else {
            status = .over
        }

        let iso: (year: Int, week: Int) = isoWeek(weekStart: ws, calendar: calendar)
        return WeekBalance(weekStart: ws,
                           weekEnd: weekEnd,
                           isoYear: iso.year,
                           isoWeek: iso.week,
                           monthKey: monthKey(weekStart: ws, calendar: calendar),
                           quotaMinutes: quota,
                           isPartial: isPartial,
                           doneMinutes: done,
                           plannedRemainingMinutes: plannedRemaining,
                           projectedMinutes: projected,
                           pendingCount: pending,
                           isCurrent: isCurrent,
                           isComplete: isComplete,
                           remainingDays: isComplete ? 0 : remainingDays,
                           status: status,
                           dayDone: dayDone,
                           dayPlanned: dayPlanned)
    }

    // MARK: Compteurs (106.4)

    /// Compteurs sur les semaines finies sans session à confirmer. Règle inconnue ou "non reporté" : tout à zéro,
    /// l'app ne présume rien. Reporté : solde cumulé depuis le début du contrat. Lissé sur le mois : solde du mois
    /// de la semaine la plus récente (mois du jeudi). Payé : seulement le trop, sur ce même mois.
    static func counters(weeks: [WeekBalance], rule: HoursCarryRule) -> HoursCounters {
        var counted: Int = 0
        var skipped: Int = 0
        for w in weeks where w.isComplete {
            if w.pendingCount > 0 {
                skipped += 1
            } else {
                counted += 1
            }
        }
        var monthRef: Int = 0
        if let last = weeks.last {
            monthRef = last.monthKey
        }
        var netAll: Int = 0
        var netMonth: Int = 0
        var paidMonth: Int = 0
        for w in weeks where w.isComplete && w.pendingCount == 0 {
            let delta: Int = w.doneMinutes - w.quotaMinutes
            netAll += delta
            if w.monthKey == monthRef {
                netMonth += delta
                if delta > 0 {
                    paidMonth += delta
                }
            }
        }
        var advance: Int = 0
        var catchUp: Int = 0
        var paid: Int = 0
        switch rule {
        case .unknown, .notCarried:
            break
        case .carried:
            advance = max(netAll, 0)
            catchUp = max(-netAll, 0)
        case .smoothedMonth:
            advance = max(netMonth, 0)
            catchUp = max(-netMonth, 0)
        case .paid:
            paid = paidMonth
        }
        return HoursCounters(rule: rule, advanceMinutes: advance, catchUpMinutes: catchUp,
                             paidExtraMinutes: paid, weeksCounted: counted, weeksSkippedPending: skipped)
    }

    // MARK: Distribution (106.6)

    /// Les 8 dernières semaines finies, pleines (ni début ni fin de contrat partiels) et sans session à confirmer.
    static func distribution(weeks: [WeekBalance]) -> HoursDistribution? {
        var eligible: [WeekBalance] = weeks.filter { (w: WeekBalance) -> Bool in
            return w.isComplete && !w.isPartial && w.pendingCount == 0
        }
        if eligible.count > 8 {
            eligible = Array(eligible.suffix(8))
        }
        if eligible.isEmpty { return nil }
        var sum: Int = 0
        var minV: Int = Int.max
        var maxV: Int = 0
        var over: Int = 0
        for w in eligible {
            sum += w.doneMinutes
            minV = min(minV, w.doneMinutes)
            maxV = max(maxV, w.doneMinutes)
            if w.doneMinutes > w.quotaMinutes {
                over += 1
            }
        }
        let n: Int = eligible.count
        let average: Int = Int((Double(sum) / Double(n)).rounded())
        return HoursDistribution(weeksCount: n,
                                 averageMinutes: average,
                                 minMinutes: minV,
                                 maxMinutes: maxV,
                                 overCount: over,
                                 recurrentOver: n >= 4 && over * 2 >= n)
    }

    // MARK: Alerte de proximité (109)

    /// Alerte de proximité d'une limite (quota du contrat par défaut). `thresholdsMinutes` : seuils activés,
    /// par exemple [120, 60, 0] pour "2 h, 1 h, atteint". Le réalisé inclut la session en cours.
    /// Un seuil est franchi quand il reste ce temps ou moins. `suppressed` : congés, vacances, période bloquée.
    static func quotaAlert(doneMinutes: Int,
                           limitMinutes: Int,
                           thresholdsMinutes: [Int],
                           suppressed: Bool) -> QuotaAlertLevel {
        if suppressed || limitMinutes <= 0 || thresholdsMinutes.isEmpty { return .off }
        let remaining: Int = limitMinutes - doneMinutes
        var crossed: Bool = false
        for t in thresholdsMinutes where t >= 0 {
            if remaining <= t {
                crossed = true
            }
        }
        if !crossed { return .off }
        if remaining > 0 { return .remaining(minutes: remaining) }
        if remaining == 0 { return .reached }
        return .exceeded(overMinutes: -remaining)
    }

    // MARK: Suggestions (106.3, 106.7)

    static func suggestions(for week: WeekBalance) -> [HoursSuggestion] {
        if !week.isCurrent || week.status == .toConfirm { return [] }
        let delta: Int = week.projectedMinutes - week.quotaMinutes
        if delta == 0 { return [.nothingToChange] }
        if delta > 0 { return [.explainOver(minutes: delta)] }
        if week.remainingDays > 0 {
            return [.placeMissing(minutes: -delta, days: week.remainingDays)]
        }
        return []
    }

    /// Répartition égale arrondie à la minute supérieure : 540 min sur 3 jours = 180 min par jour.
    static func evenSplitMinutes(missing: Int, days: Int) -> Int {
        if days <= 0 || missing <= 0 { return 0 }
        return (missing + days - 1) / days
    }
}

// MARK: - Textes

/// Phrases de l'écran, en français, tutoiement. Elles informent, jamais d'ordre ni de droit affirmé.
enum ContractHoursText {

    private static func two(_ n: Int) -> String {
        return n < 10 ? "0\(n)" : "\(n)"
    }

    /// "13 h", "1 h 14", "45 min", "0 h". Les valeurs négatives donnent "0 h".
    static func hours(_ minutes: Int) -> String {
        let m: Int = max(0, minutes)
        if m == 0 { return "0 h" }
        if m < 60 { return "\(m) min" }
        if m % 60 == 0 { return "\(m / 60) h" }
        return "\(m / 60) h \(two(m % 60))"
    }

    /// Nombre d'heures court pour une barre : "13", "11,5".
    static func shortHours(_ minutes: Int) -> String {
        let m: Int = max(0, minutes)
        if m % 60 == 0 { return "\(m / 60)" }
        let tenths: Int = Int((Double(m) / 6.0).rounded())
        return "\(tenths / 10),\(tenths % 10)"
    }

    static func statusTitle(_ status: WeekStatus) -> String {
        switch status {
        case .inContract: return "Dans le contrat"
        case .under: return "En dessous du contrat"
        case .over: return "Au-dessus du contrat"
        case .inProgress: return "En cours"
        case .toConfirm: return "À confirmer"
        }
    }

    /// 106.3 : la phrase claire de la semaine.
    static func headline(_ w: WeekBalance) -> String {
        let q: String = hours(w.quotaMinutes)
        if w.status == .toConfirm {
            return "Des sessions sont à confirmer : le total de la semaine n'est pas définitif."
        }
        let delta: Int = w.projectedMinutes - w.quotaMinutes
        if w.isComplete {
            if delta == 0 { return "\(q) au total, ton contrat est atteint pile." }
            if delta > 0 { return "\(hours(delta)) au-dessus de ton contrat." }
            return "Il te manque \(hours(-delta)) pour tes \(q)."
        }
        let remaining: Int = max(w.quotaMinutes - w.doneMinutes, 0)
        if w.plannedRemainingMinutes == 0 {
            if w.doneMinutes < w.quotaMinutes { return "Il te reste \(hours(remaining)) pour tes \(q)." }
            if w.doneMinutes == w.quotaMinutes { return "\(q) au total, ton contrat est atteint pile." }
            return "Tu en es à \(hours(w.doneMinutes)), soit \(hours(delta)) de plus que ton contrat."
        }
        let first: String = remaining > 0 ? "Il te reste \(hours(remaining)) pour tes \(q)" : "Tu as déjà tes \(q)"
        var tail: String = "pile ton contrat"
        if delta > 0 {
            tail = "soit \(hours(delta)) de plus que ton contrat"
        } else if delta < 0 {
            tail = "soit \(hours(-delta)) de moins que ton contrat"
        }
        return "\(first), ton planning en prévoit \(hours(w.plannedRemainingMinutes)), tu finiras à \(hours(w.projectedMinutes)), \(tail)."
    }

    /// 109 : phrase d'alerte, ton neutre.
    static func alertTitle(_ level: QuotaAlertLevel) -> String {
        switch level {
        case .off:
            return ""
        case .remaining(let minutes):
            return "Plus que \(hours(minutes)) avant ton quota de la semaine."
        case .reached:
            return "Ton quota de la semaine est atteint."
        case .exceeded(let over):
            return "Tu es \(hours(over)) au-dessus de ton quota de la semaine."
        }
    }

    /// 106.6 : phrase sur la distribution, sans accuser.
    static func distributionSentence(_ d: HoursDistribution, quotaMinutes: Int) -> String {
        let plural: String = d.overCount > 1 ? "s" : ""
        var text: String = "Tu as dépassé tes \(hours(quotaMinutes)) \(d.overCount) semaine\(plural) sur \(d.weeksCount)."
        if d.recurrentOver {
            text += " Si ça devient une habitude, un avenant a peut-être été prévu : à vérifier dans ton contrat."
        }
        return text
    }
}
