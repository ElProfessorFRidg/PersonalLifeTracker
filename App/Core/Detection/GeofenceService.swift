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

    init(container: ModelContainer, notifier: DetectionNotifier, manager: CLLocationManager = CLLocationManager()) {
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
                self?.refreshMonitoredPlaces()
                self?.tick()
            }
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
    func refreshMonitoredPlaces() {
        lastRefreshDate = Date()
        let status: CLAuthorizationStatus = manager.authorizationStatus
        authorizationMessage = nil
        applyAuthorization(status, shouldLog: false)
        let allowed: Bool = (status == .authorizedAlways || status == .authorizedWhenInUse)
        if !allowed {
            stopAllRegions()
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
                continue
            }
            let region = CLCircularRegion(center: center, radius: radius, identifier: uid.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
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

    private func regionEntered(identifier: String, date: Date, accuracy: Double?) {
        lastEventDate = date
        guard let uid = UUID(uuidString: identifier), let place = fetchPlace(uid: uid) else { return }
        let dp: DetectionPlace = detectionPlace(place)
        log(.regionEntered, place: dp, detail: "Entrée dans la zone", date: date, accuracy: accuracy)
        feed(.entered(place: dp, date: date, accuracy: accuracy))
    }

    private func regionExited(identifier: String, date: Date, accuracy: Double?) {
        lastEventDate = date
        guard let uid = UUID(uuidString: identifier), let place = fetchPlace(uid: uid) else { return }
        let dp: DetectionPlace = detectionPlace(place)
        log(.regionExited, place: dp, detail: "Sortie de la zone", date: date, accuracy: accuracy)
        feed(.exited(place: dp, date: date))
    }

    /// État initial d'une zone (demandé à l'enregistrement) : "dedans" sans session en cours vaut une entrée à cet instant.
    private func regionStateInside(identifier: String, date: Date, accuracy: Double?) {
        guard let uid = UUID(uuidString: identifier), let place = fetchPlace(uid: uid) else { return }
        let dp: DetectionPlace = detectionPlace(place)
        feed(.entered(place: dp, date: date, accuracy: accuracy))
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
        updateTracking()
        scheduleTick()
    }

    private func updateTracking() {
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
                log(.arrivalConfirmed, place: place, detail: "Lieu de courses : visite notée, aucune session comptée", date: entered)
            case .skipBecauseSessionRunning(let place, let date):
                log(.ignoredShortVisit, place: place, detail: "Ignoré : une session est déjà en cours", date: date)
            case .departureCancelled(let place, let date):
                log(.regionEntered, place: place, detail: "Retour dans la zone pendant le délai de grâce : la session continue", date: date)
            case .ignoreExitWithoutEntry(let place, let date):
                log(.regionExited, place: place, detail: "Sortie sans entrée connue et sans session en cours : rien fait", date: date)
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
            let session: WorkSession = try SessionService(context: context).start(activity: model.type.defaultActivity, place: model, now: date)
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

    private func handleLocationUpdate(date: Date) {
        tick()
        let total: Int = fetchPlaces().count
        if total > RegionSelection.maxRegions {
            let last: Date = lastRefreshDate ?? Date.distantPast
            if date.timeIntervalSince(last) > 15 * 60 {
                refreshMonitoredPlaces()
            }
        }
    }

    // MARK: CLLocationManagerDelegate (hors acteur principal : on récupère des valeurs simples puis on y revient)

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier: String = region.identifier
        let now: Date = Date()
        var accuracy: Double? = nil
        if let loc = manager.location, loc.horizontalAccuracy >= 0 { accuracy = loc.horizontalAccuracy }
        let acc: Double? = accuracy
        Task { @MainActor [weak self] in
            self?.regionEntered(identifier: identifier, date: now, accuracy: acc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let identifier: String = region.identifier
        let now: Date = Date()
        var accuracy: Double? = nil
        if let loc = manager.location, loc.horizontalAccuracy >= 0 { accuracy = loc.horizontalAccuracy }
        let acc: Double? = accuracy
        Task { @MainActor [weak self] in
            self?.regionExited(identifier: identifier, date: now, accuracy: acc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let identifier: String = region.identifier
        let now: Date = Date()
        var accuracy: Double? = nil
        if let loc = manager.location, loc.horizontalAccuracy >= 0 { accuracy = loc.horizontalAccuracy }
        let acc: Double? = accuracy
        let isInside: Bool = (state == .inside)
        Task { @MainActor [weak self] in
            if isInside {
                self?.regionStateInside(identifier: identifier, date: now, accuracy: acc)
            }
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
        Task { @MainActor [weak self] in
            self?.handleLocationUpdate(date: now)
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
