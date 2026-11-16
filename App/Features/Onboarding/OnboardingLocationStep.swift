import SwiftUI

/// Étape 3 : explication avant la fenêtre iOS, puis résultat. Ne bloque jamais.
struct OnboardingLocationStep: View {
    @Environment(\.palette) private var palette
    let permissions: PermissionRequester
    let onContinue: () -> Void

    @State private var hasAsked: Bool = false
    @State private var isAsking: Bool = false

    private var showsResult: Bool {
        // Si l'accès est déjà décidé (retour en arrière, réglages iOS), on montre directement le résultat.
        return hasAsked || permissions.location != .notDetermined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if showsResult {
                resultView
            } else {
                introView
            }
        }
    }

    // MARK: Explication

    private var introView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: "location.fill")
            OnboardingTitle(title: "J'ai besoin de savoir où t'es.",
                            lead: "Pour noter tes heures tout seul, je dois voir quand t'arrives au taf et quand t'en pars, même app fermée. Rien ne sort de ton tel.")
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                OnboardingPoint(symbol: "mappin.and.ellipse", title: "Je repère tes lieux",
                                detail: "Seulement ceux que t'ajoutes, avec une zone autour.")
                OnboardingPoint(symbol: "figure.walk.arrival", title: "Je note arrivées et départs",
                                detail: "Écran éteint, sans que t'ouvres l'app.")
                OnboardingPoint(symbol: "lock.fill", title: "Rien n'est envoyé",
                                detail: "Pas de compte, pas de serveur.")
            }
            PLTCard {
                Text("Ce qu'iOS va te demander")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text("iOS commence par « Pendant l'utilisation », puis te redemande un peu plus tard. Choisis « Toujours autoriser », sinon je vois rien quand l'app est fermée.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            PLTCard {
                Text("Et si tu refuses ?")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text("Rien ne casse. Tu lances et tu arrêtes tes sessions à la main, et tu peux remettre la localisation quand tu veux.")
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
            await permissions.requestLocationAccess()
            isAsking = false
            hasAsked = true
        }
    }

    // MARK: Résultat

    private var resultView: some View {
        let level: LocationAccessLevel = permissions.location
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: heroSymbol(level), kind: heroKind(level))
            OnboardingTitle(title: resultTitle(level), lead: resultLead(level))
            if level != .always {
                PLTBanner(kind: level == .whenInUse ? .warning : .error,
                          title: level == .whenInUse ? "Je te vois seulement quand l'app est ouverte" : "Sans localisation, je ne vois rien tout seul",
                          message: level == .notDetermined ? "iOS ne t'a pas encore demandé. Tu peux le faire plus tard depuis Réglages." : nil,
                          actionTitle: level == .notDetermined ? nil : "Ouvrir les réglages iOS",
                          action: level == .notDetermined ? nil : { permissions.openSystemSettings() })
                PLTCard {
                    Text("Comment la remettre")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("1. Ouvre les réglages iOS de l'app, avec le bouton plus haut.\n2. Touche Position.\n3. Choisis Toujours.\n4. Laisse Position exacte activée.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    Text("Tu peux aussi le faire plus tard, depuis Réglages.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Button("Continuer", action: onContinue)
                .buttonStyle(.pltPrimary)
        }
    }

    private func heroSymbol(_ level: LocationAccessLevel) -> String {
        switch level {
        case .always: return "checkmark"
        case .whenInUse: return "location.fill"
        case .notDetermined: return "location.slash.fill"
        case .denied, .restricted: return "location.slash.fill"
        }
    }

    private func heroKind(_ level: LocationAccessLevel) -> OnboardingHero.Kind {
        switch level {
        case .always: return .ok
        case .whenInUse: return .warning
        case .notDetermined: return .warning
        case .denied, .restricted: return .error
        }
    }

    private func resultTitle(_ level: LocationAccessLevel) -> String {
        switch level {
        case .always: return "C'est bon, je peux te suivre."
        case .whenInUse: return "Presque, mais pas assez."
        case .notDetermined: return "Pas encore de réponse."
        case .denied, .restricted: return "Localisation refusée."
        }
    }

    private func resultLead(_ level: LocationAccessLevel) -> String {
        switch level {
        case .always: return "iOS m'a donné « Toujours ». Je note tes arrivées et tes départs sans que t'aies rien à faire."
        case .whenInUse: return "Du coup je rate tes arrivées et tes départs. Passe la localisation sur « Toujours » dans les réglages iOS, ça prend dix secondes."
        case .notDetermined: return "Tu peux continuer, je te le redemanderai quand tu voudras."
        case .denied, .restricted: return "Je ne note plus tes arrivées. Tu peux lancer et arrêter tes sessions à la main, ou remettre la localisation quand tu veux."
        }
    }
}
