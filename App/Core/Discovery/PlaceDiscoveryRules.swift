import Foundation

struct PlaceVisitObservation: Codable, Equatable {
    let arrival: Date
    let departure: Date
    let accuracy: Double

    var duration: TimeInterval { departure.timeIntervalSince(arrival) }
}

struct DiscoveredPlaceContext: Codable, Equatable {
    let name: String?
    let address: String?
    let category: PlaceType?
}

struct DiscoveredPlace: Codable, Identifiable, Equatable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var arrivals: [Date] = []
    var dismissed = false
    // Optional fields preserve the existing on-device discovery history.
    var visits: [PlaceVisitObservation]?
    var context: DiscoveredPlaceContext?

}

struct PlaceRecommendation: Equatable {
    let type: PlaceType
    let reason: String
}

struct PendingPlaceVisit: Codable {
    let latitude: Double
    let longitude: Double
    let arrival: Date
    let accuracy: Double
}

enum PlaceDiscoveryRules {
    static let history: TimeInterval = 45 * 86400
    static let minimumStay: TimeInterval = 600
    private static let maximumAccuracy = 100.0

    static func distance(_ lat: Double, _ lon: Double, _ otherLat: Double, _ otherLon: Double) -> Double {
        PlaceRules.distanceMeters(latitude1: lat, longitude1: lon, latitude2: otherLat, longitude2: otherLon)
    }

