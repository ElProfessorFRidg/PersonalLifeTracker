import Foundation

// Moteur de règles de paie (sections 21, 22 et 26) et relevé d'heures (section 20.2). Logique pure : Foundation seulement.
// Tout est une ESTIMATION. Aucune valeur légale n'est écrite ici : les pourcentages, seuils et fenêtres viennent d'un pack
// (ConventionPack) ou de l'utilisateur. Argent : centimes entiers, calculs en Decimal.
//
// Choix de calcul (documentés dans notes/pay_step6.md) :
// - Une session est découpée aux minuits et aux bornes de la fenêtre de nuit. Chaque morceau est rangé dans UNE catégorie :
//   férié, dimanche, nuit ou normal. Si plusieurs règles s'appliquent, on prend la plus haute (ou la somme, au choix du pack).
// - Le dimanche et le férié se jugent sur le jour calendaire du morceau (minuit à minuit).
// - Les heures au-delà du seuil se comptent par semaine ISO (lundi à dimanche), dans l'ordre chronologique.
// - Majoration d'une ligne = secondes x taux horaire x pourcentage / 3600, arrondie au centime, une fois par ligne.

// MARK: - Catégories et résultats

enum PayCategory: String, CaseIterable, Equatable, Hashable {
    case normal
    case night
    case sunday
    case holiday

    var title: String {
        switch self {
        case .normal: return "Normales"
        case .night: return "Nuit"
        case .sunday: return "Dimanche"
        case .holiday: return "Jour férié"
        }
    }

    /// Ordre d'affichage et de priorité en cas d'égalité.
    var order: Int {
        switch self {
        case .holiday: return 0
        case .sunday: return 1
        case .night: return 2
        case .normal: return 3
        }
    }
}

/// Un intervalle travaillé, déjà ramené à la base retenue (exacte ou heures pleines).
struct PayInterval: Equatable {
    let id: UUID
    let start: Date
    let end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}

/// Un morceau d'intervalle qui reste dans un seul jour et une seule catégorie.
struct PaySegment: Equatable {
    let start: Date
    let end: Date
    let seconds: Int
    let category: PayCategory
    /// Pourcentage de majoration de la catégorie (0 si normal).
    let percent: Decimal
    /// Début du jour du morceau.
    let day: Date
}

/// Un morceau après découpe au seuil hebdomadaire.
struct PayPiece: Equatable {
    let day: Date
    let category: PayCategory
    /// Index de la tranche au-delà du seuil, nil si le morceau est avant le seuil.
    let band: Int?
    /// Pourcentage appliqué à ce morceau (catégorie et tranche combinées).
    let percent: Decimal
    let seconds: Int
    /// Taux horaire du jour, nil s'il n'y en avait pas encore.
    let hourlyGross: Decimal?
}

/// Une ligne de majoration du mois, pour l'écran et le relevé.
struct PayRuleLine: Equatable {
    let category: PayCategory
    let band: Int?
    let hourlyGross: Decimal
    let seconds: Int
    let percent: Decimal
    let majorationCents: Int
}

struct PayRulesResult: Equatable {
    let lines: [PayRuleLine]
    let pieces: [PayPiece]
    let segments: [PaySegment]
    let categorySeconds: [PayCategory: Int]
    /// Secondes au-delà du seuil hebdomadaire (en plus des catégories : sous-ensemble).
    let overtimeSeconds: Int
    let majorationCents: Int
    /// Secondes sans taux : pas de majoration chiffrée.
    let unratedSeconds: Int
    let totalSeconds: Int

    func seconds(_ category: PayCategory) -> Int { return categorySeconds[category] ?? 0 }

    static let empty: PayRulesResult = PayRulesResult(lines: [], pieces: [], segments: [], categorySeconds: [:],
                                                      overtimeSeconds: 0, majorationCents: 0, unratedSeconds: 0, totalSeconds: 0)
}

struct OvertimePiece: Equatable {
    let band: Int?
    let seconds: Int
}

// MARK: - Jours fériés

enum FrenchHolidays {
    /// Date de Pâques (calendrier grégorien), algorithme de Meeus, Jones et Butcher.
    static func easter(year: Int) -> (month: Int, day: Int) {
        let a: Int = year % 19
        let b: Int = year / 100
        let c: Int = year % 100
        let d: Int = b / 4
        let e: Int = b % 4
        let f: Int = (b + 8) / 25
        let g: Int = (b - f + 1) / 3
        let h: Int = (19 * a + b - d - g + 15) % 30
        let i: Int = c / 4
        let k: Int = c % 4
        let l: Int = (32 + 2 * e + 2 * i - h - k) % 7
        let m: Int = (a + 11 * h + 22 * l) / 451
        let month: Int = (h + l - 7 * m + 114) / 31
        let day: Int = ((h + l - 7 * m + 114) % 31) + 1
        return (month, day)
    }

    /// Les 11 jours fériés légaux de l'année, en clés mois x 100 + jour. Hors Alsace-Moselle.
    static func keys(year: Int, calendar: Calendar) -> Set<Int> {
        var keys: Set<Int> = [101, 501, 508, 714, 815, 1101, 1111, 1225]
        let e = easter(year: year)
        var comps = DateComponents()
        comps.year = year
        comps.month = e.month
        comps.day = e.day
        comps.hour = 12
        guard let easterDate = calendar.date(from: comps) else { return keys }
        let offsets: [Int] = [1, 39, 50]
        for offset in offsets {
            if let d = calendar.date(byAdding: .day, value: offset, to: easterDate) {
                let c: DateComponents = calendar.dateComponents([.month, .day], from: d)
                keys.insert((c.month ?? 0) * 100 + (c.day ?? 0))
            }
        }
        return keys
    }

