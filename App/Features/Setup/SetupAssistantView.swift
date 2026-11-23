import SwiftUI
import SwiftData

/// Où l'assistant envoie quand une étape demande un écran existant.
enum SetupDestination: Hashable {
    case employment
    case pay
    case planningImport
    case contractHours
}

/// Assistant de configuration. Poussé depuis Réglages ou depuis la carte de l'Accueil, sans argument.
/// Il lit l'état réel de l'app, propose « Tout configurer pour moi » puis les étapes qui restent à la main.
@MainActor
struct SetupAssistantView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?

    @Query private var places: [Place]
    @Query private var employers: [Employer]
    @Query private var contracts: [Contract]
    @Query private var payRates: [PayRate]
    @Query private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]

    @State private var capabilities: CapabilityService = CapabilityService()
    @State private var permissions: PermissionRequester = PermissionRequester()
    @State private var automation: SetupAutomation = SetupAutomation()
    @State private var destination: SetupDestination? = nil
    @State private var showPlaceSheet: Bool = false

    @State private var placeName: String = ""
    @State private var placeError: String? = nil
    @State private var contractKind: ContractKind = .cdi
    @State private var hoursText: String = ""
    @State private var employerName: String = ""
    @State private var contractError: String? = nil

    private var facts: SetupFacts {
        return SetupFactsBuilder.facts(capabilities: capabilities,
                                       modules: modules,
                                       places: places,
                                       employers: employers,
                                       contracts: contracts,
                                       payRates: payRates,
                                       shifts: shifts,
                                       sessionCount: sessions.count)
    }

    private var draftPlace: Place? {
        guard let uid = automation.draftPlaceUID else { return nil }
        return places.first(where: { (p: Place) -> Bool in return p.uid == uid })
    }

    private var draftContract: Contract? {
        guard let uid = automation.draftContractUID else { return nil }
        return contracts.first(where: { (c: Contract) -> Bool in return c.uid == uid })
    }

    var body: some View {
        let currentFacts: SetupFacts = facts
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: currentFacts)
        let progress: SetupProgress = SetupChecklist.progress(of: steps)
        let complete: Bool = SetupChecklist.isComplete(steps)
        return PLTScreen(title: "Assistant de configuration") {
            headerCard(progress: progress, complete: complete, message: SetupChecklist.completionMessage(for: currentFacts))
            if !automation.report.isEmpty {
                reportSection
            }
            if draftPlace != nil {
                placeDraftCard
            }
            if draftContract != nil {
                contractDraftCard
            }
            stepsSection(steps)
        }
        .onAppear {
            capabilities.refresh()
            Task { @MainActor in
                await permissions.refreshNotifications()
                capabilities.refresh()
            }
        }
        .onChange(of: scenePhase) { (_: ScenePhase, newPhase: ScenePhase) in
            if newPhase == .active { capabilities.refresh() }
        }
        .onChange(of: automation.draftPlaceUID, initial: true) { (_: UUID?, _: UUID?) in
            if let place = draftPlace { placeName = place.name }
        }
        .onChange(of: automation.draftContractUID, initial: true) { (_: UUID?, _: UUID?) in
            if let contract = draftContract {
                contractKind = (contract.kind == .cdd) ? .cdd : .cdi
                employerName = contract.employer?.name ?? ""
                hoursText = ""
            }
        }
        .navigationDestination(item: $destination) { (dest: SetupDestination) in
            destinationView(dest)
        }
        .sheet(isPresented: $showPlaceSheet) {
            LieuAjoutView(locateOnOpen: true, initialType: .taf)
        }
    }

    @ViewBuilder
    private func destinationView(_ dest: SetupDestination) -> some View {
        switch dest {
        case .employment: EmploiView()
        case .pay: PaieView()
        case .planningImport: PlanningImportView()
        case .contractHours: ContratHeuresView()
        }
    }

    // MARK: En-tête

    private func headerCard(progress: SetupProgress, complete: Bool, message: String) -> some View {
        return PLTCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Ta configuration")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                Text(progress.text)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
            ProgressView(value: progress.fraction)
                .tint(palette.accent)
            if complete {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Text("Je regarde où en est ton app et je fais ce qui peut l'être en un tap. Les noms et les chiffres de ton contrat, c'est toi qui les confirmes.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                Button {
                    Task { @MainActor in
                        await automation.configureEverything(modules: modules,
                                                             context: context,
                                                             undo: undoCenter,
                                                             permissions: permissions,
                                                             capabilities: capabilities)
                    }
                } label: {
                    Label(automation.isRunning ? "Je m'en occupe..." : "Tout configurer pour moi", systemImage: "wand.and.stars")
                }
                .buttonStyle(.pltPrimary)
                .disabled(automation.isRunning)
            }
        }
    }

    // MARK: Compte rendu

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que j'ai fait")
            PLTListGroup {
                ForEach(automation.report) { (line: SetupReportLine) in
                    PLTRow(symbol: line.isOK ? "checkmark" : "exclamationmark.triangle",
                           tone: line.isOK ? PLTTone.accent : PLTTone.danger,
                           title: line.text,
                           showsSeparator: line.id != automation.report.last?.id)
                }
            }
            Text("Si ça ne te va pas, le bouton Annuler en bas défait ce que j'ai créé.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Brouillons à confirmer

    private var placeDraftCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Comment s'appelle ton taf ?")
            TextField("Par exemple : Supérette du Canal", text: $placeName)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Nom de ton taf")
            if let error = placeError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            }
            Button("Valider le nom") {
                placeError = automation.confirmPlaceName(placeName, context: context)
            }
            .buttonStyle(.pltPrimary)
            Text("Le lieu est posé là où tu es, avec un rayon de \(Int(PlaceRules.defaultRadius)) m. Tu pourras le déplacer dans Lieux.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var contractDraftCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ton contrat")
            Picker("Type de contrat", selection: $contractKind) {
                Text("CDI").tag(ContractKind.cdi)
                Text("CDD").tag(ContractKind.cdd)
            }
            .pickerStyle(.segmented)
            TextField("Nom de l'employeur", text: $employerName)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Nom de l'employeur")
            TextField("Heures par semaine, comme sur ton contrat", text: $hoursText)
                .keyboardType(.decimalPad)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Heures par semaine")
            if let error = contractError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            }
            Button("Enregistrer mon contrat") {
                contractError = automation.confirmContract(kind: contractKind,
                                                           weeklyHoursText: hoursText,
                                                           employerName: employerName,
                                                           context: context)
            }
            .buttonStyle(.pltPrimary)
            if contractKind == .cdd {
                Text("Pour un CDD, ajoute la date de fin dans Emploi.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: Étapes

    private func stepsSection(_ steps: [SetupStep]) -> some View {
        let pending: [SetupStep] = steps.filter { (s: SetupStep) -> Bool in return s.status == .todo || s.status == .blocked }
        let finished: [SetupStep] = steps.filter { (s: SetupStep) -> Bool in return s.status == .done }
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if !pending.isEmpty {
                PLTSectionHeader(title: "Ce qui reste")
                ForEach(pending, id: \.id) { (step: SetupStep) in
                    stepCard(step)
                }
            }
            if !finished.isEmpty {
                PLTSectionHeader(title: "C'est fait")
                PLTListGroup {
                    ForEach(finished, id: \.id) { (step: SetupStep) in
                        PLTRow(symbol: "checkmark", tone: PLTTone.accent, title: step.title,
                               showsSeparator: step.id != finished.last?.id)
                    }
                }
            }
        }
    }

    private func stepCard(_ step: SetupStep) -> some View {
        let blocked: Bool = (step.status == .blocked)
        return PLTCard {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Image(systemName: blocked ? "exclamationmark.triangle.fill" : "circle")
                    .foregroundStyle(blocked ? palette.warning : palette.textTertiary)
                    .accessibilityHidden(true)
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
            }
            Text(step.why)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            if let title = step.actionTitle, let action = step.action {
                Button(title) { perform(action) }
                    .buttonStyle(.pltSecondary)
                    .disabled(automation.isRunning)
            }
            if step.id == .firstPlace && (facts.location == .always || facts.location == .whenInUse) {
                Button("Placer le lieu moi-même sur la carte") { showPlaceSheet = true }
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
        }
    }

    private func perform(_ action: SetupAction) {
        switch action {
        case .requestLocation:
            Task { @MainActor in
                await automation.requestLocation(permissions: permissions, capabilities: capabilities)
            }
        case .requestNotifications:
            Task { @MainActor in
                await automation.requestNotifications(permissions: permissions, capabilities: capabilities)
            }
        case .openSystemSettings:
            permissions.openSystemSettings()
        case .createFirstPlace:
            if permissions.location == .always || permissions.location == .whenInUse {
                Task { @MainActor in
                    await automation.createFirstPlace(modules: modules, context: context, undo: undoCenter, permissions: permissions)
                }
            } else {
                showPlaceSheet = true
            }
        case .createEmployerDraft:
            automation.createEmployerAndContract(modules: modules, context: context, undo: undoCenter)
        case .openEmployment:
            destination = .employment
        case .openPay:
            destination = .pay
        case .openPlanningImport:
            destination = .planningImport
        case .openContractHours:
            destination = .contractHours
        }
    }
}
