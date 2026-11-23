import Foundation

// Congés payés (spec section 23, module leave). Logique pure, Foundation seulement, Calendar toujours explicite.
//
// Section 23 : "période de référence (défaut proposé après vérification des sources officielles, modifiable car la
// convention ou l'entreprise peut la fixer autrement), nombre de jours acquis par mois de travail effectif, unité
// (jours ouvrables ou ouvrés)". La spec voudrait lire ces valeurs dans Resources/reference/leave.json, qui n'existe
// pas : elles sont ici des DONNÉES (LeaveParameters), marquées "à vérifier" et modifiables dans UserDefaults.
// L'app informe, elle n'affirme jamais un droit : tout est une estimation à comparer à la fiche de paie.

/// Unité de décompte (section 23 : "jours ouvrables ou ouvrés").
enum LeaveUnit: String, CaseIterable, Equatable {
    /// Lundi au samedi.
    case ouvrable
    /// Lundi au vendredi.
    case ouvre

    var title: String {
        switch self {
        case .ouvrable: return "Jours ouvrables (lundi au samedi)"
        case .ouvre: return "Jours ouvrés (lundi au vendredi)"
        }
    }

    var shortTitle: String {
        switch self {
        case .ouvrable: return "Ouvrables"
        case .ouvre: return "Ouvrés"
        }
    }
}

/// Nature d'un congé (LeaveEntry.kindRaw : paid, unpaid, sick, other). Seul un congé payé consomme le solde.
enum LeaveKindChoice: String, CaseIterable, Equatable {
    case paid
    case unpaid
    case sick
    case other

    var title: String {
        switch self {
        case .paid: return "Congé payé"
        case .unpaid: return "Sans solde"
        case .sick: return "Maladie"
        case .other: return "Autre"
        }
    }

    var consumesBalance: Bool {
        switch self {
        case .paid: return true
        case .unpaid, .sick, .other: return false
        }
    }

    /// Valeur brute inconnue : "other", sans jamais planter.
    static func from(raw: String) -> LeaveKindChoice {
        return LeaveKindChoice(rawValue: raw) ?? .other
    }
}

/// Règles de calcul, en données. Défauts à vérifier (service-public.fr, Légifrance), jamais présentés comme un droit.
struct LeaveParameters: Equatable {
    var unit: LeaveUnit
    /// Jours acquis par mois de travail effectif.
    var daysPerMonth: Double
    /// Plafond sur une période de référence.
    var maxPerPeriod: Double
    /// Mois de début de la période de référence (1 à 12), toujours le 1er du mois.
    var referenceStartMonth: Int
    /// Nombre de jours avant la fin de période sous lequel on alerte sur les jours à risque.
    var alertDays: Int
    /// Arrondi du total acquis au jour entier supérieur.
    var roundUpToWholeDay: Bool

    /// Note affichée avec les valeurs par défaut.
    static let verificationNote: String = "À vérifier : valeurs habituelles (2,5 jours ouvrables par mois, 30 par an, période du 1er juin au 31 mai). Ta convention collective ou ton entreprise peut fixer autre chose. Ta fiche de paie fait foi."

    // Valeurs par défaut à vérifier. Code du travail, articles L3141-3 (2,5 jours ouvrables par mois, 30 par an),
    // L3141-4 (période de référence du 1er juin au 31 mai à défaut d'accord), L3141-7 (arrondi au jour entier supérieur).
    static let defaultOuvrablesPerMonth: Double = 2.5
    static let defaultOuvrablesMax: Double = 30
    static let defaultOuvresPerMonth: Double = 25.0 / 12.0
    static let defaultOuvresMax: Double = 25
    static let defaultReferenceStartMonth: Int = 6
    static let defaultAlertDays: Int = 60

    static func defaults(unit: LeaveUnit) -> LeaveParameters {
        switch unit {
        case .ouvrable:
            return LeaveParameters(unit: .ouvrable, daysPerMonth: defaultOuvrablesPerMonth, maxPerPeriod: defaultOuvrablesMax,
                                   referenceStartMonth: defaultReferenceStartMonth, alertDays: defaultAlertDays, roundUpToWholeDay: true)
        case .ouvre:
            return LeaveParameters(unit: .ouvre, daysPerMonth: defaultOuvresPerMonth, maxPerPeriod: defaultOuvresMax,
                                   referenceStartMonth: defaultReferenceStartMonth, alertDays: defaultAlertDays, roundUpToWholeDay: true)
        }
    }

    // MARK: UserDefaults (surcharge utilisateur)

