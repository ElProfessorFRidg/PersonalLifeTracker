import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues lues dans spec/MODULES.md (section 1, tableau du registre).
final class ModuleRegistryTests: XCTestCase {
    private func def(_ id: String) -> ModuleDefinition {
        return ModuleRegistry.definition(for: id)!
    }

    // MARK: données du registre

    func testIdsAreUnique() {
        let ids = ModuleRegistry.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testRegistryHoldsCorePlusAllRowsOfModulesTable() {
        // spec/MODULES.md section 1 : 108 lignes, plus le noyau.
        XCTAssertEqual(ModuleRegistry.all.count, 109)
        XCTAssertEqual(ModuleRegistry.all.first?.id, "core")
    }

    func testCoreIsMandatoryAndOnByDefault() {
        let core = def("core")
        XCTAssertTrue(core.isMandatory)
        XCTAssertTrue(core.isAvailable)
        XCTAssertTrue(ModuleRegistry.defaultEnabledIDs.contains("core"))
        XCTAssertEqual(ModuleRegistry.mandatoryIDs, ["core"])
    }

    func testEveryRequirementPointsToAnExistingOtherModule() {
        let ids = Set(ModuleRegistry.all.map { $0.id })
        for m in ModuleRegistry.all {
            for r in m.requires {
                XCTAssertTrue(ids.contains(r), "\(m.id) exige \(r) qui n'existe pas")
                XCTAssertNotEqual(r, m.id, "\(m.id) s'exige lui-même")
            }
        }
    }

    func testDefaultsAndRequirementsMatchSpecTable() {
        XCTAssertTrue(def("planning_ocr").defaultOn)
        XCTAssertTrue(def("employment").defaultOn)
        XCTAssertFalse(def("leave").defaultOn)
        XCTAssertFalse(def("multi_employer").defaultOn)
        XCTAssertEqual(def("pay").requires, ["employment"])
        XCTAssertEqual(def("leave").requires, ["employment"])
        XCTAssertEqual(def("simulator").requires, ["pay"])
        XCTAssertEqual(def("interview_prep").requires, ["employment", "pay"])
        XCTAssertEqual(def("schedule_archive").requires, ["planning_ocr"])
        XCTAssertEqual(def("pay").step, 5)
        XCTAssertEqual(def("undo_safety").step, 2)
    }

    // MARK: règles de dépendances

    func testEnablingPayAlsoEnablesEmployment() {
        let result = ModuleRules.enabling("pay", in: ["core"])
        XCTAssertEqual(result, ["core", "employment", "pay"])
    }

    func testEnablingFollowsRequirementsTransitively() {
        // payslip_check exige pay, qui exige employment.
        let result = ModuleRules.enabling("payslip_check", in: ["core"])
        XCTAssertEqual(result, ["core", "employment", "pay", "payslip_check"])
    }

    func testEnablingKeepsOtherModulesAndAddsCore() {
        let result = ModuleRules.enabling("notes", in: ["search"])
        XCTAssertEqual(result, ["core", "search", "notes"])
    }

    func testEnablingUnknownIdChangesNothingButKeepsCore() {
        XCTAssertEqual(ModuleRules.enabling("n_existe_pas", in: ["notes"]), ["core", "notes"])
    }

    func testDisablingEmploymentDisablesDependentsTransitively() {
        // leave exige employment, simulator exige pay qui exige employment.
        let start: Set<String> = ["core", "employment", "pay", "leave", "simulator", "notes"]
        XCTAssertEqual(ModuleRules.disabling("employment", in: start), ["core", "notes"])
    }

    func testDisablingPayKeepsEmploymentAndSiblings() {
        let start: Set<String> = ["core", "employment", "pay", "leave", "simulator"]
        XCTAssertEqual(ModuleRules.disabling("pay", in: start), ["core", "employment", "leave"])
    }

    func testCoreCannotBeDisabled() {
        let start: Set<String> = ["core", "employment"]
        XCTAssertEqual(ModuleRules.disabling("core", in: start), start)
    }

    func testDisablingRestoresCoreEvenIfMissingFromInput() {
        XCTAssertEqual(ModuleRules.disabling("notes", in: ["notes"]), ["core"])
    }

    func testRequirementsAndDependentsQueries() {
        XCTAssertEqual(ModuleRules.requirements(of: "payslip_check"), ["pay", "employment"])
        let dependents = ModuleRules.dependents(of: "employment")
        XCTAssertTrue(dependents.contains("pay"))
        XCTAssertTrue(dependents.contains("simulator"))
        XCTAssertTrue(dependents.contains("leave"))
        XCTAssertFalse(dependents.contains("notes"))
        XCTAssertFalse(dependents.contains("employment"))
    }

    func testMissingRequirementsAndActiveDependents() {
        XCTAssertEqual(ModuleRules.missingRequirements(for: "pay", enabled: ["core"]), ["employment"])
        XCTAssertEqual(ModuleRules.missingRequirements(for: "pay", enabled: ["core", "employment"]), [])
        XCTAssertEqual(ModuleRules.activeDependents(of: "pay", enabled: ["core", "pay", "simulator", "leave"]), ["simulator"])
    }

    func testCyclicRequirementsTerminate() {
        let a = ModuleDefinition(id: "a", title: "A", summary: "", step: 1, defaultOn: false, requires: ["b"], isAvailable: true)
        let b = ModuleDefinition(id: "b", title: "B", summary: "", step: 1, defaultOn: false, requires: ["a"], isAvailable: true)
        XCTAssertEqual(ModuleRules.requirements(of: "a", registry: [a, b]), ["b"])
        XCTAssertEqual(ModuleRules.dependents(of: "a", registry: [a, b]), ["b"])
        XCTAssertEqual(ModuleRules.enabling("a", in: [], registry: [a, b]), ["a", "b"])
    }

    // MARK: ModuleStore

    func testStoreStartsFromRegistryDefaults() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let store = ModuleStore(defaults: iso.defaults)
        XCTAssertEqual(store.enabledIDs, ModuleRegistry.defaultEnabledIDs)
        XCTAssertTrue(store.isEnabled("employment"))
        XCTAssertFalse(store.isEnabled("leave"))
    }

