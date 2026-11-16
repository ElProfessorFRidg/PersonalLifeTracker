import SwiftUI

/// Racine : onboarding au premier lancement, ensuite les quatre onglets. Applique le thème (palette) à tout l'arbre.
struct RootView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(onDone: {
                    settings.hasCompletedOnboarding = true
                })
            }
        }
        .pltTheme()
    }
}

enum AppTab: Hashable {
    case accueil
    case planning
    case lieux
    case stats
}

/// Les 4 onglets de la maquette. Chaque onglet a sa NavigationStack : les écrans de contenu n'en ajoutent pas.
struct MainTabView: View {
    @State private var selection: AppTab = .accueil

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { AccueilView() }
                .tabItem { Label("Accueil", systemImage: "house") }
                .tag(AppTab.accueil)
            NavigationStack { PlanningView() }
                .tabItem { Label("Planning", systemImage: "calendar") }
                .tag(AppTab.planning)
            NavigationStack { LieuxView() }
                .tabItem { Label("Lieux", systemImage: "mappin.and.ellipse") }
                .tag(AppTab.lieux)
            NavigationStack { StatsView() }
                .tabItem { Label("Statistiques", systemImage: "chart.bar") }
                .tag(AppTab.stats)
        }
    }
}
