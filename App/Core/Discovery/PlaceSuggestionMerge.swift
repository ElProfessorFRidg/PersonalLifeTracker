import Foundation

/// Nouvelle forme proposée pour un lieu existant qui touche une suggestion (agrandir ou déplacer au lieu d'ajouter).
struct PlaceEnlargeShape: Equatable {
    let placeID: UUID
    let placeName: String
    let latitude: Double
    let longitude: Double
    let radius: Double
}

enum PlaceOverlapAssessment: Equatable {
    /// Aucun lieu enregistré ne touche la suggestion.
    case free
    /// Un lieu enregistré couvre déjà la suggestion (ou la touche sans pouvoir être agrandi) : ne jamais la proposer.
    case covered
    /// Un lieu enregistré la touche en partie : proposer d'agrandir ou déplacer ce lieu.
    case enlarge(PlaceEnlargeShape)
}

/// Une suggestion regroupée, avec le rayon qui couvre tous ses bâtiments.
struct PlaceSuggestionItem: Equatable {
    let suggestion: DiscoveredPlace
    let radius: Double
    let memberIDs: [UUID]
}

struct PlaceEnlargeProposal: Equatable {
    let shape: PlaceEnlargeShape
    /// Arrêts réunis dans cette proposition (à marquer comme traités une fois appliquée).
    let memberIDs: [UUID]
}

struct PlaceSuggestionPlan: Equatable {
    var suggestions: [PlaceSuggestionItem] = []
    var enlargements: [PlaceEnlargeProposal] = []
    /// Groupes ignorés par l'utilisateur et qui reviendraient sans cela.
    var ignoredCount: Int = 0
}

/// Regroupement des arrêts voisins en une seule suggestion et recouvrement avec les lieux enregistrés. Pur, Foundation seulement.
enum PlaceSuggestionMerge {

    /// Distance de fusion de départ en mètres : deux bâtiments d'une même rue.
    static let baseDistance: Double = 150
    /// Plafond de la distance de fusion.
    static let maxDistance: Double = 250
    /// La distance s'élargit de 100 m plus les deux précisions annoncées, jusqu'au plafond.
    static let accuracyPadding: Double = 100
    /// En dessous, deux arrêts sont le même bâtiment quel que soit leur type.
    static let sameBuildingDistance: Double = 60
    /// Demi-emprise d'un bâtiment, ajoutée au rayon de la zone.
    static let buildingHalfFootprint: Double = 40
    static let defaultAccuracy: Double = 35
    /// Marge pour dire qu'un lieu enregistré couvre déjà la suggestion.
    static let coverMargin: Double = 30
    /// Marge pour dire que deux zones se touchent.
    static let overlapMargin: Double = 30

    static func accuracy(of candidate: DiscoveredPlace) -> Double {
        let values: [Double] = (candidate.visits ?? []).map { (v: PlaceVisitObservation) -> Double in return v.accuracy }
        return values.min() ?? defaultAccuracy
    }

    /// 150 m, élargi par les précisions (100 + a + b), jamais plus de 250 m. `learnedDistance` : écart déjà fusionné à la main.
    static func mergeDistance(accuracyA: Double, accuracyB: Double, learnedDistance: Double? = nil) -> Double {
        let a: Double = (accuracyA.isFinite && accuracyA >= 0) ? accuracyA : defaultAccuracy
        let b: Double = (accuracyB.isFinite && accuracyB >= 0) ? accuracyB : defaultAccuracy
        var distance: Double = max(baseDistance, accuracyPadding + a + b)
        if let learned = learnedDistance, learned.isFinite { distance = max(distance, learned) }
        return min(maxDistance, distance)
    }

    private static func weight(_ candidate: DiscoveredPlace) -> Int {
        return max(1, candidate.arrivals.count)
    }

    private static func centroid(_ members: [DiscoveredPlace]) -> (latitude: Double, longitude: Double) {
        var total: Double = 0
        var lat: Double = 0
        var lon: Double = 0
        for member in members {
            let w: Double = Double(weight(member))
            total += w
            lat += member.latitude * w
            lon += member.longitude * w
        }
        if total <= 0 { return (latitude: members.first?.latitude ?? 0, longitude: members.first?.longitude ?? 0) }
        return (latitude: lat / total, longitude: lon / total)
    }

