import SwiftUI
import SwiftData

/// Cartes de l'Accueil pour battery_recovery (section 131) et clock_check (section 140).
/// Chaque carte n'apparaît que si son module est actif. Les états viennent de UserDefaults (voir RecoveryStore, ClockCheckStore).
struct RecoveryCardsSection: View {
    let now: Date
    let calendar: Calendar
    let running: WorkSession?

    @Environment(ModuleStore.self) private var modules
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?

    /// Incrémenté après chaque action pour relire UserDefaults.
    @State private var refreshToken: Int = 0
    @State private var showCustomTime: Bool = false
    @State private var customDate: Date = Date()

    private var pendingPlan: RecoveryPlan? {
        let token: Int = refreshToken
        if token < 0 { return nil }
        guard modules.isActive("battery_recovery") else { return nil }
        guard let plan = RecoveryStore().loadPending() else { return nil }
        guard let live = running, live.uid == plan.sessionID, live.endDate == nil else { return nil }
        return plan
    }

    private var clockAlert: ClockAlert? {
        let token: Int = refreshToken
        if token < 0 { return nil }
        guard modules.isActive("clock_check") else { return nil }
        guard let alert = ClockCheckStore().loadAlert(), !alert.isDismissed else { return nil }
        return alert
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let plan = pendingPlan {
                recoveryCard(plan)
            }
            if let alert = clockAlert {
                clockCards(alert)
            }
        }
        .sheet(isPresented: $showCustomTime) {
            if let plan = pendingPlan {
                RecoveryCustomTimeSheet(plan: plan, calendar: calendar, initial: customDate) { (picked: Date) in
                    RecoveryApplier.apply(choice: .custom, plan: plan, customDate: picked, context: context, undo: undoCenter)
                    refreshToken += 1
                }
            }
        }
    }

    // MARK: Récupération après extinction

    private func recoveryCard(_ plan: RecoveryPlan) -> some View {
        let endText: String = Formatting.clock(plan.estimatedEnd, calendar: calendar)
        return PLTCard {
            Text(RecoveryText.title(plan: plan, calendar: calendar))
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(RecoveryText.message(plan: plan, calendar: calendar))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Button {
                RecoveryApplier.apply(choice: .endAtLastHint, plan: plan, context: context, undo: undoCenter)
                refreshToken += 1
            } label: {
                Text("Fin à \(endText)")
                    .font(.headline.monospacedDigit())
            }
            .buttonStyle(.pltPrimary)
            .accessibilityLabel("Terminer la session à \(endText)")
            Button {
                RecoveryApplier.apply(choice: .stillThere, plan: plan, context: context, undo: undoCenter)
                refreshToken += 1
            } label: {
                Text("J'étais encore là")
            }
            .buttonStyle(.pltSecondary)
            Button {
                customDate = plan.customUpper
                showCustomTime = true
            } label: {
                Text("Choisir une autre heure")
            }
            .buttonStyle(.pltSecondary)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Contrôle de l'horloge

    @ViewBuilder
    private func clockCards(_ alert: ClockAlert) -> some View {
        if let jump = alert.jump {
            PLTBanner(kind: .warning,
                      title: ClockText.jumpTitle(jump),
                      message: ClockText.jumpMessage(jump, affected: alert.affectedSessionCount),
                      actionTitle: "Compris",
                      action: { dismissClock() })
        }
        if let zone = alert.timeZoneChange {
            PLTBanner(kind: .info,
                      title: ClockText.zoneTitle(zone),
                      message: ClockText.zoneMessage(zone),
                      actionTitle: "Compris",
                      action: { dismissClock() })
        }
    }

    private func dismissClock() {
        ClockCheckStore().dismissAlert()
        refreshToken += 1
    }
}

/// Choix d'une heure de fin dans la plage bornée par les traces (dernier indice, réveil).
struct RecoveryCustomTimeSheet: View {
    let plan: RecoveryPlan
    let calendar: Calendar
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var picked: Date

    init(plan: RecoveryPlan, calendar: Calendar, initial: Date, onConfirm: @escaping (Date) -> Void) {
        self.plan = plan
        self.calendar = calendar
        self.onConfirm = onConfirm
        let clamped: Date = min(max(initial, plan.customLower), plan.customUpper)
        _picked = State(initialValue: clamped)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text("Choisis l'heure à laquelle ta session s'est arrêtée. Je n'accepte que des heures entre \(Formatting.clock(plan.customLower, calendar: calendar)) et \(Formatting.clock(plan.customUpper, calendar: calendar)), là où j'ai des traces.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                DatePicker("Heure de fin",
                           selection: $picked,
                           in: plan.customLower...plan.customUpper,
                           displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.calendar, calendar)
                    .environment(\.timeZone, calendar.timeZone)
                Button {
                    onConfirm(picked)
                    dismiss()
                } label: {
                    Text("Confirmer")
                }
                .buttonStyle(.pltPrimary)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.m)
            .background(palette.background)
            .navigationTitle("Autre heure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
