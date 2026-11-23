import Foundation
import SwiftData
import Observation

// Assistant de configuration : lit l'état réel de l'app (SetupFactsBuilder), retient le « Plus tard » (SetupDismissal)
// et fait en un tap ce qui peut l'être sans rien te faire écrire (SetupAutomation).

/// Transforme l'état réel en SetupFacts. Aucune écriture.
enum SetupFactsBuilder {
    @MainActor
    static func facts(capabilities: CapabilityService,
                      modules: ModuleStore,
                      places: [Place],
                      employers: [Employer],
                      contracts: [Contract],
                      payRates: [PayRate],
                      shifts: [PlannedShift],
                      sessionCount: Int) -> SetupFacts {
        let location: SetupLocationLevel
        switch capabilities.location {
        case .always: location = .always
        case .whenInUse: location = .whenInUse
        case .denied, .restricted: location = .denied
        case .notDetermined: location = .notDetermined
        }
        let notifications: SetupNotificationLevel
        switch capabilities.notifications {
        case .allowed, .provisional: notifications = .allowed
        case .denied: notifications = .denied
        case .notDetermined: notifications = .notDetermined
        }
        let hasTaf: Bool = places.contains { (p: Place) -> Bool in return p.type == .taf }
        let hasHours: Bool = contracts.contains { (c: Contract) -> Bool in return c.weeklyHours > 0 }
        return SetupFacts(location: location,
                          notifications: notifications,
                          placeCount: places.count,
                          hasTafPlace: hasTaf,
                          employmentActive: modules.isActive("employment"),
                          payActive: modules.isActive("pay"),
                          contractHoursActive: modules.isActive("contract_hours"),
                          planningOCRActive: modules.isActive("planning_ocr"),
                          hasEmployer: !employers.isEmpty,
                          hasContract: !contracts.isEmpty,
                          hasContractWeeklyHours: hasHours,
                          hasPayRate: !payRates.isEmpty,
                          hasPlannedShift: !shifts.isEmpty,
                          hasSession: sessionCount > 0)
    }
}

/// « Plus tard » de la carte de l'Accueil, gardé dans UserDefaults avec les permissions déjà bloquées à ce moment-là.
struct SetupDismissal {
    static let dismissedKey: String = "plt.setup.dismissed"
    static let blockedKey: String = "plt.setup.dismissedBlocked"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    var isDismissed: Bool {
        return defaults.bool(forKey: SetupDismissal.dismissedKey)
    }

    var blockedIDs: Set<String> {
        let list: [String] = (defaults.array(forKey: SetupDismissal.blockedKey) as? [String]) ?? []
        return Set(list)
    }

    func dismiss(blockedIDs: Set<String>) {
        defaults.set(true, forKey: SetupDismissal.dismissedKey)
        defaults.set(blockedIDs.sorted(), forKey: SetupDismissal.blockedKey)
    }

    func reset() {
        defaults.set(false, forKey: SetupDismissal.dismissedKey)
        defaults.set([String](), forKey: SetupDismissal.blockedKey)
    }
}

/// Une ligne du compte rendu de « Tout configurer pour moi ».
struct SetupReportLine: Identifiable, Equatable {
    let id: UUID = UUID()
    let text: String
    /// Faux quand quelque chose n'a pas pu être fait (le texte dit quoi faire).
    let isOK: Bool
}

/// Ce qu'une action automatique a créé, pour pouvoir tout annuler d'un coup.
struct SetupCreated: Equatable {
    var placeUIDs: [UUID] = []
    var employerUIDs: [UUID] = []
    var addedModules: [String] = []

    var isEmpty: Bool {
        return placeUIDs.isEmpty && employerUIDs.isEmpty && addedModules.isEmpty
    }
}

@MainActor
@Observable
final class SetupAutomation {
    /// Modules que « Tout configurer pour moi » active (s'ils sont livrés).
    static let recommendedModules: [String] = ["employment", "pay", "contract_hours", "planning_ocr", "place_discovery"]
    static let draftPlaceName: String = "Mon taf"
    static let draftEmployerName: String = "Mon employeur"

