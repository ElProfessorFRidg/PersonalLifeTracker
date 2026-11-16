import Foundation

/// Les sept étapes de l'onboarding, dans l'ordre (design/SCREENS.md).
enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome = 0
    case modules = 1
    case location = 2
    case notifications = 3
    case photos = 4
    case firstPlace = 5
    case ready = 6
}

/// Préréglages de l'étape "Choix des modules".
enum OnboardingPreset: Equatable {
    case essentiel
    case complet
    case choix
}

/// Niveau d'accès à la localisation, indépendant de CoreLocation (pour rester testable).
enum LocationAccessLevel: Equatable {
    case notDetermined
    /// "Pendant l'utilisation" : limitée, l'app rate les arrivées et départs en arrière-plan.
    case whenInUse
    case always
    case denied
    /// Restreint par le contrôle parental ou un profil : se traite comme un refus.
    case restricted
}

/// Niveau d'accès aux notifications, indépendant de UserNotifications.
enum NotificationAccessLevel: Equatable {
    case notDetermined
    case authorized
    case denied
}

/// Avertissement du récap final.
enum OnboardingWarning: Equatable {
    case locationNotAlways
    case locationDenied
    case notificationsDenied
}

/// Logique pure de l'onboarding : étapes, navigation, progression, préréglages, avertissements.
enum OnboardingFlow {

    /// Identifiant du module dont dépend l'étape Photos.
    static let photosModuleID: String = "planning_ocr"

    /// Modules proposés à l'étape 2 (ceux du prototype), dans l'ordre d'affichage, par groupe.
    static let workModuleIDs: [String] = ["employment", "pay", "contract_hours", "leave", "multi_employer"]
    static let studyModuleIDs: [String] = ["school_calendar", "exam_mode", "study_slots"]
    static let dayModuleIDs: [String] = ["planning_ocr", "missing_hours", "now_card", "notes", "recaps",
                                         "weekly_review", "live_activity_widgets", "travel_departure"]

    static var offeredModuleIDs: [String] {
        return workModuleIDs + studyModuleIDs + dayModuleIDs
    }

    // MARK: Étapes

    /// Étapes affichées : l'étape Photos disparaît si le module planning_ocr est éteint.
    static func steps(enabledModules: Set<String>) -> [OnboardingStep] {
        var result: [OnboardingStep] = []
        for step in OnboardingStep.allCases {
            if step == .photos && !enabledModules.contains(photosModuleID) { continue }
            result.append(step)
        }
        return result
    }

    static func next(after step: OnboardingStep, enabledModules: Set<String>) -> OnboardingStep? {
        let list = steps(enabledModules: enabledModules)
        guard let index = list.firstIndex(of: step) else {
            // Étape absente de la liste (Photos sautée) : la première étape suivante affichée.
            for candidate in list where candidate.rawValue > step.rawValue { return candidate }
            return nil
        }
        if index + 1 < list.count { return list[index + 1] }
        return nil
    }

    static func previous(before step: OnboardingStep, enabledModules: Set<String>) -> OnboardingStep? {
        let list = steps(enabledModules: enabledModules)
        guard let index = list.firstIndex(of: step) else {
            for candidate in list.reversed() where candidate.rawValue < step.rawValue { return candidate }
            return nil
        }
        if index > 0 { return list[index - 1] }
        return nil
    }

    /// Numéro de l'étape (à partir de 1) et nombre d'étapes affichées. Nil si l'étape n'est pas affichée.
    static func position(of step: OnboardingStep, enabledModules: Set<String>) -> (number: Int, total: Int)? {
        let list = steps(enabledModules: enabledModules)
        guard let index = list.firstIndex(of: step) else { return nil }
        return (index + 1, list.count)
    }

    /// Fraction de la barre de progression : numéro d'étape divisé par le nombre d'étapes (0 si l'étape n'existe pas).
    static func progress(of step: OnboardingStep, enabledModules: Set<String>) -> Double {
        guard let p = position(of: step, enabledModules: enabledModules) else { return 0 }
        return Double(p.number) / Double(p.total)
    }

    // MARK: Préréglages

    /// Modules actifs pour un préréglage. `.choix` renvoie les valeurs par défaut du registre.
    /// Essentiel : les valeurs par défaut sans les modules proposés à l'étape 2, ni ceux qui en dépendent.
    /// Complet : tout le registre.
    static func presetIDs(_ preset: OnboardingPreset, registry: [ModuleDefinition] = ModuleRegistry.all) -> Set<String> {
        var mandatory: Set<String> = []
        var defaults: Set<String> = []
        var everything: Set<String> = []
        for m in registry {
            everything.insert(m.id)
            if m.isMandatory { mandatory.insert(m.id) }
            if m.defaultOn || m.isMandatory { defaults.insert(m.id) }
        }
        switch preset {
        case .complet:
            return everything
        case .choix:
            return defaults
        case .essentiel:
            var result: Set<String> = defaults.subtracting(Set(offeredModuleIDs)).union(mandatory)
            // Retire en cascade tout module dont une exigence a disparu.
            var changed = true
            while changed {
                changed = false
                for m in registry where !m.isMandatory && result.contains(m.id) {
                    for needed in m.requires where !result.contains(needed) {
                        result.remove(m.id)
                        changed = true
                        break
                    }
                }
            }
            return result
        }
    }

    /// Préréglage qui correspond exactement à la sélection sur les modules proposés, sinon `.choix`.
    static func detectPreset(enabled: Set<String>, registry: [ModuleDefinition] = ModuleRegistry.all) -> OnboardingPreset {
        let offered = Set(offeredModuleIDs)
        let mine = enabled.intersection(offered)
        if mine == presetIDs(.essentiel, registry: registry).intersection(offered) { return .essentiel }
        if mine == presetIDs(.complet, registry: registry).intersection(offered) { return .complet }
        return .choix
    }

    /// Nombre de modules proposés à l'étape 2 qui sont activés.
    static func offeredEnabledCount(enabled: Set<String>) -> Int {
        return enabled.intersection(Set(offeredModuleIDs)).count
    }

    // MARK: Récap

    static func warnings(location: LocationAccessLevel, notifications: NotificationAccessLevel) -> [OnboardingWarning] {
        var result: [OnboardingWarning] = []
        switch location {
        case .always:
            break
        case .whenInUse, .notDetermined:
            result.append(.locationNotAlways)
        case .denied, .restricted:
            result.append(.locationDenied)
        }
        if notifications == .denied { result.append(.notificationsDenied) }
        return result
    }

    /// Vrai quand la détection automatique ne marchera pas (c'est ce qui rend le récap "partiel").
    static func isDetectionLimited(location: LocationAccessLevel) -> Bool {
        return location != .always
    }
}
