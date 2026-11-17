import Foundation
import Observation

/// Modules actifs, persistés dans UserDefaults. À injecter avec `.environment(moduleStore)`
/// et à lire avec `@Environment(ModuleStore.self)`.
@Observable
final class ModuleStore {
    static let defaultsKey: String = "plt.modules.enabled"

    @ObservationIgnored private let defaults: UserDefaults

    /// Identifiants activés par l'utilisateur (noyau toujours inclus). Passe par `setEnabled` pour respecter les dépendances.
    private(set) var enabledIDs: Set<String> = []

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: ModuleStore.defaultsKey) as? [String] {
            let known = Set(ModuleRegistry.all.map { $0.id })
            let kept = Set(stored).intersection(known)
            self.enabledIDs = kept.union(ModuleRegistry.mandatoryIDs)
        } else {
            self.enabledIDs = ModuleRegistry.defaultEnabledIDs
        }
    }

    /// Activé dans les réglages (même si le module n'est pas encore livré).
    func isEnabled(_ id: String) -> Bool {
        return enabledIDs.contains(id)
    }

    /// Utilisable maintenant : activé ET livré. C'est ce test que les écrans utilisent pour montrer ou cacher un module.
    func isActive(_ id: String) -> Bool {
        guard let def = ModuleRegistry.definition(for: id) else { return false }
        return def.isAvailable && enabledIDs.contains(id)
    }

    /// Active ou désactive un module en appliquant les dépendances (active les exigences, désactive les dépendants).
    /// Le noyau ne change jamais. Pour prévenir l'utilisateur avant, utilise ModuleRules.missingRequirements / activeDependents.
    func setEnabled(_ id: String, _ on: Bool) {
        let next: Set<String> = on
            ? ModuleRules.enabling(id, in: enabledIDs)
            : ModuleRules.disabling(id, in: enabledIDs)
        apply(next)
    }

    /// Remet les valeurs par défaut du registre.
    func resetToDefaults() {
        apply(ModuleRegistry.defaultEnabledIDs)
    }

    private func apply(_ ids: Set<String>) {
        enabledIDs = ids.union(ModuleRegistry.mandatoryIDs)
        defaults.set(enabledIDs.sorted(), forKey: ModuleStore.defaultsKey)
    }
}
