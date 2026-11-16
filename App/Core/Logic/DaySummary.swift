import Foundation

/// Une session vue par l'accueil : uniquement des valeurs simples, sans SwiftData.
struct DaySessionInput: Equatable {
    let id: UUID
    let start: Date
    /// nil = session en cours.
    let end: Date?
    let activity: ActivityType
    let chosenStart: Date?
    let chosenEnd: Date?

    init(id: UUID = UUID(), start: Date, end: Date?, activity: ActivityType, chosenStart: Date? = nil, chosenEnd: Date? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.activity = activity
        self.chosenStart = chosenStart
        self.chosenEnd = chosenEnd
    }
}

/// Total d'une activité sur une journée.
struct ActivityDayTotal: Equatable {
    /// Secondes retenues selon la base de calcul (exact si une borne est en doute sans choix, ou si une session tourne).
    let seconds: Int
    /// Secondes exactes de la journée pour cette activité.
    let exactSeconds: Int
    /// Nombre de sessions qui touchent la journée.
    let sessionCount: Int
    /// Vrai si une borne est en zone de doute sans choix : la valeur affichée est l'exacte, "à confirmer".
    let isProvisional: Bool
    /// Vrai si une session de cette activité est en cours.
    let hasLive: Bool
}

/// Ce que la carte "Maintenant" doit montrer.
enum NowDecision: Equatable {
    /// Une session tourne : demander si c'est bon ou l'arrêter.
    case confirmRunning(UUID)
    /// Une session finie a une borne en zone de doute sans choix.
    case chooseDoubt(UUID)
    /// Aucune session du tout : premier jour.
    case firstDay
    /// Rien à faire.
    case calm
}

/// Candidat pour la carte "Maintenant".
struct NowCandidate: Equatable {
    let id: UUID
    let start: Date
    let end: Date?
    let hasUnresolvedDoubt: Bool
}

/// Totaux de la journée et décision de la carte "Maintenant". Logique pure.
enum DaySummary {

    private static func dayBounds(day: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let s = calendar.startOfDay(for: day)
        let e = calendar.date(byAdding: .day, value: 1, to: s) ?? s.addingTimeInterval(86400)
        return (s, e)
    }

    private static func seconds(from a: Date, to b: Date) -> Int {
        return max(0, Int(b.timeIntervalSince(a).rounded()))
    }

    /// Vrai si la session recouvre la journée (la fin vaut `now` si elle tourne).
    static func overlapsDay(start: Date, end: Date?, day: Date, now: Date, calendar: Calendar) -> Bool {
        let b = dayBounds(day: day, calendar: calendar)
        let rawEnd: Date = end ?? now
        let s: Date = max(start, b.start)
        let e: Date = min(rawEnd, b.end)
        return e > s
    }

    /// Total d'une activité pour la journée `day`. Une session à cheval sur minuit ne compte que sa part du jour.
    /// Base heures pleines : bornes arrondies ou choisies, tronquées à la journée. Si une borne est en doute sans choix,
    /// la session compte sa valeur exacte et le total est provisoire. Une session en cours compte toujours son exact.
    static func total(activity: ActivityType,
                      day: Date,
                      inputs: [DaySessionInput],
                      base: CalculationBase,
                      now: Date,
                      calendar: Calendar) -> ActivityDayTotal {
        let b = dayBounds(day: day, calendar: calendar)
        var retained = 0
        var exact = 0
        var count = 0
        var provisional = false
        var live = false

        for input in inputs {
            if input.activity != activity { continue }
            let rawEnd: Date = input.end ?? now
            let exactStart: Date = max(input.start, b.start)
            let exactEnd: Date = min(rawEnd, b.end)
            if exactEnd <= exactStart { continue }

            count += 1
            let exactPart = seconds(from: exactStart, to: exactEnd)
            exact += exactPart

            if input.end == nil {
                live = true
                retained += exactPart
                continue
            }
            switch base {
            case .exact:
                retained += exactPart
            case .fullHours:
                let rs: Date? = SessionDurations.resolvedBound(exact: input.start, chosen: input.chosenStart, calendar: calendar)
                let re: Date? = SessionDurations.resolvedBound(exact: rawEnd, chosen: input.chosenEnd, calendar: calendar)
                if let rs = rs, let re = re {
                    let s: Date = max(rs, b.start)
                    let e: Date = min(re, b.end)
                    retained += seconds(from: s, to: e)
                } else {
                    provisional = true
                    retained += exactPart
                }
            }
        }
        return ActivityDayTotal(seconds: retained, exactSeconds: exact, sessionCount: count, isProvisional: provisional, hasLive: live)
    }

    /// Valeur de la tuile : "3 h 00", "0 h" quand il n'y a rien.
    static func tileValue(_ total: ActivityDayTotal) -> String {
        if total.seconds == 0 { return "0 h" }
        return Formatting.duration(seconds: total.seconds)
    }

    /// Note de la tuile.
    static func tileNote(_ total: ActivityDayTotal, base: CalculationBase) -> String {
        if total.sessionCount == 0 { return "Rien pour l'instant" }
        if total.isProvisional { return "À confirmer, exact \(Formatting.duration(seconds: total.exactSeconds))" }
        if total.hasLive { return "En cours" }
        if base == .fullHours && total.exactSeconds / 60 != total.seconds / 60 {
            return "Heures pleines, exact \(Formatting.duration(seconds: total.exactSeconds))"
        }
        if total.sessionCount == 1 { return "1 session" }
        return "\(total.sessionCount) sessions"
    }

    /// Décision de la carte "Maintenant". Priorité : session en cours (la plus récente), puis doute à lever
    /// sur une session finie (la plus récente), puis premier jour si aucune session n'existe, sinon calme.
    static func decideNow(candidates: [NowCandidate]) -> NowDecision {
        var running: NowCandidate?
        for c in candidates where c.end == nil {
            if let r = running {
                if c.start > r.start { running = c }
            } else {
                running = c
            }
        }
        if let r = running { return .confirmRunning(r.id) }

        var doubt: NowCandidate?
        for c in candidates where c.end != nil && c.hasUnresolvedDoubt {
            if let d = doubt {
                if c.start > d.start { doubt = c }
            } else {
                doubt = c
            }
        }
        if let d = doubt { return .chooseDoubt(d.id) }

        if candidates.isEmpty { return .firstDay }
        return .calm
    }
}
