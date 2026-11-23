import SwiftUI

/// Écran `pauses` (section 32) : réglages des pauses. Jamais imposées. Poussé dans une NavigationStack existante.
struct PausesView: View {
    @Environment(\.palette) private var palette

    private let settings: BreakSettingsStore = BreakSettingsStore.shared
    private let store: BreakStore = BreakStore.shared

    @State private var notificationsRefused: Bool = false

    private var modeBinding: Binding<BreakMode> {
        return Binding<BreakMode>(
            get: { return settings.mode },
            set: { (newValue: BreakMode) in
                settings.setMode(newValue)
                if newValue == .reminder {
                    JournalNotifier.requestAuthorization { (granted: Bool) in
                        notificationsRefused = !granted
                    }
                }
            }
        )
    }

    private var paidBinding: Binding<Bool> {
        return Binding<Bool>(get: { return settings.isPaid }, set: { (v: Bool) in settings.setPaid(v) })
    }

    private var hoursBinding: Binding<Double> {
        return Binding<Double>(get: { return settings.reminderHours }, set: { (v: Double) in settings.setReminderHours(v) })
    }

    var body: some View {
        PLTScreen(title: "Pauses") {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Ce que l'app fait")
                Picker("Pauses", selection: modeBinding) {
                    ForEach(BreakMode.allCases) { (mode: BreakMode) in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                Text(settings.mode.explanation)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            if notificationsRefused && settings.mode == .reminder {
                PLTBanner(kind: .warning,
                          title: "Les notifications sont refusées",
                          message: "Autorise-les dans les réglages de l'iPhone pour recevoir le rappel.")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Comptage")
                PLTCard {
                    Toggle("Pause payée", isOn: paidBinding)
                        .frame(minHeight: 44)
                    Text(settings.isPaid
                         ? "Rien n'est déduit de ton temps de travail."
                         : "La durée de tes pauses est déduite de ton temps de travail, dans le net affiché sur la session.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            if settings.mode == .reminder {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PLTSectionHeader(title: "Rappel")
                    PLTCard {
                        Stepper(value: hoursBinding, in: BreaksRules.minReminderHours...BreaksRules.maxReminderHours, step: 0.5) {
                            Text("Après \(BreaksRules.hoursLabel(settings.reminderHours)) sans pause")
                                .font(.body.monospacedDigit())
                        }
                        .frame(minHeight: 44)
                        Text("Une seule notification par session, jamais pendant une pause.")
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }

            if settings.mode != .none {
                PLTBanner(kind: .info, title: "À titre d'information", message: BreaksRules.legalReminderText)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Où enregistrer une pause")
                Text("Ouvre une session en cours, puis « Démarrer une pause » ou « Ajouter à la main ». Les pauses apparaissent dans le détail de la session.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                Text("\(store.records.count) pause(s) enregistrée(s) au total.")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
