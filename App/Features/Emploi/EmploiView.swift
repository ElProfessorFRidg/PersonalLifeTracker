import SwiftUI
import SwiftData

/// Ce que la feuille de contrat doit ouvrir : modification d'un contrat, création, ou création pré-remplie.
struct ContratRoute: Identifiable {
    let id: UUID = UUID()
    let contract: Contract?
    let draft: ContractDraft?
}

/// Emploi (sections 18 et 19). Poussé depuis Réglages. Prototype : design/prototype/src/screens/50_emploi.html.
/// Tout est optionnel : sans ce module, le noyau suit les heures comme avant.
struct EmploiView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Query(sort: \Employer.createdAt) private var employers: [Employer]

    @State private var showNewEmployer: Bool = false

    var body: some View {
        PLTScreen(title: "Emploi") {
            if modules.isActive("employment") {
                activeContent
            } else {
                disabledContent
            }
        }
        .sheet(isPresented: $showNewEmployer) {
            EmployeurEditView(employer: nil)
        }
    }

    // MARK: Module activé

    @ViewBuilder
    private var activeContent: some View {
        if employers.isEmpty {
            PLTCard {
                PLTEmptyState(symbol: "briefcase",
                              title: "Aucun employeur pour l'instant.",
                              message: "Ajoute ton employeur et ton contrat : je te dis combien de jours il reste et je te prépare la suite. C'est facultatif, tes heures sont suivies sans.",
                              actionTitle: "Ajouter mon employeur",
                              action: { showNewEmployer = true })
            }
        } else {
            ForEach(employers) { (employer: Employer) in
                EmployerBlock(employer: employer)
            }
            if modules.isActive("multi_employer") {
                PLTListGroup {
                    PLTRow(symbol: "plus.circle",
                           title: "Ajouter un autre employeur",
                           subtitle: "Utile si t'as deux jobs en même temps",
                           showsChevron: true,
                           showsSeparator: false,
                           action: { showNewEmployer = true })
                }
            }
        }
        if modules.isActive("contract_hours") {
            NavigationLink {
                ContratHeuresView()
            } label: {
                PLTListGroup {
                    PLTRow(symbol: "clock",
                           title: "Mes heures au contrat",
                           subtitle: "Ta semaine face à ton quota, ton historique et tes compteurs",
                           showsChevron: true,
                           showsSeparator: false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mes heures au contrat")
        }
        if modules.isActive("leave") {
            NavigationLink {
                CongesView()
            } label: {
                PLTListGroup {
                    PLTRow(symbol: "sun.max",
                           title: "Congés",
                           subtitle: "Tes jours de congé et tes absences",
                           showsChevron: true,
                           showsSeparator: false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Congés")
        }
        if modules.isActive("pay") {
            NavigationLink {
                PaieView()
            } label: {
                PLTListGroup {
                    PLTRow(symbol: "eurosign.circle",
                           title: "Paie",
                           subtitle: "Estimation de ta paie, ta fiche de paie fait foi",
                           showsChevron: true,
                           showsSeparator: false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paie")
        }
        Text("Emploi est optionnel. Tu peux l'éteindre dans Réglages, Fonctionnalités : tes heures continuent d'être suivies.")
            .font(.footnote)
            .foregroundStyle(palette.textSecondary)
    }

    // MARK: Module désactivé

    @ViewBuilder
    private var disabledContent: some View {
        PLTCard {
            PLTEmptyState(symbol: "briefcase",
                          title: "Emploi, c'est optionnel.",
                          message: "Tant qu'il est éteint, l'app suit tes heures sans parler de contrat, de paie ni d'employeur. Rien ne manque.",
                          actionTitle: "Activer Emploi",
                          action: { modules.setEnabled("employment", true) })
        }
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que le module apporte")
            PLTListGroup {
                PLTRow(symbol: "doc.text",
                       title: "Ton contrat en un coup d'oeil",
                       subtitle: "Type, dates, heures par semaine, décompte avant la fin")
                PLTRow(symbol: "calendar.badge.clock",
                       title: "La fin de ton contrat",
                       subtitle: "Rappels, papiers à demander, renouvellement ou CDI en un tap")
                PLTRow(symbol: "eurosign.circle",
                       title: "Estimation de paie",
                       subtitle: "Un autre module, qui a besoin de celui-ci",
                       showsSeparator: false)
            }
            Text("Pour l'allumer plus tard : Réglages, puis Fonctionnalités, puis Employeurs, contrats, fin de contrat. Tout reste sur ton tel.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
        NavigationLink {
            FonctionnalitesView()
        } label: {
            Text("Voir les fonctionnalités")
        }
        .buttonStyle(.pltSecondary)
    }
}

// MARK: - Un employeur et son contrat

private struct EmployerBlock: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    let employer: Employer

    @State private var route: ContratRoute? = nil
    @State private var showEditEmployer: Bool = false
    @State private var showChecklist: Bool = false
    @State private var showIndemnity: Bool = false
    @State private var checkedCount: Int = 0

    private var calendar: Calendar { return Calendar.current }

    private var sortedContracts: [Contract] {
        return employer.contracts.sorted { (a: Contract, b: Contract) -> Bool in
            return a.startDate > b.startDate
        }
    }

    /// Le contrat actif aujourd'hui, sinon le plus récent.
    private var current: Contract? {
        let list: [Contract] = sortedContracts
        let spans: [ContractSpan] = list.map { (c: Contract) -> ContractSpan in
            return ContractSpan(id: c.uid, start: c.startDate, end: c.endDate)
        }
        if let index = ContractRules.activeIndex(in: spans, at: Date(), calendar: calendar) {
            return list[index]
        }
        return list.first
    }

    private var otherContracts: [Contract] {
        let currentUID: UUID? = current?.uid
        return sortedContracts.filter { (c: Contract) -> Bool in c.uid != currentUID }
    }

    private func status(of c: Contract) -> ContractStatus {
        return ContractRules.status(start: c.startDate, end: c.endDate, trialEnd: c.trialEndDate, now: Date(), calendar: calendar)
    }

    private func draft(of c: Contract) -> ContractDraft {
        return ContractDraft(kind: c.kind, startDate: c.startDate, endDate: c.endDate, weeklyHours: c.weeklyHours, hourlyGrossRate: c.hourlyGrossRate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            employerSection
            if let c = current {
                contractSection(c)
                endSection(c)
                if !otherContracts.isEmpty {
                    othersSection
                }
            }
        }
        .sheet(item: $route) { (r: ContratRoute) in
            ContratEditView(employer: employer, contract: r.contract, draft: r.draft)
        }
        .sheet(isPresented: $showEditEmployer) {
            EmployeurEditView(employer: employer)
        }
        .sheet(isPresented: $showChecklist, onDismiss: { refreshChecked() }) {
            if let c = current {
                FinContratChecklistSheet(contractUID: c.uid)
            }
        }
        .sheet(isPresented: $showIndemnity) {
            IndemniteInfoSheet()
        }
        .onAppear { refreshChecked() }
    }

    private func refreshChecked() {
        if let c = current {
            checkedCount = ContractRules.checklistDoneCount(checkedIDs: EndChecklistStore.checked(for: c.uid))
        } else {
            checkedCount = 0
        }
    }

    // MARK: Employeur et décompte

    private var employerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ton employeur", actionTitle: "Modifier", action: { showEditEmployer = true })
            if let c = current {
                employerCard(c)
            } else {
                PLTCard {
                    HStack(spacing: Theme.Spacing.s) {
                        Circle()
                            .fill(EmployerColorChoice.tone(forKey: employer.colorHex).color(palette))
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(employer.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                    }
                    PLTEmptyState(symbol: "doc.text",
                                  title: "Pas encore de contrat.",
                                  message: "Ajoute ton contrat pour voir le décompte et préparer la suite. Facultatif.",
                                  actionTitle: "Ajouter mon contrat",
                                  action: { route = ContratRoute(contract: nil, draft: nil) })
                }
            }
        }
    }

    private func employerCard(_ c: Contract) -> some View {
        let st: ContractStatus = status(of: c)
        let now: Date = Date()
        let tone: PLTTone = EmployerColorChoice.tone(forKey: employer.colorHex)
        return PLTCard {
            HStack(spacing: Theme.Spacing.s) {
                PLTChip("Taf", kind: .work)
                PLTChip(c.kind.title)
                PLTChip(st.title, kind: st == .endingSoon || st == .ended ? .doubt : .neutral)
            }
            HStack(spacing: Theme.Spacing.s) {
                Circle()
                    .fill(tone.color(palette))
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(employer.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
            }
            if let end = c.endDate {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ContractRules.countdownText(kind: c.kind, end: end, now: now, calendar: calendar) ?? "")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(palette.textPrimary)
                        Spacer(minLength: Theme.Spacing.s)
                        Text(EmploiFormat.shortDate(end))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(palette.textSecondary)
                    }
                    let ratio: Double = ContractRules.progress(start: c.startDate, end: end, now: now, calendar: calendar) ?? 0
                    ProgressView(value: ratio)
                        .tint(tone.color(palette))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .accessibilityLabel("Avancement du contrat")
                        .accessibilityValue("\(Int((ratio * 100).rounded())) pour cent")
                }
            } else {
                Text("Pas de date de fin pour \(ContractRules.possessive(c.kind)).")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            Text(noteText(c, now: now))
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func noteText(_ c: Contract, now: Date) -> String {
        var text: String = "Début le \(EmploiFormat.date(c.startDate))."
        let trial: TrialStatus = ContractRules.trialStatus(start: c.startDate, trialEnd: c.trialEndDate, now: now, calendar: calendar)
        switch trial {
        case .none, .notStarted:
            break
        case .inProgress(let daysLeft):
            text += " Période d'essai : encore \(EmploiFormat.days(daysLeft))."
        case .finished:
            text += " Période d'essai terminée."
        }
        return text
    }

    // MARK: Le contrat

    private func contractSection(_ c: Contract) -> some View {
        let edit: () -> Void = { route = ContratRoute(contract: c, draft: nil) }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ton contrat")
            PLTListGroup {
                PLTRow(title: "Type de contrat", value: c.kind.title, action: edit)
                PLTRow(title: "Heures au contrat", subtitle: "Suivi semaine par semaine", value: EmploiFormat.weeklyHours(c.weeklyHours), showsChevron: true, action: edit)
                PLTRow(title: "Date de début", value: EmploiFormat.date(c.startDate), action: edit)
                PLTRow(title: "Date de fin",
                       subtitle: c.endDate == nil ? nil : "Contrat à durée déterminée",
                       value: c.endDate.map { (d: Date) -> String in EmploiFormat.date(d) } ?? "Pas de fin",
                       action: edit)
                PLTRow(title: "Taux horaire brut saisi",
                       subtitle: "Facultatif, ta fiche de paie fait foi",
                       value: c.hourlyGrossRate.map { (r: Double) -> String in settings.formatMoney(r) } ?? "Pas renseigné",
                       showsChevron: true,
                       action: edit)
                PLTRow(title: "Lieux rattachés",
                       value: c.placeUIDs.isEmpty ? "Aucun" : "\(c.placeUIDs.count)",
                       showsSeparator: false,
                       action: edit)
            }
            Text("Chaque ligne se corrige en deux taps. Un contrat terminé est archivé, jamais supprimé.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Quand ça se termine

    @ViewBuilder
    private func endSection(_ c: Contract) -> some View {
        let st: ContractStatus = status(of: c)
        if c.endDate != nil || st == .ended {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Quand ça se termine")
                if st == .endingSoon || st == .ended {
                    PLTBanner(kind: .info,
                              title: st == .ended ? "Ton contrat est fini" : "Ça approche",
                              message: endMessage(c, st))
                }
                PLTListGroup {
                    PLTRow(symbol: "checklist",
                           title: "Checklist de fin de contrat",
                           subtitle: "Papiers à demander, \(ContractRules.endChecklist.count) points",
                           value: "\(checkedCount)/\(ContractRules.endChecklist.count)",
                           showsChevron: true,
                           action: { showChecklist = true })
                    PLTRow(symbol: "eurosign.arrow.circlepath",
                           tone: .neutral,
                           title: "Indemnité de fin de contrat",
                           subtitle: "Peut-être applicable, à vérifier",
                           showsChevron: true,
                           showsSeparator: c.kind != .cdi,
                           action: { showIndemnity = true })
                    if c.kind != .cdi {
                        PLTRow(symbol: "arrow.triangle.2.circlepath",
                               title: "Renouveler le contrat",
                               subtitle: "Je recopie tes infos, tu choisis les dates",
                               showsChevron: true,
                               action: { route = ContratRoute(contract: nil, draft: ContractRules.renewalDraft(from: draft(of: c), now: Date(), calendar: calendar)) })
                        PLTRow(symbol: "arrow.up.right.circle",
                               title: "Passer en CDI",
                               subtitle: "Un CDI qui reprend tes infos, sans date de fin",
                               showsChevron: true,
                               showsSeparator: false,
                               action: { route = ContratRoute(contract: nil, draft: ContractRules.cdiDraft(from: draft(of: c), now: Date(), calendar: calendar)) })
                    }
                }
                Text("Les rappels (14 jours et 3 jours avant la fin) ne sont pas encore envoyés en notification. Je t'informe et je cite mes sources, mais je ne donne pas de conseil juridique : vérifie toujours ton contrat. Les règles générales vérifiées ne sont pas encore dans l'app.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func endMessage(_ c: Contract, _ st: ContractStatus) -> String {
        if st == .ended {
            return "Il est archivé, pas supprimé : tes sessions et tes stats restent là. Tu peux préparer les papiers ou créer le contrat suivant."
        }
        let text: String = ContractRules.countdownText(kind: c.kind, end: c.endDate, now: Date(), calendar: calendar) ?? ""
        return "\(text). Tu peux déjà préparer les papiers, ou renouveler / passer en CDI en reprenant tes infos."
    }

    // MARK: Autres contrats

    private var othersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Autres contrats")
            PLTListGroup {
                ForEach(otherContracts) { (c: Contract) in
                    PLTRow(symbol: "archivebox",
                           tone: .neutral,
                           title: "\(c.kind.title), \(EmploiFormat.date(c.startDate))",
                           subtitle: status(of: c).title,
                           value: EmploiFormat.weeklyHours(c.weeklyHours),
                           showsChevron: true,
                           showsSeparator: c.uid != otherContracts.last?.uid,
                           action: { route = ContratRoute(contract: c, draft: nil) })
                }
            }
            Button("Ajouter un contrat") { route = ContratRoute(contract: nil, draft: nil) }
                .buttonStyle(.pltSecondary)
        }
    }
}
