import Foundation
import CoreLocation
import SwiftData
import Observation
import UIKit

/// Surveillance des lieux par régions circulaires (sections 8 et 52).
/// Tout part de `start()`, appelé depuis `PersonalLifeTrackerApp.init` : l'app peut être relancée en arrière-plan
/// par un événement de région sans qu'aucune vue n'existe.
@MainActor
@Observable
final class GeofenceService: NSObject, CLLocationManagerDelegate {

    let discovery: PlaceDiscovery

    private(set) var isMonitoring: Bool = false
    private(set) var monitoredPlaceUIDs: [UUID] = []
    private(set) var lastError: String?
    private(set) var lastEventDate: Date?

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let notifier: DetectionNotifier
    @ObservationIgnored private var engine: DetectionEngine = DetectionEngine()
    @ObservationIgnored private var started: Bool = false
    @ObservationIgnored private var isUpdatingLocation: Bool = false
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var authorizationMessage: String?
    @ObservationIgnored private var monitoringMessage: String?
    @ObservationIgnored private var lastRefreshDate: Date?
    @ObservationIgnored private var activeObserver: NSObjectProtocol?
    @ObservationIgnored private var savedMixedVisits: [UUID: OpenMixedVisit] = [:]
    private static let mixedVisitsKey = "plt.geofence.openMixedVisits"

    init(container: ModelContainer, notifier: DetectionNotifier, manager: CLLocationManager = CLLocationManager()) {
        self.discovery = PlaceDiscovery(container: container)
        self.container = container
        self.notifier = notifier
        self.manager = manager
        super.init()
        self.manager.delegate = self
    }

    // MARK: Démarrage

