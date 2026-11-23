import Foundation

// Règles pures du cycle de vie d'un contrat (sections 18 et 19). Foundation seulement.
// Aucune règle juridique (durée max d'un CDD, indemnité, essai) n'est codée ici : elles vivent dans
// Resources/reference/contracts.json (pas encore créé). Ici : dates, décomptes, statuts, rappels, validation.
// Toutes les fonctions prennent un Calendar explicite : les jours se comptent en jours calendaires, pas en 86 400 s.

enum ContractStatus: String, CaseIterable {
    case upcoming
    case trial
    case ongoing
    case endingSoon
    case ended

    var title: String {
        switch self {
        case .upcoming: return "À venir"
        case .trial: return "En période d'essai"
        case .ongoing: return "En cours"
        case .endingSoon: return "Bientôt terminé"
        case .ended: return "Terminé"
        }
    }
}

enum TrialStatus: Equatable {
    case none
    case notStarted
    case inProgress(daysLeft: Int)
    case finished
}

/// Un contrat réduit à ses dates, pour chercher le contrat actif sans dépendre de SwiftData.
struct ContractSpan: Equatable {
    let id: UUID
    let start: Date
    let end: Date?
}

enum ContractIssue: Equatable {
    case endBeforeStart
    case weeklyHoursInvalid
    case weeklyHoursImplausible
    case trialEndBeforeStart
    case trialEndAfterContractEnd
    case negativeRate
    case missingEnd(ContractKind)

    /// Bloquant : on n'enregistre pas. Sinon simple remarque.
    var isBlocking: Bool {
        switch self {
        case .missingEnd: return false
        case .endBeforeStart, .weeklyHoursInvalid, .weeklyHoursImplausible,
             .trialEndBeforeStart, .trialEndAfterContractEnd, .negativeRate:
            return true
        }
    }

    var message: String {
        switch self {
        case .endBeforeStart: return "La date de fin est avant la date de début."
        case .weeklyHoursInvalid: return "Mets un nombre d'heures par semaine supérieur à 0."
        case .weeklyHoursImplausible: return "Ça fait beaucoup d'heures par semaine. Vérifie ce que tu as saisi."
        case .trialEndBeforeStart: return "La fin de la période d'essai est avant le début du contrat."
        case .trialEndAfterContractEnd: return "La période d'essai finit après la fin du contrat."
        case .negativeRate: return "Le taux horaire ne peut pas être négatif."
        case .missingEnd(let kind): return "Un contrat de type \(kind.title) a en général une date de fin. Tu peux l'ajouter plus tard."
        }
    }
}

enum ReminderTarget: String, Equatable {
    case trialEnd
    case contractEnd
}

struct ContractReminder: Equatable {
    let target: ReminderTarget
    let daysBefore: Int
    let fireDate: Date
}

enum EndAction: String, CaseIterable {
    case prepareChecklist
    case renew
    case switchToCDI
}

/// Les informations qu'on reprend pour créer le contrat suivant.
struct ContractDraft: Equatable {
    var kind: ContractKind
    var startDate: Date
    var endDate: Date?
    var weeklyHours: Double
    var hourlyGrossRate: Double?
}

struct EndChecklistItem: Equatable {
    let id: String
    let title: String
    let purpose: String
}

enum ContractRules {
    /// Nombre de jours avant la fin à partir duquel un contrat est "bientôt terminé".
    static let endingSoonDays: Int = 14
    /// Au-delà, la saisie est probablement une erreur. Ce n'est PAS une durée légale.
    static let maxPlausibleWeeklyHours: Double = 80

    // MARK: Dates

