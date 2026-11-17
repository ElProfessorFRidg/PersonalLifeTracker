import Foundation

// Calcul de paie du module `pay` (étape 5, base). Logique pure : Foundation seulement, aucune dépendance SwiftUI ni SwiftData.
// Tout est une ESTIMATION (section 20.2 : "Chaque montant précise que c'est indicatif"). La fiche de paie fait foi.
// Argent : taux en Decimal, montants en centimes entiers (Int). Jamais de Double dans un calcul de montant.

/// Un taux horaire brut et sa date d'effet (section 69 : "chaque changement de taux est enregistré avec sa date d'effet").
struct PayRateEntry: Equatable {
    let effectiveDate: Date
    let hourlyGross: Decimal
}

/// Une session de taf vue par la paie : uniquement des valeurs simples.
struct PaySessionInput: Equatable {
    let id: UUID
    let start: Date
    /// nil = session en cours.
    let end: Date?
    let chosenStart: Date?
    let chosenEnd: Date?
    /// Faux pour une session détectée pas encore confirmée : exclue des totaux et comptée à part.
    let isConfirmed: Bool

    init(id: UUID = UUID(), start: Date, end: Date?, chosenStart: Date? = nil, chosenEnd: Date? = nil, isConfirmed: Bool = true) {
        self.id = id
        self.start = start
        self.end = end
        self.chosenStart = chosenStart
        self.chosenEnd = chosenEnd
        self.isConfirmed = isConfirmed
    }
}

/// Heures et montant d'un taux sur le mois.
struct PayRateLine: Equatable {
    let hourlyGross: Decimal
    let seconds: Int
    /// Brut estimé de cette ligne, arrondi au centime (arrondi commercial, moitié vers le haut).
    let grossCents: Int
}

/// Une journée du mois qui contient au moins une session de taf.
struct PayDayLine: Equatable {
    /// Début de la journée dans le calendrier utilisé.
    let day: Date
    let sessionCount: Int
    let exactSeconds: Int
    let fullHoursSeconds: Int
    /// Secondes selon la base choisie.
    let retainedSeconds: Int
    /// Base heures pleines : une borne en zone de doute sans choix, comptée en exact.
    let isProvisional: Bool
    let hasLive: Bool
    /// Taux appliqué ce jour-là, nil s'il n'y en avait pas encore.
    let hourlyGross: Decimal?
}

/// Résultat d'un mois.
struct PayMonthResult: Equatable {
    let year: Int
    let month: Int
    let base: CalculationBase
    /// Secondes selon la base choisie (les trois totaux restent consultables).
    let retainedSeconds: Int
    let exactSeconds: Int
    let fullHoursSeconds: Int
    /// Secondes retenues d'avant le premier taux saisi : comptées en heures, jamais payées dans l'estimation.
    let unratedSeconds: Int
    let grossCents: Int
    let netCents: Int
    let netRatio: Decimal
    /// Sessions confirmées qui touchent le mois.
    let sessionCount: Int
    /// Sessions finies dont une borne est en zone de doute sans choix (base heures pleines seulement) : comptées en exact.
    let doubtSessionCount: Int
    let liveSessionCount: Int
    /// Sessions non confirmées qui touchent le mois : exclues des totaux.
    let unconfirmedSessionCount: Int
    let rateLines: [PayRateLine]
    let days: [PayDayLine]

    var hasAnySession: Bool { return sessionCount > 0 }
    var hasRate: Bool { return !rateLines.isEmpty }
}

/// Un créneau prévu (section 25). Vide pour l'instant : le planning arrive à l'étape 7.
struct PlannedSlot: Equatable {
    let start: Date
    let end: Date
}

/// Prévu contre réel pour une journée.
struct PlannedDayComparison: Equatable {
    let day: Date
    let plannedSeconds: Int
    let realSeconds: Int
    /// Réel moins prévu : positif = tu as fait plus que prévu.
    var differenceSeconds: Int { return realSeconds - plannedSeconds }
}

