import Foundation

/// Un instantané connu, vu uniquement par son nom de fichier et sa date de création.
struct SnapshotEntry: Equatable {
    let fileName: String
    let createdAt: Date
}

/// Règles pures des instantanés quotidiens (section 128). Foundation seulement.
enum SnapshotPlan {
    /// Conservation par défaut : 14 jours (section 128).
    static let defaultRetentionDays: Int = 14
    /// Plafond de sécurité du nombre de fichiers (instantanés manuels et de restauration compris).
    static let defaultMaxCount: Int = 30

    /// Un instantané est dû si aucun n'existe pour le jour calendaire de `now` (dans le calendrier donné).
    static func isDue(lastSnapshot: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let last = lastSnapshot else { return true }
        return !calendar.isDate(last, inSameDayAs: now)
    }

    /// Nombre de jours calendaires entre la date de l'instantané et `now` (0 = aujourd'hui).
    static func ageInDays(of date: Date, now: Date, calendar: Calendar) -> Int {
        let from: Date = calendar.startOfDay(for: date)
        let to: Date = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Instantanés à supprimer, du plus ancien au plus récent.
    /// 1) ceux dont l'âge est supérieur ou égal à `retentionDays` jours ;
    /// 2) puis, s'il en reste plus que `maxCount`, les plus anciens en trop.
    /// Le plus récent n'est jamais supprimé, même s'il est très vieux.
    static func entriesToPrune(_ entries: [SnapshotEntry],
                               now: Date,
                               retentionDays: Int,
                               maxCount: Int,
                               calendar: Calendar) -> [SnapshotEntry] {
        if entries.isEmpty { return [] }
        let ascending: [SnapshotEntry] = entries.sorted { (a: SnapshotEntry, b: SnapshotEntry) -> Bool in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.fileName < b.fileName
        }
        let newest: SnapshotEntry = ascending[ascending.count - 1]
        var pruned: [SnapshotEntry] = []
        var kept: [SnapshotEntry] = []
        for entry in ascending {
            let age: Int = ageInDays(of: entry.createdAt, now: now, calendar: calendar)
            if entry != newest && age >= retentionDays {
                pruned.append(entry)
            } else {
                kept.append(entry)
            }
        }
        let limit: Int = max(1, maxCount)
        if kept.count > limit {
            let excess: Int = kept.count - limit
            for entry in kept.prefix(excess) {
                pruned.append(entry)
            }
        }
        return pruned
    }
}

/// Textes de comptage en français, purs.
enum SnapshotFormat {
    static func places(_ count: Int) -> String {
        return count > 1 ? "\(count) lieux" : "\(count) lieu"
    }

    static func sessions(_ count: Int) -> String {
        return count > 1 ? "\(count) sessions" : "\(count) session"
    }

    static func summary(places: Int, sessions: Int) -> String {
        return "\(Self.places(places)), \(Self.sessions(sessions))"
    }
}
