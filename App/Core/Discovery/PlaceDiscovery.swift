import Foundation
import CoreLocation
import SwiftData
import Observation

struct DiscoveredPlace: Codable, Identifiable, Equatable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var arrivals: [Date] = []
    var dismissed = false

    var isReady: Bool { arrivals.count >= 3 }
}

/// Three completed stays of at least ten minutes, separated by four hours.
/// Only stop coordinates are kept, never a continuous route.
enum PlaceDiscoveryRules {
    static func distance(_ lat: Double, _ lon: Double, _ otherLat: Double, _ otherLon: Double) -> Double {
        let radians = Double.pi / 180
        let a = pow(sin((lat - otherLat) * radians / 2), 2)
            + cos(lat * radians) * cos(otherLat * radians) * pow(sin((lon - otherLon) * radians / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, a))))
    }

    static func record(in candidates: inout [DiscoveredPlace], latitude: Double, longitude: Double,
                       accuracy: Double, arrival: Date, departure: Date, now: Date) {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180,
              accuracy.isFinite, accuracy >= 0, accuracy <= 100,
              arrival != .distantPast, departure != .distantFuture,
              departure <= now, departure.timeIntervalSince(arrival) >= 600,
              arrival >= now.addingTimeInterval(-30 * 86400) else { return }
        if let i = candidates.firstIndex(where: { distance(latitude, longitude, $0.latitude, $0.longitude) <= 100 }) {
            guard !candidates[i].dismissed else { return }
            candidates[i].arrivals.removeAll { $0 < now.addingTimeInterval(-30 * 86400) }
            guard !candidates[i].arrivals.contains(where: { abs($0.timeIntervalSince(arrival)) < 4 * 3600 }) else { return }
            candidates[i].arrivals.append(arrival)
            candidates[i].arrivals = Array(candidates[i].arrivals.sorted().suffix(20))
        } else {
            candidates.removeAll { !$0.dismissed && ($0.arrivals.max() ?? .distantPast) < now.addingTimeInterval(-30 * 86400) }
            guard candidates.filter({ !$0.dismissed }).count < 100 else { return }
            candidates.append(DiscoveredPlace(latitude: latitude, longitude: longitude, arrivals: [arrival]))
        }
    }
}

@MainActor
@Observable
final class PlaceDiscovery: NSObject, CLLocationManagerDelegate {
    private(set) var candidates: [DiscoveredPlace] = []
    private(set) var error: String?
    private(set) var isMonitoring = false
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let container: ModelContainer
    private static let key = "plt.discovery.stops.v1"

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
        super.init()
        manager.delegate = self
        if let data = defaults.data(forKey: Self.key) {
            do { candidates = try JSONDecoder().decode([DiscoveredPlace].self, from: data) }
            catch { self.error = "Lecture des lieux impossible." }
        }
    }

    func refresh() {
        let active = ModuleStore(defaults: defaults).isActive("place_discovery")
        let allowed = manager.authorizationStatus == .authorizedAlways
        isMonitoring = active && allowed
        if isMonitoring { manager.startMonitoringVisits() }
        else { manager.stopMonitoringVisits() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { refresh() }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        recordVisit(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude,
                    accuracy: visit.horizontalAccuracy, arrival: visit.arrivalDate,
                    departure: visit.departureDate, now: Date())
    }

    func recordVisit(latitude: Double, longitude: Double, accuracy: Double,
                     arrival: Date, departure: Date, now: Date) {
        guard ModuleStore(defaults: defaults).isActive("place_discovery"), error == nil else { return }
        do {
            let places = try container.mainContext.fetch(FetchDescriptor<Place>())
            guard !places.contains(where: {
                PlaceDiscoveryRules.distance(latitude, longitude,
                                             $0.latitude, $0.longitude) <= max(100, $0.radius)
            }) else { return }
            PlaceDiscoveryRules.record(in: &candidates, latitude: latitude,
                                       longitude: longitude, accuracy: accuracy,
                                       arrival: arrival, departure: departure, now: now)
            persist()
        } catch { self.error = "Lecture des lieux impossible." }
    }

    func dismiss(_ id: UUID) {
        guard let i = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[i].dismissed = true
        persist()
    }

    func restoreSuggestions() {
        for i in candidates.indices { candidates[i].dismissed = false }
        persist()
    }

    func confirm(_ candidate: DiscoveredPlace, type: PlaceType, name: String) -> Bool {
        let context = container.mainContext
        do {
            let places = try context.fetch(FetchDescriptor<Place>())
            if places.contains(where: {
                PlaceDiscoveryRules.distance(candidate.latitude, candidate.longitude,
                                             $0.latitude, $0.longitude) <= max(100, $0.radius)
            }) {
                dismiss(candidate.id)
                return true
            }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let place = Place(name: trimmed.isEmpty ? type.title : trimmed, type: type,
                              latitude: candidate.latitude, longitude: candidate.longitude)
            context.insert(place)
            do { try context.save() }
            catch {
                context.delete(place)
                self.error = "Enregistrement impossible."
                return false
            }
            dismiss(candidate.id)
            return true
        } catch {
            self.error = "Lecture des lieux impossible."
            return false
        }
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(candidates), forKey: Self.key) }
        catch { self.error = "Enregistrement impossible." }
    }
}