/// Arrondis et conversions d'argent sans surprise binaire.
enum PayMath {
    /// Double (saisie ou stockage SwiftData) vers Decimal, arrondi à `digits` décimales par le texte.
    /// Decimal(0.79) peut donner 0.79000000000000003553 : on passe par une chaîne de 4 décimales.
    static func decimal(_ value: Double, digits: Int = 4) -> Decimal {
        let text: String = String(format: "%.\(max(0, digits))f", value)
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    /// Double pour le stockage (PayRate.hourlyGross est un Double) ou l'affichage.
    static func double(_ value: Decimal) -> Double {
        return NSDecimalNumber(decimal: value).doubleValue
    }

    /// Montant en unités (euros) vers centimes entiers, arrondi commercial (0,005 donne 1 centime).
    static func roundedCents(_ amount: Decimal) -> Int {
        var scaled: Decimal = amount * 100
        var result: Decimal = Decimal()
        NSDecimalRound(&result, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: result).intValue
    }

    /// Centimes vers Double pour AppSettings.formatMoney (qui arrondit au centime).
    static func units(fromCents cents: Int) -> Double {
        return Double(cents) / 100.0
    }
}

/// Réglages de la paie, stockés dans UserDefaults (clés partagées avec @AppStorage dans les vues).
enum PayPreferences {
    enum Key {
        static let netRatio: String = "plt.pay.netRatio"
        /// Taux SMIC choisi par l'utilisateur ; 0 = pas de surcharge.
        static let smicOverride: String = "plt.pay.smicOverride"
        static let hideAmounts: String = "plt.pay.hideAmounts"
    }

    /// Section 20.1 : "défaut indicatif autour de 0,79 pour un salarié non cadre, modifiable".
    static let defaultNetRatio: Double = 0.79
    static let minNetRatio: Double = 0.50
    static let maxNetRatio: Double = 1.00

    static func clampedRatio(_ value: Double) -> Double {
        if value.isNaN { return defaultNetRatio }
        return min(maxNetRatio, max(minNetRatio, value))
    }

    static func netRatio(defaults: UserDefaults) -> Double {
        guard defaults.object(forKey: Key.netRatio) != nil else { return defaultNetRatio }
        return clampedRatio(defaults.double(forKey: Key.netRatio))
    }

    static func smicOverride(defaults: UserDefaults) -> Double? {
        let v: Double = defaults.double(forKey: Key.smicOverride)
        return v > 0 ? v : nil
    }
}

/// Le SMIC horaire brut. C'est une DONNÉE qui change (revalorisation au 1er janvier, parfois en cours d'année).
/// Un seul endroit dans le code, avec sa date d'effet. L'utilisateur peut le surcharger. Jamais présenté comme certain.
/// Divergence avec la section 20.1 (valeur dans Resources/reference/legal.json) : voir notes/pay.md.
enum SmicReference {
    /// SMIC horaire brut en centimes d'euro : 12,02 EUR. NON VÉRIFIÉ par l'app auprès d'une source officielle.
    static let hourlyGrossCents: Int = 1202
    /// Date d'effet de cette valeur : 1er janvier 2026.
    static let effectiveYear: Int = 2026
    static let effectiveMonth: Int = 1
    static let effectiveDay: Int = 1
    static let sourceName: String = "service-public.fr"
    /// Date de dernière vérification officielle : aucune pour l'instant (nil = jamais vérifié par l'app).
    static let checkedYear: Int? = nil

    static var hourlyGross: Decimal { return Decimal(hourlyGrossCents) / 100 }

    static func effectiveDate(calendar: Calendar) -> Date {
        var c = DateComponents()
        c.year = effectiveYear
        c.month = effectiveMonth
        c.day = effectiveDay
        return calendar.startOfDay(for: calendar.date(from: c) ?? Date(timeIntervalSince1970: 0))
    }

    /// Valeur à utiliser : la surcharge de l'utilisateur si elle existe, sinon la valeur de l'app.
    static func resolved(overrideValue: Double?) -> (hourlyGross: Decimal, isOverride: Bool) {
        if let v = overrideValue, v > 0 {
            return (PayMath.decimal(v), true)
        }
        return (hourlyGross, false)
    }

    /// Vrai si la valeur de l'app a plus de 6 mois depuis sa date d'effet (section 20.1 : inviter à vérifier).
    static func isOlderThanSixMonths(now: Date, calendar: Calendar) -> Bool {
        let from: Date = effectiveDate(calendar: calendar)
        guard let limit = calendar.date(byAdding: .month, value: 6, to: from) else { return false }
        return now >= limit
    }
}

enum PayCalculator {

    // MARK: Saisie