    static let unitKey: String = "plt.leave.unit"
    static let perMonthKey: String = "plt.leave.daysPerMonth"
    static let maxKey: String = "plt.leave.maxPerPeriod"
    static let monthKey: String = "plt.leave.referenceStartMonth"
    static let alertKey: String = "plt.leave.alertDays"
    static let roundKey: String = "plt.leave.roundUp"

    /// Lit les surcharges. Une valeur illisible ou hors plage retombe sur le défaut.
    static func load(from defaults: UserDefaults) -> LeaveParameters {
        let unit: LeaveUnit = LeaveUnit(rawValue: defaults.string(forKey: unitKey) ?? "") ?? .ouvrable
        var p: LeaveParameters = LeaveParameters.defaults(unit: unit)
        if let v = defaults.object(forKey: perMonthKey) as? Double, v > 0, v <= 10 { p.daysPerMonth = v }
        if let v = defaults.object(forKey: maxKey) as? Double, v > 0, v <= 100 { p.maxPerPeriod = v }
        if let v = defaults.object(forKey: monthKey) as? Int, v >= 1, v <= 12 { p.referenceStartMonth = v }
        if let v = defaults.object(forKey: alertKey) as? Int, v >= 0, v <= 366 { p.alertDays = v }
        if let v = defaults.object(forKey: roundKey) as? Bool { p.roundUpToWholeDay = v }
        return p
    }

    /// Enregistre seulement ce qui diffère du défaut de l'unité choisie.
    func save(to defaults: UserDefaults) {
        let base: LeaveParameters = LeaveParameters.defaults(unit: unit)
        defaults.set(unit.rawValue, forKey: LeaveParameters.unitKey)
        if abs(daysPerMonth - base.daysPerMonth) > 1e-9 {
            defaults.set(daysPerMonth, forKey: LeaveParameters.perMonthKey)
        } else {
            defaults.removeObject(forKey: LeaveParameters.perMonthKey)
        }
        if abs(maxPerPeriod - base.maxPerPeriod) > 1e-9 {
            defaults.set(maxPerPeriod, forKey: LeaveParameters.maxKey)
        } else {
            defaults.removeObject(forKey: LeaveParameters.maxKey)
        }
        if referenceStartMonth != base.referenceStartMonth {
            defaults.set(referenceStartMonth, forKey: LeaveParameters.monthKey)
        } else {
            defaults.removeObject(forKey: LeaveParameters.monthKey)
        }
        if alertDays != base.alertDays {
            defaults.set(alertDays, forKey: LeaveParameters.alertKey)
        } else {
            defaults.removeObject(forKey: LeaveParameters.alertKey)
        }
        if roundUpToWholeDay != base.roundUpToWholeDay {
            defaults.set(roundUpToWholeDay, forKey: LeaveParameters.roundKey)
        } else {
            defaults.removeObject(forKey: LeaveParameters.roundKey)
        }
    }

    static func reset(in defaults: UserDefaults) {
        let keys: [String] = [unitKey, perMonthKey, maxKey, monthKey, alertKey, roundKey]
        for k in keys { defaults.removeObject(forKey: k) }
    }
}

/// Période de référence : premier et dernier jour inclus (début de journée).
struct LeavePeriod: Equatable {
    let start: Date
    let end: Date
}

/// Durée d'un contrat (fin nil = sans date de fin).
struct LeaveSpan: Equatable {
    let start: Date
    let end: Date?
}

/// Un congé à compter (jours calendaires entre start et end inclus).
struct LeaveRange: Equatable {
    let start: Date
    let end: Date
    let kind: LeaveKindChoice
}

enum LeaveIssue: Equatable {
    case endBeforeStart
    case overlapsOther
    case noContract
    case outsideContract

    var message: String {
        switch self {
        case .endBeforeStart: return "La fin doit être le même jour que le début, ou après."
        case .overlapsOther: return "Ces dates chevauchent un autre congé."
        case .noContract: return "Il n'y a aucun contrat pour cet employeur."
        case .outsideContract: return "Ces dates sortent de ton contrat."
        }
    }
}

struct LeaveRisk: Equatable {
    /// Jours acquis et non posés qui seraient perdus si rien ne change (estimation, règles de report à vérifier).
    let daysAtRisk: Double
    let expiryDate: Date
    let daysUntilExpiry: Int
    let isAlert: Bool
}

struct LeaveBalance: Equatable {
    let period: LeavePeriod
    let acquired: Double
    /// Jours déjà passés (jusqu'à aujourd'hui inclus).
    let taken: Double
    /// Jours posés après aujourd'hui.
    let planned: Double
    /// acquis - pris - prévus. Peut être négatif : jamais ramené à zéro en silence.
    let remaining: Double
    let risk: LeaveRisk

