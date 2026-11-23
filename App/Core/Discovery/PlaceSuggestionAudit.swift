import Foundation

struct PlaceZoneChange: Equatable {
    let placeID: UUID
    let radius: Double
}

/// Correction en un geste d'un problème repéré.
enum PlaceAuditFix: Equatable {
    case mergePlaces(ids: [UUID])
    case consolidateSuggestions(ids: [UUID])
    case enlargePlace(shape: PlaceEnlargeShape, candidateIDs: [UUID])
    case changeType(placeID: UUID, to: PlaceType)
    case shrinkZones(changes: [PlaceZoneChange])
}

struct PlaceAuditProblem: Equatable, Identifiable {
    /// Stable d'un appel à l'autre : sert à mémoriser un "Ignorer".
    let id: String
    let message: String
    let fixTitle: String
    let fix: PlaceAuditFix
    /// Plus petit = plus important.
    let priority: Int
}

/// Contrôle des données existantes : doublons, chevauchements, types invraisemblables. Pur, Foundation seulement.
enum PlaceSuggestionAudit {

    /// Types pour lesquels deux lieux voisins sont presque sûrement un doublon.
    static let duplicateTypes: [PlaceType] = [.taf, .cours, .courses, .sport]
    /// Score minimal du type vraisemblable pour dire que le type enregistré est invraisemblable.
    static let unlikelyScore: Double = 50
    /// Score maximal toléré pour le type enregistré.
    static let registeredScoreCeiling: Double = 20
    /// À partir de ce nombre de sessions, l'utilisateur a prouvé son choix : on ne le contredit pas sur le seul nom.
    static let provenSessionCount: Int = 5

    private static func ids(_ values: [UUID]) -> String {
        return values.map { (u: UUID) -> String in return u.uuidString }.sorted().joined(separator: "+")
    }

