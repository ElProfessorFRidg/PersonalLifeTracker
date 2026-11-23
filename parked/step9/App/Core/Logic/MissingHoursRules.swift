import Foundation

/// Un créneau prévu, avec son lieu éventuel.
struct MissingShift: Equatable {
    let slot: PlanSlot
    let placeUID: UUID?
}

/// Un contrat actif, réduit à ce que la détection utilise.
struct MissingContract: Equatable {
    let id: UUID
    let start: Date
    let end: Date?
    let weeklyHours: Double
}

enum MissingKind: String, Equatable {
    /// Créneau prévu sans aucune session correspondante.
    case unloggedShift
    /// Une partie du créneau prévu n'a pas de session.
    case partialShift
    /// Long trou entre deux sessions de travail d'une même journée, hors créneau prévu.
    case longGap
    /// Contrat actif sans aucune session sur toute la période observée.
    case emptyContract
}

/// Un élément à vérifier. `start` et `end` sont nil pour un contrat sans session (aucun horaire à préremplir).
struct MissingItem: Equatable, Identifiable {
    let id: String
    let kind: MissingKind
    let day: Date
    let start: Date?
    let end: Date?
    let activity: ActivityType
    let placeUID: UUID?

    /// Durée à ajouter en minutes, 0 si inconnue.
    var minutes: Int {
        guard let s = start, let e = end else { return 0 }
        return max(0, Int(e.timeIntervalSince(s)) / 60)
    }
}

/// Détection d'heures manquantes (section 86). Logique pure, Foundation seulement.
/// Jamais d'ajout silencieux : ce fichier ne fait que proposer.
enum MissingHoursRules {

    // MARK: Seuils (origine entre parenthèses)

    /// On ne regarde que les 7 derniers jours : "pas de relance au-delà de quelques jours" (spec 86).
    /// Le chiffre 7 est mon choix, aligné sur PlannedWorkReview.
    static let lookbackDays: Int = 7
    /// Un trou de moins d'une heure dans un créneau prévu est ignoré (pauses, écarts de détection).
    /// Origine : mon choix, identique à PlannedWorkReview.gaps.
    static let minGapMinutes: Int = 60
    /// Un trou de 4 h ou plus entre deux sessions de travail d'une même journée, sans créneau prévu, est signalé.
    /// Origine : mon choix.
    static let longGapHours: Int = 4
    /// Heures hebdomadaires minimales d'un contrat pour attendre des sessions. Origine : mon choix.
    static let minContractWeeklyHours: Double = 1
    /// Les réponses "Ignorer" sont oubliées après 30 jours. Origine : mon choix.
    static let ignoreRetentionDays: Int = 30

    // MARK: Détection

    /// Tous les éléments à vérifier, du plus récent au plus ancien, sans ceux déjà ignorés.
    /// - Parameters:
    ///   - shifts: créneaux prévus (planning importé ou saisi).
    ///   - sessions: sessions réelles (toutes activités, fin nil = en cours).
    ///   - leaveDays: congés, en intervalles de jours entiers.
    ///   - contracts: contrats (pour le cas "aucune session du tout").
    ///   - ignoredIDs: identifiants déjà ignorés.
    static func detect(shifts: [MissingShift],
                       sessions: [RealSlot],
                       leaveDays: [DateInterval],
                       contracts: [MissingContract],
                       ignoredIDs: Set<String>,
                       now: Date,
                       calendar: Calendar) -> [MissingItem] {
        var items: [MissingItem] = []
        items.append(contentsOf: shiftItems(shifts: shifts, sessions: sessions, leaveDays: leaveDays, now: now, calendar: calendar))
        items.append(contentsOf: longGapItems(shifts: shifts, sessions: sessions, leaveDays: leaveDays, now: now, calendar: calendar))
        items.append(contentsOf: emptyContractItems(shifts: shifts, sessions: sessions, leaveDays: leaveDays,
                                                    contracts: contracts, now: now, calendar: calendar))
        let kept: [MissingItem] = items.filter { (i: MissingItem) -> Bool in return !ignoredIDs.contains(i.id) }
        return kept.sorted { (a: MissingItem, b: MissingItem) -> Bool in
            if a.day != b.day { return a.day > b.day }
            let sa: Date = a.start ?? a.day
            let sb: Date = b.start ?? b.day
            if sa != sb { return sa < sb }
            return a.id < b.id
        }
    }

    /// Identifiant stable d'un trou dans un créneau (même forme que PlannedWorkReviewSection, pour que
    /// un "Ignorer" déjà donné ailleurs reste valable).
    static func shiftGapID(shiftID: UUID, interval: DateInterval) -> String {
        return "\(shiftID):\(interval.start.timeIntervalSinceReferenceDate):\(interval.end.timeIntervalSinceReferenceDate)"
    }

    // MARK: Créneaux prévus

