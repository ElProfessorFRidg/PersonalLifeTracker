import SwiftUI
import SwiftData
import OSLog

@main
struct PersonalLifeTrackerApp: App {
    private struct OpenStore {
        let container: ModelContainer
        let geofence: GeofenceService
    }

    @State private var store: OpenStore?
    @State private var settings: AppSettings = AppSettings()
    @State private var moduleStore: ModuleStore = ModuleStore()

    /// Garde les services en vie même si aucune scène n'existe (relance en arrière-plan par un événement de région).
    private static var retainedServices: [AnyObject] = []
    private static let logger = Logger(subsystem: "io.github.elprofessorfridg.personallifetracker", category: "Persistence")

    init() {
        _store = State(initialValue: MainActor.assumeIsolated { Self.openStore() })
    }

    @MainActor
    private static func openStore() -> OpenStore? {
        do {
            let container = try IntentStore.sharedContainer()
            let notifier = DetectionNotifier(container: container)
            let geofence = GeofenceService(container: container, notifier: notifier)
            geofence.start()
            retainedServices.append(notifier)
            retainedServices.append(geofence)
            return OpenStore(container: container, geofence: geofence)
        } catch {
            logger.error("Ouverture de la base locale impossible : \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store {
                RootView()
                    .modifier(SendHoursReminderActivation())
                    .environment(settings)
                    .environment(moduleStore)
                    .environment(store.geofence)
                    .modelContainer(store.container)
            } else {
                ContentUnavailableView {
                    Label("Historique indisponible", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Life Tracker n’a pas pu ouvrir sa base locale. Réessaie pour retrouver tes lieux et tes sessions.")
                } actions: {
                    Button("Réessayer") { store = Self.openStore() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
