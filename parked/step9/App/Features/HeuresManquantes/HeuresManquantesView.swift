import SwiftUI
import SwiftData

/// Écran `missing_hours` (section 86) : créneaux où des heures semblent manquer.
/// Jamais d'ajout silencieux : chaque ajout est un tap, et les sessions ajoutées restent "à confirmer".
struct HeuresManquantesView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \PlannedShift.start) private var shifts: [PlannedShift]
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]
    @Query private var leaves: [LeaveEntry]
    @Query private var contracts: [Contract]
    @Query private var places: [Place]

    private let ignoreStore: MissingHoursIgnoreStore = MissingHoursIgnoreStore.shared

    @State private var errorMessage: String? = nil
    @State private var showManualAdd: Bool = false

    private var calendar: Calendar { return Calendar.current }

    var body: some View {
        let now: Date = Date()
        let vacation: Bool = modules.isActive("vacation_mode")
        let items: [MissingItem] = vacation ? [] : MissingHoursSupport.items(shifts: shifts, sessions: sessions, leaves: leaves,
                                                                            contracts: contracts,
                                                                            ignored: ignoreStore.activeIDs(now: now),
                                                                            now: now, calendar: calendar)
        let ignoredCount: Int = ignoreStore.activeIDs(now: now).count
        return PLTScreen(title: "Heures manquantes") {
            PLTBanner(kind: .info,
                      title: "Rien n'est ajouté sans toi",
                      message: "Je repère les créneaux prévus sans session, sur les \(MissingHoursRules.lookbackDays) derniers jours. Une session ajoutée reste « à confirmer ».")

            if let message = errorMessage {
                PLTBanner(kind: .error, title: message)
            }

            if vacation {
                PLTBanner(kind: .info, title: "Mode vacances actif", message: "Aucune question pendant les vacances.")
            } else if items.isEmpty {
                PLTEmptyState(symbol: "checkmark.circle",
                              title: "Rien à vérifier",
                              message: "Tous tes créneaux prévus ont une session, ou ils sont déjà réglés.")
            } else {
                ForEach(items) { (item: MissingItem) in
                    itemCard(item)
                }
            }

            if ignoredCount > 0 {
                Button("Réafficher les \(ignoredCount) créneaux ignorés") {
                    ignoreStore.resetAll()
                }
                .buttonStyle(.pltSecondary)
            }
        }
        .sheet(isPresented: $showManualAdd) {
            SessionAjoutView()
        }
    }

    private func itemCard(_ item: MissingItem) -> some View {
        let placeName: String? = item.placeUID.flatMap { (uid: UUID) -> String? in
            return places.first(where: { (p: Place) -> Bool in return p.uid == uid })?.name
        }
        return PLTCard {
            Text(Formatting.dayTitle(item.day, calendar: calendar))
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            if let start = item.start, let end = item.end {
                Text("\(Formatting.clock(start, calendar: calendar)) à \(Formatting.clock(end, calendar: calendar)), \(Formatting.duration(minutes: item.minutes))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            Text(MissingHoursRules.title(for: item) + (placeName.map { (n: String) -> String in return " (" + n + ")" } ?? ""))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Text(question(for: item))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            if item.start != nil && item.end != nil {
                Button("Ajouter la session") { add(item) }
                    .buttonStyle(.pltPrimary)
            } else {
                Button("Ajouter une session") { showManualAdd = true }
                    .buttonStyle(.pltPrimary)
            }
            Button("Ignorer") { ignoreStore.ignore(id: item.id) }
                .buttonStyle(.pltSecondary)
        }
    }

    private func question(for item: MissingItem) -> String {
        switch item.kind {
        case .unloggedShift, .partialShift:
            return "Tu as travaillé sur ce créneau ?"
        case .longGap:
            return "T'as bossé pendant ce trou ?"
        case .emptyContract:
            return "Tu as bien un contrat actif, mais aucune session. T'as bossé ?"
        }
    }

    private func add(_ item: MissingItem) {
        guard let start = item.start, let end = item.end else { return }
        let now: Date = Date()
        var others: [SessionInterval] = []
        for s in sessions {
            let sEnd: Date = s.endDate ?? now
            if sEnd > s.startDate {
                others.append(SessionInterval(start: s.startDate, end: sEnd))
            }
        }
        let errors: [SessionValidationError] = SessionRules.validate(start: start, end: end, now: now, others: others)
        if let first = errors.first {
            errorMessage = first.message
            return
        }
        let place: Place? = item.placeUID.flatMap { (uid: UUID) -> Place? in
            return places.first(where: { (p: Place) -> Bool in return p.uid == uid })
        }
        let ctx: ModelContext = context
        let service: SessionService = SessionService(context: ctx)
        do {
            let created: WorkSession = try service.addProposedSession(activity: item.activity, start: start, end: end, place: place)
            errorMessage = nil
            let createdUID: UUID = created.uid
            undoCenter?.register(message: "Session ajoutée") {
                let all: [WorkSession] = (try? ctx.fetch(FetchDescriptor<WorkSession>())) ?? []
                for s in all where s.uid == createdUID {
                    ctx.delete(s)
                }
                try? ctx.save()
            }
        } catch {
            errorMessage = "Impossible d'ajouter la session. Réessaie."
        }
    }
}
