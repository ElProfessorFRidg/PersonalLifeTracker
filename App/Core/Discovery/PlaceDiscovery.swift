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
    @ObservationIgnored let kindStore: PlaceKindStore
    private var pending: [PendingPlaceVisit] = []
    @ObservationIgnored private var lookups: Set<UUID> = []
    private static let key = "plt.discovery.stops.v1"
    private static let pendingKey = "plt.discovery.pending.v1"

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
        self.kindStore = PlaceKindStore(defaults: defaults)
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
        guard ModuleStore(defaults: defaults).isActive("place_discovery") else { return }
        let usableFix = PlaceDiscoveryRules.validFix(latitude: latitude, longitude: longitude, accuracy: accuracy)
        let canCompleteKnownArrival = departure <= now && arrival != .distantPast && accuracy > 100 && accuracy <= 200
            && PlaceDiscoveryRules.validFix(latitude: latitude, longitude: longitude, accuracy: 0)
        guard usableFix || canCompleteKnownArrival else { return }
        let cutoff = now.addingTimeInterval(-PlaceDiscoveryRules.history)
        let oldPendingCount = pending.count
        pending.removeAll { $0.arrival < cutoff }
        let matchingIndices = pending.indices.filter { index in
            let visit = pending[index]
            let arrivalDifference = abs(visit.arrival.timeIntervalSince(arrival))
            let meters = PlaceDiscoveryRules.distance(latitude, longitude, visit.latitude, visit.longitude)
            let span = departure.timeIntervalSince(visit.arrival)
            guard departure == .distantFuture || (span > 0 && span <= 3 * 86400) else { return false }
            if !usableFix {
                return visit.accuracy <= 65 && arrivalDifference < 2 * 60 && meters <= 75
            }
            let sameArrival = arrival == .distantPast || arrivalDifference < 10 * 60
            return sameArrival && PlaceDiscoveryRules.isSamePlace(distance: meters, accuracy: max(accuracy, visit.accuracy))
        }
        guard usableFix || matchingIndices.count == 1 else { return }
        let matchIndex = matchingIndices.max { pending[$0].arrival < pending[$1].arrival }

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

    /// Plan complet : suggestions regroupées (deux bâtiments voisins = une seule suggestion), propositions d'agrandir un lieu existant.
    func suggestionPlan(excluding places: [Place], now: Date = Date()) -> PlaceSuggestionPlan {
        let calendar: Calendar = Calendar.current
        let snapshots: [PlaceSnapshot] = places.map { (p: Place) -> PlaceSnapshot in return p.snapshot }
        return PlaceSuggestionMerge.plan(candidates: candidates, places: snapshots, now: now, calendar: calendar,
                                         learnedDistance: kindStore.memory.learnedMergeDistance,
                                         leaning: { (c: DiscoveredPlace) -> PlaceType? in
                                             return PlaceKindClassifier.leaning(of: c, now: now, calendar: calendar)
                                         })
    }

    func suggestions(excluding places: [Place], now: Date = Date()) -> [DiscoveredPlace] {
        return suggestionPlan(excluding: places, now: now).suggestions.map { (i: PlaceSuggestionItem) -> DiscoveredPlace in
            return i.suggestion
        }
    }

    /// Version à jour d'une suggestion (recombine ses arrêts à partir de l'historique courant).
    func current(_ suggestion: DiscoveredPlace) -> DiscoveredPlace {
        let ids: [UUID] = suggestion.mergedIDs ?? [suggestion.id]
        let members: [DiscoveredPlace] = candidates.filter { (c: DiscoveredPlace) -> Bool in return ids.contains(c.id) }
        guard let combined = PlaceSuggestionMerge.combine(members) else { return suggestion }
        return combined
    }

    /// Rayon qui couvre tous les bâtiments réunis dans la suggestion.
    func suggestedRadius(for suggestion: DiscoveredPlace) -> Double {
        let ids: [UUID] = suggestion.mergedIDs ?? [suggestion.id]
        let members: [DiscoveredPlace] = candidates.filter { (c: DiscoveredPlace) -> Bool in return ids.contains(c.id) }
        return PlaceSuggestionMerge.suggestedRadius(members: members, latitude: suggestion.latitude, longitude: suggestion.longitude)
    }

    /// Identification (type probable, question ou affirmation) d'une suggestion.
    func identification(for suggestion: DiscoveredPlace, places: [Place], contractPlaceUIDs: Set<UUID>,
                        now: Date = Date()) -> PlaceKindDecision {
        let snapshots: [PlaceSnapshot] = places.map { (p: Place) -> PlaceSnapshot in return p.snapshot }
        return PlaceKindClassifier.identify(suggestion, places: snapshots, contractPlaceUIDs: contractPlaceUIDs,
                                            memory: kindStore.memory, now: now, calendar: Calendar.current)
    }

    /// Refus d'une suggestion : tous ses arrêts sont ignorés, et l'app retient ce qu'elle proposait.
    func dismissSuggestion(_ suggestion: DiscoveredPlace) {
        let ids: Set<UUID> = Set(suggestion.mergedIDs ?? [suggestion.id])
        var changed: Bool = false
        for index in candidates.indices where ids.contains(candidates[index].id) && !candidates[index].dismissed {
            candidates[index].dismissed = true
            changed = true
        }
        if changed { persist() }
        let now: Date = Date()
        let calendar: Calendar = Calendar.current
        let decision: PlaceKindDecision = PlaceKindClassifier.identify(suggestion, places: [], contractPlaceUIDs: [],
                                                                       memory: kindStore.memory, now: now, calendar: calendar)
        kindStore.recordRefusal(key: "suggestion-" + suggestion.id.uuidString, latitude: suggestion.latitude,
                                longitude: suggestion.longitude, suggested: decision.leaning,
                                patternKey: decision.patternKey, now: now)
    }

    /// Marque des arrêts comme traités sans rien apprendre (lieu agrandi, couvert).
    func markHandled(_ ids: [UUID]) {
        var changed: Bool = false
        for index in candidates.indices where ids.contains(candidates[index].id) && !candidates[index].dismissed {
            candidates[index].dismissed = true
            changed = true
        }
        if changed { persist() }
    }

    /// Fusionne pour de bon les arrêts en double dans l'historique (un seul arrêt par groupe). Renvoie le nombre d'arrêts retirés.
    @discardableResult
    func consolidateDuplicates(now: Date = Date()) -> Int {
        let calendar: Calendar = Calendar.current
        let groups: [[DiscoveredPlace]] = PlaceSuggestionMerge.group(
            candidates, learnedDistance: kindStore.memory.learnedMergeDistance,
            leaning: { (c: DiscoveredPlace) -> PlaceType? in
                return PlaceKindClassifier.leaning(of: c, now: now, calendar: calendar)
            })
        var rebuilt: [DiscoveredPlace] = []
        var removed: Int = 0
        for members in groups {
            if members.count > 1, var combined = PlaceSuggestionMerge.combine(members) {
                combined.mergedIDs = nil
                combined.arrivals = Array(combined.arrivals.suffix(60))
                if let list = combined.visits { combined.visits = Array(list.suffix(60)) }
                rebuilt.append(combined)
                removed += members.count - 1
            } else {
                rebuilt.append(contentsOf: members)
            }
        }
        if removed > 0 {
            candidates = rebuilt
            persist()
        }
        return removed
    }

    func hasRecentArrivalAwaitingDeparture(now: Date = Date()) -> Bool {
        pending.contains { visit in
            let elapsed = now.timeIntervalSince(visit.arrival)
            return (0...86400).contains(elapsed)
        }
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
        let current: DiscoveredPlace = self.current(candidate)
        guard candidates.contains(where: { $0.id == current.id && !$0.dismissed }) else { return false }
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
        return suggestionPlan(excluding: places, now: now).ignoredCount > 0
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
        guard candidates.contains(where: { $0.id == candidate.id }) else {
            confirmationError = "Ce lieu n’est plus dans les suggestions."
            return false
        }
        let merged: DiscoveredPlace = current(candidate)
        let memberIDs: [UUID] = candidate.mergedIDs ?? [candidate.id]
        let radius: Double = suggestedRadius(for: candidate)
        let context = container.mainContext
        do {
            let places = try context.fetch(FetchDescriptor<Place>())
            let snapshots: [PlaceSnapshot] = places.map { (p: Place) -> PlaceSnapshot in return p.snapshot }
            let assessment: PlaceOverlapAssessment = PlaceSuggestionMerge.assess(
                latitude: merged.latitude, longitude: merged.longitude, radius: radius, leaning: nil,
                accuracy: PlaceSuggestionMerge.accuracy(of: merged), places: snapshots)
            if assessment == .covered {
                markHandled(memberIDs)
                return true
            }
            let cleaned = PlaceRules.cleanedName(name)
            let finalName = cleaned.isEmpty ? (merged.context?.name ?? type.title) : cleaned
            if let issue = PlaceRules.nameIssue(finalName, existingNames: places.map(\.name)) {
                confirmationError = issue.message
                return false
            }
            let place = Place(name: finalName, type: type, latitude: merged.latitude, longitude: merged.longitude,
                              radius: radius, address: merged.context?.address ?? "",
                              alsoWorksHere: type == .courses && alsoWorksHere)
            context.insert(place)
            do { try context.save() }
            catch {
                context.delete(place)
                confirmationError = "Le lieu n’a pas été enregistré. Réessaie."
                return false
            }
            let now: Date = Date()
            let decision: PlaceKindDecision = PlaceKindClassifier.identify(
                merged, places: snapshots, contractPlaceUIDs: [], memory: kindStore.memory,
                now: now, calendar: Calendar.current)
            kindStore.recordChoice(key: "suggestion-" + candidate.id.uuidString, latitude: merged.latitude,
                                   longitude: merged.longitude, chosen: type, suggested: decision.leaning,
                                   patternKey: decision.patternKey, now: now)
            markHandled(memberIDs)
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