    static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        return calendar.startOfDay(for: date)
    }

    /// Jours calendaires de `from` à `to` (négatif si `to` est avant `from`).
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        let a: Date = calendar.startOfDay(for: from)
        let b: Date = calendar.startOfDay(for: to)
        let comps: DateComponents = calendar.dateComponents([.day], from: a, to: b)
        return comps.day ?? 0
    }

    // MARK: Contrat actif

    /// Actif le jour `date` : début et fin inclus (le dernier jour, tu travailles encore).
    static func isActive(start: Date, end: Date?, at date: Date, calendar: Calendar) -> Bool {
        let today: Date = calendar.startOfDay(for: date)
        if today < calendar.startOfDay(for: start) { return false }
        if let end = end, today > calendar.startOfDay(for: end) { return false }
        return true
    }

    /// Index du contrat actif. Plusieurs actifs (chevauchement) : celui qui a commencé le plus récemment.
    static func activeIndex(in spans: [ContractSpan], at date: Date, calendar: Calendar) -> Int? {
        var best: Int? = nil
        for (index, span) in spans.enumerated() {
            if !isActive(start: span.start, end: span.end, at: date, calendar: calendar) { continue }
            if let current = best {
                if span.start >= spans[current].start { best = index }
            } else {
                best = index
            }
        }
        return best
    }

    // MARK: Décompte et avancement

    /// Jours restants jusqu'au dernier jour du contrat. 0 le dernier jour, négatif une fois terminé. nil sans date de fin.
    static func daysRemaining(end: Date?, now: Date, calendar: Calendar) -> Int? {
        guard let end = end else { return nil }
        return daysBetween(now, end, calendar: calendar)
    }

    /// Avancement entre 0 et 1, nil sans date de fin.
    static func progress(start: Date, end: Date?, now: Date, calendar: Calendar) -> Double? {
        guard let end = end else { return nil }
        let total: Int = daysBetween(start, end, calendar: calendar)
        if total <= 0 {
            return daysBetween(now, end, calendar: calendar) <= 0 ? 1 : 0
        }
        let elapsed: Int = daysBetween(start, now, calendar: calendar)
        let ratio: Double = Double(elapsed) / Double(total)
        return min(1, max(0, ratio))
    }

    /// "ton CDD", "ton stage"... pour les phrases de décompte.
    static func possessive(_ kind: ContractKind) -> String {
        switch kind {
        case .cdi: return "ton CDI"
        case .cdd: return "ton CDD"
        case .interim: return "ton contrat d'intérim"
        case .apprentissage: return "ton alternance"
        case .stage: return "ton stage"
        case .saisonnier: return "ton contrat saisonnier"
        case .autre: return "ton contrat"
        }
    }

    /// "Fin de ton CDD dans 23 jours". nil sans date de fin.
    static func countdownText(kind: ContractKind, end: Date?, now: Date, calendar: Calendar) -> String? {
        guard let days = daysRemaining(end: end, now: now, calendar: calendar) else { return nil }
        let noun: String = possessive(kind)
        if days < 0 { return "C'est fini pour \(noun)" }
        if days == 0 { return "Dernier jour de \(noun)" }
        if days == 1 { return "Fin de \(noun) demain" }
        return "Fin de \(noun) dans \(days) jours"
    }

    // MARK: Période d'essai et statut

    static func trialStatus(start: Date, trialEnd: Date?, now: Date, calendar: Calendar) -> TrialStatus {
        guard let trialEnd = trialEnd else { return .none }
        let today: Date = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: start) { return .notStarted }
        if today > calendar.startOfDay(for: trialEnd) { return .finished }
        return .inProgress(daysLeft: daysBetween(now, trialEnd, calendar: calendar))
    }

    static func status(start: Date, end: Date?, trialEnd: Date?, now: Date, calendar: Calendar) -> ContractStatus {
        let today: Date = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: start) { return .upcoming }
        if let end = end, today > calendar.startOfDay(for: end) { return .ended }
        if let trialEnd = trialEnd, today <= calendar.startOfDay(for: trialEnd) { return .trial }
        if let end = end, daysBetween(now, end, calendar: calendar) <= endingSoonDays { return .endingSoon }
        return .ongoing
    }

    // MARK: Rappels

    /// Rappels à venir (jamais dans le passé), triés par date. Pas de rappel de fin pour un CDI.
    /// Les décalages (7 et 2 jours avant l'essai, 14 et 3 avant la fin) sont ceux de la section 19 et se configurent.
    static func reminders(kind: ContractKind,
                          end: Date?,
                          trialEnd: Date?,
                          now: Date,
                          calendar: Calendar,
                          trialOffsets: [Int] = [7, 2],
                          endOffsets: [Int] = [14, 3],
                          hour: Int = 9) -> [ContractReminder] {
        var result: [ContractReminder] = []
        if let trialEnd = trialEnd {
            for n in trialOffsets {
                if let fire = fireDate(daysBefore: n, of: trialEnd, hour: hour, calendar: calendar), fire > now {
                    result.append(ContractReminder(target: .trialEnd, daysBefore: n, fireDate: fire))
                }
            }
        }
        if let end = end, kind != .cdi {
            for n in endOffsets {
                if let fire = fireDate(daysBefore: n, of: end, hour: hour, calendar: calendar), fire > now {
                    result.append(ContractReminder(target: .contractEnd, daysBefore: n, fireDate: fire))
                }
            }
        }
        return result.sorted { (a: ContractReminder, b: ContractReminder) -> Bool in
            return a.fireDate < b.fireDate
        }
    }

    private static func fireDate(daysBefore: Int, of target: Date, hour: Int, calendar: Calendar) -> Date? {
        let day: Date = calendar.startOfDay(for: target)
        guard let shifted = calendar.date(byAdding: .day, value: -daysBefore, to: day) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: shifted)
    }

    // MARK: Validation

    static func validate(kind: ContractKind,
                         start: Date,
                         end: Date?,
                         weeklyHours: Double,
                         trialEnd: Date?,
                         hourlyRate: Double?,
                         calendar: Calendar) -> [ContractIssue] {
        var issues: [ContractIssue] = []
        let startDay: Date = calendar.startOfDay(for: start)
        if let end = end, calendar.startOfDay(for: end) < startDay {
            issues.append(.endBeforeStart)
        }
        if !weeklyHours.isFinite || weeklyHours <= 0 {
            issues.append(.weeklyHoursInvalid)
        } else if weeklyHours > maxPlausibleWeeklyHours {
            issues.append(.weeklyHoursImplausible)
        }
        if let trialEnd = trialEnd {
            let trialDay: Date = calendar.startOfDay(for: trialEnd)
            if trialDay < startDay {
                issues.append(.trialEndBeforeStart)
            }
            if let end = end, trialDay > calendar.startOfDay(for: end) {
                issues.append(.trialEndAfterContractEnd)
            }
        }
        if let rate = hourlyRate, rate < 0 || !rate.isFinite {
            issues.append(.negativeRate)
        }
        if end == nil {
            switch kind {
            case .cdd, .saisonnier, .stage, .interim:
                issues.append(.missingEnd(kind))
            case .cdi, .apprentissage, .autre:
                break
            }
        }
        return issues
    }

    static func hasBlockingIssue(_ issues: [ContractIssue]) -> Bool {
        for issue in issues where issue.isBlocking { return true }
        return false
    }

    // MARK: Fin de contrat

    /// Ce que l'app propose selon le statut. Rien pour un CDI en cours.
    static func proposedActions(kind: ContractKind, status: ContractStatus) -> [EndAction] {
        switch status {
        case .ended:
            if kind == .cdi { return [.prepareChecklist] }
            return [.prepareChecklist, .renew, .switchToCDI]
        case .endingSoon:
            if kind == .cdi { return [] }
            return [.renew, .switchToCDI, .prepareChecklist]
        case .upcoming, .trial, .ongoing:
            return []
        }
    }

    /// Renouvellement : commence le lendemain de la fin, même durée, mêmes heures et même taux, sans essai.
    /// Sans date de fin, commence à `now`.
    static func renewalDraft(from draft: ContractDraft, now: Date, calendar: Calendar) -> ContractDraft {
        var next: ContractDraft = draft
        guard let end = draft.endDate else {
            next.startDate = calendar.startOfDay(for: now)
            return next
        }
        let endDay: Date = calendar.startOfDay(for: end)
        let length: Int = daysBetween(draft.startDate, end, calendar: calendar)
        let newStart: Date = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        next.startDate = newStart
        next.endDate = calendar.date(byAdding: .day, value: max(0, length), to: newStart)
        return next
    }

    /// Passage en CDI : commence le lendemain de la fin, sans date de fin, mêmes heures et même taux.
    static func cdiDraft(from draft: ContractDraft, now: Date, calendar: Calendar) -> ContractDraft {
        var next: ContractDraft = draft
        next.kind = .cdi
        next.endDate = nil
        if let end = draft.endDate {
            let endDay: Date = calendar.startOfDay(for: end)
            next.startDate = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        } else {
            next.startDate = calendar.startOfDay(for: now)
        }
        return next
    }

    // MARK: Checklist

    static let endChecklist: [EndChecklistItem] = [
        EndChecklistItem(id: "certificat", title: "Certificat de travail", purpose: "Prouve ce que tu as fait chez cet employeur."),
        EndChecklistItem(id: "solde", title: "Solde de tout compte", purpose: "Récapitule ce qu'on te doit à la fin."),
        EndChecklistItem(id: "france_travail", title: "Attestation pour France Travail", purpose: "Utile si tu demandes des allocations."),
        EndChecklistItem(id: "fiche_paie", title: "Dernière fiche de paie", purpose: "Pour comparer avec mes estimations."),
        EndChecklistItem(id: "conges", title: "Relevé des congés non pris", purpose: "Pour être sûr que rien ne saute."),
        EndChecklistItem(id: "materiel", title: "Restitution du matériel", purpose: "Badge, clés, tenue si besoin."),
        EndChecklistItem(id: "export", title: "Export du relevé d'heures final", purpose: "Ta preuve à toi, si on te la demande."),
    ]

    /// Nombre de cases cochées parmi les lignes connues (un identifiant inconnu ne compte pas).
    static func checklistDoneCount(checkedIDs: [String]) -> Int {
        let known: Set<String> = Set(endChecklist.map { $0.id })
        return Set(checkedIDs).intersection(known).count
    }
}
