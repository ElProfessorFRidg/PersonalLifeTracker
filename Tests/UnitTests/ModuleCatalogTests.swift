import XCTest
@testable import PersonalLifeTracker

final class ModuleCatalogTests: XCTestCase {

    private func mod(_ id: String, _ title: String, _ summary: String = "", requires: [String] = [],
                     available: Bool = true) -> ModuleDefinition {
        return ModuleDefinition(id: id, title: title, summary: summary, step: 1, defaultOn: false,
                                requires: requires, isAvailable: available)
    }

    private var mini: [ModuleDefinition] {
        return [
            ModuleRegistry.core,
            mod("employment", "Employeurs et contrats"),
            mod("pay", "Salaire et paie", "Estime ta paie", requires: ["employment"]),
            mod("leave", "Congés payés", "Compte tes congés", requires: ["employment"], available: false),
            mod("mystery", "Fonction sans thème")
        ]
    }

    // MARK: groupes sur le vrai registre

    func testEveryOptionalModuleIsInExactlyOneGroup() {
        let groups = ModuleCatalog.groups()
        var seen: [String: Int] = [:]
        for g in groups { for m in g.modules { seen[m.id, default: 0] += 1 } }
        let optionalIDs = ModuleRegistry.all.filter { !$0.isMandatory }.map { $0.id }
        XCTAssertEqual(optionalIDs.count, 108)
        XCTAssertEqual(seen.count, 108)
        for id in optionalIDs { XCTAssertEqual(seen[id], 1, "module \(id)") }
        XCTAssertNil(seen["core"])
    }

    func testThemeMapHasNoStaleIdentifier() {
        let known = Set(ModuleRegistry.all.map { $0.id })
        for id in ModuleCatalog.themeByID.keys { XCTAssertTrue(known.contains(id), "id inconnu \(id)") }
    }

    func testEveryMappedThemeIsInTheDisplayOrder() {
        for t in Set(ModuleCatalog.themeByID.values) { XCTAssertTrue(ModuleCatalog.themeOrder.contains(t), t) }
    }

    func testKnownModulesLandInExpectedThemes() {
        XCTAssertEqual(ModuleCatalog.theme(for: "pay"), "Emploi et paie")
        XCTAssertEqual(ModuleCatalog.theme(for: "exam_mode"), "Études")
        XCTAssertEqual(ModuleCatalog.theme(for: "going_home"), "Trajets")
        XCTAssertEqual(ModuleCatalog.theme(for: "biometric_lock"), "Sécurité et données")
        XCTAssertEqual(ModuleCatalog.theme(for: "planning_ocr"), "Planning")
    }

    func testUnknownIdentifierFallsBackToAutres() {
        XCTAssertEqual(ModuleCatalog.theme(for: "does_not_exist"), "Autres")
        let groups = ModuleCatalog.groups(registry: mini)
        let last = groups.last
        XCTAssertEqual(last?.theme, "Autres")
        XCTAssertEqual(last?.modules.map { $0.id }, ["mystery"])
    }

    func testGroupsKeepThemeOrderAndRegistryOrderAndSkipEmpty() {
        let groups = ModuleCatalog.groups(registry: mini)
        XCTAssertEqual(groups.map { $0.theme }, ["Emploi et paie", "Autres"])
        XCTAssertEqual(groups[0].modules.map { $0.id }, ["employment", "pay", "leave"])
    }

    // MARK: recherche

    func testSearchIgnoresCaseAndAccents() {
        XCTAssertTrue(ModuleCatalog.matches(mod("leave", "Congés payés"), query: "conges"))
        XCTAssertTrue(ModuleCatalog.matches(mod("leave", "Congés payés"), query: "CONGÉS"))
        XCTAssertTrue(ModuleCatalog.matches(mod("x", "Etudes"), query: "études"))
        XCTAssertFalse(ModuleCatalog.matches(mod("leave", "Congés payés"), query: "paie"))
    }

    func testSearchLooksInSummaryAndRequiresEveryWord() {
        let m = mod("pay", "Salaire", "Estime ta paie à partir de tes heures")
        XCTAssertTrue(ModuleCatalog.matches(m, query: "paie"))
        XCTAssertTrue(ModuleCatalog.matches(m, query: "estime heures"))
        XCTAssertFalse(ModuleCatalog.matches(m, query: "estime vacances"))
    }

    func testEmptyQueryKeepsEverything() {
        XCTAssertEqual(ModuleCatalog.groups(registry: mini, query: "   ").flatMap { $0.modules }.count, 4)
    }

    func testSearchOnRealRegistryFindsLeaveWithoutAccent() {
        let found = ModuleCatalog.groups(query: "conges").flatMap { $0.modules }.map { $0.id }
        XCTAssertTrue(found.contains("leave"))
        XCTAssertFalse(found.contains("notes"))
    }

    func testSearchWithNoResultGivesNoGroup() {
        XCTAssertTrue(ModuleCatalog.groups(registry: mini, query: "zzzzqq").isEmpty)
    }

    // MARK: compteurs

    func testCountsCoverOptionalModulesOnly() {
        // 4 optionnels, 3 livrés (employment, pay, mystery), leave pas livré.
        let c1 = ModuleCatalog.counts(enabled: ["core"], registry: mini)
        XCTAssertEqual(c1.active, 0)
        XCTAssertEqual(c1.total, 4)
        let c2 = ModuleCatalog.counts(enabled: ["core", "employment", "pay", "leave"], registry: mini)
        XCTAssertEqual(c2.active, 2)
        XCTAssertEqual(c2.total, 4)
        XCTAssertEqual(ModuleCatalog.comingSoonCount(registry: mini), 1)
    }

    func testCountsOnRealRegistryTotal() {
        XCTAssertEqual(ModuleCatalog.counts(enabled: ModuleRegistry.defaultEnabledIDs).total, 108)
    }

    // MARK: confirmations de dépendances

    func testEnablingPayAsksToEnableEmployment() {
        let req = ModuleCatalog.changeRequest(for: "pay", turnOn: true, enabled: ["core"], registry: mini)
        XCTAssertEqual(req?.others.map { $0.id }, ["employment"])
        XCTAssertEqual(req?.turnOn, true)
    }

    func testEnablingWithRequirementAlreadyOnNeedsNoConfirmation() {
        XCTAssertNil(ModuleCatalog.changeRequest(for: "pay", turnOn: true, enabled: ["core", "employment"], registry: mini))
    }

    func testDisablingEmploymentListsActiveDependentsOnly() {
        let req = ModuleCatalog.changeRequest(for: "employment", turnOn: false,
                                              enabled: ["core", "employment", "pay"], registry: mini)
        XCTAssertEqual(req?.others.map { $0.id }, ["pay"])
        XCTAssertEqual(req?.turnOn, false)
    }

    func testDisablingALeafNeedsNoConfirmation() {
        XCTAssertNil(ModuleCatalog.changeRequest(for: "pay", turnOn: false, enabled: ["core", "employment", "pay"], registry: mini))
    }
}
