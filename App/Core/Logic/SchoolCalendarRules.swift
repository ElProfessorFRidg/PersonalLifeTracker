import Foundation

/// Un jour férié (jour calculé, début de journée dans le calendrier donné).
struct PublicHoliday: Equatable, Identifiable {
    let day: Date
    let name: String
    var id: String { return "\(name)-\(day.timeIntervalSince1970)" }
}

/// Zone scolaire française (A, B ou C). Les vacances d'été, Toussaint et Noël sont communes aux trois.
enum SchoolZone: String, CaseIterable, Codable {
    case a = "A"
    case b = "B"
    case c = "C"

    var title: String { return "Zone \(rawValue)" }
}

/// Une plage de vacances ou de pause. Les jours sont écrits "yyyy-MM-dd" (premier et dernier jour sans cours, inclus).
/// `zone` vaut "A", "B", "C" ou "all" (toutes les zones). `isCustom` : saisie par l'utilisateur.
struct SchoolBreak: Equatable, Codable, Identifiable {
    var id: String
    var name: String
    var zone: String
    var startDay: String
    var endDay: String
    var note: String
    var isCustom: Bool

    init(id: String, name: String, zone: String, startDay: String, endDay: String, note: String = "", isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.zone = zone
        self.startDay = startDay
        self.endDay = endDay
        self.note = note
        self.isCustom = isCustom
    }
}

/// Une plage de vacances avec ses jours déjà lus.
struct BreakSpan: Equatable {
    let item: SchoolBreak
    let start: Date
    let end: Date
}

/// Contenu du fichier school_calendar.json.
struct SchoolCalendarData: Equatable, Codable {
    var source: String
    var verificationNote: String
    var breaks: [SchoolBreak]
}

/// Règles pures du calendrier scolaire (section 30) : jours fériés calculés, vacances en données.
enum SchoolCalendarRules {

    // MARK: Jours fériés

    /// Dimanche de Pâques (algorithme grégorien anonyme de Meeus/Jones/Butcher), début de journée dans `calendar`.
    static func easterSunday(year: Int, calendar: Calendar) -> Date {
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
        return makeDay(year: year, month: month, day: day, calendar: calendar)
    }

    /// Les jours fériés légaux de l'année, triés par date : 8 fixes (1 janvier, 1 mai, 8 mai, 14 juillet, 15 août,
    /// 1 novembre, 11 novembre, 25 décembre) et 4 liés à Pâques (Pâques, lundi de Pâques +1 jour, Ascension +39 jours,
    /// lundi de Pentecôte +50 jours). Source : Code du travail, article L3133-1.
    static func publicHolidays(year: Int, calendar: Calendar) -> [PublicHoliday] {
        var result: [PublicHoliday] = []
        let fixed: [(Int, Int, String)] = [
            (1, 1, "Jour de l'an"),
            (5, 1, "Fête du Travail"),
            (5, 8, "Victoire 1945"),
            (7, 14, "Fête nationale"),
            (8, 15, "Assomption"),
            (11, 1, "Toussaint"),
            (11, 11, "Armistice 1918"),
            (12, 25, "Noël")
        ]
        for item in fixed {
            result.append(PublicHoliday(day: makeDay(year: year, month: item.0, day: item.1, calendar: calendar), name: item.2))
        }
        let easter: Date = easterSunday(year: year, calendar: calendar)
        let moving: [(Int, String)] = [
            (0, "Pâques"),
            (1, "Lundi de Pâques"),
            (39, "Ascension"),
            (50, "Lundi de Pentecôte")
        ]
        for item in moving {
            if let d = calendar.date(byAdding: .day, value: item.0, to: easter) {
                result.append(PublicHoliday(day: calendar.startOfDay(for: d), name: item.1))
            }
        }
        result.sort { (x: PublicHoliday, y: PublicHoliday) -> Bool in return x.day < y.day }
        return result
    }

    /// Le jour férié de ce jour, s'il y en a un.
    static func holiday(on day: Date, calendar: Calendar) -> PublicHoliday? {
        let year: Int = calendar.component(.year, from: day)
        let start: Date = calendar.startOfDay(for: day)
        for h in publicHolidays(year: year, calendar: calendar) where h.day == start {
            return h
        }
        return nil
    }

    static func isPublicHoliday(_ day: Date, calendar: Calendar) -> Bool {
        return holiday(on: day, calendar: calendar) != nil
    }

    /// Les `count` prochains jours fériés à partir de `day` inclus (cherche sur l'année en cours et la suivante).
    static func upcomingHolidays(from day: Date, count: Int, calendar: Calendar) -> [PublicHoliday] {
        let start: Date = calendar.startOfDay(for: day)
        let year: Int = calendar.component(.year, from: start)
        var all: [PublicHoliday] = publicHolidays(year: year, calendar: calendar)
        all.append(contentsOf: publicHolidays(year: year + 1, calendar: calendar))
        var result: [PublicHoliday] = []
        for h in all where h.day >= start {
            if result.count >= count { break }
            result.append(h)
        }
        return result
    }

