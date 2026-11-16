import Foundation

/// Un lieu candidat à la surveillance (Foundation seulement).
struct RegionCandidate: Equatable {
    let uid: UUID
    let latitude: Double
    let longitude: Double
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
