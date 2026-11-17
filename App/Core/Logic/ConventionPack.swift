import Foundation

// Format des packs de convention (sections 21 et 22), chargement, validation, recherche, surcharges de l'utilisateur
// et stockage des primes (section 26). Logique pure : Foundation seulement.
//
// RÈGLE : aucune valeur légale n'est écrite dans le Swift. Les valeurs vivent dans les fichiers JSON
// `convention_*.json` (App/Resources/reference/), chacune avec sa source et sa date. L'utilisateur peut tout surcharger.
// Une règle absente du pack veut dire "à renseigner" : l'app n'applique rien et le dit.

// MARK: - Règles d'un pack

/// Majoration en pourcentage (dimanche).
struct PackPercentRule: Codable, Equatable {
    var percent: Double
    var source: String
    /// Date au format "AAAA-MM-JJ" à laquelle la valeur a été relevée dans la source.
    var sourceDate: String?

    init(percent: Double, source: String, sourceDate: String? = nil) {
        self.percent = percent
        self.source = source
        self.sourceDate = sourceDate
    }
}

/// Heures de nuit : fenêtre en minutes depuis minuit (le début peut être supérieur à la fin : la fenêtre passe minuit).
struct PackNightRule: Codable, Equatable {
    var startMinute: Int
    var endMinute: Int
    var percent: Double
    var source: String
    var sourceDate: String?

    init(startMinute: Int, endMinute: Int, percent: Double, source: String, sourceDate: String? = nil) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.percent = percent
        self.source = source
        self.sourceDate = sourceDate
    }
}

/// Jours fériés : "all" = les 11 jours fériés légaux, "mayFirstOnly" = le 1er mai seulement.
struct PackHolidayRule: Codable, Equatable {
    var scope: String
    var percent: Double
    var source: String
    var sourceDate: String?

    static let scopeAll: String = "all"
    static let scopeMayFirstOnly: String = "mayFirstOnly"

    init(scope: String, percent: Double, source: String, sourceDate: String? = nil) {
        self.scope = scope
        self.percent = percent
        self.source = source
        self.sourceDate = sourceDate
    }
}

/// Une tranche d'heures au-delà du seuil. `overMinutes` = nombre de minutes que couvre la tranche (nil = sans limite, dernière tranche).
struct PackOvertimeBand: Codable, Equatable {
    var overMinutes: Int?
    var percent: Double

    init(overMinutes: Int?, percent: Double) {
        self.overMinutes = overMinutes
        self.percent = percent
    }
}

/// Heures au-delà d'un seuil hebdomadaire (semaine ISO, lundi à dimanche).
struct PackOvertimeRule: Codable, Equatable {
    var weeklyThresholdMinutes: Int
    var bands: [PackOvertimeBand]
    var source: String
    var sourceDate: String?

    init(weeklyThresholdMinutes: Int, bands: [PackOvertimeBand], source: String, sourceDate: String? = nil) {
        self.weeklyThresholdMinutes = weeklyThresholdMinutes
        self.bands = bands
        self.source = source
        self.sourceDate = sourceDate
    }
}

/// Taux horaire minimal conventionnel, s'il y en a un (en centimes).
struct PackMinimumRate: Codable, Equatable {
    var hourlyCents: Int
    var label: String
    var source: String
    var sourceDate: String?

    init(hourlyCents: Int, label: String, source: String, sourceDate: String? = nil) {
        self.hourlyCents = hourlyCents
        self.label = label
        self.source = source
        self.sourceDate = sourceDate
    }
}

/// Mode de cumul quand une même heure relève de plusieurs majorations.
enum RuleCumulation: String, Equatable {
    /// On applique la plus haute (défaut, prudent).
    case highest
    /// On additionne.
    case sum

    var title: String {
        switch self {
        case .highest: return "La plus haute seulement"
        case .sum: return "On additionne"
        }
    }
}

/// Toutes les règles d'un pack. Tout est facultatif : une règle absente = "à renseigner".
struct ConventionRules: Codable, Equatable {
    var night: PackNightRule?
    var sunday: PackPercentRule?
    var publicHoliday: PackHolidayRule?
    var overtime: PackOvertimeRule?
    var minimumRate: PackMinimumRate?
    /// "highest" ou "sum". nil = highest.
    var cumulation: String?

