import SwiftUI
import SwiftData

@main
struct PersonalLifeTrackerApp: App {
    private let container: ModelContainer
    @State private var settings: AppSettings = AppSettings()
    @State private var moduleStore: ModuleStore = ModuleStore()
    @State private var geofence: GeofenceService

    /// Garde les services en vie même si aucune scène n'existe (relance en arrière-plan par un événement de région).
    private static var retainedServices: [AnyObject] = []

    init() {
        let built = AppModelContainer.makeForApp()
        self.container = built.container
        let builtContainer: ModelContainer = built.container
        var created: GeofenceService? = nil
        MainActor.assumeIsolated {
            let notifier = DetectionNotifier(container: builtContainer)
            let service = GeofenceService(container: builtContainer, notifier: notifier)
            notifier.install()
            service.start()
            PersonalLifeTrackerApp.retainedServices.append(notifier)
            PersonalLifeTrackerApp.retainedServices.append(service)
            created = service
        }
        guard let service = created else {
            fatalError("GeofenceService non créé")
        }
        self._geofence = State(initialValue: service)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(moduleStore)
                .environment(geofence)
                .modelContainer(container)
        }
    }
}