    /// Lit un taux saisi : "12,02" ou "12.02". Refuse le vide, zéro, le négatif, les lettres, plus de 4 décimales,
    /// et tout taux de 1000 ou plus (probablement une erreur d'unité).
    static func parseAmount(_ text: String) -> Decimal? {
        var cleaned: String = ""
        for ch in text {
            if ch == " " || ch == "\u{00A0}" || ch == "\u{202F}" { continue }
            cleaned.append(ch == "," ? "." : ch)
        }
        if cleaned.isEmpty { return nil }
        var dotCount: Int = 0
        var digitsAfterDot: Int = 0
        var digitCount: Int = 0
        for ch in cleaned {
            if ch == "." {
                dotCount += 1
            } else if ch.isASCII && ch.isNumber {
                digitCount += 1
                if dotCount > 0 { digitsAfterDot += 1 }
            } else {
                return nil
            }
        }
        if dotCount > 1 || digitCount == 0 || digitsAfterDot > 4 { return nil }
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        if value <= 0 || value >= 1000 { return nil }
        return value
    }

    /// Net vers brut avec le ratio net sur brut (section 20.1 : conversion dans les deux sens). Arrondi à 4 décimales.
    static func grossFromNet(net: Decimal, ratio: Decimal) -> Decimal {
        if ratio <= 0 { return net }
        return rounded(net / ratio, scale: 4)
    }

    /// Brut vers net avec le ratio. Arrondi à 4 décimales.
    static func netFromGross(gross: Decimal, ratio: Decimal) -> Decimal {
        return rounded(gross * ratio, scale: 4)
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var v: Decimal = value
        var r: Decimal = Decimal()
        NSDecimalRound(&r, &v, scale, .plain)
        return r
    }

    /// Évolution en pourcentage entre deux taux, arrondie à 1 décimale (section 69). nil si l'ancien taux n'est pas positif.
    static func percentChange(from old: Decimal, to new: Decimal) -> Decimal? {
        if old <= 0 { return nil }
        return rounded((new - old) / old * 100, scale: 1)
    }

    /// Date d'effet proposée pour "Je suis au SMIC" : la plus tardive entre le début du contrat et la date d'effet du SMIC.
    /// Avant cette date, la valeur actuelle du SMIC serait fausse : on ne l'applique pas rétroactivement (section 69).
    static func smicEffectiveDate(contractStart: Date, calendar: Calendar) -> Date {
        return max(calendar.startOfDay(for: contractStart), SmicReference.effectiveDate(calendar: calendar))
    }

    // MARK: Taux à une date

    /// Taux en vigueur le jour `day` : le plus récent dont la date d'effet est le jour même ou avant. nil s'il n'y en a pas encore.
    /// Les mois passés ne changent jamais rétroactivement : un nouveau taux ne touche que les jours depuis sa date d'effet (section 69).
    static func rate(on day: Date, rates: [PayRateEntry], calendar: Calendar) -> Decimal? {
        let dayStart: Date = calendar.startOfDay(for: day)
        var best: PayRateEntry? = nil
        for entry in rates {
            if calendar.startOfDay(for: entry.effectiveDate) > dayStart { continue }
            if let b = best {
                if entry.effectiveDate > b.effectiveDate { best = entry }
            } else {
                best = entry
            }
        }
        return best?.hourlyGross
    }

    // MARK: Mois

    static func monthBounds(year: Int, month: Int, calendar: Calendar) -> (start: Date, end: Date)? {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = 1
        guard let first = calendar.date(from: c) else { return nil }
        let start: Date = calendar.startOfDay(for: first)
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
        return (start, end)
    }

    private static func touches(_ s: PaySessionInput, start: Date, end: Date, now: Date) -> Bool {
        let rawEnd: Date = s.end ?? now
        return s.start < end && rawEnd > start && rawEnd > s.start
    }

    /// Heures, brut et net estimés d'un mois.
    /// - Section 13.1 : base heures pleines (arrondi, choix dans la zone de doute) ou exacte selon `base`.
    ///   Une borne en zone de doute sans choix est comptée en exact et signalée (doubtSessionCount), jamais arrondie en silence.
    /// - Une session à cheval sur minuit ou sur la fin du mois ne compte que sa part de chaque jour (comme DaySummary).
    /// - Le taux est celui de chaque jour (section 69). Les heures d'avant le premier taux sont comptées sans montant (unratedSeconds).
    /// - Montant : secondes d'un taux x taux / 3600 en Decimal, arrondi une fois au centime par taux. Le total est la somme des lignes arrondies.
    /// - Net : brut arrondi x ratio, arrondi au centime.
    static func month(year: Int,
                      month: Int,
                      sessions: [PaySessionInput],
                      rates: [PayRateEntry],
                      base: CalculationBase,
                      netRatio: Decimal,
                      now: Date,
                      calendar: Calendar) -> PayMonthResult {
        let bounds: (start: Date, end: Date) = monthBounds(year: year, month: month, calendar: calendar)
            ?? (start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 0))