    /// Regroupe les arrêts. Un arrêt rejoint le groupe le plus proche dont le centre est à moins de la distance de fusion
    /// et dont le type est compatible (même type, ou l'un des deux inconnu, ou moins de 60 m : même bâtiment).
    /// Groupes construits du plus fréquenté au moins fréquenté, centre recalculé à chaque ajout : pas d'effet de chaîne.
    static func group(_ candidates: [DiscoveredPlace], learnedDistance: Double?,
                      leaning: (DiscoveredPlace) -> PlaceType?) -> [[DiscoveredPlace]] {
        let ordered: [DiscoveredPlace] = candidates.sorted { (a: DiscoveredPlace, b: DiscoveredPlace) -> Bool in
            if weight(a) != weight(b) { return weight(a) > weight(b) }
            return a.id.uuidString < b.id.uuidString
        }
        var groups: [[DiscoveredPlace]] = []
        var groupLeanings: [PlaceType?] = []
        for candidate in ordered {
            let own: PlaceType? = leaning(candidate)
            var bestIndex: Int? = nil
            var bestDistance: Double = Double.greatestFiniteMagnitude
            for index in 0..<groups.count {
                let center = centroid(groups[index])
                let meters: Double = PlaceRules.distanceMeters(latitude1: candidate.latitude, longitude1: candidate.longitude,
                                                               latitude2: center.latitude, longitude2: center.longitude)
                var groupAccuracy: Double = Double.greatestFiniteMagnitude
                for member in groups[index] { groupAccuracy = min(groupAccuracy, accuracy(of: member)) }
                let limit: Double = mergeDistance(accuracyA: accuracy(of: candidate), accuracyB: groupAccuracy,
                                                  learnedDistance: learnedDistance)
                if meters > limit { continue }
                let other: PlaceType? = groupLeanings[index]
                let compatible: Bool = meters <= sameBuildingDistance || own == nil || other == nil || own == other
                if compatible && meters < bestDistance {
                    bestDistance = meters
                    bestIndex = index
                }
            }
            if let index = bestIndex {
                groups[index].append(candidate)
            } else {
                groups.append([candidate])
                groupLeanings.append(own)
            }
        }
        return groups
    }

    /// Un seul arrêt à partir de plusieurs : centre pondéré par le nombre de passages, passages et jours additionnés,
    /// identifiant de l'arrêt le plus fréquenté, ignoré si l'un des arrêts l'était.
    static func combine(_ members: [DiscoveredPlace]) -> DiscoveredPlace? {
        guard let first = members.first else { return nil }
        if members.count == 1 { return first }
        let primary: DiscoveredPlace = members.sorted { (a: DiscoveredPlace, b: DiscoveredPlace) -> Bool in
            if weight(a) != weight(b) { return weight(a) > weight(b) }
            return a.id.uuidString < b.id.uuidString
        }[0]
        let center = centroid(members)
        var arrivals: [Date] = []
        var visits: [PlaceVisitObservation] = []
        var hasVisits: Bool = false
        for member in members {
            for date in member.arrivals where !arrivals.contains(date) { arrivals.append(date) }
            if let list = member.visits {
                hasVisits = true
                for visit in list where !visits.contains(visit) { visits.append(visit) }
            }
        }
        var result: DiscoveredPlace = primary
        result.latitude = center.latitude
        result.longitude = center.longitude
        result.arrivals = arrivals.sorted()
        result.visits = hasVisits ? visits.sorted { (a: PlaceVisitObservation, b: PlaceVisitObservation) -> Bool in
            return a.arrival < b.arrival
        } : nil
        result.dismissed = members.contains { (m: DiscoveredPlace) -> Bool in return m.dismissed }
        if result.context == nil {
            result.context = members.compactMap { (m: DiscoveredPlace) -> DiscoveredPlaceContext? in return m.context }.first
        }
        result.mergedIDs = members.map { (m: DiscoveredPlace) -> UUID in return m.id }
        return result
    }

    /// Rayon qui couvre tous les bâtiments : plus grande distance au centre + demi-emprise, au moins le rayon minimal, par 10 m.
    static func suggestedRadius(members: [DiscoveredPlace], latitude: Double, longitude: Double) -> Double {
        var needed: Double = PlaceRules.minRadius
        for member in members {
            let meters: Double = PlaceRules.distanceMeters(latitude1: latitude, longitude1: longitude,
                                                           latitude2: member.latitude, longitude2: member.longitude)
            needed = max(needed, meters + buildingHalfFootprint)
        }
        return PlaceRules.roundedUpRadius(needed)
    }

    // MARK: Recouvrement avec les lieux enregistrés

