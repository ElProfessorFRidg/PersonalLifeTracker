import Foundation
import SwiftData

/// Point d'entrée unique pour créer le ModelContainer (app et tests).
enum AppModelContainer {
    static let schema: Schema = Schema([Place.self, WorkSession.self, DetectionEvent.self, PlaceSample.self, Employer.self, Contract.self, PayRate.self, PlannedShift.self, LeaveEntry.self])

    /// Les tests en mémoire et les tests de migration utilisent le même schéma que l'app.
    static func make(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let configuration = storeURL.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
