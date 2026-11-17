import SwiftUI

/// Étape 4 : explication avant la fenêtre iOS, puis résultat. Ne bloque jamais.
struct OnboardingNotificationsStep: View {
    @Environment(\.palette) private var palette
    let permissions: PermissionRequester
    let onContinue: () -> Void

    @State private var hasAsked: Bool = false
    @State private var isAsking: Bool = false

    private var showsResult: Bool {
        return hasAsked || permissions.notifications != .notDetermined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if showsResult {
                resultView
            } else {
                introView
            }
        }
        .task {
            await permissions.refreshNotifications()
        }
    }

    private var introView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: "bell.badge.fill")
            OnboardingTitle(title: "Je te préviens en un tap.",
                            lead: "Quand j'ai un doute, je te le demande vite fait : « T'es arrivé au taf à 17:56, c'est bon ? ». Tu réponds depuis l'écran verrouillé.")
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                OnboardingPoint(symbol: "number", title: "6 par jour maximum",
                                detail: "Je regroupe, je spamme pas.")
                OnboardingPoint(symbol: "moon.fill", title: "Silence la nuit",
                                detail: "Heures silencieuses réglables.")
                OnboardingPoint(symbol: "slider.horizontal.3", title: "Tu choisis par catégorie",
                                detail: "Tu coupes ce qui te sert pas.")
            }
            PLTCard {
                Text("Et si tu refuses ?")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text("Rien ne casse. Tes heures sont notées pareil, mais je peux pas te demander de confirmer quand t'es pas dans l'app.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            Button(isAsking ? "Je te demande..." : "Continuer") {
                ask()
            }
            .buttonStyle(.pltPrimary)
            .disabled(isAsking)
            Text("Rien ne se passe avant que tu touches un bouton d'iOS.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func ask() {
        isAsking = true
        Task { @MainActor in
            await permissions.requestNotifications()
            isAsking = false
            hasAsked = true
        }
    }

    private var resultView: some View {
        let level: NotificationAccessLevel = permissions.notifications
        let granted: Bool = level == .authorized
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: granted ? "checkmark" : "bell.slash.fill", kind: granted ? .ok : .warning)
            OnboardingTitle(title: granted ? "Top, je te préviens au bon moment." : "Pas de notifications, pas de souci.",
                            lead: granted
                                ? "6 par jour maximum, jamais la nuit. Tu règles tout dans Réglages, Notifications."
                                : "Je te poserai mes questions sur l'accueil, dans la carte Maintenant. Il faudra juste ouvrir l'app pour les voir.")
            if !granted {
                PLTBanner(kind: .warning,
                          title: "Les notifications sont coupées",
                          message: "Si tu changes d'avis : Réglages iOS, Notifications, puis « Autoriser les notifications ».",
                          actionTitle: "Ouvrir les réglages iOS",
                          action: { permissions.openSystemSettings() })
            }
            Button("Continuer", action: onContinue)
                .buttonStyle(.pltPrimary)
        }
    }
}