    static func isHoliday(year: Int, month: Int, day: Int, scope: String, calendar: Calendar) -> Bool {
        if scope == PackHolidayRule.scopeMayFirstOnly { return month == 5 && day == 1 }
        return keys(year: year, calendar: calendar).contains(month * 100 + day)
    }
}

// MARK: - Primes (section 26)

enum PremiumKind: String, Codable, CaseIterable, Equatable {
    case panier
    case transport
    case treizieme
    case objectifs
    case repas
    case autre

    var title: String {
        switch self {
        case .panier: return "Panier"
        case .transport: return "Transport"
        case .treizieme: return "13e mois"
        case .objectifs: return "Objectifs"
        case .repas: return "Repas"
        case .autre: return "Autre"
        }
    }
}

enum PremiumAmountType: String, Codable, CaseIterable, Equatable {
    case fixed
    case percentOfGross

    var title: String {
        switch self {
        case .fixed: return "Montant fixe"
        case .percentOfGross: return "Pourcentage du brut"
        }
    }
}

enum PremiumFrequency: String, Codable, CaseIterable, Equatable {
    case perHour
    case perSession
    case perDay
    case monthly
    case annual
    case oneOff

    var title: String {
        switch self {
        case .perHour: return "Par heure"
        case .perSession: return "Par session"
        case .perDay: return "Par jour travaillé"
        case .monthly: return "Chaque mois"
        case .annual: return "Une fois par an"
        case .oneOff: return "Ponctuelle"
        }
    }

    /// Vrai si la condition (dimanche, soirée) a un sens pour cette fréquence.
    var supportsCondition: Bool {
        switch self {
        case .perHour, .perSession, .perDay: return true
        case .monthly, .annual, .oneOff: return false
        }
    }
}

enum PremiumBasis: String, Codable, CaseIterable, Equatable {
    case gross
    case net

    var title: String {
        switch self {
        case .gross: return "Brut"
        case .net: return "Net"
        }
    }
}

enum PremiumCondition: String, Codable, CaseIterable, Equatable {
    case none
    case sunday
    case evening

    var title: String {
        switch self {
        case .none: return "Aucune"
        case .sunday: return "Le dimanche"
        case .evening: return "En soirée"
        }
    }
}

/// Une prime saisie par l'utilisateur pour un employeur. Jamais proposée par un pack sans confirmation.
struct PayPremium: Codable, Equatable, Identifiable {
    var id: String
    /// uid de l'employeur en texte.
    var employerKey: String
    var name: String
    var kind: PremiumKind
    var amountType: PremiumAmountType
    /// Montant fixe en centimes (par heure, par session, par jour, par mois ou une fois selon la fréquence).
    var amountCents: Int
    /// Pourcentage du brut (si amountType = percentOfGross).
    var percent: Double
    var frequency: PremiumFrequency
    var basis: PremiumBasis
    /// Case indicative (section 26), sans effet sur le calcul.
    var subjectToContributions: Bool
    var condition: PremiumCondition
    /// Début de la soirée en minutes depuis minuit, saisi par l'utilisateur (condition "en soirée").
    var eveningStartMinute: Int?
    var startDate: Date?
    var endDate: Date?
    /// Date de la prime ponctuelle, ou mois de versement d'une prime annuelle.
    var anchorDate: Date?
    var note: String

    init(id: String = UUID().uuidString,
         employerKey: String,
         name: String,
         kind: PremiumKind = .autre,
         amountType: PremiumAmountType = .fixed,
         amountCents: Int = 0,
         percent: Double = 0,
         frequency: PremiumFrequency = .monthly,
         basis: PremiumBasis = .gross,
         subjectToContributions: Bool = true,
         condition: PremiumCondition = .none,
         eveningStartMinute: Int? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         anchorDate: Date? = nil,
         note: String = "") {
        self.id = id
        self.employerKey = employerKey
        self.name = name
        self.kind = kind
        self.amountType = amountType
        self.amountCents = amountCents
        self.percent = percent
        self.frequency = frequency
        self.basis = basis
        self.subjectToContributions = subjectToContributions
        self.condition = condition
        self.eveningStartMinute = eveningStartMinute
        self.startDate = startDate
        self.endDate = endDate
        self.anchorDate = anchorDate
        self.note = note
    }
}

struct PremiumLine: Equatable {
    let premiumID: String
    let name: String
    let kind: PremiumKind
    let basis: PremiumBasis
    let cents: Int
    let quantityText: String
}

struct PremiumNotCounted: Equatable {
    let premiumID: String
    let name: String
    let reason: String
}

struct PremiumsResult: Equatable {
    let lines: [PremiumLine]
    let notCounted: [PremiumNotCounted]
    /// Somme des primes brutes (ajoutées au brut).
    let grossCents: Int
    /// Somme des primes nettes (ajoutées au net seulement).
    let netCents: Int

    static let empty: PremiumsResult = PremiumsResult(lines: [], notCounted: [], grossCents: 0, netCents: 0)
}

// MARK: - Moteur

enum PayRules {

    // MARK: Semaine ISO

    static func isoCalendar(from calendar: Calendar) -> Calendar {
        var c: Calendar = calendar
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    /// Clé de semaine ISO : année de la semaine x 100 + numéro de semaine.
    static func weekKey(_ date: Date, calendar: Calendar) -> Int {
        let c: Calendar = isoCalendar(from: calendar)
        let comps: DateComponents = c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (comps.yearForWeekOfYear ?? 0) * 100 + (comps.weekOfYear ?? 0)
    }

    /// Début (lundi, minuit) de la semaine ISO qui contient `date`.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let c: Calendar = isoCalendar(from: calendar)
        if let interval = c.dateInterval(of: .weekOfYear, for: date) { return interval.start }
        return c.startOfDay(for: date)
    }

