import Foundation
import SwiftData

enum SessionServiceError: Error, Equatable {
    /// Une session tourne déjà : on n'en démarre pas une deuxième.
    case alreadyRunning
    /// La session est déjà terminée.
    case notRunning
}

/// Démarrage et arrêt manuels d'une session (section 15.2). Prend un ModelContext, donc testable en mémoire.
struct SessionService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Sessions en cours, la plus récente d'abord.
    func runningSessions() throws -> [WorkSession] {
        let all: [WorkSession] = try context.fetch(FetchDescriptor<WorkSession>())
        let running: [WorkSession] = all.filter { $0.endDate == nil }
        return running.sorted { $0.startDate > $1.startDate }
    }

    /// La session en cours, nil s'il n'y en a pas.
    func runningSession() throws -> WorkSession? {
        return try runningSessions().first
    }

    /// Démarre une session manuelle à `now`. Refuse s'il y en a déjà une en cours.
    @discardableResult
    func start(activity: ActivityType, place: Place? = nil, now: Date = Date()) throws -> WorkSession {
        let current: WorkSession? = try runningSession()
        if current != nil {
            throw SessionServiceError.alreadyRunning
        }
        let session = WorkSession(activity: activity, start: now, end: nil, place: place, source: .manual, isConfirmed: true)
        context.insert(session)
        try context.save()
        return session
    }

    /// Arrête la session à `now` (jamais avant son début). Refuse si elle est déjà terminée.
    @discardableResult
    func stop(_ session: WorkSession, now: Date = Date()) throws -> WorkSession {
        if session.endDate != nil {
            throw SessionServiceError.notRunning
        }
        session.endDate = max(now, session.startDate)
        try context.save()
        return session
    }

    /// Arrête la session en cours, nil s'il n'y en a pas.
    @discardableResult
    func stopRunning(now: Date = Date()) throws -> WorkSession? {
        guard let running = try runningSession() else { return nil }
        return try stop(running, now: now)
    }
}
