import Foundation

// Lecture d'un planning à partir de lignes de texte positionnées (section 16).
// Logique pure : Foundation seulement. Aucune lecture dans l'ordre du texte : tout passe par la position
// (en-têtes de jours = colonnes, une personne par ligne). Rien n'est deviné en silence : chaque créneau a une
// confiance et une raison, et les cas incertains remontent à l'écran de validation.

/// Une ligne de texte reconnue, avec sa position dans l'image. Coordonnées normalisées 0 à 1, origine en haut à gauche.
struct OCRTextLine: Equatable {
    let text: String
    let minX: Double
    let minY: Double
    let width: Double
    let height: Double
    /// Confiance de la reconnaissance, 0 à 1.
    let confidence: Double

    init(text: String, minX: Double, minY: Double, width: Double, height: Double, confidence: Double = 1.0) {
        self.text = text
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
        self.confidence = confidence
    }

    var midX: Double { return minX + width / 2 }
    var midY: Double { return minY + height / 2 }
}

enum ScheduleRestKind: Equatable {
    case rest
    case leave
}

/// Une plage horaire en minutes depuis minuit du jour de la case. `endMinutes` dépasse 1440 si la fin est le lendemain.
struct ShiftTimeRange: Equatable {
    let startMinutes: Int
    let endMinutes: Int
    let crossesMidnight: Bool

    var durationMinutes: Int { return endMinutes - startMinutes }
}

/// Contenu d'une case du tableau.
enum ScheduleCellContent: Equatable {
    case empty
    case rest(ScheduleRestKind)
    case shifts([ShiftTimeRange])
    case unreadable
}

/// En-tête de colonne : "L 23", "Mardi 24/11", "Dim".
struct ScheduleDayHeader: Equatable {
    /// Jours possibles, 0 = lundi ... 6 = dimanche. Plusieurs valeurs pour la lettre "M" seule.
    let weekdays: [Int]
    let dayOfMonth: Int?
    let month: Int?
}

/// Titre de semaine : "Planning du 23 au 29 nov."
struct ScheduleWeekTitle: Equatable {
    let day: Int
    /// Mois du premier jour (déduit de la fin si le début n'en porte pas).
    let startMonth: Int?
    let year: Int?
}

enum ScheduleConfidenceLevel: Equatable {
    case high
    case mid
    case low
}

enum ScheduleConfidence {
    static let highThreshold: Double = 0.85
    static let midThreshold: Double = 0.6

    static func level(_ confidence: Double) -> ScheduleConfidenceLevel {
        if confidence >= highThreshold { return .high }
        if confidence >= midThreshold { return .mid }
        return .low
    }

    static func percent(_ confidence: Double) -> Int {
        let clamped = min(1.0, max(0.0, confidence))
        return Int((clamped * 100).rounded())
    }
}

struct ParsedShift: Equatable {
    /// Début du jour de la case (selon le calendrier des options).
    let day: Date
    let startMinutes: Int
    let endMinutes: Int
    let confidence: Double
    /// Pourquoi ce créneau est moins sûr (nil si rien à signaler).
    let reason: String?
    let rawText: String
    let crossesMidnight: Bool

    var level: ScheduleConfidenceLevel { return ScheduleConfidence.level(confidence) }

    func interval(calendar: Calendar) -> (start: Date, end: Date) {
        let start = ScheduleTextParser.date(day: day, minutes: startMinutes, calendar: calendar)
        let end = ScheduleTextParser.date(day: day, minutes: endMinutes, calendar: calendar)
        return (start, end)
    }
}

struct ParsedRestDay: Equatable {
    let day: Date
    let kind: ScheduleRestKind
}

/// Une case dont le texte n'a pas pu être lu : elle remonte à l'utilisateur, jamais devinée.
struct UnreadableCell: Equatable {
    let day: Date
    let rawText: String
}

/// Rectangle en coordonnées normalisées (0 à 1, origine en haut à gauche), pour surligner une ligne sur la photo.
struct NormalizedRect: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct ScheduleNameCandidate: Equatable {
    let rowIndex: Int
    let name: String
    /// 1 = identique, 0,9 = contenu, 0,8 = initiales, 0,55 = ressemble (une lettre d'écart).
    let score: Double
}

enum ScheduleParseFailure: Equatable {
    /// Aucun texte lisible.
    case noText
    /// Pas d'en-têtes de jours reconnus (trois jours au moins).
    case noHeader
    /// Le tableau est là mais aucune ligne ne ressemble au nom donné.
    case nameNotFound
}