    /// Vrai si "location" figure dans UIBackgroundModes (sinon activer allowsBackgroundLocationUpdates ferait planter l'app).
    static var isBackgroundLocationDeclared: Bool {
        let modes: [String] = (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]) ?? []
        return modes.contains("location")
    }

    func start() {
        if started {
            refreshMonitoredPlaces()
            return
        }
        started = true
        notifier.install()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if GeofenceService.isBackgroundLocationDeclared {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
        }
        activeObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                               object: nil, queue: OperationQueue.main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMonitoredPlaces(checkExisting: true)
                self?.tick()
            }
        }
        if let data = UserDefaults.standard.data(forKey: Self.mixedVisitsKey),
           let visits = try? JSONDecoder().decode([UUID: OpenMixedVisit].self, from: data) {
            savedMixedVisits = visits
            engine.restoreMixedVisits(visits, places: fetchPlaces().map(detectionPlace), now: Date())
        }
        applyAuthorization(manager.authorizationStatus, shouldLog: false)
        refreshMonitoredPlaces()
        tick()
    }

    // MARK: Autorisation

    private func applyAuthorization(_ status: CLAuthorizationStatus, shouldLog: Bool) {
        var message: String? = nil
        switch status {
        case .notDetermined:
            message = "La localisation n'a pas encore été autorisée."
        case .restricted:
            message = "La localisation est restreinte sur cet iPhone."
        case .denied:
            message = "La localisation est refusée. Active-la dans les Réglages pour détecter tes arrivées."
        case .authorizedWhenInUse:
            message = "Il faut l'autorisation Toujours pour détecter quand l'app est fermée."
        case .authorizedAlways:
            message = nil
        @unknown default:
            message = "Autorisation de localisation inconnue."
        }
        authorizationMessage = message
        updateLastError()
        if status == .authorizedAlways && CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
        }
        if shouldLog {
            log(.authorizationChanged, detail: message ?? "Autorisation Toujours accordée")
        }
    }

    private func updateLastError() {
        lastError = authorizationMessage ?? monitoringMessage
    }

    // MARK: Régions

    private func fetchPlaces() -> [Place] {
        let all: [Place] = (try? container.mainContext.fetch(FetchDescriptor<Place>())) ?? []
        return all.sorted { $0.createdAt < $1.createdAt }
    }

    private func fetchPlace(uid: UUID) -> Place? {
        return fetchPlaces().first { $0.uid == uid }
    }

    private func detectionPlace(_ place: Place) -> DetectionPlace {
        return DetectionPlace(uid: place.uid, name: place.name, type: place.type, alsoWorksHere: place.alsoWorksHere)
    }

    /// Réenregistre les régions : à appeler quand les lieux changent. Idempotent.
    func refreshMonitoredPlaces(checkExisting: Bool = false) {
        discovery.refresh()
        lastRefreshDate = Date()
        let status: CLAuthorizationStatus = manager.authorizationStatus
        authorizationMessage = nil
        applyAuthorization(status, shouldLog: false)
        let allowed: Bool = (status == .authorizedAlways || status == .authorizedWhenInUse)
        if !allowed {
            stopAllRegions()
            engine = DetectionEngine()
            persistMixedVisits()
            updateTracking()
            scheduleTick()
            isMonitoring = false
            monitoredPlaceUIDs = []
            return
        }
        if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            monitoringMessage = "La surveillance des zones n'est pas disponible sur cet appareil."
            updateLastError()
            isMonitoring = false
            log(.monitoringFailed, detail: monitoringMessage ?? "")
            return
        }
        monitoringMessage = nil
        updateLastError()

        let places: [Place] = fetchPlaces()
        let mixedIDs = Set(places.lazy.filter { $0.type == .courses && $0.alsoWorksHere }.map(\.uid))
        for uid in engine.openMixedVisits.keys where !mixedIDs.contains(uid) {
            engine.discardMixedVisit(for: uid)
        }
        persistMixedVisits()
        var candidates: [RegionCandidate] = []
        for p in places {
            candidates.append(RegionCandidate(uid: p.uid, latitude: p.latitude, longitude: p.longitude))
        }
        var refLat: Double? = nil
        var refLon: Double? = nil
        if let loc = manager.location {
            refLat = loc.coordinate.latitude
            refLon = loc.coordinate.longitude
        }
        let selected: [UUID] = RegionSelection.select(candidates, referenceLatitude: refLat, referenceLongitude: refLon)
        let selectedIDs: Set<String> = Set(selected.map { $0.uuidString })

        // Retire les régions qui ne sont plus voulues (seulement les nôtres : identifiant = UUID d'un lieu).
        var existing: [String: CLCircularRegion] = [:]
        for region in manager.monitoredRegions {
            guard let circular = region as? CLCircularRegion else { continue }
            if UUID(uuidString: circular.identifier) == nil { continue }
            if selectedIDs.contains(circular.identifier) {
                existing[circular.identifier] = circular
            } else {
                manager.stopMonitoring(for: circular)
            }
        }

        let maxRadius: Double = manager.maximumRegionMonitoringDistance
        for uid in selected {
            guard let place = places.first(where: { $0.uid == uid }) else { continue }
            var radius: Double = PlaceRules.clampRadius(place.radius)
            if maxRadius > 0 { radius = min(radius, maxRadius) }
            let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            if let old = existing[uid.uuidString],
               abs(old.radius - radius) < 0.5,
               abs(old.center.latitude - center.latitude) < 0.000001,
               abs(old.center.longitude - center.longitude) < 0.000001 {
                if checkExisting { manager.requestState(for: old) }
                continue
            }
            let region = CLCircularRegion(center: center, radius: radius, identifier: uid.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }

        let changed: Bool = Set(monitoredPlaceUIDs) != Set(selected)
        monitoredPlaceUIDs = selected
        isMonitoring = !selected.isEmpty
        if changed {
            log(.monitoringStarted, detail: "\(selected.count) zone(s) surveillée(s) sur \(places.count) lieu(x)")
        }
    }

    private func stopAllRegions() {
        for region in manager.monitoredRegions {
            if let circular = region as? CLCircularRegion, UUID(uuidString: circular.identifier) != nil {
                manager.stopMonitoring(for: circular)
            }
        }
    }

    // MARK: Événements

    private func regionEntered(identifier: String, date: Date, fix: RegionFix?, fromState: Bool = false) {
        lastEventDate = date
        guard let uid = UUID(uuidString: identifier), let place = fetchPlace(uid: uid) else { return }
        let dp: DetectionPlace = detectionPlace(place)
        if let fix, rejectsEntry(for: place, fix: fix) {
            log(.entryRejected, place: dp, detail: "La position récente est en dehors du lieu ou indique un domicile enregistré.",
                date: date, accuracy: fix.accuracy)
            return
        }
        if !fromState {
            log(.regionEntered, place: dp, detail: "Entrée dans la zone", date: date, accuracy: fix?.accuracy)
        }
        feed(.entered(place: dp, date: date, accuracy: fix?.accuracy))
    }

    private func rejectsEntry(for place: Place, fix: RegionFix) -> Bool {
        let zone = PlaceRules.Zone(name: place.name, latitude: place.latitude, longitude: place.longitude, radius: place.radius)
        if fix.clearlyOutside(zone) { return true }
        guard place.type == .taf || place.type == .cours || (place.type == .courses && place.alsoWorksHere) else { return false }
        return fetchPlaces().contains { other in
            guard other.type == .domicile else { return false }
            let home = PlaceRules.Zone(name: other.name, latitude: other.latitude, longitude: other.longitude, radius: other.radius)
            return fix.favorsHome(home, over: zone)
        }
    }

    private func regionExited(identifier: String, date: Date, accuracy: Double?) {
        lastEventDate = date
        guard let uid = UUID(uuidString: identifier), let place = fetchPlace(uid: uid) else { return }
        let dp: DetectionPlace = detectionPlace(place)
        log(.regionExited, place: dp, detail: "Sortie de la zone", date: date, accuracy: accuracy)
        feed(.exited(place: dp, date: date))
    }

    func tick() {
        feed(.tick(date: Date()))
    }

    private func feed(_ input: DetectionInput) {
        let context: ModelContext = container.mainContext
        let service = SessionService(context: context)
        let running: WorkSession? = (try? service.runningSession()) ?? nil
        var runningPlace: DetectionPlace? = nil
        if let r = running, let p = r.place {
            runningPlace = detectionPlace(p)
        }
        engine.syncRunningSession(isRunning: running != nil, place: runningPlace)
        let decisions: [DetectionDecision] = engine.handle(input)
        apply(decisions)
        persistMixedVisits()
        updateTracking()
        scheduleTick()
    }

    private func persistMixedVisits() {
        let visits = engine.openMixedVisits
        guard visits != savedMixedVisits else { return }
        let defaults = UserDefaults.standard
        if visits.isEmpty {
            defaults.removeObject(forKey: Self.mixedVisitsKey)
        } else if let data = try? JSONEncoder().encode(visits) {
            defaults.set(data, forKey: Self.mixedVisitsKey)
        }
        savedMixedVisits = visits
    }

    private func updateTracking() {
        manager.desiredAccuracy = engine.placesAwaitingDeparture.isEmpty
            ? kCLLocationAccuracyHundredMeters : kCLLocationAccuracyNearestTenMeters
        let status: CLAuthorizationStatus = manager.authorizationStatus
        let allowed: Bool = (status == .authorizedAlways || status == .authorizedWhenInUse)
        let wants: Bool = engine.hasPendingWork && allowed
        if wants && !isUpdatingLocation {
            manager.startUpdatingLocation()
            isUpdatingLocation = true
        } else if !wants && isUpdatingLocation {
            manager.stopUpdatingLocation()
            isUpdatingLocation = false
        }
    }

    private func scheduleTick() {
        tickTask?.cancel()
        tickTask = nil
        guard let deadline = engine.nextDeadline() else { return }
        let delay: TimeInterval = max(1, deadline.timeIntervalSinceNow + 1)
        tickTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            self?.tick()
        }
    }

    // MARK: Application des décisions

    private func apply(_ decisions: [DetectionDecision]) {
        var touched: WorkSession? = nil
        for decision in decisions {
            switch decision {
            case .startSession(let place, let date, let uncertain):
                touched = startSession(place: place, date: date, uncertain: uncertain)
            case .stopSession(let place, let date):
                touched = stopSession(place: place, date: date)
            case .ignoreShortVisit(let place, let entered, let exited):
                let seconds: Int = Int(exited.timeIntervalSince(entered))
                log(.ignoredShortVisit, place: place, detail: "Passage de \(seconds) s, sous le minimum de \(Int(DetectionEngine.minimumDwellSeconds)) s", date: exited)
            case .askConfirmation(let place, let bound, let date):
                askConfirmation(place: place, bound: bound, date: date, session: touched)
            case .noteVisit(let place, let entered):
                log(.visitNoted, place: place, detail: "Arrivée observée dans la zone", date: entered)
            case .skipBecauseSessionRunning(let place, let date):
                log(.ignoredShortVisit, place: place, detail: "Ignoré : une session est déjà en cours", date: date)
            case .departureCancelled(let place, let date):
                log(.regionEntered, place: place, detail: "Retour dans la zone pendant le délai de grâce : la session continue", date: date)
            case .ignoreExitWithoutEntry(let place, let date):
                log(.regionExited, place: place, detail: "Sortie sans entrée connue et sans session en cours : rien fait", date: date)
            case .visitEnded(let place, let entered, let exited):
                classifyDualUseVisit(place: place, entered: entered, exited: exited)
            }
        }
    }

    private func startSession(place: DetectionPlace, date: Date, uncertain: Bool) -> WorkSession? {
        let context: ModelContext = container.mainContext
        guard let model = fetchPlace(uid: place.uid) else {
            log(.monitoringFailed, place: place, detail: "Lieu introuvable au démarrage de la session", date: date)
            return nil
        }
        do {
            // Section 11 : le classeur tranche l'activité (taf donne travail, cours donne études).
            let visit = VisitContext(placeKey: model.uid.uuidString, placeType: model.type, alsoWorksHere: model.alsoWorksHere,
                                     start: date, durationSeconds: nil, plannedShifts: [])
            let result: ClassificationResult = VisitClassifier.classify(visit, habits: HabitStore.shared.model,
                                                                        now: date, calendar: Calendar.current)
            var activity: ActivityType = result.activity
            if activity == .unknown { activity = model.type.defaultActivity }
            let session: WorkSession = try SessionService(context: context).start(activity: activity, place: model, now: date)
            session.source = .gps
            session.isConfirmed = false
            try context.save()
            var detail: String = "Session démarrée à l'heure exacte d'entrée"
            if uncertain { detail += " (précision faible, à confirmer)" }
            log(.sessionStarted, place: place, detail: detail, date: date)
            return session
        } catch {
            log(.monitoringFailed, place: place, detail: "Démarrage de session impossible : \(error)", date: date)
            return nil
        }
    }

    /// Visite terminée dans un lieu de courses où l'on travaille aussi (section 11) : classée avec sa durée réelle.
    /// Courses sûres (score au-dessus de 75) : visite notée, aucune session. Sinon une session déjà terminée est créée,
    /// non confirmée, avec le classement provisoire ou "inconnu" à confirmer.
    private func classifyDualUseVisit(place: DetectionPlace, entered: Date, exited: Date) {
        guard let model = fetchPlace(uid: place.uid), model.type == .courses, model.alsoWorksHere else {
            log(.monitoringFailed, place: place, detail: "Lieu introuvable pour classer la visite", date: exited)
            return
        }
        let calendar = Calendar.current
        let seconds = exited.timeIntervalSince(entered)
        guard seconds >= DetectionEngine.minimumDwellSeconds else { return }
        let visit = VisitContext(placeKey: model.uid.uuidString, placeType: model.type, alsoWorksHere: model.alsoWorksHere,
                                 start: entered, durationSeconds: seconds,
                                 plannedShifts: workShifts(for: model, at: entered, calendar: calendar))
        let result: ClassificationResult = VisitClassifier.classify(visit, habits: HabitStore.shared.model,
                                                                    now: exited, calendar: calendar)
        if result.activity == .shopping && !result.needsConfirmation {
            log(.arrivalConfirmed, place: place, detail: "Visite classée courses, aucune session comptée. \(result.reason)", date: exited)
            return
        }
        let context: ModelContext = container.mainContext
        do {
            let candidates = try context.fetch(FetchDescriptor<WorkSession>(predicate: #Predicate<WorkSession> { $0.startDate < exited }))
            if candidates.contains(where: { ($0.endDate ?? .distantFuture) > entered }) {
                log(.ignoredShortVisit, place: place, detail: "Visite non comptée : une autre session couvre déjà tout ou partie de ce créneau. \(result.reason)", date: exited)
                return
            }
            let session = WorkSession(activity: result.activity, start: entered, end: exited, place: model,
                                      source: .gps, isConfirmed: result.level == .automatic)
            context.insert(session)
            do { try context.save() }
            catch {
                context.delete(session)
                throw error
            }
            log(.sessionStarted, place: place, detail: "Visite classée \(result.activity.title), score \(result.confidence). \(result.reason)", date: exited)
        } catch {
            log(.monitoringFailed, place: place, detail: "Session de visite impossible à enregistrer : \(error)", date: exited)
        }
    }

    private func workShifts(for place: Place, at date: Date, calendar: Calendar) -> [VisitPlannedShift] {
        let from = PlanningRules.weekStart(for: date, calendar: calendar)
        let to = PlanningRules.shiftWeek(from, by: 1, calendar: calendar)
        let work = ActivityType.work.rawValue
        let descriptor = FetchDescriptor<PlannedShift>(predicate: #Predicate<PlannedShift> { shift in
            shift.activityRaw == work && shift.start < to && shift.end > from
        })
        let shifts = (try? container.mainContext.fetch(descriptor)) ?? []
        let otherWorkplaces = fetchPlaces().contains { other in
            other.uid != place.uid && (other.type == .taf || (other.type == .courses && other.alsoWorksHere))
        }
        return shifts.filter { shift in
            shift.placeUID == place.uid || (shift.placeUID == nil && shift.employerUID == nil && !otherWorkplaces)
        }.map { VisitPlannedShift(start: $0.start, end: $0.end) }
    }

    private func stopSession(place: DetectionPlace, date: Date) -> WorkSession? {
        let context: ModelContext = container.mainContext
        let service = SessionService(context: context)
        guard let running = (try? service.runningSession()) ?? nil else {
            log(.monitoringFailed, place: place, detail: "Départ à enregistrer mais aucune session en cours", date: date)
            return nil
        }
        if let p = running.place, p.uid != place.uid {
            log(.monitoringFailed, place: place, detail: "La session en cours appartient à un autre lieu : non arrêtée", date: date)
            return nil
        }
        do {
            let stopped: WorkSession = try service.stop(running, now: date)
            log(.sessionStopped, place: place, detail: "Session arrêtée à l'heure exacte de sortie", date: date)
            return stopped
        } catch {
            log(.monitoringFailed, place: place, detail: "Arrêt de session impossible : \(error)", date: date)
            return nil
        }
    }

    private func askConfirmation(place: DetectionPlace, bound: DetectionBound, date: Date, session: WorkSession?) {
        guard let session = session else { return }
        var kind: DetectionNotificationKind = .arrival
        switch bound {
        case .arrival: kind = .arrival
        case .departure: kind = .departure
        }
        let outcome: DetectionNotifyOutcome = notifier.notify(kind: kind, sessionUID: session.uid, placeName: place.name,
                                                              placeType: place.type, bound: date)
        switch outcome {
        case .queued(let body):
            log(.notificationSent, place: place, detail: body, date: Date())
        case .skipped(let reason):
            log(.notificationSent, place: place, detail: "Non envoyée : \(reason). La session reste à confirmer dans l'app.", date: Date())
        }
    }

    // MARK: Journal

    private func log(_ kind: DetectionEventKind, place: DetectionPlace? = nil, detail: String,
                     date: Date = Date(), accuracy: Double? = nil) {
        let context: ModelContext = container.mainContext
        let event = DetectionEvent(kind: kind, date: date, placeName: place?.name, placeUID: place?.uid,
                                   detail: detail, accuracyMeters: accuracy)
        context.insert(event)
        try? context.save()
    }

    // MARK: Autres événements CoreLocation (côté acteur principal)

    private func handleMonitoringFailure(identifier: String?, message: String) {
        monitoringMessage = "Surveillance en erreur : \(message)"
        updateLastError()
        log(.monitoringFailed, detail: "\(identifier ?? "zone") : \(message)")
    }

    private func handleLocationUpdate(date: Date, fix: RegionFix?) {
        if let fix {
            for place in engine.placesAwaitingDeparture {
                guard let model = fetchPlace(uid: place.uid) else { continue }
                let zone = PlaceRules.Zone(name: model.name, latitude: model.latitude,
                                           longitude: model.longitude, radius: model.radius)
                if fix.clearlyInside(zone), !rejectsEntry(for: model, fix: fix) {
                    feed(.presenceVerified(place: place, date: fix.timestamp))
                }
            }
        }
        feed(.tick(date: date))
        let total: Int = fetchPlaces().count
        if total > RegionSelection.maxRegions {
            let last: Date = lastRefreshDate ?? Date.distantPast
            if date.timeIntervalSince(last) > 15 * 60 {
                refreshMonitoredPlaces()
            }
        }
    }

    // MARK: CLLocationManagerDelegate (hors acteur principal : on récupère des valeurs simples puis on y revient)

    nonisolated private func recentFix(from manager: CLLocationManager, now: Date) -> RegionFix? {
        guard let location = manager.location else { return nil }
        let fix = RegionFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                            accuracy: location.horizontalAccuracy, timestamp: location.timestamp)
        return fix.isRecent(at: now) ? fix : nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        manager.requestState(for: region)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier: String = region.identifier
        let now: Date = Date()
        let fix = recentFix(from: manager, now: now)
        Task { @MainActor [weak self] in
            self?.regionEntered(identifier: identifier, date: now, fix: fix)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let identifier: String = region.identifier
        let now: Date = Date()
        let accuracy = recentFix(from: manager, now: now)?.accuracy
        Task { @MainActor [weak self] in
            self?.regionExited(identifier: identifier, date: now, accuracy: accuracy)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard state == .inside else { return }
        let identifier: String = region.identifier
        let now: Date = Date()
        let fix = recentFix(from: manager, now: now)
        Task { @MainActor [weak self] in
            self?.regionEntered(identifier: identifier, date: now, fix: fix, fromState: true)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let identifier: String? = region?.identifier
        let message: String = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.handleMonitoringFailure(identifier: identifier, message: message)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message: String = error.localizedDescription
        var transient: Bool = false
        if let clError = error as? CLError, clError.code == CLError.Code.locationUnknown { transient = true }
        let isTransient: Bool = transient
        Task { @MainActor [weak self] in
            if !isTransient {
                self?.handleMonitoringFailure(identifier: nil, message: message)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let now: Date = Date()
        let fix = recentFix(from: manager, now: now)
        Task { @MainActor [weak self] in
            self?.handleLocationUpdate(date: now, fix: fix)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.applyAuthorization(status, shouldLog: true)
            self.refreshMonitoredPlaces()
        }
    }
}
