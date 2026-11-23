import XCTest
@testable import PersonalLifeTracker

final class SetupChecklistTests: XCTestCase {

    /// App avec tous les modules utiles actifs, rien de configuré.
    private func fullModules() -> SetupFacts {
        return SetupFacts(employmentActive: true, payActive: true, contractHoursActive: true, planningOCRActive: true)
    }

    /// Tout est fait, tous modules actifs.
    private func allDone() -> SetupFacts {
        return SetupFacts(location: .always, notifications: .allowed, placeCount: 1, hasTafPlace: true,
                          employmentActive: true, payActive: true, contractHoursActive: true, planningOCRActive: true,
                          hasEmployer: true, hasContract: true, hasContractWeeklyHours: true,
                          hasPayRate: true, hasPlannedShift: true, hasSession: true)
    }

    private func step(_ id: SetupStepID, _ facts: SetupFacts) -> SetupStep {
        let found: SetupStep? = SetupChecklist.steps(for: facts).first { (s: SetupStep) -> Bool in return s.id == id }
        return found!
    }

    // MARK: Départ à zéro

    func testFreshInstallNoLocationNoPlace() {
        let facts: SetupFacts = fullModules()
        XCTAssertEqual(step(.location, facts).status, .todo)
        XCTAssertEqual(step(.location, facts).action, .requestLocation)
        XCTAssertTrue(step(.location, facts).isAutomatic)
        XCTAssertEqual(step(.notifications, facts).status, .todo)
        XCTAssertEqual(step(.notifications, facts).action, .requestNotifications)
        // Sans localisation, créer le lieu depuis la position n'est pas possible en un tap.
        XCTAssertEqual(step(.firstPlace, facts).status, .todo)
        XCTAssertFalse(step(.firstPlace, facts).isAutomatic)
        XCTAssertEqual(step(.firstPlace, facts).actionTitle, "Ajouter un lieu")
        XCTAssertEqual(step(.employer, facts).status, .todo)
        // Taux et heures attendent le contrat.
        XCTAssertEqual(step(.payRate, facts).status, .blocked)
        XCTAssertEqual(step(.contractHours, facts).status, .blocked)
        XCTAssertEqual(step(.planning, facts).status, .todo)
        let applicable: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(applicable.count, 7)
        XCTAssertEqual(SetupChecklist.progress(of: applicable), SetupProgress(done: 0, total: 7))
        XCTAssertEqual(SetupChecklist.nextStep(in: applicable)?.id, SetupStepID.location)
        XCTAssertFalse(SetupChecklist.isComplete(applicable))
    }

    func testStepOrderIsFixed() {
        let ids: [SetupStepID] = SetupChecklist.steps(for: fullModules()).map { (s: SetupStep) -> SetupStepID in return s.id }
        XCTAssertEqual(ids, [SetupStepID.location, SetupStepID.notifications, SetupStepID.firstPlace, SetupStepID.employer,
                             SetupStepID.payRate, SetupStepID.planning, SetupStepID.contractHours])
    }

    // MARK: Localisation et lieu

    func testLocationOkButNoPlaceOffersOneTapPlace() {
        var facts: SetupFacts = fullModules()
        facts.location = .always
        facts.notifications = .allowed
        XCTAssertEqual(step(.location, facts).status, .done)
        XCTAssertEqual(step(.notifications, facts).status, .done)
        let place: SetupStep = step(.firstPlace, facts)
        XCTAssertEqual(place.status, .todo)
        XCTAssertTrue(place.isAutomatic)
        XCTAssertEqual(place.action, .createFirstPlace)
        XCTAssertEqual(place.actionTitle, "Créer à partir de ma position")
        XCTAssertEqual(SetupChecklist.progress(of: SetupChecklist.applicableSteps(for: facts)), SetupProgress(done: 2, total: 7))
        XCTAssertEqual(SetupChecklist.nextStep(in: SetupChecklist.applicableSteps(for: facts))?.id, SetupStepID.firstPlace)
    }

    func testWhenInUseIsBlockedAndOpensSettings() {
        var facts: SetupFacts = fullModules()
        facts.location = .whenInUse
        let s: SetupStep = step(.location, facts)
        XCTAssertEqual(s.status, .blocked)
        XCTAssertEqual(s.action, .openSystemSettings)
        XCTAssertFalse(s.isAutomatic)
        // « Pendant l'utilisation » suffit pour créer un lieu depuis la position.
        XCTAssertTrue(step(.firstPlace, facts).isAutomatic)
    }

    func testDeniedLocationIsBlocked() {
        var facts: SetupFacts = fullModules()
        facts.location = .denied
        XCTAssertEqual(step(.location, facts).status, .blocked)
        XCTAssertEqual(step(.location, facts).action, .openSystemSettings)
        XCTAssertFalse(step(.firstPlace, facts).isAutomatic)
    }