    init(night: PackNightRule? = nil,
         sunday: PackPercentRule? = nil,
         publicHoliday: PackHolidayRule? = nil,
         overtime: PackOvertimeRule? = nil,
         minimumRate: PackMinimumRate? = nil,
         cumulation: String? = nil) {
        self.night = night
        self.sunday = sunday
        self.publicHoliday = publicHoliday
        self.overtime = overtime
        self.minimumRate = minimumRate
        self.cumulation = cumulation
    }

    var cumulationMode: RuleCumulation {
        if let raw = cumulation, let mode = RuleCumulation(rawValue: raw) { return mode }
        return .highest
    }

    var isEmpty: Bool {
        return night == nil && sunday == nil && publicHoliday == nil && overtime == nil && minimumRate == nil
    }

    /// Les règles de `self` (surcharges de l'utilisateur) passent devant celles de `base` (pack), règle par règle.
    func merged(over base: ConventionRules) -> ConventionRules {
        return ConventionRules(night: night ?? base.night,
                               sunday: sunday ?? base.sunday,
                               publicHoliday: publicHoliday ?? base.publicHoliday,
                               overtime: overtime ?? base.overtime,
                               minimumRate: minimumRate ?? base.minimumRate,
                               cumulation: cumulation ?? base.cumulation)
    }
}

// MARK: - Pack

struct ConventionPack: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    /// Numéro IDCC en texte ("2216"), nil pour le pack général et le pack personnalisé.
    var idcc: String?
    var sector: String?
    var keywords: [String]
    var summary: String
    /// Date de validité des valeurs, "AAAA-MM-JJ" (nil = inconnue).
    var validFrom: String?
    /// Date de dernière vérification sur une source officielle, "AAAA-MM-JJ". nil = JAMAIS vérifié.
    var verifiedOn: String?
    var sourceNote: String
    var sourceURLs: [String]
    /// Règles que le pack ne renseigne pas : affichées "à renseigner".
    var toFill: [String]
    var rules: ConventionRules

    init(id: String,
         name: String,
         idcc: String? = nil,
         sector: String? = nil,
         keywords: [String] = [],
         summary: String = "",
         validFrom: String? = nil,
         verifiedOn: String? = nil,
         sourceNote: String = "",
         sourceURLs: [String] = [],
         toFill: [String] = [],
         rules: ConventionRules = ConventionRules()) {
        self.id = id
        self.name = name
        self.idcc = idcc
        self.sector = sector
        self.keywords = keywords
        self.summary = summary
        self.validFrom = validFrom
        self.verifiedOn = verifiedOn
        self.sourceNote = sourceNote
        self.sourceURLs = sourceURLs
        self.toFill = toFill
        self.rules = rules
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, idcc, sector, keywords, summary, validFrom, verifiedOn, sourceNote, sourceURLs, toFill, rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.idcc = try c.decodeIfPresent(String.self, forKey: .idcc)
        self.sector = try c.decodeIfPresent(String.self, forKey: .sector)
        self.keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.validFrom = try c.decodeIfPresent(String.self, forKey: .validFrom)
        self.verifiedOn = try c.decodeIfPresent(String.self, forKey: .verifiedOn)
        self.sourceNote = try c.decodeIfPresent(String.self, forKey: .sourceNote) ?? ""
        self.sourceURLs = try c.decodeIfPresent([String].self, forKey: .sourceURLs) ?? []
        self.toFill = try c.decodeIfPresent([String].self, forKey: .toFill) ?? []
        self.rules = try c.decodeIfPresent(ConventionRules.self, forKey: .rules) ?? ConventionRules()
    }

    /// Vrai si le pack n'a jamais été vérifié sur une source officielle.
    var isUnverified: Bool { return verifiedOn == nil }
}

// MARK: - Validation

enum PackValidationError: Equatable {
    case emptyID
    case emptyName
    case invalidIDCC(String)
    case invalidDate(field: String, value: String)
    case percentOutOfRange(rule: String, value: Double)
    case invalidNightWindow(start: Int, end: Int)
    case invalidOvertimeThreshold(Int)
    case invalidOvertimeBands(String)
    case invalidMinimumRate(Int)
    case unknownHolidayScope(String)
    case unknownCumulation(String)
    case missingSource(rule: String)