    func testStoreAppliesDependenciesAndPersists() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let store = ModuleStore(defaults: iso.defaults)
        store.setEnabled("employment", false)
        XCTAssertFalse(store.isEnabled("pay"), "pay dépend d'employment")
        store.setEnabled("leave", true)
        XCTAssertTrue(store.isEnabled("employment"), "leave exige employment")
        XCTAssertTrue(store.isEnabled("leave"))

        let reloaded = ModuleStore(defaults: iso.defaults)
        XCTAssertEqual(reloaded.enabledIDs, store.enabledIDs)
        XCTAssertTrue(reloaded.isEnabled("leave"))
        XCTAssertFalse(reloaded.isEnabled("pay"))
    }

    func testStoreNeverDisablesCore() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let store = ModuleStore(defaults: iso.defaults)
        store.setEnabled("core", false)
        XCTAssertTrue(store.isEnabled("core"))
        XCTAssertTrue(store.isActive("core"))
    }

    func testStoreIgnoresUnknownStoredIdsAndKeepsCore() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        iso.defaults.set(["notes", "module_disparu"], forKey: ModuleStore.defaultsKey)
        let store = ModuleStore(defaults: iso.defaults)
        XCTAssertEqual(store.enabledIDs, ["core", "notes"])
    }

    func testIsActiveRequiresAvailability() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let store = ModuleStore(defaults: iso.defaults)
        for m in ModuleRegistry.all {
            XCTAssertEqual(store.isActive(m.id), m.isAvailable && store.isEnabled(m.id), m.id)
        }
        XCTAssertFalse(store.isActive("n_existe_pas"))
    }

    func testResetToDefaults() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let store = ModuleStore(defaults: iso.defaults)
        store.setEnabled("leave", true)
        store.setEnabled("notes", false)
        store.resetToDefaults()
        XCTAssertEqual(store.enabledIDs, ModuleRegistry.defaultEnabledIDs)
    }
}
