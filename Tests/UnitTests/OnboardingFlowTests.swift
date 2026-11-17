import XCTest
@testable import PersonalLifeTracker

final class OnboardingFlowTests: XCTestCase {

    private func def(_ id: String, defaultOn: Bool, requires: [String] = [], mandatory: Bool = false) -> ModuleDefinition {
        return ModuleDefinition(id: id, title: id, summary: id, step: 1, defaultOn: defaultOn,
                                requires: requires, isAvailable: true, isMandatory: mandatory)
    }

    // MARK: Étapes

    func testAllSevenStepsWhenPhotosModuleIsOn() {
        let steps = OnboardingFlow.steps(enabledModules: ["core", "planning_ocr"])
        XCTAssertEqual(steps, [.welcome, .modules, .location, .notifications, .photos, .firstPlace, .ready])
    }

    func testPhotosStepIsSkippedWhenPhotosModuleIsOff() {
        let steps = OnboardingFlow.steps(enabledModules: ["core"])
        XCTAssertEqual(steps, [.welcome, .modules, .location, .notifications, .firstPlace, .ready])
    }

    func testNextSkipsPhotosWhenOff() {
        XCTAssertEqual(OnboardingFlow.next(after: .notifications, enabledModules: ["core"]), .firstPlace)
        XCTAssertEqual(OnboardingFlow.next(after: .notifications, enabledModules: ["core", "planning_ocr"]), .photos)
    }

    func testPreviousSkipsPhotosWhenOff() {
        XCTAssertEqual(OnboardingFlow.previous(before: .firstPlace, enabledModules: ["core"]), .notifications)
        XCTAssertEqual(OnboardingFlow.previous(before: .firstPlace, enabledModules: ["core", "planning_ocr"]), .photos)
    }

    func testNoPreviousOnFirstStepAndNoNextOnLast() {
        XCTAssertNil(OnboardingFlow.previous(before: .welcome, enabledModules: ["core"]))
        XCTAssertNil(OnboardingFlow.next(after: .ready, enabledModules: ["core"]))
    }

    func testNextFromHiddenPhotosStepGoesToFirstPlace() {
        XCTAssertEqual(OnboardingFlow.next(after: .photos, enabledModules: ["core"]), .firstPlace)
        XCTAssertEqual(OnboardingFlow.previous(before: .photos, enabledModules: ["core"]), .notifications)
    }

    // MARK: Progression

    func testPositionWithSevenSteps() {
        let enabled: Set<String> = ["core", "planning_ocr"]
        let p = OnboardingFlow.position(of: .location, enabledModules: enabled)
        XCTAssertEqual(p?.number, 3)
        XCTAssertEqual(p?.total, 7)
    }

    func testPositionWithSixSteps() {
        let p = OnboardingFlow.position(of: .ready, enabledModules: ["core"])
        XCTAssertEqual(p?.number, 6)
        XCTAssertEqual(p?.total, 6)
        XCTAssertNil(OnboardingFlow.position(of: .photos, enabledModules: ["core"]))
    }