    // MARK: Jours en texte

    /// "2026-10-17" donne le début de ce jour. Nil si le texte n'est pas une date valide.
    static func parseDay(_ text: String, calendar: Calendar) -> Date? {
        let parts: [String] = text.split(separator: "-").map { String($0) }
        if parts.count != 3 { return nil }
        guard let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        if m < 1 || m > 12 || d < 1 || d > 31 { return nil }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        guard let date = calendar.date(from: comps) else { return nil }
        // Refuse "2026-02-31" : le calendrier le décale au mois suivant.
        let back: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        if back.year != y || back.month != m || back.day != d { return nil }
        return calendar.startOfDay(for: date)
    }

    /// Le jour de `date` au format "yyyy-MM-dd".
    static func dayText(_ date: Date, calendar: Calendar) -> String {
        let c: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let y: Int = c.year ?? 0
        let m: Int = c.month ?? 0
        let d: Int = c.day ?? 0
        return "\(y)-\(m < 10 ? "0" : "")\(m)-\(d < 10 ? "0" : "")\(d)"
    }

    private static func makeDay(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        let date: Date = calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
        return calendar.startOfDay(for: date)
    }

    // MARK: Vacances

    /// Vrai si la plage concerne cette zone. `zone` nil (zone inconnue) : seules les plages "all" comptent.
    static func applies(_ item: SchoolBreak, zone: SchoolZone?) -> Bool {
        if item.zone == "all" { return true }
        guard let zone = zone else { return false }
        return item.zone == zone.rawValue
    }

    /// Plages valides (jours lisibles, fin non avant début) pour la zone, triées par début.
    static func breaks(_ all: [SchoolBreak], zone: SchoolZone?, calendar: Calendar) -> [BreakSpan] {
        var result: [BreakSpan] = []
        for b in all where applies(b, zone: zone) {
            guard let s = parseDay(b.startDay, calendar: calendar), let e = parseDay(b.endDay, calendar: calendar) else { continue }
            if e < s { continue }
            result.append(BreakSpan(item: b, start: s, end: e))
        }
        result.sort { (x: BreakSpan, y: BreakSpan) -> Bool in return x.start < y.start }
        return result
    }

    /// La plage qui couvre ce jour (bornes incluses), si elle existe.
    static func breakCovering(_ day: Date, in all: [SchoolBreak], zone: SchoolZone?, calendar: Calendar) -> SchoolBreak? {
        let d: Date = calendar.startOfDay(for: day)
        for entry in breaks(all, zone: zone, calendar: calendar) where d >= entry.start && d <= entry.end {
            return entry.item
        }
        return nil
    }

    static func isSchoolBreak(_ day: Date, in all: [SchoolBreak], zone: SchoolZone?, calendar: Calendar) -> Bool {
        return breakCovering(day, in: all, zone: zone, calendar: calendar) != nil
    }

    /// La prochaine plage (ou celle en cours) dont la fin n'est pas passée.
    static func nextBreak(from day: Date, in all: [SchoolBreak], zone: SchoolZone?, calendar: Calendar) -> SchoolBreak? {
        let d: Date = calendar.startOfDay(for: day)
        for entry in breaks(all, zone: zone, calendar: calendar) where entry.end >= d {
            return entry.item
        }
        return nil
    }

    /// Plages qui touchent l'année civile donnée.
    static func breaks(inYear year: Int, in all: [SchoolBreak], zone: SchoolZone?, calendar: Calendar) -> [SchoolBreak] {
        var result: [SchoolBreak] = []
        for entry in breaks(all, zone: zone, calendar: calendar) {
            let ys: Int = calendar.component(.year, from: entry.start)
            let ye: Int = calendar.component(.year, from: entry.end)
            if ys == year || ye == year { result.append(entry.item) }
        }
        return result
    }

    /// Nombre de jours entre deux débuts de jour (négatif si `to` est avant `from`).
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        let a: Date = calendar.startOfDay(for: from)
        let b: Date = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    // MARK: Saisie d'une pause

    enum BreakValidation: Equatable {
        case valid
        case emptyName
        case endBeforeStart
    }

    static func validate(name: String, start: Date, end: Date, calendar: Calendar) -> BreakValidation {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyName }
        if calendar.startOfDay(for: end) < calendar.startOfDay(for: start) { return .endBeforeStart }
        return .valid
    }

    /// Texte "du 17 octobre au 1 novembre" (jours sans cours).
    static func rangeText(start: Date, end: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "d MMMM"
        return "du \(f.string(from: start)) au \(f.string(from: end))"
    }
}