    static func validFix(latitude: Double, longitude: Double, accuracy: Double) -> Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
            && accuracy.isFinite && accuracy >= 0 && accuracy <= maximumAccuracy
    }

    static func isSamePlace(distance: Double, accuracy: Double) -> Bool {
        distance <= min(75, max(35, accuracy))
    }

    static func freshArrivals(_ candidate: DiscoveredPlace, now: Date) -> [Date] {
        candidate.arrivals.filter { $0 >= now.addingTimeInterval(-history) && $0 <= now }
    }

    static func observations(_ candidate: DiscoveredPlace, now: Date) -> [PlaceVisitObservation] {
        (candidate.visits ?? []).filter { $0.arrival >= now.addingTimeInterval(-history) && $0.departure <= now }
    }

    static func acceptsSuggestion(_ candidate: DiscoveredPlace, now: Date, calendar: Calendar) -> Bool {
        let arrivals = freshArrivals(candidate, now: now)
        let distinctDays = Set(arrivals.map { calendar.startOfDay(for: $0) })
        if distinctDays.count >= 2 { return true }
        return observations(candidate, now: now).contains {
            $0.duration >= 20 * 60 && $0.accuracy <= 65 && $0.departure >= now.addingTimeInterval(-14 * 86400)
        }
    }

    static func recommendation(_ candidate: DiscoveredPlace, now: Date, calendar: Calendar) -> PlaceRecommendation? {
        let visits = observations(candidate, now: now)
        let longVisits = visits.filter { $0.duration >= 2 * 3600 }
        let longDays = Set(longVisits.map { calendar.startOfDay(for: $0.arrival) })
        let nights = Set(visits.compactMap { overnightDay(for: $0, calendar: calendar) })
        if candidate.context?.category == nil, nights.count >= 3, nights.count * 2 >= longVisits.count {
            return PlaceRecommendation(type: .domicile, reason: "Plusieurs longues visites couvrent le milieu de la nuit.")
        }
        if let category = candidate.context?.category, category != .courses {
            return PlaceRecommendation(type: category, reason: "Catégorie du lieu proche dans Apple Plans.")
        }
        let outsideSchoolPattern = longVisits.contains {
            calendar.isDateInWeekend($0.arrival) || calendar.component(.hour, from: $0.arrival) < 7
        }
        if longDays.count >= 3, longVisits.count * 2 >= visits.count, nights.isEmpty,
           outsideSchoolPattern || candidate.context?.category == .courses {
            return PlaceRecommendation(type: .taf, reason: "Plusieurs arrêts d’au moins deux heures, sur des jours différents.")
        }
        if candidate.context?.category == .courses {
            return PlaceRecommendation(type: .courses, reason: "Commerce proche indiqué par Apple Plans.")
        }
        return nil
    }

    private static func overnightDay(for visit: PlaceVisitObservation, calendar: Calendar) -> Date? {
        guard visit.duration >= 4 * 3600 else { return nil }
        let start = calendar.startOfDay(for: visit.arrival)
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let midnightWindowStart = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: day),
                  let midnightWindowEnd = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: day) else { continue }
            if visit.arrival <= midnightWindowStart && visit.departure >= midnightWindowEnd { return day }
        }
        return nil
    }

    static func record(in candidates: inout [DiscoveredPlace], latitude: Double, longitude: Double,
                       accuracy: Double, arrival: Date, departure: Date, now: Date) {
        let cutoff = now.addingTimeInterval(-history)
        guard validFix(latitude: latitude, longitude: longitude, accuracy: accuracy),
              arrival >= cutoff, departure <= now, departure.timeIntervalSince(arrival) >= minimumStay else { return }
        let matches = candidates.indices.compactMap { index -> (Int, Double)? in
            let candidate = candidates[index]
            let meters = distance(latitude, longitude, candidate.latitude, candidate.longitude)
            let candidateAccuracy = candidate.visits?.map(\.accuracy).min() ?? 35
            // One precise visit and one noisier fix can still describe the same stop.
            // Keep separate, nearby buildings when both fixes are precise.
            let matchingRadius = min(85, max(35, hypot(accuracy, candidateAccuracy)))
            let active = candidate.dismissed || candidate.arrivals.contains { $0 >= cutoff }
            return active && meters <= matchingRadius ? (index, meters) : nil
        }.sorted { $0.1 < $1.1 }
        let observation = PlaceVisitObservation(arrival: arrival, departure: departure, accuracy: accuracy)
        if let (index, meters) = matches.first {
            if matches.count > 1 && matches[1].1 - meters < 15 { return }
            guard !candidates[index].dismissed else { return }
            update(&candidates[index], observation: observation, cutoff: cutoff)
        } else {
            candidates.removeAll { !$0.dismissed && !$0.arrivals.contains { $0 >= cutoff } }
            if candidates.lazy.filter({ !$0.dismissed }).count >= 150 {
                guard let oldest = candidates.indices.filter({ !candidates[$0].dismissed }).min(by: {
                    (candidates[$0].arrivals.max() ?? .distantPast) < (candidates[$1].arrivals.max() ?? .distantPast)
                }) else { return }
                candidates.remove(at: oldest)
            }
            candidates.append(DiscoveredPlace(latitude: latitude, longitude: longitude,
                                              arrivals: [arrival], visits: [observation]))
        }
    }

    private static func update(_ candidate: inout DiscoveredPlace, observation: PlaceVisitObservation, cutoff: Date) {
        var visits = (candidate.visits ?? []).filter { $0.arrival >= cutoff }
        candidate.arrivals.removeAll { $0 < cutoff }
        if let index = visits.firstIndex(where: {
            abs($0.arrival.timeIntervalSince(observation.arrival)) < 10 * 60
                || ($0.arrival < observation.departure && observation.arrival < $0.departure)
        }) {
            let old = visits[index]
            visits[index] = PlaceVisitObservation(arrival: old.arrival,
                                                  departure: max(old.departure, observation.departure),
                                                  accuracy: min(old.accuracy, observation.accuracy))
        } else if let legacyIndex = candidate.arrivals.firstIndex(where: { arrival in
            abs(arrival.timeIntervalSince(observation.arrival)) < 10 * 60
                && !visits.contains { $0.arrival == arrival }
        }) {
            // A replay with a departure can complete an arrival recorded by the old app.
            candidate.arrivals[legacyIndex] = observation.arrival
            visits.append(observation)
        } else {
            // Core Location may deliver several stops during one stint indoors. Keep only one representative.
            guard !candidate.arrivals.contains(where: { abs($0.timeIntervalSince(observation.arrival)) < 2 * 3600 }) else { return }
            candidate.arrivals.append(observation.arrival)
            visits.append(observation)
        }
        candidate.arrivals = Array(candidate.arrivals.sorted().suffix(60))
        candidate.visits = Array(visits.sorted { $0.arrival < $1.arrival }.suffix(60))
    }
}
