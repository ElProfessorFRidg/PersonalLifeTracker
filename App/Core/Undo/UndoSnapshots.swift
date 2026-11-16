import Foundation
import SwiftData

/// Passage entre les modèles SwiftData et les copies de valeurs (structures d'export), pour annuler une suppression
/// et pour restaurer un instantané. Toujours reconstruire depuis une copie prise AVANT la suppression.
enum UndoSnapshots {
    // MARK: Copies de valeurs

    static func exportedPlace(_ p: Place) -> ExportedPlace {
        return ExportedPlace(uid: p.uid.uuidString, name: p.name, type: p.typeRaw,
                             latitude: p.latitude, longitude: p.longitude, radius: p.radius,
                             address: p.address, alsoWorksHere: p.alsoWorksHere, createdAt: p.createdAt)
    }

    static func exportedSession(_ s: WorkSession) -> ExportedSession {
        return ExportedSession(uid: s.uid.uuidString, activity: s.activityRaw,
                               start: s.startDate, end: s.endDate,
                               chosenStart: s.chosenStart, chosenEnd: s.chosenEnd,
                               source: s.sourceRaw, isConfirmed: s.isConfirmed, note: s.note,
                               timeZoneID: s.timeZoneID, createdAt: s.createdAt,
                               placeUID: s.place?.uid.uuidString)
    }

    static func currentDocument(context: ModelContext, now: Date) throws -> ExportDocument {
        let places: [Place] = try context.fetch(FetchDescriptor<Place>())
        let sessions: [WorkSession] = try context.fetch(FetchDescriptor<WorkSession>())
        return DataExport.makeDocument(places: places.map { exportedPlace($0) },
                                       sessions: sessions.map { exportedSession($0) },
                                       exportedAt: now)
    }

    // MARK: Reconstruction

    @discardableResult
    private static func insertPlace(_ e: ExportedPlace, context: ModelContext) -> Place {
        let place: Place = Place(name: e.name, type: PlaceType(rawValue: e.type) ?? .taf,
                                 latitude: e.latitude, longitude: e.longitude, radius: e.radius,
                                 address: e.address, alsoWorksHere: e.alsoWorksHere)
        place.typeRaw = e.type
        place.uid = UUID(uuidString: e.uid) ?? UUID()
        place.createdAt = e.createdAt
        context.insert(place)
        return place
    }

    @discardableResult
    private static func insertSession(_ e: ExportedSession, place: Place?, context: ModelContext) -> WorkSession {
        let session: WorkSession = WorkSession(activity: ActivityType(rawValue: e.activity) ?? .unknown,
                                               start: e.start, end: e.end, place: nil,
                                               source: SessionSource(rawValue: e.source) ?? .manual,
                                               isConfirmed: e.isConfirmed, note: e.note)
        session.activityRaw = e.activity
        session.sourceRaw = e.source
        session.uid = UUID(uuidString: e.uid) ?? UUID()
        session.chosenStart = e.chosenStart
        session.chosenEnd = e.chosenEnd
        session.timeZoneID = e.timeZoneID
        session.createdAt = e.createdAt
        context.insert(session)
        session.place = place
        return session
    }

    /// Remet une session supprimée, avec les mêmes valeurs et son lieu s'il existe encore. Sans effet si elle existe déjà.
    static func restoreSession(_ e: ExportedSession, context: ModelContext) throws {
        let sessions: [WorkSession] = try context.fetch(FetchDescriptor<WorkSession>())
        if sessions.contains(where: { $0.uid.uuidString == e.uid }) { return }
        var place: Place? = nil
        if let placeUID = e.placeUID {
            let places: [Place] = try context.fetch(FetchDescriptor<Place>())
            place = places.first(where: { $0.uid.uuidString == placeUID })
        }
        insertSession(e, place: place, context: context)
        try context.save()
    }

    /// Remet un lieu supprimé et rattache ses sessions (celles qui existent encore sont rattachées, les autres recréées).
    static func restorePlace(_ e: ExportedPlace, sessions linked: [ExportedSession], context: ModelContext) throws {
        let places: [Place] = try context.fetch(FetchDescriptor<Place>())
        if places.contains(where: { $0.uid.uuidString == e.uid }) { return }
        let place: Place = insertPlace(e, context: context)
        let existing: [WorkSession] = try context.fetch(FetchDescriptor<WorkSession>())
        for item in linked {
            if let found = existing.first(where: { $0.uid.uuidString == item.uid }) {
                found.place = place
            } else {
                insertSession(item, place: place, context: context)
            }
        }
        try context.save()
    }

    /// Remplace tous les lieux et toutes les sessions par le contenu du document. En cas d'erreur, annule tout.
    static func replaceAll(with document: ExportDocument, context: ModelContext) throws {
        do {
            let oldSessions: [WorkSession] = try context.fetch(FetchDescriptor<WorkSession>())
            for s in oldSessions { context.delete(s) }
            let oldPlaces: [Place] = try context.fetch(FetchDescriptor<Place>())
            for p in oldPlaces { context.delete(p) }
            var byUID: [String: Place] = [:]
            for e in document.places {
                byUID[e.uid] = insertPlace(e, context: context)
            }
            for e in document.sessions {
                var place: Place? = nil
                if let placeUID = e.placeUID { place = byUID[placeUID] }
                insertSession(e, place: place, context: context)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Instantané quotidien

    /// Écrit l'instantané du jour s'il est dû et si la base n'est pas vide, puis élague. Renvoie l'instantané créé.
    @discardableResult
    static func takeDailySnapshotIfDue(context: ModelContext,
                                       store: SnapshotStore,
                                       now: Date,
                                       calendar: Calendar) -> SnapshotInfo? {
        let last: Date? = store.list().first?.createdAt
        if !SnapshotPlan.isDue(lastSnapshot: last, now: now, calendar: calendar) { return nil }
        guard let document = try? currentDocument(context: context, now: now) else { return nil }
        if document.places.isEmpty && document.sessions.isEmpty { return nil }
        let info: SnapshotInfo? = try? store.write(document)
        store.prune(now: now, calendar: calendar)
        return info
    }
}