    /// Phrase en français pour l'écran (tutoiement, pas de tiret cadratin).
    var message: String {
        switch self {
        case .emptyID: return "Le pack n'a pas d'identifiant."
        case .emptyName: return "Le pack n'a pas de nom."
        case .invalidIDCC(let v): return "Le numéro IDCC \"\(v)\" n'est pas valide (1 à 4 chiffres)."
        case .invalidDate(let field, let value): return "La date \"\(value)\" (\(field)) n'est pas valide, il faut AAAA-MM-JJ."
        case .percentOutOfRange(let rule, let value): return "Le pourcentage \(value) de la règle \(rule) est hors limites (0 à 300)."
        case .invalidNightWindow(let s, let e): return "La fenêtre de nuit \(s) à \(e) n'est pas valide (minutes de 0 à 1439, début différent de la fin)."
        case .invalidOvertimeThreshold(let m): return "Le seuil hebdomadaire de \(m) minutes n'est pas valide."
        case .invalidOvertimeBands(let why): return "Les tranches d'heures au-delà du seuil ne sont pas valides : \(why)."
        case .invalidMinimumRate(let c): return "Le taux minimal de \(c) centimes n'est pas valide."
        case .unknownHolidayScope(let s): return "La portée des jours fériés \"\(s)\" est inconnue."
        case .unknownCumulation(let s): return "Le mode de cumul \"\(s)\" est inconnu."
        case .missingSource(let rule): return "La règle \(rule) n'a pas de source."
        }
    }
}

enum ConventionPackValidator {
    static let maxPercent: Double = 300
    static let maxWeeklyMinutes: Int = 7 * 24 * 60

