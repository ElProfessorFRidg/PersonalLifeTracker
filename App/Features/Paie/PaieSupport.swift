import SwiftUI
import SwiftData

/// Règles, surcharges et primes d'un employeur, lues dans les fichiers du bundle et UserDefaults.
struct PaieRulesContext {
    let pack: ConventionPack
    let overrides: ConventionRules
    /// Règles réellement appliquées : tes valeurs, puis le pack.
    let rules: ConventionRules
    let employerKey: String
    let premiums: [PayPremium]
    let premiumsLoadFailed: Bool

    static func load(employer: Employer?, defaults: UserDefaults = UserDefaults.standard) -> PaieRulesContext {
        let packs: [ConventionPack] = ConventionCatalog.bundled.packs
        let pack: ConventionPack = ConventionCatalog.pack(for: employer?.conventionID, in: packs)
        let overrides: ConventionRules = ConventionOverrides.load(packID: pack.id, defaults: defaults)
        let key: String = employer?.uid.uuidString ?? "none"
        let stored: PremiumLoad = PremiumStore.load(defaults: defaults)
        return PaieRulesContext(pack: pack,
                                overrides: overrides,
                                rules: ConventionOverrides.effectiveRules(pack: pack, overrides: overrides),
                                employerKey: key,
                                premiums: PremiumStore.premiums(for: key, in: stored.premiums),
                                premiumsLoadFailed: stored.failed)
    }
}

/// Entrées de la paie pour un contrat (mêmes règles que PaieView : lieux du contrat, sinon toutes les sessions de taf).
enum PaieData {
    static func inputs(sessions: [WorkSession], contract: Contract) -> [PaySessionInput] {
        var list: [PaySessionInput] = []
        for s in sessions where s.activity == .work {
            if !contract.placeUIDs.isEmpty {
                guard let placeUID = s.place?.uid, contract.placeUIDs.contains(placeUID) else { continue }
            }
            list.append(PaySessionInput(id: s.uid, start: s.startDate, end: s.endDate,
                                        chosenStart: s.chosenStart, chosenEnd: s.chosenEnd, isConfirmed: s.isConfirmed))
        }
        return list
    }

    static func rateEntries(contract: Contract, payRates: [PayRate]) -> [PayRateEntry] {
        var list: [PayRateEntry] = []
        for r in payRates where r.contractUID == contract.uid {
            list.append(PayRateEntry(effectiveDate: r.effectiveDate, hourlyGross: PayMath.decimal(r.hourlyGross)))
        }
        if list.isEmpty, let rate = contract.hourlyGrossRate, rate > 0 {
            list.append(PayRateEntry(effectiveDate: contract.startDate, hourlyGross: PayMath.decimal(rate)))
        }
        return list
    }
}

/// Textes des règles (vues seulement).
enum PaieRuleText {
    static let verifyHint: String = "À vérifier avec ta convention ou ta fiche de paie."
    static let userSource: String = "Saisi par toi"

    static func percent(_ value: Decimal) -> String {
        return percent(PayMath.double(value))
    }

    /// 25 donne "25 %", 12,5 donne "12,5 %" (espace insécable).
    static func percent(_ value: Double) -> String {
        let rounded: Double = (value * 100).rounded() / 100
        var text: String
        if rounded == rounded.rounded() {
            text = String(Int(rounded))
        } else {
            text = String(format: "%.2f", rounded)
            while text.hasSuffix("0") { text.removeLast() }
            text = text.replacingOccurrences(of: ".", with: ",")
        }
        return text + "\u{00A0}%"
    }

    static func signedPercent(_ value: Decimal) -> String {
        return "+" + percent(value)
    }

    static func bandTitle(_ band: Int, rules: ConventionRules) -> String {
        guard let o = rules.overtime, band >= 0, band < o.bands.count else { return "Au-delà du seuil" }
        let b: PackOvertimeBand = o.bands[band]
        if let limit = b.overMinutes {
            return "Au-delà du seuil, jusqu'à \(Formatting.duration(minutes: limit)) de plus"
        }
        return o.bands.count > 1 ? "Au-delà du seuil, tranche suivante" : "Au-delà du seuil"
    }

    static func lineTitle(_ line: PayRuleLine, rules: ConventionRules) -> String {
        var name: String
        if let band = line.band {
            name = line.category == .normal ? bandTitle(band, rules: rules) : line.category.title + " et au-delà du seuil"
        } else {
            name = line.category.title
        }
        return name + " " + signedPercent(line.percent)
    }

    /// Source de la règle qui explique une ligne.
    static func source(for line: PayRuleLine, rules: ConventionRules) -> String {
        var parts: [String] = []
        switch line.category {
        case .night: if let n = rules.night { parts.append(n.source) }
        case .sunday: if let s = rules.sunday { parts.append(s.source) }
        case .holiday: if let h = rules.publicHoliday { parts.append(h.source) }
        case .normal: break
        }
        if line.band != nil, let o = rules.overtime { parts.append(o.source) }
        if parts.isEmpty { return "Règle saisie par toi" }
        return parts.joined(separator: " ")
    }

    static func sourceWithDate(_ source: String, date: String?) -> String {
        if let d = date { return source + " (relevé le " + d + ")" }
        return source
    }

    static func nightWindow(_ n: PackNightRule) -> String {
        return "de " + Formatting.clock(minutesFromMidnight: n.startMinute) + " à " + Formatting.clock(minutesFromMidnight: n.endMinute)
    }

    static func holidayScope(_ h: PackHolidayRule) -> String {
        return h.scope == PackHolidayRule.scopeMayFirstOnly ? "1er mai seulement" : "les 11 jours fériés"
    }

    static func overtimeSummary(_ o: PackOvertimeRule) -> String {
        var parts: [String] = ["seuil " + Formatting.duration(minutes: o.weeklyThresholdMinutes) + " par semaine"]
        for b in o.bands {
            if let limit = b.overMinutes {
                parts.append("+" + percent(b.percent) + " sur les " + Formatting.duration(minutes: limit) + " suivantes")
            } else {
                parts.append("+" + percent(b.percent) + " ensuite")
            }
        }
        return parts.joined(separator: ", ")
    }
}