    var isOverdrawn: Bool { return remaining < -1e-9 }
    /// Dépassement positif, 0 sinon.
    var overdrawnBy: Double { return isOverdrawn ? -remaining : 0 }
}

enum LeaveRules {
    // MARK: Calendrier

    static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        return calendar.startOfDay(for: date)
    }

    static func addDays(_ n: Int, to date: Date, calendar: Calendar) -> Date {
        return calendar.date(byAdding: .day, value: n, to: date) ?? date
    }

    /// Jours calendaires de `from` à `to` (pas 86 400 s : changement d'heure sûr).
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        let a: Date = startOfDay(from, calendar: calendar)
        let b: Date = startOfDay(to, calendar: calendar)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Période de référence qui contient `date`. Section 23 : période de référence, début modifiable (défaut juin).
    static func referencePeriod(containing date: Date, startMonth: Int, calendar: Calendar) -> LeavePeriod {
        let month: Int = min(12, max(1, startMonth))
        let comps: DateComponents = calendar.dateComponents([.year, .month], from: date)
        let year: Int = comps.year ?? 2000
        let currentMonth: Int = comps.month ?? 1
        let startYear: Int = currentMonth >= month ? year : year - 1
        var s: DateComponents = DateComponents()
        s.year = startYear
        s.month = month
        s.day = 1
        let start: Date = calendar.startOfDay(for: calendar.date(from: s) ?? date)
        let nextStart: Date = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        let end: Date = addDays(-1, to: nextStart, calendar: calendar)
        return LeavePeriod(start: start, end: end)
    }

    static func isCounted(_ day: Date, unit: LeaveUnit, calendar: Calendar) -> Bool {
        let weekday: Int = calendar.component(.weekday, from: day)
        switch unit {
        case .ouvrable: return weekday != 1
        case .ouvre: return weekday != 1 && weekday != 7
        }
    }

    // MARK: Jours acquis

    private static func isCovered(_ day: Date, spans: [LeaveSpan], calendar: Calendar) -> Bool {
        for span in spans {
            let s: Date = startOfDay(span.start, calendar: calendar)
            if day < s { continue }
            if let e = span.end {
                if day <= startOfDay(e, calendar: calendar) { return true }
            } else {
                return true
            }
        }
        return false
    }

    /// Jours acquis sur la période, jusqu'à `asOf` inclus.
    /// Section 23 : "nombre de jours acquis par mois de travail effectif". Règle appliquée : chaque mois civil de la
    /// période vaut (jours couverts par un contrat / jours du mois) mois de travail ; total = somme x jours par mois,
    /// plafonné, puis arrondi au jour entier supérieur si demandé. Les périodes assimilées à du travail effectif
    /// (section 23 : "à renseigner") ne sont pas gérées : approximation à vérifier.
    static func acquiredDays(spans: [LeaveSpan], period: LeavePeriod, asOf: Date, params: LeaveParameters, calendar: Calendar) -> Double {
        let lastDay: Date = min(period.end, startOfDay(asOf, calendar: calendar))
        if lastDay < period.start { return 0 }
        let total: Int = daysBetween(period.start, lastDay, calendar: calendar)
        if total < 0 || total > 400 { return 0 }
        var covered: [Int: Int] = [:]
        var daysInMonth: [Int: Int] = [:]
        let startComps: DateComponents = calendar.dateComponents([.year, .month], from: period.start)
        let startIndex: Int = (startComps.year ?? 0) * 12 + (startComps.month ?? 1)
        var offset: Int = 0
        while offset <= total {
            let day: Date = addDays(offset, to: period.start, calendar: calendar)
            let c: DateComponents = calendar.dateComponents([.year, .month], from: day)
            let index: Int = (c.year ?? 0) * 12 + (c.month ?? 1) - startIndex
            if daysInMonth[index] == nil {
                let range: Range<Int>? = calendar.range(of: .day, in: .month, for: day)
                daysInMonth[index] = range?.count ?? 30
            }
            if isCovered(day, spans: spans, calendar: calendar) {
                covered[index] = (covered[index] ?? 0) + 1
            }
            offset += 1
        }
        var months: Double = 0
        for (index, count) in covered {
            let dim: Int = daysInMonth[index] ?? 30
            if dim > 0 { months += Double(count) / Double(dim) }
        }
        var days: Double = months * params.daysPerMonth
        if days > params.maxPerPeriod { days = params.maxPerPeriod }
        if params.roundUpToWholeDay {
            // L3141-7 : jour entier supérieur. La tolérance évite 7,0000000001 -> 8.
            days = (days - 1e-9).rounded(.up)
            if days <= 0 { days = 0 }
        }
        return days
    }

    // MARK: Jours pris

    /// Jours décomptés d'un congé, bornes incluses.
    /// Section 23 : unité "jours ouvrables ou ouvrés". Ouvrables = lundi au samedi, ouvrés = lundi au vendredi.
    /// Les jours fériés chômés ne sont pas retirés (calendrier des fériés absent) : à vérifier.
    static func countedDays(from start: Date, to end: Date, unit: LeaveUnit, calendar: Calendar) -> Int {
        let s: Date = startOfDay(start, calendar: calendar)
        let e: Date = startOfDay(end, calendar: calendar)
        if e < s { return 0 }
        let n: Int = daysBetween(s, e, calendar: calendar)
        if n > 3660 { return 0 }
        var count: Int = 0
        var offset: Int = 0
        while offset <= n {
            let day: Date = addDays(offset, to: s, calendar: calendar)
            if isCounted(day, unit: unit, calendar: calendar) { count += 1 }
            offset += 1
        }
        return count
    }

    /// Jours décomptés de la partie d'un congé comprise dans [from, to].
    static func countedDays(of range: LeaveRange, from: Date, to: Date, unit: LeaveUnit, calendar: Calendar) -> Int {
        let s: Date = max(startOfDay(range.start, calendar: calendar), startOfDay(from, calendar: calendar))
        let e: Date = min(startOfDay(range.end, calendar: calendar), startOfDay(to, calendar: calendar))
        return countedDays(from: s, to: e, unit: unit, calendar: calendar)
    }

    // MARK: Solde

    /// Solde à la date `asOf`. Seuls les congés payés consomment le solde. Pris = jours jusqu'à aujourd'hui inclus,
    /// prévus = jours après aujourd'hui, dans la période de référence de `asOf`.
    static func balance(spans: [LeaveSpan], ranges: [LeaveRange], asOf: Date, params: LeaveParameters, calendar: Calendar) -> LeaveBalance {
        let today: Date = startOfDay(asOf, calendar: calendar)
        let period: LeavePeriod = referencePeriod(containing: today, startMonth: params.referenceStartMonth, calendar: calendar)
        let acquired: Double = acquiredDays(spans: spans, period: period, asOf: today, params: params, calendar: calendar)
        let tomorrow: Date = addDays(1, to: today, calendar: calendar)
        var taken: Int = 0
        var planned: Int = 0
        for r in ranges where r.kind.consumesBalance {
            taken += countedDays(of: r, from: period.start, to: today, unit: params.unit, calendar: calendar)
            planned += countedDays(of: r, from: tomorrow, to: period.end, unit: params.unit, calendar: calendar)
        }
        let remaining: Double = acquired - Double(taken) - Double(planned)
        let until: Int = daysBetween(today, period.end, calendar: calendar)
        let atRisk: Double = max(0, remaining)
        let alert: Bool = atRisk > 1e-9 && until >= 0 && until <= params.alertDays
        let risk: LeaveRisk = LeaveRisk(daysAtRisk: atRisk, expiryDate: period.end, daysUntilExpiry: until, isAlert: alert)
        return LeaveBalance(period: period, acquired: acquired, taken: Double(taken), planned: Double(planned), remaining: remaining, risk: risk)
    }

    // MARK: Validation

    /// Section 23 : fin après début, pas de chevauchement avec un autre congé, congé dans le contrat.
    static func validate(start: Date, end: Date, others: [LeaveRange], spans: [LeaveSpan], calendar: Calendar) -> [LeaveIssue] {
        var issues: [LeaveIssue] = []
        let s: Date = startOfDay(start, calendar: calendar)
        let e: Date = startOfDay(end, calendar: calendar)
        if e < s {
            issues.append(.endBeforeStart)
            return issues
        }
        for o in others {
            let os: Date = startOfDay(o.start, calendar: calendar)
            let oe: Date = startOfDay(o.end, calendar: calendar)
            if s <= oe && os <= e {
                issues.append(.overlapsOther)
                break
            }
        }
        if spans.isEmpty {
            issues.append(.noContract)
        } else if !isCovered(s, spans: spans, calendar: calendar) || !isCovered(e, spans: spans, calendar: calendar) {
            issues.append(.outsideContract)
        }
        return issues
    }

    static func hasBlockingIssue(_ issues: [LeaveIssue]) -> Bool {
        return !issues.isEmpty
    }
}
