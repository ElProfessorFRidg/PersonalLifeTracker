import Foundation

/// Réglages du module contract_hours, par employeur, dans UserDefaults (pas de modèle SwiftData).
/// Clés : plt.contracthours.<réglage>.<uid de l'employeur>.
enum ContratHeuresSettings {

    private static func key(_ name: String, _ uid: UUID) -> String {
        return "plt.contracthours.\(name).\(uid.uuidString)"
    }

    // MARK: Ce qui se passe réellement (106.4)

    static func rule(for uid: UUID, defaults: UserDefaults = UserDefaults.standard) -> HoursCarryRule {
        guard let raw = defaults.string(forKey: key("rule", uid)),
              let rule = HoursCarryRule(rawValue: raw) else {
            return .unknown
        }
        return rule
    }

    static func setRule(_ rule: HoursCarryRule, for uid: UUID, defaults: UserDefaults = UserDefaults.standard) {
        defaults.set(rule.rawValue, forKey: key("rule", uid))
    }

    // MARK: Alerte de proximité du quota (109), éteinte par défaut

    static func alertEnabled(for uid: UUID, defaults: UserDefaults = UserDefaults.standard) -> Bool {
        return defaults.bool(forKey: key("alert.enabled", uid))
    }

    static func setAlertEnabled(_ on: Bool, for uid: UUID, defaults: UserDefaults = UserDefaults.standard) {
        defaults.set(on, forKey: key("alert.enabled", uid))
    }

    /// Seuils en minutes restantes : 120 (2 h), 60 (1 h), 0 (quota atteint). Par défaut seul 2 h est coché.
    static let thresholdChoices: [Int] = [120, 60, 0]

    static func isThresholdOn(_ minutes: Int, for uid: UUID, defaults: UserDefaults = UserDefaults.standard) -> Bool {
        let k: String = key("alert.t\(minutes)", uid)
        if defaults.object(forKey: k) == nil {
            return minutes == 120
        }
        return defaults.bool(forKey: k)
    }

    static func setThreshold(_ minutes: Int, on: Bool, for uid: UUID, defaults: UserDefaults = UserDefaults.standard) {
        defaults.set(on, forKey: key("alert.t\(minutes)", uid))
    }

    /// Seuils actifs, vide si l'alerte est éteinte.
    static func activeThresholds(for uid: UUID, defaults: UserDefaults = UserDefaults.standard) -> [Int] {
        if !alertEnabled(for: uid, defaults: defaults) { return [] }
        return thresholdChoices.filter { (m: Int) -> Bool in
            return isThresholdOn(m, for: uid, defaults: defaults)
        }
    }
}
