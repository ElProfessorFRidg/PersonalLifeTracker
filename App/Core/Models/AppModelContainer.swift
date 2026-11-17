import Foundation
import SwiftData

/// Point d'entrée unique pour créer le ModelContainer (app et tests).
enum AppModelContainer {
    static let schema: Schema = Schema([Place.self, WorkSession.self, DetectionEvent.self, PlaceSample.self, Employer.self, Contract.self, PayRate.self, PlannedShift.self, LeaveEntry.self])

    /// `inMemory: true` pour les tests et les aperçus : rien n'est écrit sur disque.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Pour l'app : base sur disque, sinon base en mémoire (l'app s'ouvre quand même, `usedFallback` vaut vrai).
    static func makeForApp() -> (container: ModelContainer, usedFallback: Bool) {
        do {
            return (try make(inMemory: false), false)
        } catch {
            do {
                return (try make(inMemory: true), true)
            } catch {
                fatalError("Impossible de créer la base de données : \(error)")
            }
        }
    }
}
