import Foundation
import CoreLocation
import SwiftData
import Observation

@MainActor
@Observable
final class PlaceDiscovery: NSObject, CLLocationManagerDelegate {
    private(set) var candidates: [DiscoveredPlace] = []
    private(set) var error: String?
    private(set) var confirmationError: String?
    private(set) var isMonitoring = false
    private(set) var hasPreciseLocation = false
    private(set) var canMonitorVisits = false
    private(set) var needsPermissionRequest = false
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var pending: [PendingPlaceVisit] = []
    @ObservationIgnored private var lookups: Set<UUID> = []
    private static let key = "plt.discovery.stops.v1"
    private static let pendingKey = "plt.discovery.pending.v1"

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
        super.init()
        do {
            if let data = defaults.data(forKey: Self.key) {
                candidates = try JSONDecoder().decode([DiscoveredPlace].self, from: data)
            }
            if let data = defaults.data(forKey: Self.pendingKey) {
                pending = try JSONDecoder().decode([PendingPlaceVisit].self, from: data)
            }
        } catch { self.error = "Lecture de l’historique des lieux impossible." }
        manager.delegate = self
    }

    func refresh() {
        let active = ModuleStore(defaults: defaults).isActive("place_discovery")
        canMonitorVisits = manager.authorizationStatus == .authorizedAlways
        needsPermissionRequest = manager.authorizationStatus == .notDetermined
        hasPreciseLocation = manager.accuracyAuthorization == .fullAccuracy
        let shouldMonitor = active && canMonitorVisits && hasPreciseLocation
        guard shouldMonitor != isMonitoring else { return }
        isMonitoring = shouldMonitor
        if shouldMonitor { manager.startMonitoringVisits() }
        else {
            manager.stopMonitoringVisits()
            pending.removeAll()
            defaults.removeObject(forKey: Self.pendingKey)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let latitude = visit.coordinate.latitude
        let longitude = visit.coordinate.longitude
        let accuracy = visit.horizontalAccuracy
        let arrival = visit.arrivalDate
        let departure = visit.departureDate
        let now = Date()
        Task { @MainActor [weak self] in
            guard let self, self.isMonitoring else { return }
            self.recordVisit(latitude: latitude, longitude: longitude, accuracy: accuracy,
                             arrival: arrival, departure: departure, now: now)
        }
    }

    func recordVisit(latitude: Double, longitude: Double, accuracy: Double,
                     arrival: Date, departure: Date, now: Date) {
        guard ModuleStore(defaults: defaults).isActive("place_discovery"),
              PlaceDiscoveryRules.validFix(latitude: latitude, longitude: longitude, accuracy: accuracy) else { return }
        let cutoff = now.addingTimeInterval(-PlaceDiscoveryRules.history)
        let oldPendingCount = pending.count
        pending.removeAll { $0.arrival < cutoff }
        let matchIndex = pending.indices.filter { index in
            let visit = pending[index]
            let sameArrival = arrival == .distantPast || abs(visit.arrival.timeIntervalSince(arrival)) < 10 * 60
            let meters = PlaceDiscoveryRules.distance(latitude, longitude, visit.latitude, visit.longitude)
            let span = departure.timeIntervalSince(visit.arrival)
            let plausibleDeparture = departure == .distantFuture || (span > 0 && span <= 3 * 86400)
            return sameArrival && plausibleDeparture && PlaceDiscoveryRules.isSamePlace(distance: meters, accuracy: max(accuracy, visit.accuracy))
        }.max { pending[$0].arrival < pending[$1].arrival }

        if departure == .distantFuture {
            guard arrival >= cutoff, arrival <= now else { return }
            let visit = PendingPlaceVisit(latitude: latitude, longitude: longitude, arrival: arrival, accuracy: accuracy)
            if let matchIndex {
                if pending[matchIndex].accuracy > accuracy { pending[matchIndex] = visit }
            } else {
                pending.append(visit)
                pending = Array(pending.sorted { $0.arrival < $1.arrival }.suffix(24))
            }
            persistPending()
            return
        }
        guard departure <= now else { return }
        let previous = matchIndex.map { pending.remove(at: $0) }
        if pending.count != oldPendingCount { persistPending() }
        let start = previous?.arrival ?? arrival
        let bestFix = previous.flatMap { $0.accuracy < accuracy ? $0 : nil }
        let stopLatitude = bestFix?.latitude ?? latitude
        let stopLongitude = bestFix?.longitude ?? longitude
        let stopAccuracy = bestFix?.accuracy ?? accuracy
        do {
            let places = try container.mainContext.fetch(FetchDescriptor<Place>())
            guard !places.contains(where: { isKnown(stopLatitude, stopLongitude, place: $0) }) else { return }
            var updated = candidates
            PlaceDiscoveryRules.record(in: &updated, latitude: stopLatitude, longitude: stopLongitude,
                                       accuracy: stopAccuracy, arrival: start, departure: departure, now: now)
            error = nil
            if updated != candidates {
                candidates = updated
                persist()
            }
        } catch { self.error = "Lecture des lieux enregistrés impossible." }
    }

    func suggestions(excluding places: [Place], now: Date = Date()) -> [DiscoveredPlace] {
        let calendar = Calendar.current
        return candidates.compactMap { candidate -> (place: DiscoveredPlace, home: Bool, count: Int, last: Date)? in
            guard !candidate.dismissed,
                  !places.contains(where: { isKnown(candidate.latitude, candidate.longitude, place: $0) }),
                  PlaceDiscoveryRules.acceptsSuggestion(candidate, now: now, calendar: calendar) else { return nil }
            let arrivals = PlaceDiscoveryRules.freshArrivals(candidate, now: now)
            let home = PlaceDiscoveryRules.recommendation(candidate, now: now, calendar: calendar)?.type == .domicile
            return (candidate, home, arrivals.count, arrivals.max() ?? .distantPast)
        }.sorted {
            if $0.home != $1.home { return !$0.home }
            if $0.count != $1.count { return $0.count > $1.count }
            if $0.last != $1.last { return $0.last > $1.last }
            return $0.place.id.uuidString < $1.place.id.uuidString
        }.map(\.place)
    }

    func observations(for candidate: DiscoveredPlace, now: Date = Date()) -> [PlaceVisitObservation] {
        PlaceDiscoveryRules.observations(candidate, now: now)
    }

    func visitCount(for candidate: DiscoveredPlace) -> Int {
        PlaceDiscoveryRules.freshArrivals(candidate, now: Date()).count
    }

    func recommendation(for candidate: DiscoveredPlace) -> PlaceRecommendation? {
        PlaceDiscoveryRules.recommendation(candidate, now: Date(), calendar: .current)
    }

    @discardableResult
    func enrich(_ candidate: DiscoveredPlace) async -> Bool {
        guard let current = candidates.first(where: { $0.id == candidate.id && !$0.dismissed }) else { return false }
        if current.context != nil { return true }
        guard lookups.insert(current.id).inserted else { return false }
        defer { lookups.remove(current.id) }
        let accuracy = observations(for: current).map(\.accuracy).min() ?? 35
        let identifyVenue = recommendation(for: current)?.type != .domicile
        guard let result = await DiscoveredPlaceLookup.lookup(current, accuracy: accuracy, identifyVenue: identifyVenue),
              !Task.isCancelled,
              let index = candidates.firstIndex(where: { $0.id == current.id && !$0.dismissed }) else { return false }
        candidates[index].context = result
        persist()
        return true
    }

    func dismiss(_ id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index].dismissed = true
        persist()
    }

    func hasIgnoredSuggestions(excluding places: [Place], now: Date = Date()) -> Bool {
        candidates.contains { candidate in
            candidate.dismissed && PlaceDiscoveryRules.acceptsSuggestion(candidate, now: now, calendar: .current)
                && !places.contains { isKnown(candidate.latitude, candidate.longitude, place: $0) }
        }
    }

    func restoreSuggestions() {
        for index in candidates.indices { candidates[index].dismissed = false }
        persist()
    }

    func clearHistory() {
        candidates.removeAll()
        pending.removeAll()
        error = nil
        confirmationError = nil
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.pendingKey)
    }

    func confirm(_ candidate: DiscoveredPlace, type: PlaceType, name: String, alsoWorksHere: Bool = false) -> Bool {
        confirmationError = nil
        guard let candidate = candidates.first(where: { $0.id == candidate.id }) else {
            confirmationError = "Ce lieu n’est plus dans les suggestions."
            return false
        }
        let context = container.mainContext
        do {
            let places = try context.fetch(FetchDescriptor<Place>())
            if places.contains(where: { isKnown(candidate.latitude, candidate.longitude, place: $0) }) {
                dismiss(candidate.id)
                return true
            }
            let cleaned = PlaceRules.cleanedName(name)
            let finalName = cleaned.isEmpty ? (candidate.context?.name ?? type.title) : cleaned
            if let issue = PlaceRules.nameIssue(finalName, existingNames: places.map(\.name)) {
                confirmationError = issue.message
                return false
            }
            let place = Place(name: finalName, type: type, latitude: candidate.latitude, longitude: candidate.longitude,
                              radius: PlaceRules.minRadius, address: candidate.context?.address ?? "",
                              alsoWorksHere: type == .courses && alsoWorksHere)
            context.insert(place)
            do { try context.save() }
            catch {
                context.delete(place)
                confirmationError = "Le lieu n’a pas été enregistré. Réessaie."
                return false
            }
            dismiss(candidate.id)
            return true
        } catch {
            confirmationError = "Lecture des lieux enregistrés impossible."
            return false
        }
    }

    private func isKnown(_ latitude: Double, _ longitude: Double, place: Place) -> Bool {
        // The tracking zone can be wide. Its boundary doesn't identify which building was visited.
        let meters = PlaceDiscoveryRules.distance(latitude, longitude, place.latitude, place.longitude)
        return meters <= min(45, place.radius)
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(candidates), forKey: Self.key) }
        catch { self.error = "Enregistrement des suggestions impossible." }
    }

    private func persistPending() {
        if pending.isEmpty {
            defaults.removeObject(forKey: Self.pendingKey)
        } else {
            do { defaults.set(try JSONEncoder().encode(pending), forKey: Self.pendingKey) }
            catch { self.error = "Enregistrement de l’arrivée impossible." }
        }
    }
}
