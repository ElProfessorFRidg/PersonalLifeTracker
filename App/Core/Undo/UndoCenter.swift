import Foundation
import Observation

/// Une action annulable gardée dans l'historique.
struct UndoRecord: Identifiable, Equatable {
    let id: UUID
    let message: String
    let date: Date
    var isUndone: Bool
}

/// Centre d'annulation : un toast "Annuler" pour la dernière action, et l'historique des 20 dernières sur 7 jours.
@MainActor
@Observable
final class UndoCenter {
    struct Toast: Identifiable, Equatable {
        let id: UUID
        let message: String
    }

    static let defaultToastDuration: TimeInterval = 6
    static let historyLimit: Int = 20
    static let historyDays: Int = 7

    private(set) var current: Toast? = nil
    private(set) var history: [UndoRecord] = []
    /// Faux quand le module undo_safety est désactivé : plus rien n'est enregistré.
    var isEnabled: Bool = true

    let toastDuration: TimeInterval

    @ObservationIgnored private var actions: [UUID: () -> Void] = [:]
    @ObservationIgnored private var dismissTask: Task<Void, Never>? = nil
    @ObservationIgnored private let now: () -> Date

    init(toastDuration: TimeInterval = UndoCenter.defaultToastDuration, now: @escaping () -> Date = { return Date() }) {
        self.toastDuration = toastDuration
        self.now = now
    }

    /// Enregistre une action annulable et montre le toast. Un nouveau toast remplace le précédent.
    func register(message: String, undo: @escaping () -> Void) {
        if !isEnabled { return }
        let id: UUID = UUID()
        actions[id] = undo
        history.insert(UndoRecord(id: id, message: message, date: now(), isUndone: false), at: 0)
        trimHistory()
        current = Toast(id: id, message: message)
        scheduleExpiry(for: id)
    }

    /// Bouton "Annuler" du toast.
    func performUndo() {
        guard let toast = current else { return }
        _ = undo(recordID: toast.id)
    }

    /// Annule une entrée de l'historique. Une entrée ne s'annule qu'une fois.
    @discardableResult
    func undo(recordID: UUID) -> Bool {
        guard let action = actions[recordID] else { return false }
        actions[recordID] = nil
        action()
        if let index = history.firstIndex(where: { $0.id == recordID }) {
            history[index].isUndone = true
        }
        if current?.id == recordID {
            dismissTask?.cancel()
            current = nil
        }
        return true
    }

    func dismissToast() {
        dismissTask?.cancel()
        current = nil
    }

    /// Fin du délai : ne ferme que le toast portant cet identifiant (un toast plus récent reste).
    func expire(id: UUID) {
        if current?.id == id { current = nil }
    }

    private func scheduleExpiry(for id: UUID) {
        dismissTask?.cancel()
        let nanoseconds: UInt64 = UInt64(max(0, toastDuration) * 1_000_000_000)
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            if Task.isCancelled { return }
            self?.expire(id: id)
        }
    }

    private func trimHistory() {
        let limitDate: Date = Calendar.current.date(byAdding: .day, value: -UndoCenter.historyDays, to: now()) ?? Date.distantPast
        var kept: [UndoRecord] = history.filter { (r: UndoRecord) -> Bool in return r.date >= limitDate }
        if kept.count > UndoCenter.historyLimit {
            kept = Array(kept.prefix(UndoCenter.historyLimit))
        }
        let keptIDs: Set<UUID> = Set(kept.map { (r: UndoRecord) -> UUID in return r.id })
        for id in Array(actions.keys) where !keptIDs.contains(id) {
            actions[id] = nil
        }
        history = kept
    }
}