    // MARK: Pourcentages

    static func percentDecimal(_ value: Double) -> Decimal {
        return PayMath.decimal(value, digits: 2)
    }

    /// Lit un pourcentage saisi ("25", "12,5"). Refuse le vide, le négatif, les lettres, plus de 300.
    static func parsePercent(_ text: String) -> Double? {
        let cleaned: String = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if cleaned.isEmpty { return nil }
        guard let v = Double(cleaned) else { return nil }
        if !ConventionPackValidator.isValidPercent(v) { return nil }
        return v
    }

    // MARK: Classement

    /// Vrai si `secondOfDay` est dans la fenêtre de nuit (qui peut passer minuit). La borne de début est incluse, celle de fin exclue.
    static func isNight(secondOfDay: Int, startMinute: Int, endMinute: Int) -> Bool {
        let s: Int = startMinute * 60
        let e: Int = endMinute * 60
        if s == e { return false }
        if s < e { return secondOfDay >= s && secondOfDay < e }
        return secondOfDay >= s || secondOfDay < e
    }

    /// Catégorie et pourcentage de l'instant `date` (début d'un morceau, qui ne change plus jusqu'à sa fin).
    static func classify(at date: Date, rules: ConventionRules, calendar: Calendar) -> (category: PayCategory, percent: Decimal) {
        let comps: DateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: date)
        let secondOfDay: Int = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        var applicable: [(category: PayCategory, percent: Decimal)] = []
        if let h = rules.publicHoliday,
           FrenchHolidays.isHoliday(year: comps.year ?? 0, month: comps.month ?? 0, day: comps.day ?? 0, scope: h.scope, calendar: calendar) {
            applicable.append((category: PayCategory.holiday, percent: percentDecimal(h.percent)))
        }
        if let s = rules.sunday, comps.weekday == 1 {
            applicable.append((category: PayCategory.sunday, percent: percentDecimal(s.percent)))
        }
        if let n = rules.night, isNight(secondOfDay: secondOfDay, startMinute: n.startMinute, endMinute: n.endMinute) {
            applicable.append((category: PayCategory.night, percent: percentDecimal(n.percent)))
        }
        if applicable.isEmpty { return (PayCategory.normal, Decimal(0)) }
        var best: (category: PayCategory, percent: Decimal) = applicable[0]
        var sum: Decimal = applicable[0].percent
        if applicable.count > 1 {
            for i in 1..<applicable.count {
                sum += applicable[i].percent
                if applicable[i].percent > best.percent { best = applicable[i] }
            }
        }
        if rules.cumulationMode == .sum { return (applicable[0].category, sum) }
        return best
    }

    // MARK: Découpe

    /// Instants de coupe d'un intervalle : début, fin, chaque minuit et chaque borne de la fenêtre de nuit.
    static func cutDates(start: Date, end: Date, night: PackNightRule?, calendar: Calendar) -> [Date] {
        var cuts: [Date] = [start, end]
        var day: Date = calendar.startOfDay(for: start)
        var guardCount: Int = 0
        while day < end && guardCount < 400 {
            if day > start && day < end { cuts.append(day) }
            if let n = night {
                let minutes: [Int] = [n.startMinute, n.endMinute]
                for m in minutes {
                    if let d = calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day), d > start, d < end {
                        cuts.append(d)
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            guardCount += 1
        }
        cuts.sort { (a: Date, b: Date) -> Bool in a < b }
        var unique: [Date] = []
        for d in cuts {
            if let last = unique.last, last == d { continue }
            unique.append(d)
        }
        return unique
    }

    static func segments(of interval: PayInterval, rules: ConventionRules, calendar: Calendar) -> [PaySegment] {
        if interval.end <= interval.start { return [] }
        let cuts: [Date] = cutDates(start: interval.start, end: interval.end, night: rules.night, calendar: calendar)
        var out: [PaySegment] = []
        if cuts.count < 2 { return out }
        for i in 0..<(cuts.count - 1) {
            let a: Date = cuts[i]
            let b: Date = cuts[i + 1]
            let secs: Int = Int(b.timeIntervalSince(a).rounded())
            if secs <= 0 { continue }
            let c = classify(at: a, rules: rules, calendar: calendar)
            out.append(PaySegment(start: a, end: b, seconds: secs, category: c.category, percent: c.percent,
                                  day: calendar.startOfDay(for: a)))
        }
        return out
    }

    /// Découpe un morceau selon le seuil hebdomadaire. `weekSecondsBefore` = secondes déjà faites dans la semaine ISO.
    /// Seuil exactement atteint : pas d'heure au-delà. Une seconde de plus : la première tranche commence.
    static func overtimeSplit(weekSecondsBefore: Int, segmentSeconds: Int, rule: PackOvertimeRule?) -> [OvertimePiece] {
        guard let rule = rule, !rule.bands.isEmpty, rule.weeklyThresholdMinutes > 0 else {
            return [OvertimePiece(band: nil, seconds: segmentSeconds)]
        }
        let threshold: Int = rule.weeklyThresholdMinutes * 60
        var pos: Int = weekSecondsBefore
        var remaining: Int = segmentSeconds
        var out: [OvertimePiece] = []
        while remaining > 0 {
            var bandIndex: Int? = nil
            var room: Int = remaining
            if pos < threshold {
                room = threshold - pos
            } else {
                let over: Int = pos - threshold
                var bandStart: Int = 0
                var found: Bool = false
                for i in 0..<rule.bands.count {
                    if let limit = rule.bands[i].overMinutes {
                        let bandEnd: Int = bandStart + limit * 60
                        if over < bandEnd {
                            bandIndex = i
                            room = bandEnd - over
                            found = true
                            break
                        }
                        bandStart = bandEnd
                    } else {
                        bandIndex = i
                        room = remaining
                        found = true
                        break
                    }
                }
                if !found {
                    bandIndex = rule.bands.count - 1
                    room = remaining
                }
            }
            let take: Int = max(1, min(remaining, room))
            if let last = out.last, last.band == bandIndex {
                out[out.count - 1] = OvertimePiece(band: bandIndex, seconds: last.seconds + take)
            } else {
                out.append(OvertimePiece(band: bandIndex, seconds: take))
            }
            pos += take
            remaining -= take
        }
        return out
    }

    static func majorationCents(seconds: Int, hourlyGross: Decimal, percent: Decimal) -> Int {
        return PayMath.roundedCents(Decimal(seconds) * hourlyGross * percent / 100 / 3600)
    }

    private static func combinedPercent(category: Decimal, band: Decimal?, mode: RuleCumulation) -> Decimal {
        guard let b = band else { return category }
        switch mode {
        case .highest: return max(category, b)
        case .sum: return category + b
        }
    }

    /// Découpe et chiffre les majorations de la période [periodStart, periodEnd) (bornes à minuit).
    /// `intervals` doit contenir les semaines ISO entières qui touchent la période (début de semaine inclus), sinon les
    /// heures au-delà du seuil seraient sous-estimées. Les intervalles ne doivent pas se chevaucher.
    static func compute(intervals: [PayInterval],
                        periodStart: Date,
                        periodEnd: Date,
                        rules: ConventionRules,
                        rateOnDay: (Date) -> Decimal?,
                        calendar: Calendar) -> PayRulesResult {
        var all: [PaySegment] = []
        for iv in intervals {
            all.append(contentsOf: segments(of: iv, rules: rules, calendar: calendar))
        }
        all.sort { (a: PaySegment, b: PaySegment) -> Bool in a.start < b.start }

        let mode: RuleCumulation = rules.cumulationMode
        var weekTotals: [Int: Int] = [:]
        var inPeriod: [PaySegment] = []
        var pieces: [PayPiece] = []
        var lines: [PayRuleLine] = []
        var categorySeconds: [PayCategory: Int] = [:]
        var overtime: Int = 0
        var unrated: Int = 0
        var total: Int = 0

        for seg in all {
            let key: Int = weekKey(seg.start, calendar: calendar)
            let before: Int = weekTotals[key] ?? 0
            weekTotals[key] = before + seg.seconds
            if seg.start < periodStart || seg.start >= periodEnd { continue }
            inPeriod.append(seg)
            let split: [OvertimePiece] = overtimeSplit(weekSecondsBefore: before, segmentSeconds: seg.seconds, rule: rules.overtime)
            let rate: Decimal? = rateOnDay(seg.day)
            for p in split {
                var bandPercent: Decimal? = nil
                if let b = p.band, let o = rules.overtime, b < o.bands.count {
                    bandPercent = percentDecimal(o.bands[b].percent)
                }
                let percent: Decimal = combinedPercent(category: seg.percent, band: bandPercent, mode: mode)
                pieces.append(PayPiece(day: seg.day, category: seg.category, band: p.band, percent: percent,
                                       seconds: p.seconds, hourlyGross: rate))
                categorySeconds[seg.category] = (categorySeconds[seg.category] ?? 0) + p.seconds
                total += p.seconds
                if p.band != nil { overtime += p.seconds }
                guard let r = rate else {
                    unrated += p.seconds
                    continue
                }
                if percent <= 0 { continue }
                var merged: Bool = false
                for i in 0..<lines.count {
                    let l: PayRuleLine = lines[i]
                    if l.category == seg.category && l.band == p.band && l.hourlyGross == r && l.percent == percent {
                        lines[i] = PayRuleLine(category: l.category, band: l.band, hourlyGross: l.hourlyGross,
                                               seconds: l.seconds + p.seconds, percent: l.percent, majorationCents: 0)
                        merged = true
                        break
                    }
                }
                if !merged {
                    lines.append(PayRuleLine(category: seg.category, band: p.band, hourlyGross: r, seconds: p.seconds,
                                             percent: percent, majorationCents: 0))
                }
            }
        }

        var priced: [PayRuleLine] = []
        var majoration: Int = 0
        for l in lines {
            let cents: Int = majorationCents(seconds: l.seconds, hourlyGross: l.hourlyGross, percent: l.percent)
            priced.append(PayRuleLine(category: l.category, band: l.band, hourlyGross: l.hourlyGross,
                                      seconds: l.seconds, percent: l.percent, majorationCents: cents))
            majoration += cents
        }
        priced.sort { (a: PayRuleLine, b: PayRuleLine) -> Bool in
            if a.category.order != b.category.order { return a.category.order < b.category.order }
            let ba: Int = a.band ?? -1
            let bb: Int = b.band ?? -1
            if ba != bb { return ba < bb }
            return a.hourlyGross < b.hourlyGross
        }
        return PayRulesResult(lines: priced, pieces: pieces, segments: inPeriod, categorySeconds: categorySeconds,
                              overtimeSeconds: overtime, majorationCents: majoration, unratedSeconds: unrated, totalSeconds: total)
    }

    // MARK: Intervalles retenus

    /// Intervalles travaillés d'après la base retenue. Sessions non confirmées exclues. Session en cours : exact jusqu'à `now`.
    /// Heures pleines : bornes arrondies ou choisies ; une borne en doute sans choix retombe sur l'exact (comme DaySummary).
    /// `window` : ne garde que les sessions qui touchent cette fenêtre.
    static func retainedIntervals(sessions: [PaySessionInput],
                                  base: CalculationBase,
                                  now: Date,
                                  calendar: Calendar,
                                  window: (start: Date, end: Date)? = nil) -> [PayInterval] {
        var out: [PayInterval] = []
        for s in sessions {
            if !s.isConfirmed { continue }
            let rawEnd: Date = s.end ?? now
            if rawEnd <= s.start { continue }
            if let w = window, !(s.start < w.end && rawEnd > w.start) { continue }
            var start: Date = s.start
            var end: Date = rawEnd
            if base == .fullHours, s.end != nil {
                let rs: Date? = SessionDurations.resolvedBound(exact: s.start, chosen: s.chosenStart, calendar: calendar)
                let re: Date? = SessionDurations.resolvedBound(exact: rawEnd, chosen: s.chosenEnd, calendar: calendar)
                if let a = rs, let b = re, b > a {
                    start = a
                    end = b
                }
            }
            out.append(PayInterval(id: s.id, start: start, end: end))
        }
        out.sort { (a: PayInterval, b: PayInterval) -> Bool in a.start < b.start }
        return out
    }

    // MARK: Taux minimal

    /// Vrai si le taux saisi est sous le minimum de la convention (alerte, jamais un blocage).
    static func isBelowMinimum(hourlyGross: Decimal, rules: ConventionRules) -> Bool {
        guard let m = rules.minimumRate else { return false }
        return hourlyGross * 100 < Decimal(m.hourlyCents)
    }

    // MARK: Primes

    private static func eveningInstant(day: Date, minute: Int, calendar: Calendar) -> Date? {
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }

    private static func isActive(_ p: PayPremium, day: Date, calendar: Calendar) -> Bool {
        let d: Date = calendar.startOfDay(for: day)
        if let s = p.startDate, d < calendar.startOfDay(for: s) { return false }
        if let e = p.endDate, d > calendar.startOfDay(for: e) { return false }
        return true
    }

    private static func overlapsPeriod(_ p: PayPremium, periodStart: Date, periodEnd: Date, calendar: Calendar) -> Bool {
        if let s = p.startDate, calendar.startOfDay(for: s) >= periodEnd { return false }
        if let e = p.endDate, calendar.startOfDay(for: e) < periodStart { return false }
        return true
    }

    private static func isSunday(_ date: Date, calendar: Calendar) -> Bool {
        return calendar.component(.weekday, from: date) == 1
    }

    private static func plural(_ n: Int, _ one: String, _ many: String) -> String {
        return n == 1 ? "1 \(one)" : "\(n) \(many)"
    }

    /// Chiffre les primes d'une période. `grossBaseCents` = brut de base plus majorations (pour les primes en pourcentage).
    /// Une prime dont la condition ne peut pas être vérifiée n'est pas comptée et le dit (`notCounted`).
    static func premiums(_ list: [PayPremium],
                         periodStart: Date,
                         periodEnd: Date,
                         intervals: [PayInterval],
                         segments: [PaySegment],
                         grossBaseCents: Int,
                         calendar: Calendar) -> PremiumsResult {
        var lines: [PremiumLine] = []
        var skipped: [PremiumNotCounted] = []
        var gross: Int = 0
        var net: Int = 0

        for p in list {
            if !overlapsPeriod(p, periodStart: periodStart, periodEnd: periodEnd, calendar: calendar) { continue }
            var cents: Int = 0
            var quantity: String = ""
            var counted: Bool = true

            if p.amountType == .percentOfGross && p.frequency.supportsCondition {
                skipped.append(PremiumNotCounted(premiumID: p.id, name: p.name,
                                                 reason: "Un pourcentage du brut ne s'applique pas par heure, session ou jour."))
                continue
            }
            let conditionApplies: Bool = p.frequency.supportsCondition && p.condition != .none
            if conditionApplies && p.condition == .evening && p.eveningStartMinute == nil {
                skipped.append(PremiumNotCounted(premiumID: p.id, name: p.name,
                                                 reason: "Dis à quelle heure commence la soirée pour que je compte cette prime."))
                continue
            }
            let eveningMinute: Int = p.eveningStartMinute ?? 0

            switch p.frequency {
            case .perHour:
                var secs: Int = 0
                for seg in segments {
                    if seg.start < periodStart || seg.start >= periodEnd { continue }
                    if !isActive(p, day: seg.day, calendar: calendar) { continue }
                    switch p.condition {
                    case .none:
                        secs += seg.seconds
                    case .sunday:
                        if isSunday(seg.start, calendar: calendar) { secs += seg.seconds }
                    case .evening:
                        if let from = eveningInstant(day: seg.day, minute: eveningMinute, calendar: calendar) {
                            let a: Date = max(seg.start, from)
                            if seg.end > a { secs += Int(seg.end.timeIntervalSince(a).rounded()) }
                        }
                    }
                }
                cents = PayMath.roundedCents(Decimal(secs) * Decimal(p.amountCents) / 360000)
                quantity = Formatting.duration(seconds: secs)
                counted = secs > 0
            case .perSession:
                var count: Int = 0
                for iv in intervals {
                    if iv.start < periodStart || iv.start >= periodEnd { continue }
                    let day: Date = calendar.startOfDay(for: iv.start)
                    if !isActive(p, day: day, calendar: calendar) { continue }
                    switch p.condition {
                    case .none:
                        count += 1
                    case .sunday:
                        if isSunday(iv.start, calendar: calendar) { count += 1 }
                    case .evening:
                        if let from = eveningInstant(day: day, minute: eveningMinute, calendar: calendar), iv.end > from { count += 1 }
                    }
                }
                cents = count * p.amountCents
                quantity = plural(count, "session", "sessions")
                counted = count > 0
            case .perDay:
                var days: [Date] = []
                for seg in segments {
                    if seg.start < periodStart || seg.start >= periodEnd { continue }
                    if !isActive(p, day: seg.day, calendar: calendar) { continue }
                    var matches: Bool = false
                    switch p.condition {
                    case .none:
                        matches = true
                    case .sunday:
                        matches = isSunday(seg.start, calendar: calendar)
                    case .evening:
                        if let from = eveningInstant(day: seg.day, minute: eveningMinute, calendar: calendar) {
                            matches = seg.end > from
                        }
                    }
                    if matches && !days.contains(seg.day) { days.append(seg.day) }
                }
                cents = days.count * p.amountCents
                quantity = plural(days.count, "jour", "jours")
                counted = !days.isEmpty
            case .monthly:
                cents = flatAmount(p, grossBaseCents: grossBaseCents)
                quantity = "1 mois"
            case .annual:
                guard let anchor = p.anchorDate else {
                    skipped.append(PremiumNotCounted(premiumID: p.id, name: p.name, reason: "Choisis le mois de versement de cette prime annuelle."))
                    continue
                }
                let a: DateComponents = calendar.dateComponents([.month], from: anchor)
                let m: DateComponents = calendar.dateComponents([.month], from: periodStart)
                if a.month != m.month { continue }
                cents = flatAmount(p, grossBaseCents: grossBaseCents)
                quantity = "1 fois"
            case .oneOff:
                guard let anchor = p.anchorDate else {
                    skipped.append(PremiumNotCounted(premiumID: p.id, name: p.name, reason: "Choisis la date de cette prime ponctuelle."))
                    continue
                }
                if anchor < periodStart || anchor >= periodEnd { continue }
                cents = flatAmount(p, grossBaseCents: grossBaseCents)
                quantity = "1 fois"
            }

            if !counted { continue }
            lines.append(PremiumLine(premiumID: p.id, name: p.name, kind: p.kind, basis: p.basis, cents: cents, quantityText: quantity))
            switch p.basis {
            case .gross: gross += cents
            case .net: net += cents
            }
        }
        return PremiumsResult(lines: lines, notCounted: skipped, grossCents: gross, netCents: net)
    }

    private static func flatAmount(_ p: PayPremium, grossBaseCents: Int) -> Int {
        switch p.amountType {
        case .fixed:
            return p.amountCents
        case .percentOfGross:
            return PayMath.roundedCents(Decimal(grossBaseCents) * percentDecimal(p.percent) / 10000)
        }
    }
}

// MARK: - Relevé d'heures (section 20.2)

struct StatementSession: Equatable {
    let exactStart: Date
    /// nil = session en cours.
    let exactEnd: Date?
    /// Bornes retenues (arrondi ou choix), nil si en doute sans choix ou en base exacte sans différence utile.
    let retainedStart: Date?
    let retainedEnd: Date?
    let isLive: Bool
    let hasDoubt: Bool
}

struct StatementDay: Equatable {
    let day: Date
    let sessions: [StatementSession]
    let categorySeconds: [PayCategory: Int]
    let overtimeSeconds: Int
    let totalSeconds: Int

    func seconds(_ category: PayCategory) -> Int { return categorySeconds[category] ?? 0 }
}

struct HoursStatement: Equatable {
    let year: Int
    let month: Int
    let base: CalculationBase
    let days: [StatementDay]
    let categoryTotals: [PayCategory: Int]
    let overtimeSeconds: Int
    let totalSeconds: Int
    let sessionCount: Int
    let doubtSessionCount: Int
    let liveSessionCount: Int
    let unconfirmedSessionCount: Int
    let employerName: String
    let packName: String

    func total(_ category: PayCategory) -> Int { return categoryTotals[category] ?? 0 }
}

enum HoursStatementBuilder {
    static let monthNames: [String] = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
                                       "août", "septembre", "octobre", "novembre", "décembre"]
    static let disclaimer: String = "Estimation d'après les sessions de l'app. La fiche de paie fait foi. Les majorations dépendent des règles de ta convention, à vérifier avec ta convention ou ta fiche de paie."

    static func monthTitle(year: Int, month: Int) -> String {
        let name: String = (month >= 1 && month <= 12) ? monthNames[month - 1] : "?"
        return "\(name) \(year)"
    }

    static func build(year: Int,
                      month: Int,
                      sessions: [PaySessionInput],
                      base: CalculationBase,
                      rules: ConventionRules,
                      employerName: String,
                      packName: String,
                      now: Date,
                      calendar: Calendar) -> HoursStatement {
        let empty = HoursStatement(year: year, month: month, base: base, days: [], categoryTotals: [:], overtimeSeconds: 0,
                                   totalSeconds: 0, sessionCount: 0, doubtSessionCount: 0, liveSessionCount: 0,
                                   unconfirmedSessionCount: 0, employerName: employerName, packName: packName)
        guard let bounds = PayCalculator.monthBounds(year: year, month: month, calendar: calendar) else { return empty }
        let weekStart: Date = PayRules.weekStart(of: bounds.start, calendar: calendar)
        let intervals: [PayInterval] = PayRules.retainedIntervals(sessions: sessions, base: base, now: now, calendar: calendar,
                                                                  window: (start: weekStart, end: bounds.end))
        let result: PayRulesResult = PayRules.compute(intervals: intervals, periodStart: bounds.start, periodEnd: bounds.end,
                                                      rules: rules,
                                                      rateOnDay: { (_: Date) -> Decimal? in nil },
                                                      calendar: calendar)

        var dayKeys: [Date] = []
        var catByDay: [Date: [PayCategory: Int]] = [:]
        var overtimeByDay: [Date: Int] = [:]
        var totalByDay: [Date: Int] = [:]
        for piece in result.pieces {
            if !dayKeys.contains(piece.day) { dayKeys.append(piece.day) }
            var cats: [PayCategory: Int] = catByDay[piece.day] ?? [:]
            cats[piece.category] = (cats[piece.category] ?? 0) + piece.seconds
            catByDay[piece.day] = cats
            totalByDay[piece.day] = (totalByDay[piece.day] ?? 0) + piece.seconds
            if piece.band != nil { overtimeByDay[piece.day] = (overtimeByDay[piece.day] ?? 0) + piece.seconds }
        }

        var sessionsByDay: [Date: [StatementSession]] = [:]
        var sessionCount: Int = 0
        var doubtCount: Int = 0
        var liveCount: Int = 0
        var unconfirmed: Int = 0
        let ordered: [PaySessionInput] = sessions.sorted { (a: PaySessionInput, b: PaySessionInput) -> Bool in a.start < b.start }
        for s in ordered {
            let rawEnd: Date = s.end ?? now
            if rawEnd <= s.start { continue }
            if !(s.start < bounds.end && rawEnd > bounds.start) { continue }
            if !s.isConfirmed {
                unconfirmed += 1
                continue
            }
            sessionCount += 1
            let live: Bool = s.end == nil
            if live { liveCount += 1 }
            let doubt: Bool = !live && SessionDurations.hasUnresolvedDoubt(start: s.start, end: s.end, chosenStart: s.chosenStart,
                                                                        chosenEnd: s.chosenEnd, calendar: calendar)
            if doubt && base == .fullHours { doubtCount += 1 }
            if s.start < bounds.start { continue }
            var rs: Date? = s.start
            var re: Date? = s.end
            if base == .fullHours && !live {
                rs = SessionDurations.resolvedBound(exact: s.start, chosen: s.chosenStart, calendar: calendar)
                re = SessionDurations.resolvedBound(exact: rawEnd, chosen: s.chosenEnd, calendar: calendar)
            }
            let row = StatementSession(exactStart: s.start, exactEnd: s.end, retainedStart: rs, retainedEnd: re,
                                       isLive: live, hasDoubt: doubt)
            let dayStart: Date = calendar.startOfDay(for: s.start)
            if !dayKeys.contains(dayStart) { dayKeys.append(dayStart) }
            var list: [StatementSession] = sessionsByDay[dayStart] ?? []
            list.append(row)
            sessionsByDay[dayStart] = list
        }

        dayKeys.sort { (a: Date, b: Date) -> Bool in a < b }
        var days: [StatementDay] = []
        for d in dayKeys {
            days.append(StatementDay(day: d, sessions: sessionsByDay[d] ?? [], categorySeconds: catByDay[d] ?? [:],
                                     overtimeSeconds: overtimeByDay[d] ?? 0, totalSeconds: totalByDay[d] ?? 0))
        }
        return HoursStatement(year: year, month: month, base: base, days: days, categoryTotals: result.categorySeconds,
                              overtimeSeconds: result.overtimeSeconds, totalSeconds: result.totalSeconds,
                              sessionCount: sessionCount, doubtSessionCount: doubtCount, liveSessionCount: liveCount,
                              unconfirmedSessionCount: unconfirmed, employerName: employerName, packName: packName)
    }

    // MARK: Texte

    private static func range(_ start: Date?, _ end: Date?, calendar: Calendar, live: Bool) -> String {
        guard let s = start else { return "à choisir" }
        let a: String = Formatting.clock(s, calendar: calendar)
        if live { return a + " à en cours" }
        guard let e = end else { return a + " à ?" }
        return a + " à " + Formatting.clock(e, calendar: calendar)
    }

    private static func sessionsText(_ day: StatementDay, calendar: Calendar) -> String {
        var parts: [String] = []
        for s in day.sessions {
            var text: String = range(s.exactStart, s.exactEnd, calendar: calendar, live: s.isLive)
            if !s.isLive {
                let retained: String = range(s.retainedStart, s.retainedEnd, calendar: calendar, live: false)
                if retained != text { text += " (retenu " + retained + ")" }
            }
            if s.hasDoubt { text += " (borne à confirmer)" }
            parts.append(text)
        }
        if parts.isEmpty { return "suite de la veille" }
        return parts.joined(separator: " ; ")
    }

    /// Texte à partager : une ligne par jour, les catégories non nulles, puis les totaux.
    static func text(_ st: HoursStatement, calendar: Calendar) -> String {
        var lines: [String] = []
        lines.append("Relevé d'heures, " + monthTitle(year: st.year, month: st.month))
        lines.append("ESTIMATION. " + disclaimer)
        if !st.employerName.isEmpty { lines.append("Employeur : " + st.employerName) }
        lines.append("Règles : " + st.packName)
        lines.append("Base de calcul : " + st.base.title)
        lines.append("")
        for d in st.days {
            var line: String = Formatting.dayTitle(d.day, calendar: calendar) + " : " + sessionsText(d, calendar: calendar)
            line += ". Total " + Formatting.duration(seconds: d.totalSeconds)
            var extras: [String] = []
            for c in PayCategory.allCases where c != .normal && d.seconds(c) > 0 {
                extras.append(c.title.lowercased() + " " + Formatting.duration(seconds: d.seconds(c)))
            }
            if d.overtimeSeconds > 0 { extras.append("au-delà du seuil " + Formatting.duration(seconds: d.overtimeSeconds)) }
            if !extras.isEmpty { line += " (" + extras.joined(separator: ", ") + ")" }
            lines.append(line)
        }
        lines.append("")
        lines.append("Total du mois : " + Formatting.duration(seconds: st.totalSeconds))
        for c in PayCategory.allCases {
            let s: Int = st.total(c)
            if c == .normal || s > 0 { lines.append(c.title + " : " + Formatting.duration(seconds: s)) }
        }
        if st.overtimeSeconds > 0 { lines.append("Dont au-delà du seuil hebdomadaire : " + Formatting.duration(seconds: st.overtimeSeconds)) }
        if st.doubtSessionCount > 0 { lines.append("\(st.doubtSessionCount) session(s) avec une borne à confirmer, comptée(s) en exact.") }
        if st.liveSessionCount > 0 { lines.append("Une session en cours est comptée jusqu'à l'export.") }
        if st.unconfirmedSessionCount > 0 { lines.append("\(st.unconfirmedSessionCount) session(s) à confirmer ne sont pas comptées.") }
        return lines.joined(separator: "\n")
    }

    // MARK: CSV

    /// CSV du relevé : séparateur ";", virgule décimale, fins de ligne CRLF, heures en décimal (7,50 = 7 h 30).
    static func csv(_ st: HoursStatement, calendar: Calendar) -> String {
        let sep: String = PayExport.csvSeparator
        let eol: String = PayExport.csvLineBreak
        func row(_ fields: [String]) -> String {
            var escaped: [String] = []
            for f in fields { escaped.append(PayExport.csvField(f)) }
            return escaped.joined(separator: sep)
        }
        var rows: [String] = []
        rows.append(row(["Relevé d'heures", monthTitle(year: st.year, month: st.month)]))
        rows.append(row(["ESTIMATION", disclaimer]))
        rows.append(row(["Employeur", st.employerName]))
        rows.append(row(["Règles", st.packName]))
        rows.append(row(["Base de calcul", st.base.title]))
        rows.append("")
        let header: [String] = ["Jour", "Sessions (heures exactes, retenues entre parenthèses)", "Heures normales", "Heures de nuit",
                                "Heures du dimanche", "Heures de jour férié", "Dont au-delà du seuil", "Total"]
        rows.append(row(header))
        for d in st.days {
            let fields: [String] = [PayExport.dayKey(d.day, calendar: calendar),
                                    sessionsText(d, calendar: calendar),
                                    PayExport.hoursText(seconds: d.seconds(.normal)),
                                    PayExport.hoursText(seconds: d.seconds(.night)),
                                    PayExport.hoursText(seconds: d.seconds(.sunday)),
                                    PayExport.hoursText(seconds: d.seconds(.holiday)),
                                    PayExport.hoursText(seconds: d.overtimeSeconds),
                                    PayExport.hoursText(seconds: d.totalSeconds)]
            rows.append(row(fields))
        }
        let totals: [String] = ["Total", "",
                                PayExport.hoursText(seconds: st.total(.normal)),
                                PayExport.hoursText(seconds: st.total(.night)),
                                PayExport.hoursText(seconds: st.total(.sunday)),
                                PayExport.hoursText(seconds: st.total(.holiday)),
                                PayExport.hoursText(seconds: st.overtimeSeconds),
                                PayExport.hoursText(seconds: st.totalSeconds)]
        rows.append(row(totals))
        return rows.joined(separator: eol) + eol
    }
}

