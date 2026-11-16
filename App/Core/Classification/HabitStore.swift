import Foundation

/// Garde le `HabitModel` sur l'appareil (UserDefaults, JSON). Aucun nouveau modèle SwiftData.
/// 100% local : rien ne quitte l'appareil.
final class HabitStore {

    static let defaultsKey: String = "plt.habits.model"
    static let shared: HabitStore = HabitStore()

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = UserDefaults.standard, key: String = "plt.habits.model") {
        self.defaults = defaults
        self.key = key
    }

    /// Le modèle courant. Un contenu illisible donne un modèle vide (on n'invente rien).
    var model: HabitModel {
        guard let data = defaults.data(forKey: key) else { return HabitModel() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(HabitModel.self, from: data) {
            return decoded
        }
        return HabitModel()
    }

    private func save(_ model: HabitModel) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(model) {
            defaults.set(data, forKey: key)
        }
    }

    /// Enregistre une confirmation ou une correction (voir `HabitModel.record`).
    func record(sessionKey: String,
                placeKey: String,
                visitStart: Date,
                isWork: Bool,
                now: Date = Date(),
                calendar: Calendar = Calendar.current) {
        var current: HabitModel = model
        current.record(sessionKey: sessionKey, placeKey: placeKey, visitStart: visitStart,
                       isWork: isWork, now: now, calendar: calendar)
        save(current)
    }

    /// Efface tout ce qui a été appris.
    func reset() {
        defaults.removeObject(forKey: key)
    }

    /// Les réponses brutes, en valeurs simples.
    func exportedObservations() -> [HabitObservation] {
        return model.exportedValues
    }
}