    func testDeniedNotificationsIsBlocked() {
        var facts: SetupFacts = fullModules()
        facts.notifications = .denied
        XCTAssertEqual(step(.notifications, facts).status, .blocked)
        XCTAssertEqual(step(.notifications, facts).action, .openSystemSettings)
    }

    func testPlaceWithoutTafTypeStaysTodo() {
        var facts: SetupFacts = fullModules()
        facts.location = .always
        facts.placeCount = 2
        facts.hasTafPlace = false
        let s: SetupStep = step(.firstPlace, facts)
        XCTAssertEqual(s.status, .todo)
        XCTAssertTrue(s.why.hasPrefix("Tu as des lieux, mais aucun n'est de type taf."))
    }

    func testTafPlaceMarksStepDone() {
        var facts: SetupFacts = fullModules()
        facts.placeCount = 1
        facts.hasTafPlace = true
        XCTAssertEqual(step(.firstPlace, facts).status, .done)
        XCTAssertNil(step(.firstPlace, facts).action)
    }

    // MARK: Emploi, paie, heures

    func testEmploymentActiveWithoutEmployerOffersDraft() {
        let facts: SetupFacts = fullModules()
        let s: SetupStep = step(.employer, facts)
        XCTAssertEqual(s.status, .todo)
        XCTAssertEqual(s.action, .createEmployerDraft)
        XCTAssertTrue(s.isAutomatic)
        XCTAssertEqual(step(.payRate, facts).action, .createEmployerDraft)
    }

    func testEmployerWithoutContractAsksForContract() {
        var facts: SetupFacts = fullModules()
        facts.hasEmployer = true
        let s: SetupStep = step(.employer, facts)
        XCTAssertEqual(s.status, .todo)
        XCTAssertEqual(s.action, .openEmployment)
        XCTAssertFalse(s.isAutomatic)
        XCTAssertEqual(step(.payRate, facts).status, .blocked)
        XCTAssertEqual(step(.payRate, facts).actionTitle, "Ajouter mon contrat")
        XCTAssertEqual(step(.contractHours, facts).status, .blocked)
    }

    func testContractWithoutRateAndHours() {
        var facts: SetupFacts = fullModules()
        facts.hasEmployer = true
        facts.hasContract = true
        XCTAssertEqual(step(.employer, facts).status, .done)
        XCTAssertEqual(step(.payRate, facts).status, .todo)
        XCTAssertEqual(step(.payRate, facts).action, .openPay)
        XCTAssertFalse(step(.payRate, facts).isAutomatic)
        XCTAssertEqual(step(.contractHours, facts).status, .todo)
        XCTAssertEqual(step(.contractHours, facts).action, .openEmployment)
    }

    func testRateAndHoursDone() {
        var facts: SetupFacts = fullModules()
        facts.hasEmployer = true
        facts.hasContract = true
        facts.hasPayRate = true
        facts.hasContractWeeklyHours = true
        XCTAssertEqual(step(.payRate, facts).status, .done)
        XCTAssertEqual(step(.contractHours, facts).status, .done)
    }

    func testPlanningStep() {
        var facts: SetupFacts = fullModules()
        XCTAssertEqual(step(.planning, facts).status, .todo)
        XCTAssertEqual(step(.planning, facts).action, .openPlanningImport)
        facts.hasPlannedShift = true
        XCTAssertEqual(step(.planning, facts).status, .done)
    }

    // MARK: Modules inactifs

    func testInactiveModulesMeanNotApplicable() {
        let facts: SetupFacts = SetupFacts(location: .notDetermined, notifications: .notDetermined)
        XCTAssertEqual(step(.employer, facts).status, .notApplicable)
        XCTAssertEqual(step(.payRate, facts).status, .notApplicable)
        XCTAssertEqual(step(.planning, facts).status, .notApplicable)
        XCTAssertEqual(step(.contractHours, facts).status, .notApplicable)
        let applicable: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(applicable.map { (s: SetupStep) -> SetupStepID in return s.id },
                       [SetupStepID.location, SetupStepID.notifications, SetupStepID.firstPlace])
    }

    func testNotApplicableDoesNotBlockCompletion() {
        let facts: SetupFacts = SetupFacts(location: .always, notifications: .allowed, placeCount: 1, hasTafPlace: true)
        let applicable: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(SetupChecklist.progress(of: applicable), SetupProgress(done: 3, total: 3))
        XCTAssertTrue(SetupChecklist.isComplete(applicable))
    }

