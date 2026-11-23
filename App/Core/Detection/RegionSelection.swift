import Foundation

/// Un lieu candidat à la surveillance (Foundation seulement).
struct RegionCandidate: Equatable {
    let uid: UUID
    let latitude: Double
    let longitude: Double
}

/// Position exploitable au moment d'un événement de région, sans dépendance à Core Location.
struct RegionFix: Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date

    func isRecent(at date: Date) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return age >= -2 && age <= 10 && accuracy.isFinite && accuracy >= 0
            && PlaceRules.isValidCoordinate(latitude: latitude, longitude: longitude)
    }

    func clearlyOutside(_ zone: PlaceRules.Zone) -> Bool {
        accuracy <= 30 && distance(to: zone) > zone.radius + accuracy + 20
    }

    func clearlyInside(_ zone: PlaceRules.Zone) -> Bool {
        accuracy <= 30 && distance(to: zone) + accuracy + 15 <= zone.radius
    }

    func favorsHome(_ home: PlaceRules.Zone, over workplace: PlaceRules.Zone) -> Bool {
        let metersToHome = distance(to: home)
        return accuracy <= 30 && metersToHome + accuracy <= min(home.radius, 45)
            && distance(to: workplace) - metersToHome > 2 * accuracy + 20
    }

    private func distance(to zone: PlaceRules.Zone) -> Double {
        PlaceRules.distanceMeters(latitude1: latitude, longitude1: longitude,
                                  latitude2: zone.latitude, longitude2: zone.longitude)
    }
}

/// Choix des lieux à surveiller : iOS limite à 20 régions par app (section 8).
enum RegionSelection {
    static let maxRegions: Int = 20

    /// Garde au plus `limit` lieux. Avec une position de référence, les plus proches d'abord ; sans, l'ordre reçu est conservé.
    /// Les coordonnées invalides sont écartées.
    static func select(_ candidates: [RegionCandidate],
                       limit: Int = RegionSelection.maxRegions,
                       referenceLatitude: Double? = nil,
                       referenceLongitude: Double? = nil) -> [UUID] {
        let valid: [RegionCandidate] = candidates.filter {
            PlaceRules.isValidCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        if valid.count <= limit && (referenceLatitude == nil || referenceLongitude == nil) {
            return valid.map { $0.uid }
        }
        guard let refLat = referenceLatitude, let refLon = referenceLongitude else {
            return Array(valid.prefix(limit)).map { $0.uid }
        }
        var scored: [(index: Int, uid: UUID, distance: Double)] = []
        for (i, c) in valid.enumerated() {
            let d: Double = PlaceRules.distanceMeters(latitude1: refLat, longitude1: refLon,
                                                      latitude2: c.latitude, longitude2: c.longitude)
            scored.append((index: i, uid: c.uid, distance: d))
        }
        scored.sort { (a, b) -> Bool in
            if a.distance != b.distance { return a.distance < b.distance }
            return a.index < b.index
        }
        return Array(scored.prefix(limit)).map { $0.uid }
    }
}
