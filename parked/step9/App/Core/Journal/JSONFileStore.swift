import Foundation

/// Petit stockage JSON d'une valeur Codable dans un fichier (Application Support par défaut).
/// Sert aux notes, aux pauses : pas de nouveau modèle SwiftData. 100% local.
struct JSONFileStore<Value: Codable> {
    let url: URL

    init(fileName: String, directory: URL? = nil) {
        let base: URL = directory ?? JSONFileStore.defaultDirectory()
        self.url = base.appendingPathComponent(fileName)
    }

    static func defaultDirectory() -> URL {
        let found: [URL] = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return found.first ?? FileManager.default.temporaryDirectory
    }

    /// Lit le fichier. Fichier absent ou illisible : la valeur par défaut (on n'invente rien).
    func load(defaultValue: Value) -> Value {
        guard let data = try? Data(contentsOf: url) else { return defaultValue }
        if let decoded = try? JSONDecoder().decode(Value.self, from: data) {
            return decoded
        }
        return defaultValue
    }

    /// Écrit le fichier (le dossier est créé au besoin). Renvoie faux en cas d'échec.
    @discardableResult
    func save(_ value: Value) -> Bool {
        do {
            let directory: URL = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let data: Data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
