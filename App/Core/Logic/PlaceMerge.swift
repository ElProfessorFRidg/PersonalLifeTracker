import Foundation

/// Copie en valeurs simples d'un lieu enregistré, utilisée par les règles pures de fusion, de recouvrement et d'audit.
struct PlaceSnapshot: Equatable, Identifiable {
    let id: UUID
    let name: String
    let type: PlaceType
    let latitude: Double
    let longitude: Double
    let radius: Double
    let alsoWorksHere: Bool
    let sessionCount: Int
    /// Passages tirés des sessions du lieu (début, fin). Sert seulement à juger si le type est vraisemblable.
    var visits: [PlaceVisitObservation] = []
}

/// Résultat prévu d'une fusion de plusieurs lieux en un seul. Aucune écriture ici : l'écran applique le plan.
struct PlaceMergePlan: Equatable {
    /// Lieu conservé (celui qui a le plus de sessions). Les sessions des autres lui sont rattachées.
    let keeperID: UUID
    let removedIDs: [UUID]
    let name: String
    let type: PlaceType
    let alsoWorksHere: Bool
    let latitude: Double
    let longitude: Double
    /// Rayon qui couvre toutes les zones d'origine, ramené dans les bornes de l'app.
    let radius: Double
    /// Vrai si le rayon nécessaire dépassait le maximum de l'app (la zone ne couvre alors pas tout).
    let radiusWasCapped: Bool
    /// Plus grande distance entre deux centres fusionnés (sert à apprendre la distance de fusion).
    let largestGap: Double
}

enum PlaceMerge {

    /// Plan de fusion. nil s'il y a moins de deux lieux ou un doublon d'identifiant.
    /// Règles : le lieu conservé est celui qui a le plus de sessions (égalité : identifiant le plus petit) ;
    /// le centre est la moyenne des centres pondérée par le nombre de sessions (au moins 1 par lieu) ;
    /// le rayon couvre chaque zone d'origine ; le type et le nom sont ceux du lieu conservé.
    static func plan(_ places: [PlaceSnapshot]) -> PlaceMergePlan? {
        if places.count < 2 { return nil }
        let uniqueIDs: Set<UUID> = Set(places.map { $0.id })
        if uniqueIDs.count != places.count { return nil }
        let ordered: [PlaceSnapshot] = places.sorted { (a: PlaceSnapshot, b: PlaceSnapshot) -> Bool in
            if a.sessionCount != b.sessionCount { return a.sessionCount > b.sessionCount }
            return a.id.uuidString < b.id.uuidString
        }
        let keeper: PlaceSnapshot = ordered[0]
        var weightSum: Double = 0
        var latitudeSum: Double = 0
        var longitudeSum: Double = 0
        for place in ordered {
            let weight: Double = Double(max(1, place.sessionCount))
            weightSum += weight
            latitudeSum += place.latitude * weight
            longitudeSum += place.longitude * weight
        }
        let latitude: Double = latitudeSum / weightSum
        let longitude: Double = longitudeSum / weightSum
        var needed: Double = 0
        for place in ordered {
            let gap: Double = PlaceRules.distanceMeters(latitude1: latitude, longitude1: longitude,
                                                        latitude2: place.latitude, longitude2: place.longitude)
            needed = max(needed, gap + place.radius)
        }
        var largestGap: Double = 0
        for i in 0..<ordered.count {
            for j in (i + 1)..<ordered.count {
                let gap: Double = PlaceRules.distanceMeters(latitude1: ordered[i].latitude, longitude1: ordered[i].longitude,
                                                            latitude2: ordered[j].latitude, longitude2: ordered[j].longitude)
                largestGap = max(largestGap, gap)
            }
        }
        let anyAlsoWorks: Bool = ordered.contains { (p: PlaceSnapshot) -> Bool in return p.alsoWorksHere }
        return PlaceMergePlan(keeperID: keeper.id,
                              removedIDs: ordered.dropFirst().map { $0.id },
                              name: keeper.name,
                              type: keeper.type,
                              alsoWorksHere: keeper.type == .courses && anyAlsoWorks,
                              latitude: latitude,
                              longitude: longitude,
                              radius: PlaceRules.roundedUpRadius(needed),
                              radiusWasCapped: needed > PlaceRules.maxRadius + 0.5,
                              largestGap: largestGap)
    }

    /// Texte du résumé montré avant de confirmer la fusion.
    static func summary(_ plan: PlaceMergePlan, removedNames: [String]) -> String {
        let names: String = removedNames.joined(separator: ", ")
        var text: String = "« \(plan.name) » garde toutes les sessions de \(names). Sa zone passe à \(Int(plan.radius.rounded())) m."
        if plan.radiusWasCapped {
            text += " Ces lieux sont assez éloignés : la zone maximale ne couvre pas tout."
        }
        return text
    }
}
