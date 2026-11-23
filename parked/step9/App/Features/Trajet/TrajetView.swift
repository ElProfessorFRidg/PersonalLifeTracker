import SwiftUI
import SwiftData

/// Écran `trajet` (section 35) : mode de transport, marge de sécurité, fenêtre de la carte, notifications par lieu.
/// Poussé dans une NavigationStack existante.
struct TrajetView: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Place.name) private var places: [Place]

    private let store: TravelSettingsStore = TravelSettingsStore.shared

    @State private var notificationsRefused: Bool = false

    private var modeBinding: Binding<TravelMode> {
        return Binding<TravelMode>(
            get: { return store.settings.defaultMode },
            set: { (newValue: TravelMode) in
                store.update { (s: inout TravelSettings) in s.defaultModeRaw = newValue.rawValue }
            }
        )
    }

    private var marginBinding: Binding<Int> {
        return Binding<Int>(
            get: { return store.settings.marginMinutes },
            set: { (v: Int) in store.update { (s: inout TravelSettings) in s.marginMinutes = v } }
        )
    }

    private var windowBinding: Binding<Int> {
        return Binding<Int>(
            get: { return store.settings.windowMinutes },
            set: { (v: Int) in store.update { (s: inout TravelSettings) in s.windowMinutes = v } }
        )
    }

    private var fallbackBinding: Binding<Int> {
        return Binding<Int>(
            get: { return store.settings.fallbackMinutes },
            set: { (v: Int) in store.update { (s: inout TravelSettings) in s.fallbackMinutes = v } }
        )
    }

    private var notifyBinding: Binding<Bool> {
        return Binding<Bool>(
            get: { return store.settings.notifyByDefault },
            set: { (v: Bool) in
                store.update { (s: inout TravelSettings) in s.notifyByDefault = v }
                if v { askNotificationPermission() }
            }
        )
    }

    var body: some View {
        PLTScreen(title: "Trajet") {
            PartirMaintenantCard(alwaysShown: true)

            if notificationsRefused {
                PLTBanner(kind: .warning,
                          title: "Les notifications sont refusées",
                          message: "Autorise-les dans les réglages de l'iPhone pour recevoir « Pars maintenant ».")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Mode de transport par défaut")
                Picker("Mode de transport", selection: modeBinding) {
                    ForEach(TravelMode.allCases) { (mode: TravelMode) in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Réglages")
                PLTCard {
                    Stepper(value: marginBinding, in: 0...TravelDepartureRules.maxMarginMinutes, step: 5) {
                        Text("Marge de sécurité : \(store.settings.marginMinutes) min")
                            .font(.body.monospacedDigit())
                    }
                    .frame(minHeight: 44)
                    Stepper(value: windowBinding, in: 15...TravelDepartureRules.maxWindowMinutes, step: 15) {
                        Text("Carte visible \(store.settings.windowMinutes) min avant le départ")
                            .font(.body.monospacedDigit())
                    }
                    .frame(minHeight: 44)
                    Stepper(value: fallbackBinding, in: 5...TravelDepartureRules.maxFallbackTravelMinutes, step: 5) {
                        Text("Trajet par défaut sans position : \(store.settings.fallbackMinutes) min")
                            .font(.body.monospacedDigit())
                    }
                    .frame(minHeight: 44)
                    Toggle("Notification par défaut", isOn: notifyBinding)
                        .frame(minHeight: 44)
                    Text("Une seule notification locale, à l'heure de départ, jamais de suivi en continu. L'estimation vient de Plans quand tu as du réseau, sinon d'un calcul à vol d'oiseau, sinon de la durée par défaut.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Par lieu")
                if places.isEmpty {
                    PLTEmptyState(symbol: "mappin.and.ellipse",
                                  title: "Aucun lieu",
                                  message: "Ajoute un lieu de taf ou de cours pour régler son trajet.")
                } else {
                    PLTCard {
                        ForEach(places) { (place: Place) in
                            TrajetPlaceRow(placeUID: place.uid, placeName: place.name, onNotifyOn: { askNotificationPermission() })
                        }
                    }
                }
            }
        }
    }

    private func askNotificationPermission() {
        JournalNotifier.requestAuthorization { (granted: Bool) in
            notificationsRefused = !granted
        }
    }
}

/// Réglage d'un lieu : mode de transport et notification.
private struct TrajetPlaceRow: View {
    @Environment(\.palette) private var palette

    let placeUID: UUID
    let placeName: String
    let onNotifyOn: () -> Void

    private let store: TravelSettingsStore = TravelSettingsStore.shared

    private var modeBinding: Binding<TravelMode> {
        return Binding<TravelMode>(
            get: { return store.settings.mode(for: placeUID) },
            set: { (newValue: TravelMode) in
                store.update { (s: inout TravelSettings) in s.setMode(newValue, for: placeUID) }
            }
        )
    }

    private var notifyBinding: Binding<Bool> {
        return Binding<Bool>(
            get: { return store.settings.notifies(for: placeUID) },
            set: { (v: Bool) in
                store.update { (s: inout TravelSettings) in s.setNotify(v, for: placeUID) }
                if v { onNotifyOn() }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(placeName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                Picker("Mode pour \(placeName)", selection: modeBinding) {
                    ForEach(TravelMode.allCases) { (mode: TravelMode) in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
            }
            Toggle("Notification pour \(placeName)", isOn: notifyBinding)
                .font(.subheadline)
                .frame(minHeight: 44)
        }
    }
}