        var inputs: [DaySessionInput] = []
        var sessionCount: Int = 0
        var doubtCount: Int = 0
        var liveCount: Int = 0
        var unconfirmedCount: Int = 0
        for s in sessions {
            if !touches(s, start: bounds.start, end: bounds.end, now: now) { continue }
            if !s.isConfirmed {
                unconfirmedCount += 1
                continue
            }
            sessionCount += 1
            if s.end == nil { liveCount += 1 }
            if base == .fullHours, s.end != nil,
               SessionDurations.hasUnresolvedDoubt(start: s.start, end: s.end, chosenStart: s.chosenStart, chosenEnd: s.chosenEnd, calendar: calendar) {
                doubtCount += 1
            }
            inputs.append(DaySessionInput(id: s.id, start: s.start, end: s.end, activity: .work,
                                          chosenStart: s.chosenStart, chosenEnd: s.chosenEnd))
        }

        var dayStarts: [Date] = []
        var cursor: Date = bounds.start
        while cursor < bounds.end {
            dayStarts.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        var dayLines: [PayDayLine] = []
        var accumulators: [(rate: Decimal, seconds: Int)] = []
        var retainedTotal: Int = 0
        var exactTotal: Int = 0
        var fullTotal: Int = 0
        var unrated: Int = 0

        for day in dayStarts {
            let full: ActivityDayTotal = DaySummary.total(activity: .work, day: day, inputs: inputs, base: .fullHours, now: now, calendar: calendar)
            let exact: ActivityDayTotal = DaySummary.total(activity: .work, day: day, inputs: inputs, base: .exact, now: now, calendar: calendar)
            if exact.sessionCount == 0 { continue }
            let retained: Int = base == .fullHours ? full.seconds : exact.seconds
            let dayRate: Decimal? = rate(on: day, rates: rates, calendar: calendar)
            dayLines.append(PayDayLine(day: day,
                                       sessionCount: exact.sessionCount,
                                       exactSeconds: exact.seconds,
                                       fullHoursSeconds: full.seconds,
                                       retainedSeconds: retained,
                                       isProvisional: base == .fullHours && full.isProvisional,
                                       hasLive: exact.hasLive,
                                       hourlyGross: dayRate))
            retainedTotal += retained
            exactTotal += exact.seconds
            fullTotal += full.seconds
            if let r = dayRate {
                var found: Bool = false
                for i in 0..<accumulators.count where accumulators[i].rate == r {
                    accumulators[i].seconds += retained
                    found = true
                    break
                }
                if !found { accumulators.append((rate: r, seconds: retained)) }
            } else {
                unrated += retained
            }
        }

        var lines: [PayRateLine] = []
        var grossCents: Int = 0
        for acc in accumulators {
            let amount: Decimal = Decimal(acc.seconds) * acc.rate / 3600
            let cents: Int = PayMath.roundedCents(amount)
            lines.append(PayRateLine(hourlyGross: acc.rate, seconds: acc.seconds, grossCents: cents))
            grossCents += cents
        }
        let netCents: Int = PayMath.roundedCents(Decimal(grossCents) * netRatio / 100)

        return PayMonthResult(year: year, month: month, base: base,
                              retainedSeconds: retainedTotal, exactSeconds: exactTotal, fullHoursSeconds: fullTotal,
                              unratedSeconds: unrated, grossCents: grossCents, netCents: netCents, netRatio: netRatio,
                              sessionCount: sessionCount, doubtSessionCount: doubtCount, liveSessionCount: liveCount,
                              unconfirmedSessionCount: unconfirmedCount, rateLines: lines, days: dayLines)
    }

    // MARK: Prévu contre réel (section 25)

