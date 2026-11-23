import Foundation
import Observation

/// Une pause enregistrée dans une session (`WorkSession.uid`). Fin nil = pause en cours.
struct BreakRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var sessionUID: UUID
    var start: Date
    var end: Date?
    /// Vrai si elle a été saisie à la main.
    var isManual: Bool

    var interval: BreakInterval {
        return BreakInterval(start: start, end: end)
    }
}

enum BreakStoreError: Error, Equatable {
    case alreadyRunning
    case notRunning
    case invalidInterval
}

/// Pauses des sessions, gardées dans `breaks.json`. Pas de nouveau modèle SwiftData.
@Observable
final class BreakStore {
    static let shared: BreakStore = BreakStore()

    private(set) var records: [BreakRecord] = []
    @ObservationIgnored private let file: JSONFileStore<[BreakRecord]>

    init(file: JSONFileStore<[BreakRecord]> = JSONFileStore<[BreakRecord]>(fileName: "breaks.json")) {
        self.file = file
        self.records = file.load(defaultValue: [])
    }

    func breaks(for sessionUID: UUID) -> [BreakRecord] {
        let list: [BreakRecord] = records.filter { (r: BreakRecord) -> Bool in return r.sessionUID == sessionUID }
        return list.sorted { (a: BreakRecord, b: BreakRecord) -> Bool in return a.start < b.start }
    }

    func runningBreak(for sessionUID: UUID) -> BreakRecord? {
        return records.first(where: { (r: BreakRecord) -> Bool in return r.sessionUID == sessionUID && r.end == nil })
    }

    /// Démarre une pause. Une seule pause en cours par session.
    @discardableResult
    func start(sessionUID: UUID, now: Date = Date()) throws -> BreakRecord {
        if runningBreak(for: sessionUID) != nil { throw BreakStoreError.alreadyRunning }
        let record: BreakRecord = BreakRecord(id: UUID(), sessionUID: sessionUID, start: now, end: nil, isManual: false)
        records.append(record)
        persist()
        return record
    }

    /// Termine la pause en cours (jamais avant son début).
    @discardableResult
    func stop(sessionUID: UUID, now: Date = Date()) throws -> BreakRecord {
        guard let index = records.firstIndex(where: { (r: BreakRecord) -> Bool in
            return r.sessionUID == sessionUID && r.end == nil
        }) else { throw BreakStoreError.notRunning }
        records[index].end = max(now, records[index].start)
        persist()
        return records[index]
    }

    /// Ajoute une pause à la main.
    @discardableResult
    func addManual(sessionUID: UUID, start: Date, end: Date) throws -> BreakRecord {
        if end <= start { throw BreakStoreError.invalidInterval }
        let record: BreakRecord = BreakRecord(id: UUID(), sessionUID: sessionUID, start: start, end: end, isManual: true)
        records.append(record)
        persist()
        return record
    }

    @discardableResult
    func delete(id: UUID) -> BreakRecord? {
        guard let index = records.firstIndex(where: { (r: BreakRecord) -> Bool in return r.id == id }) else { return nil }
        let removed: BreakRecord = records.remove(at: index)
        persist()
        return removed
    }

    /// Remet une pause telle quelle (annulation).
    func restore(_ record: BreakRecord) {
        if let index = records.firstIndex(where: { (r: BreakRecord) -> Bool in return r.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        persist()
    }

    /// Supprime les pauses d'une session supprimée.
    func deleteAll(sessionUID: UUID) {
        records.removeAll(where: { (r: BreakRecord) -> Bool in return r.sessionUID == sessionUID })
        persist()
    }

    private func persist() {
        file.save(records)
    }
}