    private(set) var report: [SetupReportLine] = []
    private(set) var isRunning: Bool = false
    /// Lieu créé par l'assistant, en attente de ton nom. Nil une fois le nom confirmé.
    private(set) var draftPlaceUID: UUID? = nil
    /// Contrat créé par l'assistant, en attente de tes choix (type, heures).
    private(set) var draftContractUID: UUID? = nil

    init() {
    }

    // MARK: Tout d'un coup

    /// Enchaîne : modules, permissions, premier lieu, employeur et contrat. Ne demande jamais de saisie.
    func configureEverything(modules: ModuleStore,
                             context: ModelContext,
                             undo: UndoCenter?,
                             permissions: PermissionRequester,
                             capabilities: CapabilityService) async {
        if isRunning { return }
        isRunning = true
        report = []
        var created: SetupCreated = SetupCreated()

        enableRecommendedModules(modules: modules, created: &created)
        await askLocation(permissions: permissions, capabilities: capabilities)
        await askNotifications(permissions: permissions, capabilities: capabilities)
        await createDraftPlace(context: context, permissions: permissions, created: &created)
        createDraftEmployer(modules: modules, context: context, created: &created)

        if report.isEmpty {
            report.append(SetupReportLine(text: "Rien à faire en automatique, tout ce qui peut l'être est déjà fait.", isOK: true))
        }
        registerUndo(created: created, modules: modules, context: context, undo: undo)
        capabilities.refresh()
        isRunning = false
    }

    // MARK: Un tap sur une étape

    func requestLocation(permissions: PermissionRequester, capabilities: CapabilityService) async {
        if isRunning { return }
        isRunning = true
        report = []
        await askLocation(permissions: permissions, capabilities: capabilities)
        capabilities.refresh()
        isRunning = false
    }

    func requestNotifications(permissions: PermissionRequester, capabilities: CapabilityService) async {
        if isRunning { return }
        isRunning = true
        report = []
        await askNotifications(permissions: permissions, capabilities: capabilities)
        capabilities.refresh()
        isRunning = false
    }

    func createFirstPlace(modules: ModuleStore,
                          context: ModelContext,
                          undo: UndoCenter?,
                          permissions: PermissionRequester) async {
        if isRunning { return }
        isRunning = true
        report = []
        var created: SetupCreated = SetupCreated()
        await createDraftPlace(context: context, permissions: permissions, created: &created)
        registerUndo(created: created, modules: modules, context: context, undo: undo)
        isRunning = false
    }

    func createEmployerAndContract(modules: ModuleStore, context: ModelContext, undo: UndoCenter?) {
        if isRunning { return }
        report = []
        var created: SetupCreated = SetupCreated()
        createDraftEmployer(modules: modules, context: context, created: &created)
        registerUndo(created: created, modules: modules, context: context, undo: undo)
    }

    // MARK: Brouillons à confirmer

    /// Confirme le nom du lieu créé. Renvoie un message d'erreur, ou nil si c'est bon.
    func confirmPlaceName(_ rawName: String, context: ModelContext) -> String? {
        guard let uid = draftPlaceUID else { return nil }
        let places: [Place] = fetchPlaces(context)
        guard let place = places.first(where: { (p: Place) -> Bool in return p.uid == uid }) else {
            draftPlaceUID = nil
            return nil
        }
        let others: [String] = places.filter { (p: Place) -> Bool in return p.uid != uid }.map { (p: Place) -> String in return p.name }
        if let issue = PlaceRules.nameIssue(rawName, existingNames: others) {
            return issue.message
        }
        place.name = PlaceRules.cleanedName(rawName)
        do {
            try context.save()
        } catch {
            return "Je n'ai pas réussi à enregistrer le nom. Réessaie ?"
        }
        draftPlaceUID = nil
        return nil
    }

