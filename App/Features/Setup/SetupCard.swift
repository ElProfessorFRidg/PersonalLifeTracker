import SwiftUI
import SwiftData

/// Carte compacte de l'Accueil : progression de la configuration et prochaine étape.
/// Elle disparaît quand tout est fait, ou après « Plus tard » (elle revient si une permission se bloque ensuite).
@MainActor
struct SetupCard: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    @Query private var places: [Place]
    @Query private var employers: [Employer]
    @Query private var contracts: [Contract]
    @Query private var payRates: [PayRate]
    @Query private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]

    @State private var capabilities: CapabilityService = CapabilityService()
    /// Incrémenté après « Plus tard » pour relire UserDefaults.
    @State private var refreshToken: Int = 0

    var body: some View {
        let facts: SetupFacts = SetupFactsBuilder.facts(capabilities: capabilities,
                                                        modules: modules,
                                                        places: places,
                                                        employers: employers,
                                                        contracts: contracts,
                                                        payRates: payRates,
                                                        shifts: shifts,
                                                        sessionCount: sessions.count)
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        let dismissal: SetupDismissal = SetupDismissal()
        let dismissed: Bool = refreshToken >= 0 && dismissal.isDismissed
        let show: Bool = SetupChecklist.shouldShowCard(steps: steps, isDismissed: dismissed, dismissedBlockedIDs: dismissal.blockedIDs)
        return Group {
            if show {
                card(steps: steps)
            }
        }
        .onAppear { capabilities.refresh() }
        .onChange(of: scenePhase) { (_: ScenePhase, newPhase: ScenePhase) in
            if newPhase == .active { capabilities.refresh() }
        }
    }

    private func card(steps: [SetupStep]) -> some View {
        let progress: SetupProgress = SetupChecklist.progress(of: steps)
        let next: SetupStep? = SetupChecklist.nextStep(in: steps)
        return PLTCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Configuration")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                Text(progress.text)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
            ProgressView(value: progress.fraction)
                .tint(palette.accent)
            if let step = next {
                if step.status == .blocked {
                    PLTBanner(kind: .warning, title: step.title, message: step.why)
                } else {
                    Text("Prochaine étape : \(step.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(step.why)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(3)
                }
            }
            NavigationLink {
                SetupAssistantView()
            } label: {
                Text("Continuer la configuration")
            }
            .buttonStyle(.pltPrimary)
            Button("Plus tard") {
                SetupDismissal().dismiss(blockedIDs: SetupChecklist.blockedPermissionIDs(in: steps))
                refreshToken += 1
            }
            .buttonStyle(.pltSecondary)
        }
    }
}