    func testPayInactiveButEmploymentActive() {
        var facts: SetupFacts = SetupFacts(employmentActive: true)
        facts.hasEmployer = true
        facts.hasContract = true
        XCTAssertEqual(step(.payRate, facts).status, .notApplicable)
        XCTAssertEqual(SetupChecklist.applicableSteps(for: facts).count, 4)
    }

    // MARK: Tout est fait

    func testAllDone() {
        let facts: SetupFacts = allDone()
        let applicable: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(applicable.count, 7)
        XCTAssertTrue(applicable.allSatisfy { (s: SetupStep) -> Bool in return s.status == .done })
        XCTAssertEqual(SetupChecklist.progress(of: applicable).text, "7 sur 7 faits")
        XCTAssertTrue(SetupChecklist.isComplete(applicable))
        XCTAssertNil(SetupChecklist.nextStep(in: applicable))
        XCTAssertFalse(SetupChecklist.shouldShowCard(steps: applicable, isDismissed: false, dismissedBlockedIDs: []))
    }

    func testCompletionMessageDependsOnSession() {
        var facts: SetupFacts = allDone()
        XCTAssertEqual(SetupChecklist.completionMessage(for: facts), "Tout est en place. Tu n'as plus rien à régler.")
        facts.hasSession = false
        XCTAssertTrue(SetupChecklist.completionMessage(for: facts).contains("ta première session se lancera toute seule"))
    }

    // MARK: Progression

    func testProgressText() {
        XCTAssertEqual(SetupProgress(done: 0, total: 6).text, "0 sur 6 fait")
        XCTAssertEqual(SetupProgress(done: 1, total: 6).text, "1 sur 6 fait")
        XCTAssertEqual(SetupProgress(done: 3, total: 6).text, "3 sur 6 faits")
        XCTAssertEqual(SetupProgress(done: 3, total: 6).fraction, 0.5, accuracy: 0.0001)
    }

    func testThreeOfSixDone() {
        // Modules : emploi, paie, planning (pas d'heures du contrat) : 6 étapes.
        var facts: SetupFacts = SetupFacts(location: .always, notifications: .allowed, placeCount: 1, hasTafPlace: true,
                                           employmentActive: true, payActive: true, contractHoursActive: false, planningOCRActive: true)
        let applicable: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(SetupChecklist.progress(of: applicable).text, "3 sur 6 faits")
        XCTAssertEqual(SetupChecklist.nextStep(in: applicable)?.id, SetupStepID.employer)
        facts.hasEmployer = true
        XCTAssertEqual(SetupChecklist.progress(of: SetupChecklist.applicableSteps(for: facts)).done, 3)
    }

    // MARK: Carte de l'Accueil et « Plus tard »

    func testCardShownWhileIncomplete() {
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: fullModules())
        XCTAssertTrue(SetupChecklist.shouldShowCard(steps: steps, isDismissed: false, dismissedBlockedIDs: []))
    }

    func testCardHiddenAfterLater() {
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: fullModules())
        XCTAssertFalse(SetupChecklist.shouldShowCard(steps: steps, isDismissed: true, dismissedBlockedIDs: []))
    }

    func testCardReturnsWhenPermissionGetsBlockedAfterLater() {
        // « Plus tard » quand la localisation n'était pas encore demandée, puis l'utilisateur la refuse.
        var facts: SetupFacts = fullModules()
        facts.location = .denied
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(SetupChecklist.blockedPermissionIDs(in: steps), Set<String>(["location"]))
        XCTAssertTrue(SetupChecklist.shouldShowCard(steps: steps, isDismissed: true, dismissedBlockedIDs: []))
    }

    func testCardStaysHiddenWhenSameBlockAsAtLater() {
        var facts: SetupFacts = fullModules()
        facts.location = .denied
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertFalse(SetupChecklist.shouldShowCard(steps: steps, isDismissed: true, dismissedBlockedIDs: Set<String>(["location"])))
    }

    func testCardReturnsWhenSecondPermissionIsBlocked() {
        var facts: SetupFacts = fullModules()
        facts.location = .denied
        facts.notifications = .denied
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: facts)
        XCTAssertEqual(SetupChecklist.blockedPermissionIDs(in: steps), Set<String>(["location", "notifications"]))
        XCTAssertTrue(SetupChecklist.shouldShowCard(steps: steps, isDismissed: true, dismissedBlockedIDs: Set<String>(["location"])))
    }

    func testDependencyBlockDoesNotReviveCard() {
        // Taux et heures sont bloqués par l'absence de contrat, ce n'est pas une permission.
        let steps: [SetupStep] = SetupChecklist.applicableSteps(for: fullModules())
        XCTAssertEqual(SetupChecklist.blockedPermissionIDs(in: steps), Set<String>())
    }
}
