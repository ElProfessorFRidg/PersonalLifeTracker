import Foundation
import SwiftData

/// Applique sur SwiftData les corrections décidées par les règles pures (fusion de lieux, agrandissement, type, zones).
/// Chaque action est annulable via UndoCenter quand il existe.
@MainActor
enum PlaceFixActions {

    /// Fusionne les lieux : le lieu conservé reprend toutes les sessions (et les contrats, passages détectés des autres).
    /// Renvoie le lieu conservé, nil si le plan est impossible.
    @discardableResult
    static func merge(placeIDs: [UUID], context: ModelContext, undo: UndoCenter?, geofence: GeofenceService?) -> Place? {
        let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let chosen: [Place] = all.filter { (p: Place) -> Bool in return placeIDs.contains(p.uid) }
        let snapshots: [PlaceSnapshot] = chosen.map { (p: Place) -> PlaceSnapshot in return p.snapshot }
        guard let plan = PlaceMerge.plan(snapshots),
              let keeper = chosen.first(where: { (p: Place) -> Bool in return p.uid == plan.keeperID }) else { return nil }
        let removed: [Place] = chosen.filter { (p: Place) -> Bool in return p.uid != plan.keeperID }
        let removedUIDs: [UUID] = removed.map { (p: Place) -> UUID in return p.uid }
        let removedCopies: [ExportedPlace] = removed.map { (p: Place) -> ExportedPlace in return UndoSnapshots.exportedPlace(p) }
        let before: (latitude: Double, longitude: Double, radius: Double, alsoWorks: Bool) =
            (keeper.latitude, keeper.longitude, keeper.radius, keeper.alsoWorksHere)
        let keeperUID: UUID = keeper.uid

        var movedSessions: [(session: UUID, place: UUID)] = []
        for place in removed {
            let sessions: [WorkSession] = Array(place.sessions)
            for session in sessions {
                movedSessions.append((session: session.uid, place: place.uid))
                session.place = keeper
            }
        }
        var oldContracts: [(contract: UUID, uids: [UUID])] = []
        let contracts: [Contract] = (try? context.fetch(FetchDescriptor<Contract>())) ?? []
        for contract in contracts where contract.placeUIDs.contains(where: { (u: UUID) -> Bool in return removedUIDs.contains(u) }) {
            oldContracts.append((contract: contract.uid, uids: contract.placeUIDs))
            var updated: [UUID] = []
            for uid in contract.placeUIDs {
                let mapped: UUID = removedUIDs.contains(uid) ? keeperUID : uid
                if !updated.contains(mapped) { updated.append(mapped) }
            }
            contract.placeUIDs = updated
        }
        var oldEvents: [(event: UUID, place: UUID)] = []
        let events: [DetectionEvent] = (try? context.fetch(FetchDescriptor<DetectionEvent>())) ?? []
        for event in events {
            if let uid = event.placeUID, removedUIDs.contains(uid) {
                oldEvents.append((event: event.uid, place: uid))
                event.placeUID = keeperUID
                event.placeName = keeper.name
            }
        }
        keeper.latitude = plan.latitude
        keeper.longitude = plan.longitude
        keeper.radius = plan.radius
        keeper.alsoWorksHere = plan.alsoWorksHere
        for place in removed { context.delete(place) }
        try? context.save()
        PlaceKindStore.shared.recordMerge(gap: plan.largestGap)
        geofence?.refreshMonitoredPlaces()

        let keeperName: String = keeper.name
        let service: GeofenceService? = geofence
        undo?.register(message: "Lieux fusionnés dans « \(keeperName) »") {
            for copy in removedCopies {
                try? UndoSnapshots.restorePlace(copy, sessions: [], context: context)
            }
            let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
            if let found = places.first(where: { (p: Place) -> Bool in return p.uid == keeperUID }) {
                found.latitude = before.latitude
                found.longitude = before.longitude
                found.radius = before.radius
                found.alsoWorksHere = before.alsoWorks
            }
            let sessions: [WorkSession] = (try? context.fetch(FetchDescriptor<WorkSession>())) ?? []
            for moved in movedSessions {
                if let session = sessions.first(where: { (s: WorkSession) -> Bool in return s.uid == moved.session }),
                   let target = places.first(where: { (p: Place) -> Bool in return p.uid == moved.place }) {
                    session.place = target
                }
            }
            let allContracts: [Contract] = (try? context.fetch(FetchDescriptor<Contract>())) ?? []
            for old in oldContracts {
                if let contract = allContracts.first(where: { (c: Contract) -> Bool in return c.uid == old.contract }) {
                    contract.placeUIDs = old.uids
                }
            }
            let allEvents: [DetectionEvent] = (try? context.fetch(FetchDescriptor<DetectionEvent>())) ?? []
            for old in oldEvents {
                if let event = allEvents.first(where: { (e: DetectionEvent) -> Bool in return e.uid == old.event }) {
                    event.placeUID = old.place
                }
            }
            try? context.save()
            Task { @MainActor in service?.refreshMonitoredPlaces() }
        }
        return keeper
    }

