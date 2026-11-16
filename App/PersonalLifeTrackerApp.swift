import SwiftUI
import SwiftData

@main
struct PersonalLifeTrackerApp: App {
    private let container: ModelContainer
    @State private var settings: AppSettings = AppSettings()
    @State private var moduleStore: ModuleStore = ModuleStore()

    init() {
        self.container = AppModelContainer.makeForApp().container
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(moduleStore)
                .modelContainer(container)
        }
    }
}
