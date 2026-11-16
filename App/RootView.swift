import SwiftUI
import SwiftData

/// Racine : onboarding au premier lancement, ensuite les quatre onglets. Applique le thème (palette) à tout l'arbre.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModuleStore.self) private var modules
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var undoCenter: UndoCenter = UndoCenter()

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
        .overlay(alignment: .bottom) {
            UndoToastView()
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, 64)
        }
        .environment(undoCenter)
        .pltTheme()
        .onChange(of: modules.isActive("undo_safety"), initial: true) { (_: Bool, isOn: Bool) in
            undoCenter.isEnabled = isOn
        }
        .onChange(of: scenePhase, initial: true) { (_: ScenePhase, phase: ScenePhase) in
            if phase == .active && modules.isActive("undo_safety") {
                UndoSnapshots.takeDailySnapshotIfDue(context: modelContext,
                                                     store: SnapshotStore(directory: SnapshotStore.defaultDirectory()),
                                                     now: Date(),
                                                     calendar: Calendar.current)
            }
        }
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
