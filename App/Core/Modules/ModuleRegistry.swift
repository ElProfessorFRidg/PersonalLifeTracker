import Foundation

/// Un module de l'app (section 3, source de vérité : spec/MODULES.md).
struct ModuleDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    /// Étape de livraison (section 60).
    let step: Int
    let defaultOn: Bool
    /// Modules obligatoires pour celui-ci ("exige" de MODULES.md).
    let requires: [String]
    /// Faux tant que les écrans du module ne sont pas livrés : affiché "bientôt", non activable.
    let isAvailable: Bool
    /// Vrai pour le noyau : toujours actif, jamais désactivable.
    let isMandatory: Bool

    init(id: String, title: String, summary: String, step: Int, defaultOn: Bool,
         requires: [String], isAvailable: Bool, isMandatory: Bool = false) {
        self.id = id
        self.title = title
        self.summary = summary
        self.step = step
        self.defaultOn = defaultOn
        self.requires = requires
        self.isAvailable = isAvailable
        self.isMandatory = isMandatory
    }
}

/// Registre statique des modules. Les données des modules optionnels sont dans ModuleRegistryData.swift.
enum ModuleRegistry {
    static let coreID: String = "core"

    static let core: ModuleDefinition = ModuleDefinition(
        id: "core",
        title: "Noyau",
        summary: "Lieux, sessions, saisie manuelle, statistiques de base et réglages. Toujours actif.",
        step: 1,
        defaultOn: true,
        requires: [],
        isAvailable: true,
        isMandatory: true
    )

    /// Noyau en premier, puis tous les modules de MODULES.md dans l'ordre du registre.
    static let all: [ModuleDefinition] = [ModuleRegistry.core] + ModuleRegistry.optionalModules

    static func definition(for id: String) -> ModuleDefinition? {
        for m in all where m.id == id { return m }
        return nil
    }

    static var mandatoryIDs: Set<String> {
        var ids: Set<String> = []
        for m in all where m.isMandatory { ids.insert(m.id) }
        return ids
    }

    /// Modules cochés par défaut (noyau compris).
    static var defaultEnabledIDs: Set<String> {
        var ids: Set<String> = []
        for m in all where m.defaultOn || m.isMandatory { ids.insert(m.id) }
        return ids
    }

    static func modules(step: Int) -> [ModuleDefinition] {
        return all.filter { $0.step == step }
    }
}

/// Règles de dépendances, en fonctions pures (section 3.3). Un module "exige" les modules de `requires`.
enum ModuleRules {

    /// Tous les modules exigés, directement ou non (sans l'identifiant lui-même).
    static func requirements(of id: String, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        var byID: [String: ModuleDefinition] = [:]
        for m in registry { byID[m.id] = m }
        var seen: Set<String> = []
        var queue: [String] = byID[id]?.requires ?? []
        while let next = queue.popLast() {
            if next == id || seen.contains(next) { continue }
            guard let def = byID[next] else { continue }
            seen.insert(next)
            queue.append(contentsOf: def.requires)
        }
        return seen
    }

    /// Tous les modules qui exigent celui-ci, directement ou non (sans l'identifiant lui-même).
    static func dependents(of id: String, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        var seen: Set<String> = []
        var queue: [String] = [id]
        while let current = queue.popLast() {
            for m in registry where m.requires.contains(current) {
                if m.id == id || seen.contains(m.id) { continue }
                seen.insert(m.id)
                queue.append(m.id)
            }
        }
        return seen
    }

    /// Modules à activer en plus pour activer `id` (ceux de ses exigences encore éteints).
    static func missingRequirements(for id: String, enabled: Set<String>, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        return requirements(of: id, registry: registry).subtracting(enabled)
    }

    /// Modules actuellement actifs qui seraient désactivés avec `id`.
    static func activeDependents(of id: String, enabled: Set<String>, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        return dependents(of: id, registry: registry).intersection(enabled)
    }

    /// Ensemble des modules actifs après avoir activé `id` : lui, ses exigences et le noyau.
    /// Un identifiant inconnu ne change rien (le noyau reste présent).
    static func enabling(_ id: String, in enabled: Set<String>, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        var result: Set<String> = enabled.union(mandatory(in: registry))
        var known = false
        for m in registry where m.id == id { known = true }
        if !known { return result }
        result.insert(id)
        result.formUnion(requirements(of: id, registry: registry))
        return result
    }

    /// Ensemble des modules actifs après avoir désactivé `id` : lui et ses dépendants sont retirés.
    /// Le noyau (obligatoire) n'est jamais retiré.
    static func disabling(_ id: String, in enabled: Set<String>, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        let mandatoryIDs: Set<String> = mandatory(in: registry)
        if mandatoryIDs.contains(id) { return enabled.union(mandatoryIDs) }
        var result: Set<String> = enabled
        result.remove(id)
        result.subtract(dependents(of: id, registry: registry))
        return result.union(mandatoryIDs)
    }

    private static func mandatory(in registry: [ModuleDefinition]) -> Set<String> {
        var ids: Set<String> = []
        for m in registry where m.isMandatory { ids.insert(m.id) }
        return ids
    }
}