    /// Règles : si la zone de la suggestion tient presque dans un lieu enregistré, elle est couverte.
    /// Si les zones se touchent (avec marge), ou si un lieu du même type est à moins de la distance de fusion,
    /// on propose d'agrandir ou déplacer ce lieu (zone englobante) tant qu'elle reste sous le rayon maximal.
    static func assess(latitude: Double, longitude: Double, radius: Double, leaning: PlaceType?,
                       accuracy: Double, places: [PlaceSnapshot]) -> PlaceOverlapAssessment {
        var measured: [(place: PlaceSnapshot, meters: Double)] = []
        for place in places {
            let meters: Double = PlaceRules.distanceMeters(latitude1: latitude, longitude1: longitude,
                                                           latitude2: place.latitude, longitude2: place.longitude)
            measured.append((place: place, meters: meters))
        }
        measured.sort { (a: (place: PlaceSnapshot, meters: Double), b: (place: PlaceSnapshot, meters: Double)) -> Bool in
            return a.meters < b.meters
        }
        for item in measured {
            let place: PlaceSnapshot = item.place
            let meters: Double = item.meters
            if meters + radius <= place.radius + coverMargin { return .covered }
            let touching: Bool = meters < place.radius + radius + overlapMargin
            let sameKindNearby: Bool = leaning != nil && leaning == place.type
                && meters <= mergeDistance(accuracyA: accuracy, accuracyB: defaultAccuracy)
            if !touching && !sameKindNearby { continue }
            let zone: PlaceRules.EnclosingZone = PlaceRules.enclosingZone(
                latitude1: place.latitude, longitude1: place.longitude, radius1: place.radius,
                latitude2: latitude, longitude2: longitude, radius2: radius)
            let rounded: Double = PlaceRules.roundedUpRadius(zone.radius)
            if zone.radius > PlaceRules.maxRadius + 0.5 {
                if touching { return .covered }
                continue
            }
            return .enlarge(PlaceEnlargeShape(placeID: place.id, placeName: place.name,
                                              latitude: zone.latitude, longitude: zone.longitude, radius: rounded))
        }
        return .free
    }

    // MARK: Plan complet

    /// Regroupe, filtre et trie les suggestions. Les arrêts ignorés bloquent leurs voisins (un groupe est ignoré si l'un des siens l'est).
    static func plan(candidates: [DiscoveredPlace], places: [PlaceSnapshot], now: Date, calendar: Calendar,
                     learnedDistance: Double?, leaning: (DiscoveredPlace) -> PlaceType?) -> PlaceSuggestionPlan {
        var result: PlaceSuggestionPlan = PlaceSuggestionPlan()
        var items: [(item: PlaceSuggestionItem, home: Bool, count: Int, last: Date)] = []
        let groups: [[DiscoveredPlace]] = group(candidates, learnedDistance: learnedDistance, leaning: leaning)
        for members in groups {
            guard let combined = combine(members) else { continue }
            if !PlaceDiscoveryRules.acceptsSuggestion(combined, now: now, calendar: calendar) { continue }
            let radius: Double = suggestedRadius(members: members, latitude: combined.latitude, longitude: combined.longitude)
            let memberIDs: [UUID] = members.map { (m: DiscoveredPlace) -> UUID in return m.id }
            let assessment: PlaceOverlapAssessment = assess(latitude: combined.latitude, longitude: combined.longitude,
                                                            radius: radius, leaning: leaning(combined),
                                                            accuracy: accuracy(of: combined), places: places)
            switch assessment {
            case .covered:
                continue
            case .enlarge(let shape):
                if combined.dismissed { continue }
                if !result.enlargements.contains(where: { (p: PlaceEnlargeProposal) -> Bool in return p.shape.placeID == shape.placeID }) {
                    result.enlargements.append(PlaceEnlargeProposal(shape: shape, memberIDs: memberIDs))
                }
            case .free:
                if combined.dismissed {
                    result.ignoredCount += 1
                    continue
                }
                var suggestion: DiscoveredPlace = combined
                if members.count == 1 { suggestion.mergedIDs = nil }
                let arrivals: [Date] = PlaceDiscoveryRules.freshArrivals(combined, now: now)
                let home: Bool = PlaceDiscoveryRules.recommendation(combined, now: now, calendar: calendar)?.type == .domicile
                items.append((item: PlaceSuggestionItem(suggestion: suggestion, radius: radius, memberIDs: memberIDs),
                              home: home, count: arrivals.count, last: arrivals.max() ?? Date.distantPast))
            }
        }
        items.sort { (a: (item: PlaceSuggestionItem, home: Bool, count: Int, last: Date),
                      b: (item: PlaceSuggestionItem, home: Bool, count: Int, last: Date)) -> Bool in
            if a.home != b.home { return !a.home }
            if a.count != b.count { return a.count > b.count }
            if a.last != b.last { return a.last > b.last }
            return a.item.suggestion.id.uuidString < b.item.suggestion.id.uuidString
        }
        result.suggestions = items.map { (entry: (item: PlaceSuggestionItem, home: Bool, count: Int, last: Date)) -> PlaceSuggestionItem in
            return entry.item
        }
        return result
    }
}