    static func audit(places: [PlaceSnapshot], candidates: [DiscoveredPlace], now: Date, calendar: Calendar,
                      learnedDistance: Double?, leaning: (DiscoveredPlace) -> PlaceType?) -> [PlaceAuditProblem] {
        var problems: [PlaceAuditProblem] = []

        // 1. Lieux enregistrés en double (même type, voisins).
        var used: Set<UUID> = []
        let sortedPlaces: [PlaceSnapshot] = places.sorted { (a: PlaceSnapshot, b: PlaceSnapshot) -> Bool in
            return a.id.uuidString < b.id.uuidString
        }
        for place in sortedPlaces where !used.contains(place.id) && duplicateTypes.contains(place.type) {
            var cluster: [PlaceSnapshot] = [place]
            for other in sortedPlaces where other.id != place.id && !used.contains(other.id) && other.type == place.type {
                let meters: Double = PlaceRules.distanceMeters(latitude1: place.latitude, longitude1: place.longitude,
                                                               latitude2: other.latitude, longitude2: other.longitude)
                let limit: Double = PlaceSuggestionMerge.mergeDistance(accuracyA: PlaceSuggestionMerge.defaultAccuracy,
                                                                      accuracyB: PlaceSuggestionMerge.defaultAccuracy,
                                                                      learnedDistance: learnedDistance)
                if meters <= limit || meters < place.radius + other.radius {
                    cluster.append(other)
                }
            }
            if cluster.count < 2 { continue }
            for member in cluster { used.insert(member.id) }
            let clusterIDs: [UUID] = cluster.map { (p: PlaceSnapshot) -> UUID in return p.id }
            let names: String = cluster.map { (p: PlaceSnapshot) -> String in return "« \(p.name) »" }.joined(separator: " et ")
            problems.append(PlaceAuditProblem(
                id: "dup-places-" + ids(clusterIDs),
                message: "\(names) sont tout près l'un de l'autre et du même type. C'est probablement le même lieu.",
                fixTitle: "Fusionner",
                fix: .mergePlaces(ids: clusterIDs),
                priority: 0))
        }

        // 2. Arrêts en double dans les suggestions.
        let groups: [[DiscoveredPlace]] = PlaceSuggestionMerge.group(candidates, learnedDistance: learnedDistance, leaning: leaning)
        for members in groups where members.count > 1 {
            guard let combined = PlaceSuggestionMerge.combine(members) else { continue }
            if combined.dismissed { continue }
            if !PlaceDiscoveryRules.acceptsSuggestion(combined, now: now, calendar: calendar) { continue }
            let memberIDs: [UUID] = members.map { (m: DiscoveredPlace) -> UUID in return m.id }
            problems.append(PlaceAuditProblem(
                id: "dup-suggestions-" + ids(memberIDs),
                message: "\(members.count) suggestions décrivent le même endroit (bâtiments voisins).",
                fixTitle: "Regrouper",
                fix: .consolidateSuggestions(ids: memberIDs),
                priority: 1))
        }

        // 3. Suggestions qui touchent en partie un lieu existant : agrandir plutôt qu'ajouter.
        var proposedPlaces: Set<UUID> = []
        for members in groups {
            guard let combined = PlaceSuggestionMerge.combine(members) else { continue }
            if combined.dismissed { continue }
            if !PlaceDiscoveryRules.acceptsSuggestion(combined, now: now, calendar: calendar) { continue }
            let radius: Double = PlaceSuggestionMerge.suggestedRadius(members: members, latitude: combined.latitude,
                                                                      longitude: combined.longitude)
            let assessment: PlaceOverlapAssessment = PlaceSuggestionMerge.assess(
                latitude: combined.latitude, longitude: combined.longitude, radius: radius, leaning: leaning(combined),
                accuracy: PlaceSuggestionMerge.accuracy(of: combined), places: places)
            if case .enlarge(let shape) = assessment, !proposedPlaces.contains(shape.placeID) {
                proposedPlaces.insert(shape.placeID)
                let memberIDs: [UUID] = members.map { (m: DiscoveredPlace) -> UUID in return m.id }
                problems.append(PlaceAuditProblem(
                    id: "enlarge-" + shape.placeID.uuidString + "-" + ids(memberIDs),
                    message: "Un arrêt récurrent touche « \(shape.placeName) ». Mieux vaut agrandir ce lieu que d'en ajouter un autre.",
                    fixTitle: "Agrandir",
                    fix: .enlargePlace(shape: shape, candidateIDs: memberIDs),
                    priority: 2))
            }
        }

        // 4. Zones enregistrées qui se recouvrent (types différents) : réduire si les deux restent au-dessus du minimum.
        for i in 0..<sortedPlaces.count {
            for j in (i + 1)..<sortedPlaces.count {
                let a: PlaceSnapshot = sortedPlaces[i]
                let b: PlaceSnapshot = sortedPlaces[j]
                if a.type == b.type && duplicateTypes.contains(a.type) { continue }
                let meters: Double = PlaceRules.distanceMeters(latitude1: a.latitude, longitude1: a.longitude,
                                                               latitude2: b.latitude, longitude2: b.longitude)
                let overlap: Double = a.radius + b.radius - meters
                if overlap <= 0 { continue }
                let cut: Double = (overlap / 2).rounded(.up) + 5
                let newA: Double = a.radius - cut
                let newB: Double = b.radius - cut
                if newA < PlaceRules.minRadius || newB < PlaceRules.minRadius { continue }
                problems.append(PlaceAuditProblem(
                    id: "overlap-" + ids([a.id, b.id]),
                    message: "Les zones de « \(a.name) » et « \(b.name) » se touchent : je risque d'hésiter entre les deux.",
                    fixTitle: "Réduire les zones",
                    fix: .shrinkZones(changes: [PlaceZoneChange(placeID: a.id, radius: PlaceRules.roundedUpRadius(newA)),
                                                PlaceZoneChange(placeID: b.id, radius: PlaceRules.roundedUpRadius(newB))]),
                    priority: 4))
            }
        }

        // 5. Type invraisemblable pour un lieu enregistré.
        for place in sortedPlaces {
            if place.sessionCount >= provenSessionCount { continue }
            if place.type == .courses && place.alsoWorksHere { continue }
            let important: [PlaceType] = [.taf, .cours, .courses]
            if !important.contains(place.type) { continue }
            let signals: PlaceKindSignals = PlaceKindSignals(visits: place.visits, name: place.name, poi: nil, poiCategory: nil,
                                                             latitude: place.latitude, longitude: place.longitude,
                                                             nearby: [], lessons: [], calendar: calendar)
            let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals)
            guard let likely = decision.leaning, likely != place.type, important.contains(likely) else { continue }
            let likelyScore: Double = decision.scores[likely] ?? 0
            let registeredScore: Double = decision.scores[place.type] ?? 0
            if likelyScore < unlikelyScore || registeredScore >= registeredScoreCeiling { continue }
            problems.append(PlaceAuditProblem(
                id: "type-" + place.id.uuidString + "-" + likely.rawValue,
                message: "« \(place.name) » est enregistré comme \(place.type.title), mais le nom ressemble plutôt à \(PlaceKindClassifier.noun(likely)).",
                fixTitle: "Passer en \(likely.title)",
                fix: .changeType(placeID: place.id, to: likely),
                priority: 3))
        }

        return problems.sorted { (a: PlaceAuditProblem, b: PlaceAuditProblem) -> Bool in
            if a.priority != b.priority { return a.priority < b.priority }
            return a.id < b.id
        }
    }
}
