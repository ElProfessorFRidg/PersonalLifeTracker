import SwiftUI
import SwiftData

/// Ce que la feuille de congé doit ouvrir : modification d'un congé existant, ou création.
private struct CongesRoute: Identifiable {
    let id: UUID = UUID()
    let entry: LeaveEntry?
}

/// Congés payés (section 23). Poussé depuis un autre écran. Tout est une estimation à comparer à ta fiche de paie.
struct CongesView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \Employer.createdAt) private var employers: [Employer]
    @Query(sort: \LeaveEntry.startDay, order: .reverse) private var entries: [LeaveEntry]

    @State private var params: LeaveParameters = LeaveParameters.load(from: UserDefaults.standard)
    @State private var route: CongesRoute? = nil
    @State private var showParams: Bool = false
    @State private var selectedEmployerUID: UUID? = nil

    private var calendar: Calendar { return Calendar.current }

    var body: some View {
        PLTScreen(title: "Congés payés") {
            if !modules.isActive("leave") {
                disabledContent
            } else if let employer = currentEmployer, !employer.contracts.isEmpty {
                activeContent(employer: employer)
            } else {
                noContractContent
            }
        }
        .sheet(item: $route) { (r: CongesRoute) in
            editSheet(for: r)
        }
        .sheet(isPresented: $showParams) {
            CongesParamsSheet(initial: params, onSaved: { (p: LeaveParameters) in params = p })
        }
        .onAppear {
            params = LeaveParameters.load(from: UserDefaults.standard)
        }
    }

    // MARK: Données

    private var currentEmployer: Employer? {
        if let uid = selectedEmployerUID, let found = employers.first(where: { (e: Employer) -> Bool in e.uid == uid }) {
            return found
        }
        return employers.first
    }

    private func entries(of employer: Employer) -> [LeaveEntry] {
        let single: Bool = employers.count <= 1
        return entries.filter { (e: LeaveEntry) -> Bool in
            if let uid = e.employerUID { return uid == employer.uid }
            return single
        }
    }

    private func ranges(of list: [LeaveEntry], excluding excluded: LeaveEntry?) -> [LeaveRange] {
        var result: [LeaveRange] = []
        for e in list {
            if let x = excluded, x.uid == e.uid { continue }
            result.append(LeaveRange(start: e.startDay, end: e.endDay, kind: LeaveKindChoice.from(raw: e.kindRaw)))
        }
        return result
    }

    private func spans(of employer: Employer) -> [LeaveSpan] {
        return employer.contracts.map { (c: Contract) -> LeaveSpan in
            return LeaveSpan(start: c.startDate, end: c.endDate)
        }
    }

    // MARK: Module désactivé

    @ViewBuilder
    private var disabledContent: some View {
        PLTCard {
            PLTEmptyState(symbol: "sun.max",
                          title: "Congés payés, c'est optionnel.",
                          message: "Tant que ce module est éteint, l'app ne compte pas tes congés. Rien ne manque pour suivre tes heures.",
                          actionTitle: "Activer Congés payés",
                          action: { modules.setEnabled("leave", true) })
        }
        Text("Ce module a besoin d'Emploi : il s'allume avec.")
            .font(.footnote)
            .foregroundStyle(palette.textSecondary)
    }

    // MARK: Pas de contrat

    @ViewBuilder
    private var noContractContent: some View {
        PLTCard {
            PLTEmptyState(symbol: "doc.text",
                          title: "Pas de contrat pour l'instant.",
                          message: "Pour estimer tes congés, j'ai besoin des dates de ton contrat. Ajoute-le dans Emploi, puis reviens ici.")
        }
        Text("Les chiffres de ce module sont des estimations. Ta fiche de paie fait foi.")
            .font(.footnote)
            .foregroundStyle(palette.textSecondary)
    }

    // MARK: Module activé

    @ViewBuilder
    private func activeContent(employer: Employer) -> some View {
        let list: [LeaveEntry] = entries(of: employer)
        let balance: LeaveBalance = LeaveRules.balance(spans: spans(of: employer),
                                                       ranges: ranges(of: list, excluding: nil),
                                                       asOf: Date(),
                                                       params: params,
                                                       calendar: calendar)
        if employers.count > 1 {
            employerPicker
        }
        balanceCard(balance: balance, employerName: employer.name)
        if balance.isOverdrawn {
            PLTBanner(kind: .warning,
                      title: "Tu as posé plus de jours que tu n'en as acquis.",
                      message: "Dépassement estimé : \(CongesFormat.days(balance.overdrawnBy)). Compare avec ta fiche de paie, ton calcul peut différer.")
        }
        if balance.risk.isAlert {
            PLTBanner(kind: .warning,
                      title: "Ta période se termine le \(CongesFormat.longDate(balance.risk.expiryDate)).",
                      message: "Il te resterait \(CongesFormat.days(balance.risk.daysAtRisk)) non posés. Selon ton entreprise, ils peuvent être reportés ou perdus : vérifie auprès d'elle.")
        }
        listSection(list: list)
        Button("Poser un congé") { route = CongesRoute(entry: nil) }
            .buttonStyle(.pltPrimary)
        Button("Règles de calcul") { showParams = true }
            .buttonStyle(.pltSecondary)
        Text("Estimation indicative, pas un droit garanti. Jours fériés non retirés, périodes assimilées à du travail non gérées. Ta fiche de paie et ta convention collective font foi.")
            .font(.footnote)
            .foregroundStyle(palette.textSecondary)
    }

    private var employerPicker: some View {
        PLTCard {
            HStack {
                Text("Employeur")
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                Picker("Employeur", selection: employerBinding) {
                    ForEach(employers) { (e: Employer) in
                        Text(e.name).tag(e.uid)
                    }
                }
                .pickerStyle(.menu)
            }
            .frame(minHeight: 44)
        }
    }

    private var employerBinding: Binding<UUID> {
        return Binding<UUID>(
            get: { return currentEmployer?.uid ?? UUID() },
            set: { (newValue: UUID) in selectedEmployerUID = newValue }
        )
    }

    private func balanceCard(balance: LeaveBalance, employerName: String) -> some View {
        let headline: String = balance.isOverdrawn
            ? "Tu es à \(CongesFormat.number(balance.remaining)) jours (estimation)"
            : "Il te reste \(CongesFormat.days(balance.remaining))"
        let periodText: String = "Période du \(CongesFormat.date(balance.period.start)) au \(CongesFormat.date(balance.period.end))"
        return PLTCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(headline)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(balance.isOverdrawn ? palette.danger : palette.textPrimary)
                    .accessibilityLabel(headline)
                Text("\(employerName). \(periodText). Estimation à comparer avec ta fiche de paie.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    StatTile(label: "Acquis", value: CongesFormat.number(balance.acquired), note: "estimé", tone: .work)
                    StatTile(label: "Pris", value: CongesFormat.number(balance.taken), note: "jusqu'à aujourd'hui", tone: .neutral)
                    StatTile(label: "Prévus", value: CongesFormat.number(balance.planned), note: "à venir", tone: .accent)
                }
                Text("En \(params.unit == .ouvrable ? "jours ouvrables" : "jours ouvrés"). Règles par défaut à vérifier.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func listSection(list: [LeaveEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Tes congés")
            if list.isEmpty {
                PLTCard {
                    PLTEmptyState(symbol: "calendar",
                                  title: "Aucun congé posé.",
                                  message: "Pose tes jours pris ou prévus : le solde se met à jour tout seul.")
                }
            } else {
                PLTListGroup {
                    ForEach(Array(list.enumerated()), id: \.offset) { item in
                        leaveRow(item.element, isLast: item.offset == list.count - 1)
                    }
                }
            }
        }
    }

    private func leaveRow(_ entry: LeaveEntry, isLast: Bool) -> some View {
        let kind: LeaveKindChoice = LeaveKindChoice.from(raw: entry.kindRaw)
        let counted: Int = LeaveRules.countedDays(from: entry.startDay, to: entry.endDay, unit: params.unit, calendar: calendar)
        let title: String = CongesFormat.range(start: entry.startDay, end: entry.endDay, calendar: calendar)
        let subtitle: String = kind.consumesBalance ? kind.title : "\(kind.title), hors solde"
        return PLTRow(symbol: "calendar",
                      tone: kind.consumesBalance ? .accent : .neutral,
                      title: title,
                      subtitle: subtitle,
                      value: CongesFormat.days(Double(counted)),
                      showsChevron: true,
                      showsSeparator: !isLast,
                      action: { route = CongesRoute(entry: entry) })
    }

    // MARK: Feuille d'édition

    @ViewBuilder
    private func editSheet(for r: CongesRoute) -> some View {
        if let employer = currentEmployer {
            let list: [LeaveEntry] = entries(of: employer)
            let today: Date = calendar.startOfDay(for: Date())
            let existing: LeaveEntry? = r.entry
            let deleteAction: (() -> Void)? = deleteHandler(for: existing)
            CongesEditSheet(isNew: r.entry == nil,
                            start: r.entry?.startDay ?? today,
                            end: r.entry?.endDay ?? today,
                            kind: LeaveKindChoice.from(raw: r.entry?.kindRaw ?? "paid"),
                            note: r.entry?.note ?? "",
                            others: ranges(of: list, excluding: r.entry),
                            spans: spans(of: employer),
                            params: params,
                            onSave: { (s: Date, e: Date, k: LeaveKindChoice, n: String) in
                                save(existing: r.entry, start: s, end: e, kind: k, note: n, employer: employer)
                            },
                            onDelete: deleteAction)
        } else {
            EmptyView()
        }
    }

    // MARK: Actions

    private func deleteHandler(for entry: LeaveEntry?) -> (() -> Void)? {
        guard let target = entry else { return nil }
        return { delete(target, message: "Congé supprimé") }
    }

    private func save(existing: LeaveEntry?, start: Date, end: Date, kind: LeaveKindChoice, note: String, employer: Employer) {
        let s: Date = calendar.startOfDay(for: start)
        let e: Date = calendar.startOfDay(for: end)
        let ctx: ModelContext = context
        if let entry = existing {
            let oldStart: Date = entry.startDay
            let oldEnd: Date = entry.endDay
            let oldKind: String = entry.kindRaw
            let oldNote: String = entry.note
            let oldEmployer: UUID? = entry.employerUID
            entry.startDay = s
            entry.endDay = e
            entry.kindRaw = kind.rawValue
            entry.note = note
            if entry.employerUID == nil { entry.employerUID = employer.uid }
            try? ctx.save()
            undoCenter?.register(message: "Congé modifié") {
                entry.startDay = oldStart
                entry.endDay = oldEnd
                entry.kindRaw = oldKind
                entry.note = oldNote
                entry.employerUID = oldEmployer
                try? ctx.save()
            }
        } else {
            let created: LeaveEntry = LeaveEntry(startDay: s, endDay: e, kindRaw: kind.rawValue, note: note, employerUID: employer.uid)
            ctx.insert(created)
            try? ctx.save()
            undoCenter?.register(message: "Congé ajouté") {
                ctx.delete(created)
                try? ctx.save()
            }
        }
    }

    private func delete(_ entry: LeaveEntry?, message: String) {
        guard let entry = entry else { return }
        let ctx: ModelContext = context
        let uid: UUID = entry.uid
        let start: Date = entry.startDay
        let end: Date = entry.endDay
        let kindRaw: String = entry.kindRaw
        let note: String = entry.note
        let employerUID: UUID? = entry.employerUID
        let createdAt: Date = entry.createdAt
        ctx.delete(entry)
        try? ctx.save()
        undoCenter?.register(message: message) {
            let restored: LeaveEntry = LeaveEntry(startDay: start, endDay: end, kindRaw: kindRaw, note: note, employerUID: employerUID)
            restored.uid = uid
            restored.createdAt = createdAt
            ctx.insert(restored)
            try? ctx.save()
        }
    }
}
