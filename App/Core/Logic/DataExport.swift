import Foundation

/// Export JSON des lieux et des sessions. Pur : des structures Codable construites à partir de valeurs simples,
/// sans SwiftData. Dates en ISO 8601 (UTC, à la seconde). Le passage des modèles vers ces structures est dans la vue.
struct ExportedPlace: Codable, Equatable {
    var uid: String
    var name: String
    var type: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var address: String
    var alsoWorksHere: Bool
    var createdAt: Date
}

struct ExportedSession: Codable, Equatable {
    var uid: String
    var activity: String
    var start: Date
    /// Nil : session en cours au moment de l'export.
    var end: Date?
    var chosenStart: Date?
    var chosenEnd: Date?
    var source: String
    var isConfirmed: Bool
    var note: String
    var timeZoneID: String
    var createdAt: Date
    /// Identifiant du lieu (champ uid des lieux exportés), nil si la session n'a pas de lieu.
    var placeUID: String?
}

struct ExportDocument: Codable, Equatable {
    var app: String
    var formatVersion: Int
    var exportedAt: Date
    var places: [ExportedPlace]
    var sessions: [ExportedSession]
}

enum DataExport {
    static let appName: String = "PersonalLifeTracker"
    static let currentFormatVersion: Int = 1
    static let fileName: String = "PersonalLifeTracker-export.json"

    static func makeDocument(places: [ExportedPlace], sessions: [ExportedSession], exportedAt: Date) -> ExportDocument {
        return ExportDocument(app: appName, formatVersion: currentFormatVersion, exportedAt: exportedAt,
                              places: places, sessions: sessions)
    }

    /// JSON lisible, clés triées (sortie stable), dates ISO 8601.
    static func encode(_ document: ExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> ExportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportDocument.self, from: data)
    }

    /// Écrit le JSON dans un fichier temporaire et renvoie son adresse (pour le partage).
    static func writeTemporaryFile(_ document: ExportDocument) throws -> URL {
        let data: Data = try encode(document)
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