    /// Confirme le type de contrat et les heures par semaine. Renvoie un message d'erreur, ou nil si c'est bon.
    func confirmContract(kind: ContractKind, weeklyHoursText: String, employerName: String, context: ModelContext) -> String? {
        guard let uid = draftContractUID else { return nil }
        let contracts: [Contract] = fetchContracts(context)
        guard let contract = contracts.first(where: { (c: Contract) -> Bool in return c.uid == uid }) else {
            draftContractUID = nil
            return nil
        }
        let cleaned: String = weeklyHoursText
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let hours = Double(cleaned), hours.isFinite, hours > 0 else {
            return "Écris les heures par semaine de ton contrat, par exemple 13 ou 17,5."
        }
        if hours > ContractRules.maxPlausibleWeeklyHours {
            return "Ça fait beaucoup d'heures par semaine. Vérifie ce que tu as saisi."
        }
        let name: String = PlaceRules.cleanedName(employerName)
        contract.kind = kind
        contract.weeklyHours = hours
        if !name.isEmpty, let employer = contract.employer {
            employer.name = name
        }
        do {
            try context.save()
        } catch {
            return "Je n'ai pas réussi à enregistrer. Réessaie ?"
        }
        draftContractUID = nil
        return nil
    }

    // MARK: Étapes internes

    private func enableRecommendedModules(modules: ModuleStore, created: inout SetupCreated) {
        let before: Set<String> = modules.enabledIDs
        for id in SetupAutomation.recommendedModules {
            guard let def = ModuleRegistry.definition(for: id), def.isAvailable else { continue }
            if modules.isEnabled(id) { continue }
            modules.setEnabled(id, true)
        }
        let added: Set<String> = modules.enabledIDs.subtracting(before)
        created.addedModules = added.sorted()
        if !added.isEmpty {
            let count: Int = added.count
            report.append(SetupReportLine(text: count == 1 ? "J'ai activé 1 fonctionnalité qui te sert." : "J'ai activé \(count) fonctionnalités qui te servent.", isOK: true))
        }
    }

    private func askLocation(permissions: PermissionRequester, capabilities: CapabilityService) async {
        if permissions.location == .notDetermined {
            await permissions.requestLocationAccess()
        }
        switch permissions.location {
        case .always:
            report.append(SetupReportLine(text: "Localisation sur « Toujours » : c'est bon.", isOK: true))
        case .whenInUse:
            report.append(SetupReportLine(text: "Localisation sur « Pendant l'utilisation ». Pour détecter écran éteint, passe sur « Toujours » dans les réglages iOS.", isOK: false))
        case .denied, .restricted:
            report.append(SetupReportLine(text: "Localisation refusée. Ouvre les réglages iOS et choisis « Toujours ».", isOK: false))
        case .notDetermined:
            report.append(SetupReportLine(text: "La localisation n'a pas été demandée. Réessaie depuis l'étape.", isOK: false))
        }
    }

    private func askNotifications(permissions: PermissionRequester, capabilities: CapabilityService) async {
        await permissions.refreshNotifications()
        if permissions.notifications == .notDetermined {
            await permissions.requestNotifications()
        }
        switch permissions.notifications {
        case .authorized:
            report.append(SetupReportLine(text: "Notifications autorisées.", isOK: true))
        case .denied:
            report.append(SetupReportLine(text: "Notifications refusées. Tu peux les réactiver dans les réglages iOS.", isOK: false))
        case .notDetermined:
            report.append(SetupReportLine(text: "Les notifications n'ont pas été demandées. Réessaie depuis l'étape.", isOK: false))
        }
    }