// MARK: - Lecture de saisies

extension PayRules {
    /// Montant en euros saisi ("5", "5,50", "1 250,5") vers des centimes. Refuse le vide, zéro, le négatif, les lettres,
    /// plus de 2 décimales et plus de 100 000 euros.
    static func parseMoneyCents(_ text: String) -> Int? {
        var cleaned: String = ""
        for ch in text {
            if ch == " " || ch == "\u{00A0}" || ch == "\u{202F}" { continue }
            cleaned.append(ch == "," ? "." : ch)
        }
        if cleaned.isEmpty { return nil }
        var dots: Int = 0
        var digits: Int = 0
        var afterDot: Int = 0
        for ch in cleaned {
            if ch == "." {
                dots += 1
            } else if ch.isASCII && ch.isNumber {
                digits += 1
                if dots > 0 { afterDot += 1 }
            } else {
                return nil
            }
        }
        if dots > 1 || digits == 0 || afterDot > 2 { return nil }
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        if value <= 0 || value > 100_000 { return nil }
        return PayMath.roundedCents(value)
    }

    /// Heures saisies ("35", "7,5") vers des minutes entières. Refuse zéro, le négatif, les lettres et plus de 168 h.
    static func parseHoursToMinutes(_ text: String) -> Int? {
        let cleaned: String = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if cleaned.isEmpty { return nil }
        guard let h = Double(cleaned) else { return nil }
        if h.isNaN || h.isInfinite || h <= 0 || h > 168 { return nil }
        return Int((h * 60).rounded())
    }
}