    /// "AAAA-MM-JJ" valide, année de 1990 à 2100.
    static func isValidDate(_ text: String) -> Bool {
        let parts: [String] = text.components(separatedBy: "-")
        if parts.count != 3 { return false }
        if parts[0].count != 4 || parts[1].count != 2 || parts[2].count != 2 { return false }
        guard let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return false }
        if y < 1990 || y > 2100 || m < 1 || m > 12 || d < 1 { return false }
        let leap: Bool = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
        let lengths: [Int] = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return d <= lengths[m - 1]
    }

    static func isValidPercent(_ v: Double) -> Bool {
        if v.isNaN || v.isInfinite { return false }
        return v >= 0 && v <= maxPercent
    }

    private static func checkSource(rule: String, source: String, date: String?, into errors: inout [PackValidationError]) {
        if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.missingSource(rule: rule))
        }
        if let d = date, !isValidDate(d) {
            errors.append(.invalidDate(field: rule, value: d))
        }
    }

    /// Règles seules (utilisé aussi pour les surcharges de l'utilisateur).
    static func validate(rules: ConventionRules) -> [PackValidationError] {
        var errors: [PackValidationError] = []
        if let n = rules.night {
            if !isValidPercent(n.percent) { errors.append(.percentOutOfRange(rule: "nuit", value: n.percent)) }
            if n.startMinute < 0 || n.startMinute > 1439 || n.endMinute < 0 || n.endMinute > 1439 || n.startMinute == n.endMinute {
                errors.append(.invalidNightWindow(start: n.startMinute, end: n.endMinute))
            }
            checkSource(rule: "nuit", source: n.source, date: n.sourceDate, into: &errors)
        }
        if let s = rules.sunday {
            if !isValidPercent(s.percent) { errors.append(.percentOutOfRange(rule: "dimanche", value: s.percent)) }
            checkSource(rule: "dimanche", source: s.source, date: s.sourceDate, into: &errors)
        }
        if let h = rules.publicHoliday {
            if !isValidPercent(h.percent) { errors.append(.percentOutOfRange(rule: "jours fériés", value: h.percent)) }
            if h.scope != PackHolidayRule.scopeAll && h.scope != PackHolidayRule.scopeMayFirstOnly {
                errors.append(.unknownHolidayScope(h.scope))
            }
            checkSource(rule: "jours fériés", source: h.source, date: h.sourceDate, into: &errors)
        }
        if let o = rules.overtime {
            if o.weeklyThresholdMinutes <= 0 || o.weeklyThresholdMinutes > maxWeeklyMinutes {
                errors.append(.invalidOvertimeThreshold(o.weeklyThresholdMinutes))
            }
            if o.bands.isEmpty {
                errors.append(.invalidOvertimeBands("aucune tranche"))
            }
            for (index, band) in o.bands.enumerated() {
                if !isValidPercent(band.percent) { errors.append(.percentOutOfRange(rule: "heures au-delà du seuil", value: band.percent)) }
                let isLast: Bool = index == o.bands.count - 1
                if let limit = band.overMinutes {
                    if limit <= 0 { errors.append(.invalidOvertimeBands("une tranche a une durée nulle ou négative")) }
                    if isLast { errors.append(.invalidOvertimeBands("la dernière tranche doit être sans limite")) }
                } else if !isLast {
                    errors.append(.invalidOvertimeBands("seule la dernière tranche peut être sans limite"))
                }
            }
            checkSource(rule: "heures au-delà du seuil", source: o.source, date: o.sourceDate, into: &errors)
        }
        if let m = rules.minimumRate {
            if m.hourlyCents <= 0 || m.hourlyCents > 100_000 { errors.append(.invalidMinimumRate(m.hourlyCents)) }
            checkSource(rule: "taux minimal", source: m.source, date: m.sourceDate, into: &errors)
        }
        if let c = rules.cumulation, RuleCumulation(rawValue: c) == nil {
            errors.append(.unknownCumulation(c))
        }
        return errors
    }

    static func validate(_ pack: ConventionPack) -> [PackValidationError] {
        var errors: [PackValidationError] = []
        if pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.emptyID) }
        if pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.emptyName) }
        if let idcc = pack.idcc {
            var valid: Bool = !idcc.isEmpty && idcc.count <= 4
            for ch in idcc where !(ch.isASCII && ch.isNumber) { valid = false }
            if !valid { errors.append(.invalidIDCC(idcc)) }
        }
        if let d = pack.validFrom, !isValidDate(d) { errors.append(.invalidDate(field: "validité", value: d)) }
        if let d = pack.verifiedOn, !isValidDate(d) { errors.append(.invalidDate(field: "vérification", value: d)) }
        errors.append(contentsOf: validate(rules: pack.rules))
        return errors
    }
}

// MARK: - Chargement

struct RejectedPack: Equatable {
    let fileName: String
    let packID: String
    let errors: [PackValidationError]
}

struct ConventionLoadResult: Equatable {
    var packs: [ConventionPack]
    var rejected: [RejectedPack]
    /// Fichiers illisibles (JSON invalide).
    var unreadableFiles: [String]
}

enum ConventionPackLoader {
    static let filePrefix: String = "convention_"

    /// Décode un fichier : soit un pack seul, soit un tableau de packs.
    static func decode(data: Data) throws -> [ConventionPack] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([ConventionPack].self, from: data) { return list }
        let one: ConventionPack = try decoder.decode(ConventionPack.self, from: data)
        return [one]
    }

    /// Valide une liste de packs : les invalides sont écartés avec leurs erreurs, les doublons d'identifiant aussi (le premier gagne).
    static func accept(_ packs: [ConventionPack], fileName: String) -> (accepted: [ConventionPack], rejected: [RejectedPack]) {
        var accepted: [ConventionPack] = []
        var rejected: [RejectedPack] = []
        var seen: Set<String> = []
        for pack in packs {
            let errors: [PackValidationError] = ConventionPackValidator.validate(pack)
            if !errors.isEmpty {
                rejected.append(RejectedPack(fileName: fileName, packID: pack.id, errors: errors))
                continue
            }
            if seen.contains(pack.id) {
                rejected.append(RejectedPack(fileName: fileName, packID: pack.id, errors: [.emptyID]))
                continue
            }
            seen.insert(pack.id)
            accepted.append(pack)
        }
        return (accepted, rejected)
    }

    /// Charge tous les fichiers `convention_*.json` du bundle. Ne plante jamais : un fichier cassé est signalé et ignoré.
    static func loadAll(bundle: Bundle) -> ConventionLoadResult {
        var result = ConventionLoadResult(packs: [], rejected: [], unreadableFiles: [])
        let urls: [URL] = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let sorted: [URL] = urls.sorted { (a: URL, b: URL) -> Bool in a.lastPathComponent < b.lastPathComponent }
        var seenIDs: Set<String> = []
        for url in sorted {
            let name: String = url.lastPathComponent
            if !name.hasPrefix(filePrefix) { continue }
            guard let data = try? Data(contentsOf: url), let list = try? decode(data: data) else {
                result.unreadableFiles.append(name)
                continue
            }
            let outcome = accept(list, fileName: name)
            for pack in outcome.accepted {
                if seenIDs.contains(pack.id) {
                    result.rejected.append(RejectedPack(fileName: name, packID: pack.id, errors: [.emptyID]))
                } else {
                    seenIDs.insert(pack.id)
                    result.packs.append(pack)
                }
            }
            result.rejected.append(contentsOf: outcome.rejected)
        }
        return result
    }
}

