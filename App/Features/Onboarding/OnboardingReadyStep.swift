import SwiftUI

/// Étape 7 : récap, avertissement si la localisation n'est pas "Toujours", bouton final.
struct OnboardingReadyStep: View {
    @Environment(\.palette) private var palette
    @Environment(ModuleStore.self) private var modules
    let permissions: PermissionRequester
    let place: OnboardingPlaceSummary?
    let goTo: (OnboardingStep) -> Void
    let onDone: () -> Void

    private var warnings: [OnboardingWarning] {
        return OnboardingFlow.warnings(location: permissions.location, notifications: permissions.notifications)
    }

    private var isPartial: Bool {
        return OnboardingFlow.isDetectionLimited(location: permissions.location)
    }

    private var modulesText: String {
        let n: Int = OnboardingFlow.offeredEnabledCount(enabled: modules.enabledIDs)
        if n == 0 { return "Seulement le noyau" }
        return "Le noyau et \(n) en plus"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: isPartial ? "exclamationmark" : "checkmark", kind: isPartial ? .warning : .ok)
            OnboardingTitle(title: isPartial ? "C'est prêt, presque." : "C'est prêt.",
                            lead: isPartial
                                ? "Je peux démarrer, mais il manque un réglage pour que je note tes heures tout seul. Corrige-le d'un tap."
                                : "Voilà ce que j'ai compris. Un truc cloche ? Corrige-le d'un tap.")

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Voilà ce que j'ai compris")
                PLTListGroup {
                    PLTRow(symbol: "square.grid.2x2.fill", tone: .accent,
                           title: "Fonctionnalités", subtitle: modulesText,
                           showsChevron: true, action: { goTo(.modules) })
                    PLTRow(symbol: "location.fill", tone: locationTone,
                           title: "Localisation", subtitle: "Pour noter tes arrivées et tes départs",
                           value: locationValue, action: { goTo(.location) })
                    PLTRow(symbol: "bell.fill", tone: notificationsTone,
                           title: "Notifications", subtitle: "6 par jour maximum",
                           value: notificationsValue, action: { goTo(.notifications) })
                    placeRow
                }
                Text("Tout est modifiable ensuite dans Réglages.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            ForEach(warnings, id: \.self) { warning in
                warningBanner(warning)
            }

            VStack(spacing: Theme.Spacing.s) {
                Button("Aller à l'accueil", action: onDone)
                    .buttonStyle(.pltPrimary)
                Text("Bonne journée, et bon taf.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var placeRow: some View {
        if let place = place {
            PLTRow(symbol: place.typeTitle == PlaceType.cours.title ? "graduationcap.fill" : "briefcase.fill",
                   tone: place.typeTitle == PlaceType.cours.title ? .study : .work,
                   title: place.name,
                   subtitle: "\(place.typeTitle), zone de \(Int(place.radius)) m",
                   showsSeparator: false,
                   action: { goTo(.firstPlace) })
        } else {
            PLTRow(symbol: "mappin.and.ellipse", tone: .neutral,
                   title: "Premier lieu", subtitle: "Pas encore, tu l'ajouteras depuis Lieux",
                   value: "Corriger", showsSeparator: false,
                   action: { goTo(.firstPlace) })
        }
    }

    private var locationValue: String {
        switch permissions.location {
        case .always: return "Toujours"
        case .whenInUse: return "App ouverte"
        case .notDetermined: return "Pas demandée"
        case .denied, .restricted: return "Refusée"
        }
    }

    private var locationTone: PLTTone {
        return permissions.location == .always ? .accent : .danger
    }

    private var notificationsValue: String {
        switch permissions.notifications {
        case .authorized: return "Autorisées"
        case .denied: return "Refusées"
        case .notDetermined: return "Pas demandées"
        }
    }

    private var notificationsTone: PLTTone {
        return permissions.notifications == .authorized ? .accent : .neutral
    }

    @ViewBuilder
    private func warningBanner(_ warning: OnboardingWarning) -> some View {
        switch warning {
        case .locationNotAlways:
            PLTBanner(kind: .warning,
                      title: "Je te vois seulement quand l'app est ouverte",
                      message: "Sans « Toujours », je rate tes arrivées. Corrige-le avec la ligne Localisation, ou fais sans et lance tes sessions à la main.",
                      actionTitle: "Ouvrir les réglages iOS",
                      action: { permissions.openSystemSettings() })
        case .locationDenied:
            PLTBanner(kind: .error,
                      title: "La localisation est refusée",
                      message: "Je ne peux pas noter tes arrivées. Lance tes sessions à la main, ou remets la localisation dans les réglages iOS.",
                      actionTitle: "Ouvrir les réglages iOS",
                      action: { permissions.openSystemSettings() })
        case .notificationsDenied:
            PLTBanner(kind: .info,
                      title: "Les notifications sont coupées",
                      message: "Rien ne casse, je te poserai mes questions sur l'accueil.")
        }
    }
}
