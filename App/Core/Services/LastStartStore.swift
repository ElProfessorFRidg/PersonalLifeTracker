import Foundation

/// Mémoire du dernier démarrage manuel (activité et lieu), dans UserDefaults. Foundation seulement.
/// Sert à présélectionner la feuille Démarrer, à la ligne "Comme la dernière fois" et aux raccourcis Siri.
struct LastStartStore {
    static let activityKey: String = "plt.lastStart.activity"
    static let placeKey: String = "plt.lastStart.placeUID"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// Dernière activité démarrée, nil si aucune ou valeur illisible.
    var activity: ActivityType? {
        guard let raw = defaults.string(forKey: LastStartStore.activityKey) else { return nil }
        return ActivityType(rawValue: raw)
    }

    /// Dernier lieu choisi, nil si aucun ou valeur illisible.
    var placeUID: UUID? {
        guard let text = defaults.string(forKey: LastStartStore.placeKey) else { return nil }
        return UUID(uuidString: text)
    }

    /// Retient l'activité et le lieu (nil efface le lieu).
    func remember(activity: ActivityType, placeUID: UUID?) {
        defaults.set(activity.rawValue, forKey: LastStartStore.activityKey)
        if let uid = placeUID {
            defaults.set(uid.uuidString, forKey: LastStartStore.placeKey)
        } else {
            defaults.removeObject(forKey: LastStartStore.placeKey)
        }
    }

    func clear() {
        defaults.removeObject(forKey: LastStartStore.activityKey)
        defaults.removeObject(forKey: LastStartStore.placeKey)
    }

    /// "Comme la dernière fois : Taf, Supérette du Canal" ou "Comme la dernière fois : Taf".
    static func rowTitle(activity: ActivityType, placeName: String?) -> String {
        if let name = placeName, !name.isEmpty {
            return "Comme la dernière fois : \(activity.title), \(name)"
        }
        return "Comme la dernière fois : \(activity.title)"
    }
}
