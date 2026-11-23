import Foundation

/// Une pause à l'intérieur d'une session (fin nil = pause en cours).
struct BreakInterval: Equatable {
    let start: Date
    let end: Date?
}

/// Réglage du module Pauses (section 32). Jamais imposé.
enum BreakMode: String, CaseIterable, Identifiable {
    case none
    case info
    case reminder

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .none: return "Aucune"
        case .info: return "Info"
        case .reminder: return "Rappel"
        }
    }

    var explanation: String {
        switch self {
        case .none: return "L'app ne dit rien sur les pauses."
        case .info: return "Les repères sur les pauses sont consultables, rien n'est envoyé."
        case .reminder: return "Une notification douce, une seule par session."
        }
    }
}

/// Règles pures des pauses : durée déduite, durée nette, date du rappel.
enum BreaksRules {

    // MARK: Constantes (origine entre parenthèses)

    /// Rappel après X heures sans coupure, défaut 6 h. Origine : exemple de la spec 32 ("Ça fait 6 h que t'enchaînes").
    static let defaultReminderHours: Double = 6
    /// Bornes du réglage du rappel. Origine : mon choix.
    static let minReminderHours: Double = 2
    static let maxReminderHours: Double = 10

    /// Repère légal affiché à titre d'information seulement, jamais appliqué ni présenté comme obligatoire.
    /// Origine : règle générale du Code du travail (20 minutes consécutives dès 6 heures de travail), À VÉRIFIER :
    /// la spec interdit les montants légaux en dur, donc ceci est une constante d'information, pas une règle de calcul.
    static let legalReminderThresholdHours: Int = 6
    static let legalReminderBreakMinutes: Int = 20

    /// Texte d'information, toujours marqué "à vérifier".
    static var legalReminderText: String {
        return "Repère général : \(legalReminderBreakMinutes) min de pause dès \(legalReminderThresholdHours) h de travail d'affilée (à vérifier). "
            + "Ton contrat ou ta convention peut prévoir autre chose. Ce n'est pas un conseil juridique."
    }

    // MARK: Durées

    /// Pauses réduites à la session, triées et fusionnées (deux pauses qui se chevauchent comptent une fois).
    /// Une pause en cours s'arrête à `now`. Une session en cours s'arrête à `now`.
    static func mergedIntervals(breaks: [BreakInterval], sessionStart: Date, sessionEnd: Date?, now: Date) -> [DateInterval] {
        let limit: Date = sessionEnd ?? now
        var clamped: [DateInterval] = []
        for b in breaks {
            let rawEnd: Date = b.end ?? now
            let s: Date = max(b.start, sessionStart)
            let e: Date = min(rawEnd, limit)
            if e > s {
                clamped.append(DateInterval(start: s, end: e))
            }
        }
        clamped.sort { (a: DateInterval, b: DateInterval) -> Bool in return a.start < b.start }
        var merged: [DateInterval] = []
        for interval in clamped {
            if let last = merged.last, interval.start <= last.end {
                let newEnd: Date = max(last.end, interval.end)
                merged[merged.count - 1] = DateInterval(start: last.start, end: newEnd)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// Total des pauses en secondes, arrondi à la minute inférieure (précision d'au moins la minute, section 13.1).
    static func breakSeconds(breaks: [BreakInterval], sessionStart: Date, sessionEnd: Date?, now: Date) -> Int {
        let merged: [DateInterval] = mergedIntervals(breaks: breaks, sessionStart: sessionStart, sessionEnd: sessionEnd, now: now)
        var total: Double = 0
        for interval in merged {
            total += interval.duration
        }
        let minutes: Int = Int(total) / 60
        return minutes * 60
    }

    /// Secondes déduites du temps de travail : tout si la pause est non payée, rien si elle est payée.
    static func deductedSeconds(breaks: [BreakInterval], sessionStart: Date, sessionEnd: Date?, now: Date, isPaid: Bool) -> Int {
        if isPaid { return 0 }
        return breakSeconds(breaks: breaks, sessionStart: sessionStart, sessionEnd: sessionEnd, now: now)
    }

    /// Durée nette : durée retenue (base choisie) moins la part déduite, jamais négative.
    static func netSeconds(retainedSeconds: Int, deductedSeconds: Int) -> Int {
        return max(0, retainedSeconds - max(0, deductedSeconds))
    }

    // MARK: Rappel

    /// Instant du rappel : X heures après la dernière coupure (ou le début de session).
    /// Nil si une pause est en cours (pas de rappel pendant une pause) ou si la session est finie.
    static func reminderDate(sessionStart: Date, sessionEnd: Date?, breaks: [BreakInterval], afterHours: Double) -> Date? {
        if sessionEnd != nil { return nil }
        var lastCut: Date = sessionStart
        for b in breaks {
            guard let end = b.end else { return nil }
            if end > lastCut { lastCut = end }
        }
        let hours: Double = min(max(afterHours, minReminderHours), maxReminderHours)
        return lastCut.addingTimeInterval(hours * 3600)
    }

    /// "6 h" pour 6, "6 h 30" pour 6,5.
    static func hoursLabel(_ hours: Double) -> String {
        let minutes: Int = Int((hours * 60).rounded())
        if minutes % 60 == 0 {
            return "\(minutes / 60) h"
        }
        return Formatting.duration(minutes: minutes)
    }

    /// Message du rappel, ton non culpabilisant (spec 32).
    static func reminderMessage(hours: Double) -> String {
        return "Ça fait \(hoursLabel(hours)) que t'enchaînes, une pause si t'as le droit ?"
    }

    /// Une pause manuelle est valide si elle finit après son début et reste dans la session.
    static func isValidManualBreak(start: Date, end: Date, sessionStart: Date, sessionEnd: Date?, now: Date) -> Bool {
        if end <= start { return false }
        if start < sessionStart { return false }
        let limit: Date = sessionEnd ?? now
        return end <= limit
    }
}
