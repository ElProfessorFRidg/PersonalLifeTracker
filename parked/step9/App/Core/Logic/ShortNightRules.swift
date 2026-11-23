import Foundation

/// Une session ou un créneau de travail ou de cours, réel ou prévu, sous forme pure.
struct ShortNightSlot: Equatable {
    let start: Date
    let end: Date
}

/// Résultat du calcul : la nuit entre la dernière fin et le prochain début.
struct ShortNightResult: Equatable {
    let lastEnd: Date
    let nextStart: Date
    /// Temps entre les deux, en minutes entières : c'est un maximum pour dormir.
    let restMinutes: Int
    let thresholdMinutes: Int

    var isShort: Bool { return restMinutes < thresholdMinutes }
}

/// Règles pures de l'alerte nuit courte (section 33). Foundation seulement.
/// Ce seuil est distinct du repos minimal légal du pack de convention : il ne dit rien du droit du travail.
enum ShortNightRules {
    /// Seuil proposé par défaut : 8 h (section 33).
    static let defaultThresholdMinutes: Int = 8 * 60
    /// Bornes du réglage du seuil (choix de l'app) : de 4 h à 12 h.
    static let minThresholdMinutes: Int = 4 * 60
    static let maxThresholdMinutes: Int = 12 * 60
    /// La carte apparaît à partir de 17:00 la veille (choix de l'app).
    static let cardFromHour: Int = 17
    /// La notification part à 20:00 la veille (choix de l'app, hors heures silencieuses 22:00 à 05:00 de la détection).
    static let notifyHour: Int = 20
    /// Une "nuit" est un écart qui contient 03:00 en heure affichée (choix de l'app).
    static let nightMarkerHour: Int = 3
    /// Un écart de plus de 24 h n'est pas une nuit entre deux journées de travail.
    static let maxGapMinutes: Int = 24 * 60

    /// Vrai si l'écart [a, b] contient 03:00 en heure affichée.
    static func containsNight(from a: Date, to b: Date, calendar: Calendar) -> Bool {
        if b <= a { return false }
        var day: Date = calendar.startOfDay(for: a)
        // Au plus trois jours à regarder pour un écart de 24 h.
        for _ in 0..<3 {
            if let marker = calendar.date(bySettingHour: nightMarkerHour, minute: 0, second: 0, of: day) {
                if marker >= a && marker <= b { return true }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
            day = next
        }
        return false
    }

    /// Le prochain début après `now` qui suit une fin par une nuit, avec le repos calculé.
    /// Ignore les créneaux sans durée. Nil si rien ne permet de calculer (pas de fin connue avant le prochain début).
    static func nextNight(now: Date, slots: [ShortNightSlot], thresholdMinutes: Int, calendar: Calendar) -> ShortNightResult? {
        let valid: [ShortNightSlot] = slots.filter { $0.end > $0.start }
        let starts: [ShortNightSlot] = valid.sorted { (a: ShortNightSlot, b: ShortNightSlot) -> Bool in return a.start < b.start }
        for next in starts where next.start > now {
            // Dernière fin connue avant ce début.
            var lastEnd: Date? = nil
            for s in valid where s.end <= next.start && s.start < next.start {
                if let current = lastEnd {
                    if s.end > current { lastEnd = s.end }
                } else {
                    lastEnd = s.end
                }
            }
            guard let end = lastEnd else { continue }
            let gap: Int = Int(next.start.timeIntervalSince(end)) / 60
            if gap > maxGapMinutes { continue }
            if !containsNight(from: end, to: next.start, calendar: calendar) { continue }
            return ShortNightResult(lastEnd: end, nextStart: next.start, restMinutes: gap, thresholdMinutes: thresholdMinutes)
        }
        return nil
    }

    /// Le moment où la carte s'ouvre : `cardFromHour` la veille du jour du début.
    static func cardOpensAt(for result: ShortNightResult, calendar: Calendar) -> Date? {
        let startDay: Date = calendar.startOfDay(for: result.nextStart)
        guard let eve = calendar.date(byAdding: .day, value: -1, to: startDay) else { return nil }
        return calendar.date(bySettingHour: cardFromHour, minute: 0, second: 0, of: eve)
    }

    /// L'alerte à montrer maintenant : nuit courte, carte ouverte (à partir de la veille 17:00), début pas encore passé.
    static func alert(now: Date, slots: [ShortNightSlot], thresholdMinutes: Int, calendar: Calendar) -> ShortNightResult? {
        guard let result = nextNight(now: now, slots: slots, thresholdMinutes: thresholdMinutes, calendar: calendar) else { return nil }
        if !result.isShort { return nil }
        guard let opens = cardOpensAt(for: result, calendar: calendar) else { return nil }
        if now < opens || now >= result.nextStart { return nil }
        return result
    }

    /// L'instant de la notification : `notifyHour` la veille du début. Nil si déjà passé ou si `now` est après.
    static func notificationDate(for result: ShortNightResult, now: Date, calendar: Calendar) -> Date? {
        let startDay: Date = calendar.startOfDay(for: result.nextStart)
        guard let eve = calendar.date(byAdding: .day, value: -1, to: startDay),
              let fire = calendar.date(bySettingHour: notifyHour, minute: 0, second: 0, of: eve) else { return nil }
        if fire <= now { return nil }
        // Pas de notification s'il reste moins qu'une minute avant le début (cas d'un début pris la veille au soir).
        if fire >= result.nextStart { return nil }
        return fire
    }

    // MARK: Textes

    /// "Tu finis à 23:00 et tu reprends à 06:30 : 7 h 30 maximum pour dormir." Pas de conseil médical.
    static func message(_ result: ShortNightResult, calendar: Calendar) -> String {
        let end: String = Formatting.clock(result.lastEnd, calendar: calendar)
        let start: String = Formatting.clock(result.nextStart, calendar: calendar)
        let rest: String = Formatting.duration(minutes: result.restMinutes)
        return "Tu finis à \(end) et tu reprends à \(start) : \(rest) maximum pour dormir."
    }

    static let title: String = "Nuit courte en vue"
}
