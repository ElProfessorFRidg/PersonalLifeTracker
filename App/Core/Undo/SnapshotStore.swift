import Foundation

/// Un instantané enregistré sur disque.
struct SnapshotInfo: Equatable, Identifiable {
    let fileName: String
    let createdAt: Date
    let placeCount: Int
    let sessionCount: Int
    let byteSize: Int

    var id: String { return fileName }
}

/// Fichiers JSON d'instantanés dans un dossier (Application Support/Snapshots pour l'app, dossier temporaire en test).
/// Le contenu est un `ExportDocument` (même format que l'export), donc relisible par l'import futur.
struct SnapshotStore {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func defaultDirectory() -> URL {
        let base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Snapshots", isDirectory: true)
    }

    private static let filePrefix: String = "snapshot-"
    private static let fileExtension: String = "json"

    private func ensureDirectory() throws {
        var url: URL = directory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        // Pas d'iCloud ni de sauvegarde automatique sauf choix (section 128).
        var values: URLResourceValues = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func fileURL(_ fileName: String) -> URL {
        // lastPathComponent : jamais de sortie du dossier.
        return directory.appendingPathComponent((fileName as NSString).lastPathComponent)
    }

    /// Écrit un instantané. Le nom contient la date en secondes et un suffixe aléatoire (pas de collision).
    @discardableResult
    func write(_ document: ExportDocument) throws -> SnapshotInfo {
        try ensureDirectory()
        let data: Data = try DataExport.encode(document)
        let seconds: Int = Int(document.exportedAt.timeIntervalSince1970)
        let suffix: String = String(UUID().uuidString.prefix(6))
        let fileName: String = "\(SnapshotStore.filePrefix)\(seconds)-\(suffix).\(SnapshotStore.fileExtension)"
        try data.write(to: fileURL(fileName), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return SnapshotInfo(fileName: fileName, createdAt: document.exportedAt,
                            placeCount: document.places.count, sessionCount: document.sessions.count,
                            byteSize: data.count)
    }

    /// Liste du plus récent au plus ancien. Les fichiers illisibles sont ignorés.
    func list() -> [SnapshotInfo] {
        let urls: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                         includingPropertiesForKeys: nil,
                                                                         options: [.skipsHiddenFiles])) ?? []
        var result: [SnapshotInfo] = []
        for url in urls {
            let name: String = url.lastPathComponent
            if !name.hasPrefix(SnapshotStore.filePrefix) || url.pathExtension != SnapshotStore.fileExtension { continue }
            guard let data = try? Data(contentsOf: url), let document = try? DataExport.decode(data) else { continue }
            result.append(SnapshotInfo(fileName: name, createdAt: document.exportedAt,
                                       placeCount: document.places.count, sessionCount: document.sessions.count,
                                       byteSize: data.count))
        }
        result.sort { (a: SnapshotInfo, b: SnapshotInfo) -> Bool in
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.fileName > b.fileName
        }
        return result
    }

    func load(fileName: String) throws -> ExportDocument {
        let data: Data = try Data(contentsOf: fileURL(fileName))
        return try DataExport.decode(data)
    }

    func delete(fileName: String) throws {
        try FileManager.default.removeItem(at: fileURL(fileName))
    }

    func totalBytes() -> Int {
        var total: Int = 0
        for info in list() { total += info.byteSize }
        return total
    }

    /// Supprime ce que `SnapshotPlan` désigne. Renvoie le nombre de fichiers supprimés.
    @discardableResult
    func prune(now: Date,
               retentionDays: Int = SnapshotPlan.defaultRetentionDays,
               maxCount: Int = SnapshotPlan.defaultMaxCount,
               calendar: Calendar) -> Int {
        let entries: [SnapshotEntry] = list().map { (info: SnapshotInfo) -> SnapshotEntry in
            return SnapshotEntry(fileName: info.fileName, createdAt: info.createdAt)
        }
        let doomed: [SnapshotEntry] = SnapshotPlan.entriesToPrune(entries, now: now, retentionDays: retentionDays,
                                                                  maxCount: maxCount, calendar: calendar)
        var removed: Int = 0
        for entry in doomed {
            if (try? delete(fileName: entry.fileName)) != nil { removed += 1 }
        }
        return removed
    }
}