// MARK: - Catalogue, choix et recherche

enum ConventionCatalog {
    static let genericID: String = "generic-code-du-travail"
    static let customID: String = "custom"

    /// Packs du bundle de l'app, chargés une fois.
    static let bundled: ConventionLoadResult = ConventionPackLoader.loadAll(bundle: Bundle.main)

    /// Pack de secours si aucun fichier n'est lisible : AUCUNE règle, aucune valeur légale.
    static let emptyFallback: ConventionPack = ConventionPack(
        id: genericID,
        name: "Sans convention (aucune règle chargée)",
        summary: "Les fichiers de règles n'ont pas pu être lus. Aucune majoration n'est appliquée.",
        sourceNote: "Aucune source : pack vide.")

    /// Pack d'un employeur. `conventionID` peut être un identifiant de pack ou un numéro IDCC ("2216").
    static func pack(for conventionID: String?, in packs: [ConventionPack]) -> ConventionPack {
        if let raw = conventionID {
            let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                for p in packs where p.id == trimmed { return p }
                let stripped: String = stripZeros(trimmed)
                for p in packs {
                    if let idcc = p.idcc, stripZeros(idcc) == stripped { return p }
                }
            }
        }
        for p in packs where p.id == genericID { return p }
        if let first = packs.first { return first }
        return emptyFallback
    }

    private static func stripZeros(_ text: String) -> String {
        var chars: [Character] = Array(text)
        while chars.count > 1, chars[0] == "0" { chars.removeFirst() }
        return String(chars)
    }

    // MARK: Recherche tolérante

    /// Minuscules, sans accents.
    static func fold(_ text: String) -> String {
        return text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                            locale: Locale(identifier: "fr_FR")).lowercased()
    }

    static func words(_ text: String) -> [String] {
        let parts: [String] = fold(text).components(separatedBy: CharacterSet.alphanumerics.inverted)
        var out: [String] = []
        for p in parts where !p.isEmpty { out.append(p) }
        return out
    }

    /// Distance de Levenshtein (insertion, suppression, remplacement).
    static func editDistance(_ a: String, _ b: String) -> Int {
        let x: [Character] = Array(a)
        let y: [Character] = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous: [Int] = Array(0...y.count)
        var current: [Int] = Array(repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost: Int = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[y.count]
    }

    private static func tokenMatches(_ token: String, haystack: String, haystackWords: [String], idcc: String?) -> Bool {
        var allDigits: Bool = !token.isEmpty
        for ch in token where !(ch.isASCII && ch.isNumber) { allDigits = false }
        if allDigits {
            guard let code = idcc else { return false }
            return stripZeros(code).hasPrefix(stripZeros(token)) || code == token
        }
        if haystack.contains(token) { return true }
        if token.count >= 5 {
            for w in haystackWords where abs(w.count - token.count) <= 1 {
                if editDistance(token, w) <= 1 { return true }
            }
        }
        return false
    }

    /// Recherche par nom, numéro IDCC, secteur ou mot-clé. Insensible aux accents et à la casse, tolère une faute légère
    /// (un caractère d'écart sur les mots de 5 lettres ou plus). Tous les mots saisis doivent correspondre. Requête vide : tout.
    static func search(_ query: String, in packs: [ConventionPack]) -> [ConventionPack] {
        let tokens: [String] = words(query)
        if tokens.isEmpty { return packs }
        var out: [ConventionPack] = []
        for p in packs {
            let text: String = fold(p.name + " " + (p.idcc ?? "") + " " + (p.sector ?? "") + " " + p.keywords.joined(separator: " ") + " " + p.summary)
            let hw: [String] = words(text)
            var all: Bool = true
            for t in tokens where !tokenMatches(t, haystack: text, haystackWords: hw, idcc: p.idcc) {
                all = false
                break
            }
            if all { out.append(p) }
        }
        return out
    }
}

