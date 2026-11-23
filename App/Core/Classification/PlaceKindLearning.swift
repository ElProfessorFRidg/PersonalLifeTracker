import Foundation

/// Une réponse de l'utilisateur sur le type d'un lieu, gardée pour ne pas refaire la même erreur.
/// Valeurs simples, aucun modèle SwiftData : tout tient dans un JSON local (UserDefaults).
struct PlaceKindLesson: Codable, Equatable {
    /// Clé de remplacement : une même session, un même lieu ou une même suggestion ne compte qu'une fois (la dernière réponse gagne).
    let key: String
    let latitude: Double
    let longitude: Double
    /// Type choisi par l'utilisateur (`PlaceType.rawValue`). nil = suggestion refusée sans choisir de type.
    let chosen: String?
    /// Type que l'app proposait (`PlaceType.rawValue`), nil si elle ne proposait rien.
    let suggested: String?
    /// Empreinte des horaires (`PlaceVisitPattern.key`), pour généraliser à un autre lieu aux horaires pareils.
    let patternKey: String?
    let date: Date
}

/// Mémoire des corrections de type et des fusions. Pur, Foundation seulement.
struct PlaceKindMemory: Codable, Equatable {
    static let maxLessons: Int = 200
    static let maxMergeGaps: Int = 20
    /// Les leçons de plus de 365 jours ne comptent plus : MON CHOIX.
    static let windowDays: Int = 365

    var lessons: [PlaceKindLesson] = []
    /// Écarts (m) entre des lieux que l'utilisateur a fusionnés à la main.
    var mergeGaps: [Double] = []

    init() {}

    /// Remplace la leçon de même clé, puis garde les plus récentes.
    mutating func record(_ lesson: PlaceKindLesson, now: Date) {
        lessons.removeAll { (existing: PlaceKindLesson) -> Bool in
            return existing.key == lesson.key
        }
        lessons.append(lesson)
        prune(now: now)
    }

    mutating func prune(now: Date) {
        let cutoff: Date = now.addingTimeInterval(-TimeInterval(PlaceKindMemory.windowDays) * 86400)
        lessons.removeAll { (existing: PlaceKindLesson) -> Bool in
            return existing.date < cutoff
        }
        if lessons.count > PlaceKindMemory.maxLessons {
            lessons.removeFirst(lessons.count - PlaceKindMemory.maxLessons)
        }
    }

    mutating func recordMerge(gap: Double) {
        if !gap.isFinite || gap <= 0 { return }
        mergeGaps.append(gap)
        if mergeGaps.count > PlaceKindMemory.maxMergeGaps {
            mergeGaps.removeFirst(mergeGaps.count - PlaceKindMemory.maxMergeGaps)
        }
    }

    /// Distance de fusion apprise : le plus grand écart que l'utilisateur a lui-même fusionné, plus 20 m.
    /// nil tant qu'il n'a rien fusionné. Le plafond (250 m) est appliqué par `PlaceSuggestionMerge.mergeDistance`.
    var learnedMergeDistance: Double? {
        guard let largest = mergeGaps.max() else { return nil }
        return largest + 20
    }

    mutating func reset() {
        lessons = []
        mergeGaps = []
    }
}

/// Persistance de `PlaceKindMemory` (UserDefaults, JSON). 100 % local.
final class PlaceKindStore {

    static let defaultsKey: String = "plt.placekind.memory"
    static let shared: PlaceKindStore = PlaceKindStore()

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = UserDefaults.standard, key: String = "plt.placekind.memory") {
        self.defaults = defaults
        self.key = key
    }

    /// Un contenu illisible donne une mémoire vide : on n'invente rien.
    var memory: PlaceKindMemory {
        guard let data = defaults.data(forKey: key) else { return PlaceKindMemory() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(PlaceKindMemory.self, from: data) {
            return decoded
        }
        return PlaceKindMemory()
    }

    private func save(_ memory: PlaceKindMemory) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(memory) {
            defaults.set(data, forKey: key)
        }
    }

    /// L'utilisateur a choisi `chosen` pour ce lieu (suggestion confirmée, type modifié, session corrigée).
    func recordChoice(key lessonKey: String, latitude: Double, longitude: Double,
                      chosen: PlaceType, suggested: PlaceType?, patternKey: String?, now: Date = Date()) {
        if !PlaceRules.isValidCoordinate(latitude: latitude, longitude: longitude) { return }
        if latitude == 0 && longitude == 0 { return }
        var current: PlaceKindMemory = memory
        let lesson: PlaceKindLesson = PlaceKindLesson(key: lessonKey, latitude: latitude, longitude: longitude,
                                                      chosen: chosen.rawValue, suggested: suggested?.rawValue,
                                                      patternKey: patternKey, date: now)
        current.record(lesson, now: now)
        save(current)
    }

    /// L'utilisateur a refusé une suggestion sans choisir de type.
    func recordRefusal(key lessonKey: String, latitude: Double, longitude: Double,
                       suggested: PlaceType?, patternKey: String?, now: Date = Date()) {
        if !PlaceRules.isValidCoordinate(latitude: latitude, longitude: longitude) { return }
        guard suggested != nil else { return }
        var current: PlaceKindMemory = memory
        let lesson: PlaceKindLesson = PlaceKindLesson(key: lessonKey, latitude: latitude, longitude: longitude,
                                                      chosen: nil, suggested: suggested?.rawValue,
                                                      patternKey: patternKey, date: now)
        current.record(lesson, now: now)
        save(current)
    }

    /// L'utilisateur a fusionné des lieux séparés de `gap` mètres.
    func recordMerge(gap: Double) {
        var current: PlaceKindMemory = memory
        current.recordMerge(gap: gap)
        save(current)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