    /// Applique un correctif de l'audit. Les cas qui touchent l'historique de découverte passent par `discovery`.
    static func apply(_ fix: PlaceAuditFix, context: ModelContext, undo: UndoCenter?,
                      geofence: GeofenceService) {
        switch fix {
        case .mergePlaces(let ids):
            merge(placeIDs: ids, context: context, undo: undo, geofence: geofence)
        case .consolidateSuggestions:
            geofence.discovery.consolidateDuplicates()
        case .enlargePlace(let shape, let candidateIDs):
            let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
            guard let place = places.first(where: { (p: Place) -> Bool in return p.uid == shape.placeID }) else { return }
            let before: (latitude: Double, longitude: Double, radius: Double) = (place.latitude, place.longitude, place.radius)
            let uid: UUID = place.uid
            place.latitude = shape.latitude
            place.longitude = shape.longitude
            place.radius = PlaceRules.clampRadius(shape.radius)
            try? context.save()
            geofence.discovery.markHandled(candidateIDs)
            geofence.refreshMonitoredPlaces()
            undo?.register(message: "Lieu agrandi : \(shape.placeName)") {
                let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
                if let found = all.first(where: { (p: Place) -> Bool in return p.uid == uid }) {
                    found.latitude = before.latitude
                    found.longitude = before.longitude
                    found.radius = before.radius
                    try? context.save()
                }
                Task { @MainActor in geofence.refreshMonitoredPlaces() }
            }
        case .changeType(let placeID, let newType):
            let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
            guard let place = places.first(where: { (p: Place) -> Bool in return p.uid == placeID }) else { return }
            let previous: PlaceType = place.type
            let previousAlso: Bool = place.alsoWorksHere
            place.type = newType
            if newType != .courses { place.alsoWorksHere = false }
            try? context.save()
            PlaceKindStore.shared.recordChoice(key: "place-" + place.uid.uuidString, latitude: place.latitude,
                                               longitude: place.longitude, chosen: newType, suggested: previous,
                                               patternKey: nil)
            geofence.refreshMonitoredPlaces()
            let name: String = place.name
            undo?.register(message: "Type changé : \(name)") {
                let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
                if let found = all.first(where: { (p: Place) -> Bool in return p.uid == placeID }) {
                    found.type = previous
                    found.alsoWorksHere = previousAlso
                    try? context.save()
                }
                Task { @MainActor in geofence.refreshMonitoredPlaces() }
            }
        case .shrinkZones(let changes):
            let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
            var previous: [(uid: UUID, radius: Double)] = []
            for change in changes {
                if let place = places.first(where: { (p: Place) -> Bool in return p.uid == change.placeID }) {
                    previous.append((uid: place.uid, radius: place.radius))
                    place.radius = PlaceRules.clampRadius(change.radius)
                }
            }
            try? context.save()
            geofence.refreshMonitoredPlaces()
            undo?.register(message: "Zones réduites") {
                let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
                for old in previous {
                    if let found = all.first(where: { (p: Place) -> Bool in return p.uid == old.uid }) { found.radius = old.radius }
                }
                try? context.save()
                Task { @MainActor in geofence.refreshMonitoredPlaces() }
            }
        }
    }
}

/// Problèmes de l'audit que l'utilisateur a choisi d'ignorer (UserDefaults, identifiants stables).
enum PlaceAuditIgnore {
    static let key: String = "plt.placeaudit.ignored"

    static func load(defaults: UserDefaults = UserDefaults.standard) -> Set<String> {
        return Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func save(_ ids: Set<String>, defaults: UserDefaults = UserDefaults.standard) {
        defaults.set(Array(ids).sorted(), forKey: key)
    }
}
