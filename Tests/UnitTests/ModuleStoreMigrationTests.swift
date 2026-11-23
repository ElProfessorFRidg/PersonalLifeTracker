import XCTest
@testable import PersonalLifeTracker

final class ModuleStoreMigrationTests: XCTestCase {
    private func freshDefaults(_ name: String) -> UserDefaults {
        let d: UserDefaults = UserDefaults(suiteName: name)!
        d.removePersonalDomain(name)
        return d
    }

    func testFirstLaunchUsesRegistryDefaults() {
        let d: UserDefaults = freshDefaults("plt.test.migration.first")
        let store: ModuleStore = ModuleStore(defaults: d)
        XCTAssertEqual(store.enabledIDs, ModuleRegistry.defaultEnabledIDs)
    }

    func testModuleAddedSinceLastSaveAndDefaultOnGetsEnabled() {
        let d: UserDefaults = freshDefaults("plt.test.migration.new")
        // Sauvegarde ancienne : l'utilisateur n'avait que le noyau, et « employment » n'existait pas encore dans la liste des connus.
        let known: [String] = ModuleRegistry.all.map { $0.id }.filter { $0 != "employment" }
        d.set(Array(ModuleRegistry.mandatoryIDs).sorted(), forKey: ModuleStore.defaultsKey)
        d.set(known, forKey: ModuleStore.seenKey)
        let store: ModuleStore = ModuleStore(defaults: d)
        XCTAssertTrue(store.isEnabled("employment"))
        // Un module connu et décoché reste décoché.
        XCTAssertFalse(store.isEnabled("notes"))
    }

    func testModuleKnownAndUncheckedStaysUnchecked() {
        let d: UserDefaults = freshDefaults("plt.test.migration.keep")
        let known: [String] = ModuleRegistry.all.map { $0.id }
        d.set(Array(ModuleRegistry.mandatoryIDs).sorted(), forKey: ModuleStore.defaultsKey)
        d.set(known, forKey: ModuleStore.seenKey)
        let store: ModuleStore = ModuleStore(defaults: d)
        XCTAssertFalse(store.isEnabled("employment"))
    }
}