struct ScheduleParseResult: Equatable {
    var failure: ScheduleParseFailure? = nil
    /// Noms de toutes les lignes du tableau, dans l'ordre (pour choisir sa ligne).
    var rowNames: [String] = []
    var candidates: [ScheduleNameCandidate] = []
    var chosenRowIndex: Int? = nil
    /// Plusieurs lignes ressemblent au nom : l'utilisateur doit confirmer ou choisir.
    var needsLineChoice: Bool = false
    var shifts: [ParsedShift] = []
    var restDays: [ParsedRestDay] = []
    var unreadable: [UnreadableCell] = []
    var emptyCellCount: Int = 0
    var weekStart: Date? = nil
    /// Zone de la ligne retenue sur la photo d'origine.
    var highlight: NormalizedRect? = nil
    /// Les dates n'étaient pas sur la photo : la semaine est une hypothèse.
    var datesGuessed: Bool = false
    var warnings: [String] = []
    var averageConfidence: Double = 0

    static func failed(_ failure: ScheduleParseFailure) -> ScheduleParseResult {
        var result = ScheduleParseResult()
        result.failure = failure
        return result
    }
}

struct ScheduleParseOptions {
    /// Variantes du nom de l'utilisateur : prénom, nom, initiales, surnoms.
    var names: [String]
    var referenceDate: Date
    var calendar: Calendar
    /// Ligne choisie par l'utilisateur (indice dans `rowNames`).
    var forcedRowIndex: Int?
    /// Décalage en semaines, utilisé seulement quand les dates ne sont pas sur la photo.
    var guessedWeekOffset: Int

    init(names: [String],
         referenceDate: Date,
         calendar: Calendar = Calendar.current,
         forcedRowIndex: Int? = nil,
         guessedWeekOffset: Int = 0) {
        self.names = names
        self.referenceDate = referenceDate
        self.calendar = calendar
        self.forcedRowIndex = forcedRowIndex
        self.guessedWeekOffset = guessedWeekOffset
    }
}

enum ScheduleTextParser {

    // MARK: - Texte