    static func shiftItems(shifts: [MissingShift], sessions: [RealSlot], leaveDays: [DateInterval],
                           now: Date, calendar: Calendar) -> [MissingItem] {
        var result: [MissingItem] = []
        for shift in shifts {
            let gaps: [DateInterval] = PlannedWorkReview.gaps(in: shift.slot, sessions: sessions, leaveDays: leaveDays,
                                                              now: now, calendar: calendar)
            for gap in gaps {
                let whole: Bool = gap.start == shift.slot.start && gap.end == shift.slot.end
                let item: MissingItem = MissingItem(id: shiftGapID(shiftID: shift.slot.id, interval: gap),
                                                    kind: whole ? MissingKind.unloggedShift : MissingKind.partialShift,
                                                    day: calendar.startOfDay(for: gap.start),
                                                    start: gap.start,
                                                    end: gap.end,
                                                    activity: shift.slot.activity,
                                                    placeUID: shift.placeUID)
                result.append(item)
            }
        }
        return result
    }

    // MARK: Long trou dans une journée

    static func longGapItems(shifts: [MissingShift], sessions: [RealSlot], leaveDays: [DateInterval],
                             now: Date, calendar: Calendar) -> [MissingItem] {
        let today: Date = calendar.startOfDay(for: now)
        guard let earliest = calendar.date(byAdding: .day, value: -lookbackDays, to: today) else { return [] }
        let minGap: TimeInterval = Double(longGapHours) * 3600
        let finished: [RealSlot] = sessions
            .filter { (s: RealSlot) -> Bool in return s.activity == .work && s.end != nil }
            .sorted { (a: RealSlot, b: RealSlot) -> Bool in return a.start < b.start }
        var result: [MissingItem] = []
        if finished.count < 2 { return result }
        for index in 0..<(finished.count - 1) {
            let first: RealSlot = finished[index]
            let second: RealSlot = finished[index + 1]
            guard let firstEnd = first.end else { continue }
            if second.start.timeIntervalSince(firstEnd) < minGap { continue }
            // Même journée : la fin de la première et le début de la seconde tombent le même jour.
            if !calendar.isDate(firstEnd, inSameDayAs: second.start) { continue }
            let day: Date = calendar.startOfDay(for: firstEnd)
            if day < earliest || day >= today { continue }
            let gap: DateInterval = DateInterval(start: firstEnd, end: second.start)
            if leaveDays.contains(where: { (l: DateInterval) -> Bool in return l.start < gap.end && l.end > gap.start }) { continue }
            // Un trou qui touche un créneau prévu est déjà géré par la règle des créneaux.
            let overlapsShift: Bool = shifts.contains(where: { (s: MissingShift) -> Bool in
                return s.slot.start < gap.end && s.slot.end > gap.start
            })
            if overlapsShift { continue }
            let id: String = "gap:\(gap.start.timeIntervalSinceReferenceDate):\(gap.end.timeIntervalSinceReferenceDate)"
            result.append(MissingItem(id: id, kind: .longGap, day: day, start: gap.start, end: gap.end,
                                      activity: .work, placeUID: nil))
        }
        return result
    }

    // MARK: Contrat sans aucune session

    /// Un contrat actif sur toute la période observée, sans créneau prévu, sans congé et sans aucune session :
    /// un seul élément (pas de déduction des habitudes sans planning, spec 86).
    static func emptyContractItems(shifts: [MissingShift], sessions: [RealSlot], leaveDays: [DateInterval],
                                   contracts: [MissingContract], now: Date, calendar: Calendar) -> [MissingItem] {
        let today: Date = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: today) else { return [] }
        let window: DateInterval = DateInterval(start: windowStart, end: today)
        let anyShift: Bool = shifts.contains(where: { (s: MissingShift) -> Bool in
            return s.slot.start < window.end && s.slot.end > window.start
        })
        if anyShift { return [] }
        let anyLeave: Bool = leaveDays.contains(where: { (l: DateInterval) -> Bool in
            return l.start < window.end && l.end > window.start
        })
        if anyLeave { return [] }
        let anySession: Bool = sessions.contains(where: { (s: RealSlot) -> Bool in
            let end: Date = s.end ?? now
            return s.start < window.end && end > window.start
        })
        if anySession { return [] }
        let weekRef: Date = PlanningRules.weekStart(for: window.end.addingTimeInterval(-1), calendar: calendar)
        var result: [MissingItem] = []
        for contract in contracts {
            if contract.weeklyHours < minContractWeeklyHours { continue }
            if contract.start > window.start { continue }
            if let end = contract.end, end < window.end { continue }
            let id: String = "contract:\(contract.id):\(weekRef.timeIntervalSinceReferenceDate)"
            result.append(MissingItem(id: id, kind: .emptyContract, day: calendar.startOfDay(for: window.end.addingTimeInterval(-1)),
                                      start: nil, end: nil, activity: .work, placeUID: nil))
        }
        return result
    }

    // MARK: Textes

    static func title(for item: MissingItem) -> String {
        switch item.kind {
        case .unloggedShift: return "Rien de noté sur ce créneau prévu"
        case .partialShift: return "Une partie du créneau n'est pas notée"
        case .longGap: return "Un long trou dans ta journée"
        case .emptyContract: return "Aucune session cette semaine"
        }
    }

    static func countText(_ count: Int) -> String {
        if count == 1 { return "1 créneau à vérifier" }
        return "\(count) créneaux à vérifier"
    }
}