    func testProgressFractions() {
        let seven: Set<String> = ["core", "planning_ocr"]
        XCTAssertEqual(OnboardingFlow.progress(of: .welcome, enabledModules: seven), 1.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(OnboardingFlow.progress(of: .ready, enabledModules: seven), 1.0, accuracy: 0.0001)
        XCTAssertEqual(OnboardingFlow.progress(of: .modules, enabledModules: ["core"]), 2.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(OnboardingFlow.progress(of: .photos, enabledModules: ["core"]), 0, accuracy: 0.0001)
    }

    // MARK: Préréglages

    func testCompletIncludesEverythingInRegistry() {
        let registry = [def("core", defaultOn: true, mandatory: true),
                        def("a", defaultOn: false),
                        def("b", defaultOn: true, requires: ["a"])]
        XCTAssertEqual(OnboardingFlow.presetIDs(.complet, registry: registry), ["core", "a", "b"])
    }

    func testChoixIsRegistryDefaults() {
        let registry = [def("core", defaultOn: true, mandatory: true),
                        def("a", defaultOn: false),
                        def("b", defaultOn: true)]
        XCTAssertEqual(OnboardingFlow.presetIDs(.choix, registry: registry), ["core", "b"])
    }

    func testEssentielDropsOfferedModulesAndTheirDependents() {
        // "employment" fait partie des modules proposés à l'étape 2, "reporting" n'en fait pas partie mais l'exige.
        let registry = [def("core", defaultOn: true, mandatory: true),
                        def("employment", defaultOn: true),
                        def("reporting", defaultOn: true, requires: ["employment"]),
                        def("undo_safety", defaultOn: true),
                        def("exam_mode", defaultOn: false)]
        XCTAssertEqual(OnboardingFlow.presetIDs(.essentiel, registry: registry), ["core", "undo_safety"])
    }

    func testEssentielOnRealRegistryKeepsCoreAndDropsFinanceAndPhotos() {
        let ids = OnboardingFlow.presetIDs(.essentiel)
        XCTAssertTrue(ids.contains("core"))
        XCTAssertTrue(ids.contains("undo_safety"))
        XCTAssertFalse(ids.contains("employment"))
        XCTAssertFalse(ids.contains("pay"))
        XCTAssertFalse(ids.contains("planning_ocr"))
        // schedule_archive exige planning_ocr dans le registre : doit partir avec lui.
        XCTAssertFalse(ids.contains("schedule_archive"))
    }

    func testCompletOnRealRegistryHasEveryModule() {
        let ids = OnboardingFlow.presetIDs(.complet)
        XCTAssertEqual(ids.count, ModuleRegistry.all.count)
        XCTAssertTrue(ids.contains("travel_departure"))
        XCTAssertTrue(ids.contains("exam_mode"))
    }

    func testDetectPreset() {
        XCTAssertEqual(OnboardingFlow.detectPreset(enabled: OnboardingFlow.presetIDs(.essentiel)), .essentiel)
        XCTAssertEqual(OnboardingFlow.detectPreset(enabled: OnboardingFlow.presetIDs(.complet)), .complet)
        var custom = OnboardingFlow.presetIDs(.essentiel)
        custom.insert("notes")
        XCTAssertEqual(OnboardingFlow.detectPreset(enabled: custom), .choix)
    }

    func testOfferedEnabledCountCountsOnlyOfferedModules() {
        // "notes" et "employment" sont proposés, "undo_safety" et "core" non.
        XCTAssertEqual(OnboardingFlow.offeredEnabledCount(enabled: ["core", "undo_safety", "notes", "employment"]), 2)
    }

    func testOfferedModulesCountIsSixteenAndUnique() {
        XCTAssertEqual(OnboardingFlow.offeredModuleIDs.count, 16)
        XCTAssertEqual(Set(OnboardingFlow.offeredModuleIDs).count, 16)
    }

    // MARK: Récap

    func testNoWarningWhenAlwaysAndNotificationsAuthorized() {
        XCTAssertEqual(OnboardingFlow.warnings(location: .always, notifications: .authorized), [])
    }

    func testWarningWhenLocationOnlyWhenInUse() {
        XCTAssertEqual(OnboardingFlow.warnings(location: .whenInUse, notifications: .authorized), [.locationNotAlways])
    }

    func testWarningWhenLocationDeniedOrRestricted() {
        XCTAssertEqual(OnboardingFlow.warnings(location: .denied, notifications: .authorized), [.locationDenied])
        XCTAssertEqual(OnboardingFlow.warnings(location: .restricted, notifications: .authorized), [.locationDenied])
    }

    func testWarningsCombine() {
        XCTAssertEqual(OnboardingFlow.warnings(location: .whenInUse, notifications: .denied),
                       [.locationNotAlways, .notificationsDenied])
        XCTAssertEqual(OnboardingFlow.warnings(location: .always, notifications: .denied), [.notificationsDenied])
    }

    func testSkippedPermissionsStillWarnAboutLocationOnly() {
        XCTAssertEqual(OnboardingFlow.warnings(location: .notDetermined, notifications: .notDetermined), [.locationNotAlways])
    }

    func testDetectionLimited() {
        XCTAssertFalse(OnboardingFlow.isDetectionLimited(location: .always))
        XCTAssertTrue(OnboardingFlow.isDetectionLimited(location: .whenInUse))
        XCTAssertTrue(OnboardingFlow.isDetectionLimited(location: .denied))
    }
}