// MARK: - Surcharges de l'utilisateur (UserDefaults, JSON)

enum ConventionOverrides {
    static func key(packID: String) -> String { return "plt.pay.packOverride." + packID }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// Surcharges enregistrées pour ce pack (vides si aucune ou illisibles).
    static func load(packID: String, defaults: UserDefaults) -> ConventionRules {
        guard let data = defaults.data(forKey: key(packID: packID)) else { return ConventionRules() }
        return (try? JSONDecoder().decode(ConventionRules.self, from: data)) ?? ConventionRules()
    }

    /// Enregistre des surcharges valides. Renvoie les erreurs (rien n'est écrit s'il y en a). Surcharges vides : supprime la clé.
    @discardableResult
    static func save(_ rules: ConventionRules, packID: String, defaults: UserDefaults) -> [PackValidationError] {
        let errors: [PackValidationError] = ConventionPackValidator.validate(rules: rules)
        if !errors.isEmpty { return errors }
        if rules == ConventionRules() {
            defaults.removeObject(forKey: key(packID: packID))
            return []
        }
        if let data = try? encoder().encode(rules) {
            defaults.set(data, forKey: key(packID: packID))
        }
        return []
    }

    static func clear(packID: String, defaults: UserDefaults) {
        defaults.removeObject(forKey: key(packID: packID))
    }

    /// Règles réellement appliquées : surcharges de l'utilisateur, puis pack (section 22 : priorité à l'utilisateur).
    static func effectiveRules(pack: ConventionPack, overrides: ConventionRules) -> ConventionRules {
        return overrides.merged(over: pack.rules)
    }
}

// MARK: - Stockage des primes (section 26)

struct PremiumLoad: Equatable {
    var premiums: [PayPremium]
    /// Vrai si des données existent mais n'ont pas pu être lues : ne rien écraser.
    var failed: Bool
}

enum PremiumStore {
    static let key: String = "plt.pay.premiums"

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func load(defaults: UserDefaults) -> PremiumLoad {
        guard let data = defaults.data(forKey: key) else { return PremiumLoad(premiums: [], failed: false) }
        if let list = try? decoder().decode([PayPremium].self, from: data) {
            return PremiumLoad(premiums: list, failed: false)
        }
        return PremiumLoad(premiums: [], failed: true)
    }

    /// Renvoie faux si l'écriture est impossible.
    @discardableResult
    static func save(_ premiums: [PayPremium], defaults: UserDefaults) -> Bool {
        guard let data = try? encoder().encode(premiums) else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    /// Primes d'un employeur (la clé est l'uid de l'employeur en texte).
    static func premiums(for employerKey: String, in all: [PayPremium]) -> [PayPremium] {
        var out: [PayPremium] = []
        for p in all where p.employerKey == employerKey { out.append(p) }
        return out
    }

    /// Ajoute ou remplace (même id).
    static func upserting(_ premium: PayPremium, in all: [PayPremium]) -> [PayPremium] {
        var out: [PayPremium] = all
        for i in 0..<out.count where out[i].id == premium.id {
            out[i] = premium
            return out
        }
        out.append(premium)
        return out
    }

    static func removing(id: String, from all: [PayPremium]) -> [PayPremium] {
        var out: [PayPremium] = []
        for p in all where p.id != id { out.append(p) }
        return out
    }
}