    private func createDraftPlace(context: ModelContext, permissions: PermissionRequester, created: inout SetupCreated) async {
        let places: [Place] = fetchPlaces(context)
        if places.contains(where: { (p: Place) -> Bool in return p.type == .taf }) { return }
        guard permissions.location == .whenInUse || permissions.location == .always else {
            report.append(SetupReportLine(text: "Pas de lieu créé : sans localisation, je ne sais pas où tu es. Ajoute ton taf à la main depuis l'étape.", isOK: false))
            return
        }
        guard let coordinate = await permissions.currentCoordinate(),
              PlaceRules.isValidCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude) else {
            report.append(SetupReportLine(text: "Je n'ai pas réussi à te localiser. Réessaie dehors, ou ajoute ton taf à la main.", isOK: false))
            return
        }
        // Le nom a pu être pris pendant l'attente : on relit les lieux.
        let existingNames: [String] = fetchPlaces(context).map { (p: Place) -> String in return p.name }
        var name: String = SetupAutomation.draftPlaceName
        var attempt: Int = 2
        while PlaceRules.nameIssue(name, existingNames: existingNames) != nil && attempt < 30 {
            name = SetupAutomation.draftPlaceName + " " + String(attempt)
            attempt += 1
        }
        let place: Place = Place(name: name,
                                 type: .taf,
                                 latitude: coordinate.latitude,
                                 longitude: coordinate.longitude,
                                 radius: PlaceRules.defaultRadius)
        context.insert(place)
        do {
            try context.save()
        } catch {
            context.delete(place)
            report.append(SetupReportLine(text: "Je n'ai pas réussi à enregistrer le lieu. Réessaie ?", isOK: false))
            return
        }
        created.placeUIDs.append(place.uid)
        draftPlaceUID = place.uid
        report.append(SetupReportLine(text: "J'ai créé « \(name) » là où tu es (rayon \(Int(PlaceRules.defaultRadius)) m). Donne-lui son vrai nom ci-dessous.", isOK: true))
    }

    private func createDraftEmployer(modules: ModuleStore, context: ModelContext, created: inout SetupCreated) {
        guard modules.isActive("employment") else { return }
        if !fetchEmployers(context).isEmpty { return }
        let calendar: Calendar = Calendar.current
        let employer: Employer = Employer(name: SetupAutomation.draftEmployerName)
        employer.colorHex = "work"
        context.insert(employer)
        let contract: Contract = Contract(kind: .cdi,
                                          startDate: calendar.startOfDay(for: Date()),
                                          endDate: nil,
                                          weeklyHours: 0,
                                          employer: employer)
        if let taf = fetchPlaces(context).first(where: { (p: Place) -> Bool in return p.type == .taf }) {
            contract.placeUIDs = [taf.uid]
        }
        context.insert(contract)
        do {
            try context.save()
        } catch {
            context.delete(contract)
            context.delete(employer)
            report.append(SetupReportLine(text: "Je n'ai pas réussi à préparer ton employeur. Réessaie ?", isOK: false))
            return
        }
        created.employerUIDs.append(employer.uid)
        draftContractUID = contract.uid
        report.append(SetupReportLine(text: "J'ai préparé un employeur et un contrat. Choisis CDI ou CDD et écris tes heures par semaine ci-dessous : je n'invente rien.", isOK: true))
    }

    // MARK: Annuler

    private func registerUndo(created: SetupCreated, modules: ModuleStore, context: ModelContext, undo: UndoCenter?) {
        if created.isEmpty { return }
        guard let center = undo else { return }
        center.register(message: "Configuration automatique annulée") {
            SetupAutomation.rollback(created, modules: modules, context: context)
        }
    }

    /// Supprime ce que l'assistant a créé et éteint les modules qu'il a allumés.
    static func rollback(_ created: SetupCreated, modules: ModuleStore, context: ModelContext) {
        let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        for place in places where created.placeUIDs.contains(place.uid) {
            context.delete(place)
        }
        let employers: [Employer] = (try? context.fetch(FetchDescriptor<Employer>())) ?? []
        for employer in employers where created.employerUIDs.contains(employer.uid) {
            context.delete(employer)
        }
        try? context.save()
        for id in created.addedModules.reversed() {
            modules.setEnabled(id, false)
        }
    }

    // MARK: Lecture

    private func fetchPlaces(_ context: ModelContext) -> [Place] {
        return (try? context.fetch(FetchDescriptor<Place>())) ?? []
    }

    private func fetchEmployers(_ context: ModelContext) -> [Employer] {
        return (try? context.fetch(FetchDescriptor<Employer>())) ?? []
    }

    private func fetchContracts(_ context: ModelContext) -> [Contract] {
        return (try? context.fetch(FetchDescriptor<Contract>())) ?? []
    }
}