    /// Minuscules, sans accents.
    static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        return folded.lowercased()
    }

    /// Suites de lettres et suites de chiffres, repliées. Le reste sépare.
    static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var currentIsDigit = false
        for ch in fold(text) {
            let isDigit = ch.isASCII && ch.isNumber
            let isLetter = ch.isLetter
            if isDigit || isLetter {
                if !current.isEmpty && isDigit != currentIsDigit {
                    result.append(current)
                    current = ""
                }
                current.append(ch)
                currentIsDigit = isDigit
            } else if !current.isEmpty {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func digitValue(_ ch: Character) -> Int? {
        if !ch.isASCII { return nil }
        return ch.wholeNumberValue
    }

    // MARK: - Heures

    private static func normalizedChars(_ text: String) -> [Character] {
        var out: [Character] = []
        for ch in fold(text) {
            switch ch {
            case "\u{2013}", "\u{2014}", "\u{2212}", "\u{2011}", "\u{2012}", "\u{2192}", "~":
                out.append("-")
            case "\u{00A0}", "\u{202F}", "\t", "\n":
                out.append(" ")
            default:
                out.append(ch)
            }
        }
        return out
    }

    /// Lit une heure à partir de `start` : "9", "9h", "9h30", "09:00", "16:30". Renvoie les minutes depuis minuit.
    private static func parseTime(_ c: [Character], _ start: Int) -> (minutes: Int, next: Int)? {
        var i = start
        var hour = 0
        var hourDigits = 0
        while i < c.count, hourDigits < 2, let d = digitValue(c[i]) {
            hour = hour * 10 + d
            hourDigits += 1
            i += 1
        }
        if hourDigits == 0 { return nil }
        if i < c.count, digitValue(c[i]) != nil { return nil }
        var minute = 0
        if i < c.count, c[i] == ":" || c[i] == "h" {
            let isColon = c[i] == ":"
            i += 1
            if i + 1 < c.count, let m1 = digitValue(c[i]), let m2 = digitValue(c[i + 1]) {
                minute = m1 * 10 + m2
                i += 2
                if i < c.count, digitValue(c[i]) != nil { return nil }
            } else if isColon {
                return nil
            }
        }
        if hour > 24 || minute > 59 { return nil }
        if hour == 24 && minute > 0 { return nil }
        return (hour * 60 + minute, i)
    }

    private static func skipSpaces(_ c: [Character], _ from: Int) -> Int {
        var i = from
        while i < c.count, c[i] == " " { i += 1 }
        return i
    }

    /// Toutes les plages horaires d'un texte : "9-16", "9h-16h", "09:00-16:30", "8h-12h / 14h-18h", "9h à 16h".
    static func parseRanges(in text: String) -> [ShiftTimeRange] {
        let c = normalizedChars(text)
        var ranges: [ShiftTimeRange] = []
        var i = 0
        while i < c.count {
            if digitValue(c[i]) == nil {
                i += 1
                continue
            }
            guard let t1 = parseTime(c, i) else {
                while i < c.count, digitValue(c[i]) != nil { i += 1 }
                continue
            }
            var j = skipSpaces(c, t1.next)
            var matched = false
            if j < c.count, c[j] == "-" {
                j += 1
                matched = true
            } else if j + 1 < c.count, c[j] == "a", c[j + 1] == " " || digitValue(c[j + 1]) != nil {
                j += 1
                matched = true
            }
            if !matched {
                i = max(t1.next, i + 1)
                continue
            }
            j = skipSpaces(c, j)
            guard j < c.count, let t2 = parseTime(c, j) else {
                i = max(t1.next, i + 1)
                continue
            }
            i = max(t2.next, i + 1)
            if t2.minutes == t1.minutes { continue }
            if t2.minutes > t1.minutes {
                ranges.append(ShiftTimeRange(startMinutes: t1.minutes, endMinutes: t2.minutes, crossesMidnight: false))
            } else {
                ranges.append(ShiftTimeRange(startMinutes: t1.minutes, endMinutes: t2.minutes + 1440, crossesMidnight: true))
            }
        }
        return ranges
    }

    /// Une seule heure saisie à la main ("9:00", "09h", "9h30"). Nil si le texte n'est pas une heure.
    static func parseClockInput(_ text: String) -> Int? {
        let c = normalizedChars(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if c.isEmpty { return nil }
        guard let t = parseTime(c, 0) else { return nil }
        if t.next != c.count { return nil }
        if t.minutes >= 1440 { return nil }
        return t.minutes
    }

    private static let restWords: Set<String> = ["r", "repos", "rh", "off", "rc"]
    private static let leaveWords: Set<String> = ["conge", "conges", "cp", "rtt", "vacances", "ferie", "maladie", "absent", "abs"]
    private static let fillerWords: Set<String> = ["paye", "payes", "jour", "de", "du", "le", "en"]

    /// Contenu d'une case : horaires, repos, congé, vide ou illisible.
    static func parseCell(_ text: String) -> ScheduleCellContent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        let emptyChars: Set<Character> = [" ", "-", "_", ".", "/", "|", "\u{2013}", "\u{2014}"]
        if trimmed.allSatisfy({ emptyChars.contains($0) }) { return .empty }

        let words: [String] = tokens(trimmed).filter { Int($0) == nil }
        let hasRestWord = words.contains(where: { restWords.contains($0) || leaveWords.contains($0) })
        let ranges = parseRanges(in: trimmed)
        if !ranges.isEmpty {
            if hasRestWord { return .unreadable }
            return .shifts(ranges)
        }
        if words.isEmpty { return .unreadable }
        let allKnown = words.allSatisfy { restWords.contains($0) || leaveWords.contains($0) || fillerWords.contains($0) }
        if allKnown && hasRestWord {
            if words.contains(where: { leaveWords.contains($0) }) { return .rest(.leave) }
            return .rest(.rest)
        }
        return .unreadable
    }

    // MARK: - En-têtes et titre

    private static let weekdayWords: [String: [Int]] = [
        "lundi": [0], "lun": [0], "lu": [0], "l": [0],
        "mardi": [1], "mar": [1], "ma": [1],
        "mercredi": [2], "mer": [2], "me": [2],
        "jeudi": [3], "jeu": [3], "je": [3], "j": [3],
        "vendredi": [4], "ven": [4], "ve": [4], "v": [4],
        "samedi": [5], "sam": [5], "sa": [5], "s": [5],
        "dimanche": [6], "dim": [6], "di": [6], "d": [6],
        "m": [1, 2]
    ]

    private static let monthNames: [String] = [
        "janvier", "fevrier", "mars", "avril", "mai", "juin",
        "juillet", "aout", "septembre", "octobre", "novembre", "decembre"
    ]

    /// Numéro de mois (1 à 12) d'un mot replié : "nov", "novembre", "janv". Nil si ambigu ou inconnu.
    static func monthNumber(_ token: String) -> Int? {
        if token.count < 3 { return nil }
        var found: Int? = nil
        for (index, name) in monthNames.enumerated() {
            if name.hasPrefix(token) {
                if found != nil { return nil }
                found = index + 1
            }
        }
        return found
    }

    private static func smallInt(_ s: String, _ maxValue: Int) -> Int? {
        if s.count > 2 { return nil }
        guard let n = Int(s), n >= 1, n <= maxValue else { return nil }
        return n
    }

    private static func yearValue(_ s: String) -> Int? {
        if s.count != 4 { return nil }
        guard let y = Int(s), y >= 2000, y <= 2100 else { return nil }
        return y
    }

    static func parseDayHeader(_ text: String) -> ScheduleDayHeader? {
        let t = tokens(text)
        guard let first = t.first, let days = weekdayWords[first] else { return nil }
        var dayOfMonth: Int? = nil
        var month: Int? = nil
        var index = 1
        while index < t.count {
            let token = t[index]
            if let n = smallInt(token, 31) {
                if dayOfMonth == nil {
                    dayOfMonth = n
                } else if month == nil && n <= 12 {
                    month = n
                } else {
                    return nil
                }
            } else if yearValue(token) != nil {
                // année ignorée
            } else if let m = monthNumber(token) {
                month = m
            } else {
                return nil
            }
            index += 1
        }
        if month != nil && dayOfMonth == nil { return nil }
        return ScheduleDayHeader(weekdays: days, dayOfMonth: dayOfMonth, month: month)
    }

    /// "Planning du 23 au 29 nov.", "Semaine du 23/11 au 29/11", "du 28 au 3 déc."
    static func parseWeekTitle(_ text: String) -> ScheduleWeekTitle? {
        let t = tokens(text)
        guard let duIndex = t.firstIndex(of: "du") else { return nil }
        var i = duIndex + 1
        guard i < t.count, let d1 = smallInt(t[i], 31) else { return nil }
        i += 1
        var m1: Int? = nil
        var year: Int? = nil
        if i < t.count {
            if let m = smallInt(t[i], 12) {
                m1 = m
                i += 1
            } else if let m = monthNumber(t[i]) {
                m1 = m
                i += 1
            }
        }
        if i < t.count, let y = yearValue(t[i]) {
            year = y
            i += 1
        }
        if i < t.count, t[i] == "au" || t[i] == "a" {
            i += 1
        }
        var d2: Int? = nil
        var m2: Int? = nil
        if i < t.count, let d = smallInt(t[i], 31) {
            d2 = d
            i += 1
            if i < t.count {
                if let m = smallInt(t[i], 12) {
                    m2 = m
                    i += 1
                } else if let m = monthNumber(t[i]) {
                    m2 = m
                    i += 1
                }
            }
            if year == nil, i < t.count, let y = yearValue(t[i]) {
                year = y
            }
        }
        var startMonth: Int? = m1
        if startMonth == nil, let end = m2 {
            if let endDay = d2, d1 > endDay {
                startMonth = end == 1 ? 12 : end - 1
            } else {
                startMonth = end
            }
        }
        if startMonth == nil && year == nil && d2 == nil { return nil }
        return ScheduleWeekTitle(day: d1, startMonth: startMonth, year: year)
    }

    // MARK: - Noms

    /// Nom replié, ponctuation retirée : "L.M." devient "l m".
    static func normalizeName(_ text: String) -> String {
        return tokens(text).joined(separator: " ")
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let x = Array(a)
        let y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous: [Int] = Array(0...y.count)
        for i in 1...x.count {
            var current: [Int] = [i]
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost))
            }
            previous = current
        }
        return previous[y.count]
    }

    /// Ressemblance entre un nom de ligne et les variantes du profil. Insensible aux accents et à la casse.
    static func nameScore(rowName: String, variants: [String]) -> Double {
        let rn = normalizeName(rowName)
        if rn.isEmpty { return 0 }
        let rt: [String] = rn.split(separator: " ").map { String($0) }
        let rc = rt.joined()
        var best = 0.0
        for variant in variants {
            let v = normalizeName(variant)
            let vt: [String] = v.split(separator: " ").map { String($0) }
            if vt.isEmpty { continue }
            let vc = vt.joined()
            var score = 0.0
            if rn == v || rc == vc {
                score = 1.0
            } else if vt.allSatisfy({ rt.contains($0) }) {
                score = 0.9
            } else if rt.count >= 2 && vc.count >= 2 && vc.count <= 3 && String(rt.compactMap { $0.first }) == vc {
                score = 0.8
            } else {
                var similar = false
                for vtok in vt where vtok.count >= 3 {
                    for rtok in rt where rtok.count >= 3 {
                        if editDistance(vtok, rtok) == 1 { similar = true }
                    }
                }
                if similar { score = 0.55 }
            }
            best = max(best, score)
        }
        return best
    }

    // MARK: - Dates

    private static func weekdayIndex(_ date: Date, _ cal: Calendar) -> Int {
        return (cal.component(.weekday, from: date) + 5) % 7
    }

    /// Date d'un jour du mois la plus proche de `near`, mois et année déduits si absents.
    private static func resolveDay(day: Int, month: Int?, year: Int?, near: Date, calendar cal: Calendar) -> Date? {
        let refYear = cal.component(.year, from: near)
        var years: [Int] = [refYear - 1, refYear, refYear + 1]
        if let y = year { years = [y] }
        var months: [Int] = Array(1...12)
        if let m = month { months = [m] }
        var best: Date? = nil
        var bestDistance = Double.infinity
        for y in years {
            for m in months {
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = day
                guard let d = cal.date(from: comps) else { continue }
                if cal.component(.day, from: d) != day || cal.component(.month, from: d) != m { continue }
                let startOfDay = cal.startOfDay(for: d)
                let distance = abs(startOfDay.timeIntervalSince(near))
                if distance < bestDistance {
                    bestDistance = distance
                    best = startOfDay
                }
            }
        }
        return best
    }

    private static func searchDate(day: Int, month: Int?, weekday: Int, anchor: Date, calendar cal: Calendar) -> Date? {
        var offsets: [Int] = [0]
        for step in 1...45 {
            offsets.append(step)
            offsets.append(-step)
        }
        for offset in offsets {
            guard let d = cal.date(byAdding: .day, value: offset, to: anchor) else { continue }
            if cal.component(.day, from: d) != day { continue }
            if weekdayIndex(d, cal) != weekday { continue }
            if let m = month, cal.component(.month, from: d) != m { continue }
            return cal.startOfDay(for: d)
        }
        return nil
    }

    private static func firstDate(onOrAfter start: Date, weekday: Int, calendar cal: Calendar) -> Date? {
        for offset in 0...6 {
            guard let d = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            if weekdayIndex(d, cal) == weekday { return cal.startOfDay(for: d) }
        }
        return nil
    }

    /// Instant d'une heure en minutes depuis minuit du jour `day` (1440 et plus : jours suivants).
    static func date(day: Date, minutes: Int, calendar: Calendar) -> Date {
        let extraDays = minutes / 1440
        let remainder = minutes % 1440
        var base = calendar.startOfDay(for: day)
        if extraDays > 0, let shifted = calendar.date(byAdding: .day, value: extraDays, to: base) {
            base = calendar.startOfDay(for: shifted)
        }
        if let d = calendar.date(bySettingHour: remainder / 60, minute: remainder % 60, second: 0, of: base) {
            return d
        }
        return base.addingTimeInterval(Double(remainder) * 60)
    }

    // MARK: - Grille

    private struct HeaderToken {
        let line: OCRTextLine
        let header: ScheduleDayHeader
    }

    private struct GridColumn {
        let weekday: Int
        let dayOfMonth: Int?
        let month: Int?
        let midX: Double
    }

    private struct GridRow {
        var name: String
        var cells: [Int: [OCRTextLine]]
        var lastY: Double
        var lines: [OCRTextLine]
    }

    private struct Grid {
        var columns: [GridColumn]
        var rows: [GridRow]
        var pitch: Double
        var layoutUncertain: Bool
        var strayCount: Int
        var isTransposed: Bool
    }

    private struct RowCluster {
        var lines: [OCRTextLine]
        var meanY: Double
    }

    private static func median(_ values: [Double]) -> Double {
        if values.isEmpty { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[mid] }
        return (sorted[mid - 1] + sorted[mid]) / 2
    }

    private static func clusterRows(_ lines: [OCRTextLine], tolerance: Double) -> [RowCluster] {
        let sorted = lines.sorted { $0.midY < $1.midY }
        var clusters: [RowCluster] = []
        for line in sorted {
            if let last = clusters.last, abs(line.midY - last.meanY) <= tolerance {
                var updated = last
                updated.lines.append(line)
                let total = updated.lines.reduce(0.0) { $0 + $1.midY }
                updated.meanY = total / Double(updated.lines.count)
                clusters[clusters.count - 1] = updated
            } else {
                clusters.append(RowCluster(lines: [line], meanY: line.midY))
            }
        }
        return clusters
    }

    private static func transposed(_ line: OCRTextLine) -> OCRTextLine {
        return OCRTextLine(text: line.text, minX: line.minY, minY: line.minX,
                           width: line.height, height: line.width, confidence: line.confidence)
    }

    private static func buildGrid(_ lines: [OCRTextLine], isTransposed: Bool) -> Grid? {
        if lines.isEmpty { return nil }
        var tolerance = 0.03
        if !isTransposed {
            tolerance = min(0.03, max(0.008, 0.6 * median(lines.map { $0.height })))
        }
        let clusters = clusterRows(lines, tolerance: tolerance)

        var bestIndex: Int? = nil
        var bestTokens: [HeaderToken] = []
        for (index, cluster) in clusters.enumerated() {
            var found: [HeaderToken] = []
            for line in cluster.lines {
                if let header = parseDayHeader(line.text) {
                    found.append(HeaderToken(line: line, header: header))
                }
            }
            if found.count > bestTokens.count {
                bestTokens = found
                bestIndex = index
            }
        }
        guard let headerIndex = bestIndex, bestTokens.count >= 3 else { return nil }

        let sortedTokens = bestTokens.sorted { $0.line.midX < $1.line.midX }
        var columns: [GridColumn] = []
        var previous: Int? = nil
        var uncertain = false
        for token in sortedTokens {
            let candidates = token.header.weekdays
            var chosen = candidates[0]
            if let p = previous {
                if candidates.contains(p + 1) {
                    chosen = p + 1
                } else if candidates.count > 1 {
                    chosen = candidates.first(where: { $0 > p }) ?? candidates[0]
                }
                if chosen <= p { uncertain = true }
            }
            columns.append(GridColumn(weekday: chosen, dayOfMonth: token.header.dayOfMonth,
                                      month: token.header.month, midX: token.line.midX))
            previous = chosen
        }

        var gaps: [Double] = []
        for k in 1..<columns.count {
            gaps.append(columns[k].midX - columns[k - 1].midX)
        }
        let pitch = median(gaps)
        if pitch < 0.005 { return nil }
        let boundary = columns[0].midX - pitch * 0.6

        var rows: [GridRow] = []
        var stray = 0
        // Une suite de case sur deux lignes ne se rattache que si elle est tout près de la ligne nommée au-dessus.
        let mergeGap: Double = isTransposed ? 0 : 2.5 * median(lines.map { $0.height })
        let headerY = clusters[headerIndex].meanY
        for cluster in clusters where cluster.meanY > headerY + 0.0001 {
            var nameLines: [OCRTextLine] = []
            var cells: [Int: [OCRTextLine]] = [:]
            for line in cluster.lines.sorted(by: { $0.midX < $1.midX }) {
                if line.midX < boundary {
                    nameLines.append(line)
                    continue
                }
                var nearest = 0
                var nearestDistance = Double.infinity
                for (k, column) in columns.enumerated() {
                    let d = abs(line.midX - column.midX)
                    if d < nearestDistance {
                        nearestDistance = d
                        nearest = k
                    }
                }
                if nearestDistance <= pitch * 0.6 {
                    var existing: [OCRTextLine] = cells[nearest] ?? []
                    existing.append(line)
                    cells[nearest] = existing
                } else {
                    stray += 1
                }
            }
            if nameLines.isEmpty {
                // Suite d'une case sur deux lignes : rattachée à la ligne nommée juste au-dessus.
                if var lastRow = rows.last, cluster.meanY - lastRow.lastY <= mergeGap {
                    lastRow.lastY = cluster.meanY
                    lastRow.lines.append(contentsOf: cluster.lines)
                    for (k, extra) in cells {
                        var existing: [OCRTextLine] = lastRow.cells[k] ?? []
                        existing.append(contentsOf: extra)
                        lastRow.cells[k] = existing
                    }
                    rows[rows.count - 1] = lastRow
                } else {
                    stray += cells.values.reduce(0) { $0 + $1.count }
                }
                continue
            }
            let name = nameLines.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            if name.contains("=") { continue }
            rows.append(GridRow(name: name, cells: cells, lastY: cluster.meanY, lines: cluster.lines))
        }
        if rows.isEmpty { return nil }
        return Grid(columns: columns, rows: rows, pitch: pitch, layoutUncertain: uncertain, strayCount: stray, isTransposed: isTransposed)
    }

    // MARK: - Analyse

    static func parse(lines: [OCRTextLine], options: ScheduleParseOptions) -> ScheduleParseResult {
        let clean = lines.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if clean.isEmpty { return ScheduleParseResult.failed(.noText) }

        let normalGrid = buildGrid(clean, isTransposed: false)
        let flippedGrid = buildGrid(clean.map { transposed($0) }, isTransposed: true)
        var chosenGrid: Grid? = normalGrid
        if let n = normalGrid, let f = flippedGrid {
            chosenGrid = f.columns.count > n.columns.count ? f : n
        } else if normalGrid == nil {
            chosenGrid = flippedGrid
        }
        guard let grid = chosenGrid else { return ScheduleParseResult.failed(.noHeader) }

        let cal = options.calendar
        var result = ScheduleParseResult()
        result.rowNames = grid.rows.map { $0.name }
        let ocrValues = clean.map { $0.confidence }
        result.averageConfidence = ocrValues.reduce(0.0, +) / Double(ocrValues.count)

        // Nom
        let variants: [String] = options.names.filter { !normalizeName($0).isEmpty }
        var candidates: [ScheduleNameCandidate] = []
        for (index, row) in grid.rows.enumerated() {
            let score = nameScore(rowName: row.name, variants: variants)
            if score >= 0.5 {
                candidates.append(ScheduleNameCandidate(rowIndex: index, name: row.name, score: score))
            }
        }
        candidates.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.rowIndex < b.rowIndex
        }
        result.candidates = candidates

        var chosen: Int? = nil
        var fuzzyName = false
        if let forced = options.forcedRowIndex, forced >= 0, forced < grid.rows.count {
            chosen = forced
        } else if candidates.count == 1 {
            chosen = candidates[0].rowIndex
            fuzzyName = candidates[0].score < 0.8
        } else if candidates.count >= 2 {
            result.needsLineChoice = true
            if candidates[0].score - candidates[1].score >= 0.2 {
                chosen = candidates[0].rowIndex
                fuzzyName = candidates[0].score < 0.8
            }
        }
        result.chosenRowIndex = chosen

        // Dates
        var title: ScheduleWeekTitle? = nil
        for line in clean.sorted(by: { $0.midY < $1.midY }) {
            if let t = parseWeekTitle(line.text) {
                title = t
                break
            }
        }
        let refDay = cal.startOfDay(for: options.referenceDate)
        var titleStart: Date? = nil
        if let t = title {
            titleStart = resolveDay(day: t.day, month: t.startMonth, year: t.year, near: refDay, calendar: cal)
        }
        let anchor = titleStart ?? refDay
        let daysToNextMonday = 7 - weekdayIndex(refDay, cal)
        let nextMonday = cal.date(byAdding: .day, value: daysToNextMonday + 7 * options.guessedWeekOffset, to: refDay) ?? refDay
        var columnDates: [Date] = []
        var guessed = false
        var headerMismatch = false
        for column in grid.columns {
            var found: Date? = nil
            if let d = column.dayOfMonth {
                found = searchDate(day: d, month: column.month, weekday: column.weekday, anchor: anchor, calendar: cal)
                if found == nil { headerMismatch = true }
            }
            if found == nil, let start = titleStart {
                found = firstDate(onOrAfter: start, weekday: column.weekday, calendar: cal)
            }
            if found == nil {
                guessed = true
                let d = cal.date(byAdding: .day, value: column.weekday, to: nextMonday) ?? nextMonday
                found = cal.startOfDay(for: d)
            }
            columnDates.append(found ?? refDay)
        }
        result.datesGuessed = guessed
        if let firstColumn = grid.columns.first, let firstColumnDate = columnDates.first {
            result.weekStart = cal.date(byAdding: .day, value: -firstColumn.weekday, to: firstColumnDate)
        }
        if guessed {
            result.warnings.append("Je n'ai pas trouvé les dates sur la photo, j'ai pris la semaine du prochain lundi.")
        }
        if headerMismatch {
            result.warnings.append("Un numéro de jour de l'en-tête ne colle pas avec son jour de la semaine.")
        }
        if grid.layoutUncertain {
            result.warnings.append("Les jours de l'en-tête sont dans un ordre inhabituel.")
        }
        if grid.strayCount > 0 {
            result.warnings.append("Du texte hors des colonnes a été ignoré.")
        }

        guard let rowIndex = chosen else {
            if candidates.isEmpty { result.failure = .nameNotFound }
            return result
        }
        let row = grid.rows[rowIndex]
        if !row.lines.isEmpty {
            let minX = row.lines.map { $0.minX }.min() ?? 0
            let maxX = row.lines.map { $0.minX + $0.width }.max() ?? 1
            let minY = row.lines.map { $0.minY }.min() ?? 0
            let maxY = row.lines.map { $0.minY + $0.height }.max() ?? 1
            let pad = 0.008
            let x0 = max(0.0, minX - pad)
            let y0 = max(0.0, minY - pad)
            let w = min(1.0, maxX + pad) - x0
            let h = min(1.0, maxY + pad) - y0
            if grid.isTransposed {
                result.highlight = NormalizedRect(x: y0, y: x0, width: h, height: w)
            } else {
                result.highlight = NormalizedRect(x: x0, y: y0, width: w, height: h)
            }
        }

        for (k, column) in grid.columns.enumerated() {
            let day = columnDates[k]
            let cellLines: [OCRTextLine] = (row.cells[k] ?? []).sorted { a, b in
                if abs(a.midY - b.midY) > 0.0001 { return a.midY < b.midY }
                return a.midX < b.midX
            }
            let text = cellLines.map { $0.text }.joined(separator: " ")
            let content = parseCell(text)
            let ocrConfidence = cellLines.map { $0.confidence }.min() ?? 1.0
            var maxOffset = 0.0
            for line in cellLines {
                maxOffset = max(maxOffset, abs(line.midX - column.midX) / grid.pitch)
            }
            switch content {
            case .empty:
                result.emptyCellCount += 1
            case .rest(let kind):
                result.restDays.append(ParsedRestDay(day: day, kind: kind))
            case .unreadable:
                result.unreadable.append(UnreadableCell(day: day, rawText: text))
            case .shifts(let ranges):
                for range in ranges {
                    var confidence = ocrConfidence
                    var reasons: [String] = []
                    if guessed {
                        confidence = min(confidence, 0.5)
                        reasons.append("Les dates ne sont pas sur la photo, vérifie le jour.")
                    }
                    if grid.layoutUncertain {
                        confidence = min(confidence, 0.5)
                        reasons.append("Les colonnes de la photo sont dans un ordre bizarre.")
                    }
                    if range.durationMinutes > 720 {
                        confidence *= 0.6
                        reasons.append("Plus de 12 h d'affilée, regarde la photo avant de garder.")
                    }
                    if range.durationMinutes < 60 {
                        confidence *= 0.6
                        reasons.append("Moins d'une heure, regarde la photo avant de garder.")
                    }
                    if range.crossesMidnight {
                        confidence *= 0.85
                        reasons.append("La fin tombe le lendemain, vérifie.")
                    }
                    if fuzzyName {
                        confidence *= 0.65
                        reasons.append("Le nom de la ligne est écrit un peu différemment du tien.")
                    }
                    if maxOffset > 0.35 {
                        confidence *= 0.85
                        reasons.append("Le texte est entre deux colonnes.")
                    }
                    if ocrConfidence < 0.8 {
                        reasons.append("La lecture de cette case est peu nette.")
                    }
                    result.shifts.append(ParsedShift(day: day,
                                                     startMinutes: range.startMinutes,
                                                     endMinutes: range.endMinutes,
                                                     confidence: min(1.0, max(0.0, confidence)),
                                                     reason: reasons.first,
                                                     rawText: text,
                                                     crossesMidnight: range.crossesMidnight))
                }
            }
        }
        result.shifts.sort { a, b in
            if a.day != b.day { return a.day < b.day }
            return a.startMinutes < b.startMinutes
        }
        return result
    }
}
