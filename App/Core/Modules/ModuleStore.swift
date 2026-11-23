import Foundation
import Observation

/// Modules actifs, persistés dans UserDefaults. À injecter avec `.environment(moduleStore)`
/// et à lire avec `@Environment(ModuleStore.self)`.
@Observable
final class ModuleStore {
    static let defaultsKey: String = "plt.modules.enabled"
    /// Identifiants du registre connus lors de la dernière sauvegarde : sert à repérer les modules arrivés depuis (mise à jour de l'app).
    static let seenKey: String = "plt.modules.seen"

    @ObservationIgnored private let defaults: UserDefaults

    /// Identifiants activés par l'utilisateur (noyau toujours inclus). Passe par `setEnabled` pour respecter les dépendances.
    private(set) var enabledIDs: Set<String> = []

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: ModuleStore.defaultsKey) as? [String] {
            let known = Set(ModuleRegistry.all.map { $0.id })
            let seen: Set<String>? = (defaults.array(forKey: ModuleStore.seenKey) as? [String]).map { Set($0) }
            let kept = Set(stored).intersection(known)
            // Un module arrivé depuis la dernière sauvegarde et coché par défaut est activé tout seul (avec ses dépendances),
            // sinon une mise à jour ne montrerait jamais ses nouvelles fonctions. Ce que l'utilisateur a décoché reste décoché
            // quand la liste des modules connus existe. Sans elle (versions avant ce correctif), on ne peut pas distinguer un
            // choix d'un oubli : on active les modules livrés des étapes 5 et plus, cochés par défaut, qui manquent.
            let newcomers: Set<String>
            if let seen = seen {
                newcomers = ModuleRegistry.all.filter { $0.defaultOn && !seen.contains($0.id) }.reduce(into: Set<String>()) { $0.insert($1.id) }
            } else {
                newcomers = ModuleRegistry.all.filter { $0.defaultOn && $0.isAvailable && !kept.contains($0.id) && $0.step >= 5 }.reduce(into: Set<String>()) { $0.insert($1.id) }
            }
            var merged: Set<String> = kept.union(ModuleRegistry.mandatoryIDs)
            for id in newcomers.sorted() { merged = ModuleRules.enabling(id, in: merged) }
            self.enabledIDs = merged
            defaults.set(enabledIDs.sorted(), forKey: ModuleStore.defaultsKey)
            defaults.set(known.sorted(), forKey: ModuleStore.seenKey)
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
        defaults.set(ModuleRegistry.all.map { $0.id }.sorted(), forKey: ModuleStore.seenKey)
    }
}
