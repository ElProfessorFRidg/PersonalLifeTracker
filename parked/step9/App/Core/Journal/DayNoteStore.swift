import Foundation
import Observation

/// Notes de journée (section 39), gardées dans `day_notes.json`.
/// Pas d'isolation d'acteur : à utiliser depuis le thread principal (vues et actions).
@Observable
final class DayNoteStore {
    static let shared: DayNoteStore = DayNoteStore()

    private(set) var notes: [DayNote] = []
    @ObservationIgnored private let file: JSONFileStore<[DayNote]>

    init(file: JSONFileStore<[DayNote]> = JSONFileStore<[DayNote]>(fileName: "day_notes.json")) {
        self.file = file
        self.notes = file.load(defaultValue: [])
    }

    func note(id: UUID) -> DayNote? {
        return notes.first(where: { (n: DayNote) -> Bool in return n.id == id })
    }

    /// Ajoute une note. Renvoie nil si le texte est vide.
    @discardableResult
    func add(day: Date, text: String, tags: [String], sessionUID: UUID?, calendar: Calendar, now: Date = Date()) -> DayNote? {
        if !DayNotesRules.isValid(text: text) { return nil }
        let note: DayNote = DayNote(id: UUID(),
                                    day: calendar.startOfDay(for: day),
                                    text: DayNotesRules.normalizedText(text),
                                    tags: tags,
                                    sessionUID: sessionUID,
                                    createdAt: now,
                                    updatedAt: now)
        notes.append(note)
        persist()
        return note
    }

    /// Modifie une note existante. Renvoie l'ancienne version (pour l'annulation), nil si introuvable ou texte vide.
    @discardableResult
    func update(id: UUID, day: Date, text: String, tags: [String], sessionUID: UUID?, calendar: Calendar, now: Date = Date()) -> DayNote? {
        if !DayNotesRules.isValid(text: text) { return nil }
        guard let index = notes.firstIndex(where: { (n: DayNote) -> Bool in return n.id == id }) else { return nil }
        let old: DayNote = notes[index]
        var changed: DayNote = old
        changed.day = calendar.startOfDay(for: day)
        changed.text = DayNotesRules.normalizedText(text)
        changed.tags = tags
        changed.sessionUID = sessionUID
        changed.updatedAt = now
        notes[index] = changed
        persist()
        return old
    }

    /// Supprime une note. Renvoie la note supprimée (pour l'annulation).
    @discardableResult
    func delete(id: UUID) -> DayNote? {
        guard let index = notes.firstIndex(where: { (n: DayNote) -> Bool in return n.id == id }) else { return nil }
        let removed: DayNote = notes.remove(at: index)
        persist()
        return removed
    }

    /// Remet une note telle quelle (annulation d'une suppression ou d'une modification).
    func restore(_ note: DayNote) {
        if let index = notes.firstIndex(where: { (n: DayNote) -> Bool in return n.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        persist()
    }

    private func persist() {
        file.save(notes)
    }
}