    /// Compare, jour par jour, les créneaux prévus et les heures réelles retenues. Les jours sans prévu ni réel sont omis.
    /// Avec une liste de créneaux vide (le planning n'existe pas encore), le prévu vaut 0 partout.
    static func plannedVersusReal(year: Int,
                                  month: Int,
                                  planned: [PlannedSlot],
                                  sessions: [PaySessionInput],
                                  base: CalculationBase,
                                  now: Date,
                                  calendar: Calendar) -> [PlannedDayComparison] {
        guard let bounds = monthBounds(year: year, month: month, calendar: calendar) else { return [] }
        var inputs: [DaySessionInput] = []
        for s in sessions where s.isConfirmed {
            inputs.append(DaySessionInput(id: s.id, start: s.start, end: s.end, activity: .work,
                                          chosenStart: s.chosenStart, chosenEnd: s.chosenEnd))
        }
        var result: [PlannedDayComparison] = []
        var day: Date = bounds.start
        while day < bounds.end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            var plannedSeconds: Int = 0
            for slot in planned {
                let s: Date = max(slot.start, day)
                let e: Date = min(slot.end, next)
                if e > s { plannedSeconds += Int(e.timeIntervalSince(s).rounded()) }
            }
            let real: ActivityDayTotal = DaySummary.total(activity: .work, day: day, inputs: inputs, base: base, now: now, calendar: calendar)
            if plannedSeconds > 0 || real.sessionCount > 0 {
                result.append(PlannedDayComparison(day: day, plannedSeconds: plannedSeconds, realSeconds: real.seconds))
            }
            day = next
        }
        return result
    }
}

// MARK: - Détail avec règles et primes (étape 6)

/// Résultat d'un mois avec les majorations d'un pack et les primes saisies. Estimation.
/// `month` reste le calcul de base (heures x taux) : sans règle ni prime, `grossCents == month.grossCents`.
struct PayDetailResult: Equatable {
    let month: PayMonthResult
    let rules: PayRulesResult
    let premiums: PremiumsResult
    /// Brut de base (heures x taux).
    let baseGrossCents: Int
    /// Brut de base, plus majorations, plus primes brutes.
    let grossCents: Int
    /// Brut multiplié par le ratio, plus primes nettes.
    let netCents: Int
}

extension PayCalculator {

    /// Estimation du mois avec les règles de convention (surcharges déjà appliquées) et les primes de l'employeur.
    /// Les heures au-delà du seuil hebdomadaire regardent la semaine ISO entière, y compris les jours du mois d'avant.
    static func monthDetail(year: Int,
                            month monthNumber: Int,
                            sessions: [PaySessionInput],
                            rates: [PayRateEntry],
                            base: CalculationBase,
                            netRatio: Decimal,
                            rules: ConventionRules,
                            premiums: [PayPremium],
                            now: Date,
                            calendar: Calendar) -> PayDetailResult {
        let basis: PayMonthResult = PayCalculator.month(year: year, month: monthNumber, sessions: sessions, rates: rates,
                                                        base: base, netRatio: netRatio, now: now, calendar: calendar)
        guard let bounds = monthBounds(year: year, month: monthNumber, calendar: calendar) else {
            return PayDetailResult(month: basis, rules: PayRulesResult.empty, premiums: PremiumsResult.empty,
                                   baseGrossCents: basis.grossCents, grossCents: basis.grossCents, netCents: basis.netCents)
        }
        let weekStart: Date = PayRules.weekStart(of: bounds.start, calendar: calendar)
        let intervals: [PayInterval] = PayRules.retainedIntervals(sessions: sessions, base: base, now: now, calendar: calendar,
                                                                  window: (start: weekStart, end: bounds.end))
        let rateOnDay: (Date) -> Decimal? = { (day: Date) -> Decimal? in
            return PayCalculator.rate(on: day, rates: rates, calendar: calendar)
        }
        let ruleResult: PayRulesResult = PayRules.compute(intervals: intervals, periodStart: bounds.start, periodEnd: bounds.end,
                                                          rules: rules, rateOnDay: rateOnDay, calendar: calendar)
        let grossBeforePremiums: Int = basis.grossCents + ruleResult.majorationCents
        let premiumResult: PremiumsResult = PayRules.premiums(premiums, periodStart: bounds.start, periodEnd: bounds.end,
                                                              intervals: intervals, segments: ruleResult.segments,
                                                              grossBaseCents: grossBeforePremiums, calendar: calendar)
        let gross: Int = grossBeforePremiums + premiumResult.grossCents
        let net: Int = PayMath.roundedCents(Decimal(gross) * netRatio / 100) + premiumResult.netCents
        return PayDetailResult(month: basis, rules: ruleResult, premiums: premiumResult,
                               baseGrossCents: basis.grossCents, grossCents: gross, netCents: net)
    }
}
