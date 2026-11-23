import Foundation

/// Une note de journée (section 39) : une phrase libre par jour, des tags facultatifs,
/// rattachée au jour et, au choix, à une session. Codable : stockée dans un fichier JSON, pas dans SwiftData.
struct DayNote: Codable, Identifiable, Equatable {
    var id: UUID
    /// Début du jour (dans le calendrier de l'utilisateur au moment de l'écriture).
    var day: Date
    var text: String
    var tags: [String]
    /// `WorkSession.uid` si la note est liée à une session précise.
    var sessionUID: UUID?
    var createdAt: Date
    var updatedAt: Date
}

/// Les notes d'un même jour.
struct DayNoteGroup: Equatable {
    let day: Date
    let notes: [DayNote]
}

/// Règles pures des notes de journée (Foundation seulement).
enum DayNotesRules {

    /// Longueur maximale d'une note. Origine : mon choix (la spec parle d'une phrase libre, sans limite chiffrée).
    static let maxTextLength: Int = 500
    /// Nombre maximal de tags par note. Origine : mon choix.
    static let maxTags: Int = 8
    /// Longueur maximale d'un tag. Origine : mon choix.
    static let maxTagLength: Int = 24

    /// Texte nettoyé : espaces de début et de fin retirés, coupé à `maxTextLength`.
    static func normalizedText(_ raw: String) -> String {
        let trimmed: String = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.count > maxTextLength {
            return String(trimmed.prefix(maxTextLength))
        }
        return trimmed
    }

    /// Une note vide n'est pas enregistrée.
    static func isValid(text: String) -> Bool {
        return !normalizedText(text).isEmpty
    }

    /// Tags saisis à la main, séparés par des virgules, points-virgules ou retours à la ligne.
    /// Le "#" de début est retiré, les doublons (sans tenir compte de la casse) et les tags vides sont écartés.
    static func parseTags(_ raw: String) -> [String] {
        let separators: CharacterSet = CharacterSet(charactersIn: ",;\n")
        let parts: [String] = raw.components(separatedBy: separators)
        var result: [String] = []
        var seen: Set<String> = []
        for part in parts {
            var tag: String = part.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            while tag.hasPrefix("#") {
                tag = String(tag.dropFirst())
            }
            tag = tag.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if tag.isEmpty { continue }
            if tag.count > maxTagLength {
                tag = String(tag.prefix(maxTagLength))
            }
            let key: String = tag.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(tag)
            if result.count >= maxTags { break }
        }
        return result
    }

    /// Tags en une ligne pour le champ de saisie : "rush, client relou".
    static func tagsText(_ tags: [String]) -> String {
        return tags.joined(separator: ", ")
    }

    /// Notes d'un jour (comparaison par jour calendaire du calendrier donné), les plus anciennes d'abord.
    static func notes(on day: Date, in notes: [DayNote], calendar: Calendar) -> [DayNote] {
        let matching: [DayNote] = notes.filter { (n: DayNote) -> Bool in
            return calendar.isDate(n.day, inSameDayAs: day)
        }
        return sortedWithinDay(matching)
    }

    /// Recherche par texte ou par tag, sans tenir compte de la casse ni des accents.
    /// Plusieurs mots : chacun doit se trouver dans le texte ou dans un tag. Une recherche vide renvoie tout.
    static func search(_ notes: [DayNote], query: String) -> [DayNote] {
        let words: [String] = query
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map { (w: String) -> String in
                var word: String = w
                while word.hasPrefix("#") { word = String(word.dropFirst()) }
                return word
            }
            .filter { (w: String) -> Bool in return !w.isEmpty }
        if words.isEmpty { return notes }
        return notes.filter { (n: DayNote) -> Bool in
            for word in words {
                if !contains(n.text, word) && !n.tags.contains(where: { (t: String) -> Bool in return contains(t, word) }) {
                    return false
                }
            }
            return true
        }
    }

    /// Notes regroupées par jour, jour le plus récent d'abord.
    static func groupedByDay(_ notes: [DayNote], calendar: Calendar) -> [DayNoteGroup] {
        var buckets: [Date: [DayNote]] = [:]
        for n in notes {
            let key: Date = calendar.startOfDay(for: n.day)
            var list: [DayNote] = buckets[key] ?? []
            list.append(n)
            buckets[key] = list
        }
        let days: [Date] = buckets.keys.sorted { (a: Date, b: Date) -> Bool in return a > b }
        return days.map { (d: Date) -> DayNoteGroup in
            return DayNoteGroup(day: d, notes: sortedWithinDay(buckets[d] ?? []))
        }
    }

    private static func sortedWithinDay(_ list: [DayNote]) -> [DayNote] {
        return list.sorted { (a: DayNote, b: DayNote) -> Bool in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
