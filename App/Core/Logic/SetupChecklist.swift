import Foundation

// Assistant de configuration : règles pures (Foundation seulement). Les vues et SetupAutomation lisent l'état réel,
// le transforment en SetupFacts, et cette liste dit quoi faire ensuite.

/// Localisation, version simplifiée (restreinte se traite comme refusée).
enum SetupLocationLevel: Equatable {
    case always
    case whenInUse
    case denied
    case notDetermined
}

/// Notifications, version simplifiée (silencieuses = autorisées).
enum SetupNotificationLevel: Equatable {
    case allowed
    case denied
    case notDetermined
}

/// Tout ce que la liste a besoin de savoir, en valeurs simples.
struct SetupFacts: Equatable {
    var location: SetupLocationLevel
    var notifications: SetupNotificationLevel
    var placeCount: Int
    var hasTafPlace: Bool
    var employmentActive: Bool
    var payActive: Bool
    var contractHoursActive: Bool
    var planningOCRActive: Bool
    var hasEmployer: Bool
    var hasContract: Bool
    /// Vrai si un contrat a un nombre d'heures par semaine saisi (supérieur à 0).
    var hasContractWeeklyHours: Bool
    var hasPayRate: Bool
    var hasPlannedShift: Bool
    var hasSession: Bool

    init(location: SetupLocationLevel = .notDetermined,
         notifications: SetupNotificationLevel = .notDetermined,
         placeCount: Int = 0,
         hasTafPlace: Bool = false,
         employmentActive: Bool = false,
         payActive: Bool = false,
         contractHoursActive: Bool = false,
         planningOCRActive: Bool = false,
         hasEmployer: Bool = false,
         hasContract: Bool = false,
         hasContractWeeklyHours: Bool = false,
         hasPayRate: Bool = false,
         hasPlannedShift: Bool = false,
         hasSession: Bool = false) {
        self.location = location
        self.notifications = notifications
        self.placeCount = placeCount
        self.hasTafPlace = hasTafPlace
        self.employmentActive = employmentActive
        self.payActive = payActive
        self.contractHoursActive = contractHoursActive
        self.planningOCRActive = planningOCRActive
        self.hasEmployer = hasEmployer
        self.hasContract = hasContract
        self.hasContractWeeklyHours = hasContractWeeklyHours
        self.hasPayRate = hasPayRate
        self.hasPlannedShift = hasPlannedShift
        self.hasSession = hasSession
    }
}

enum SetupStepID: String, CaseIterable {
    case location
    case notifications
    case firstPlace
    case employer
    case payRate
    case planning
    case contractHours

    /// Les étapes de permission : celles qui peuvent se bloquer quand iOS refuse ou retire une autorisation.
    var isPermission: Bool {
        switch self {
        case .location, .notifications: return true
        case .firstPlace, .employer, .payRate, .planning, .contractHours: return false
        }
    }
}

enum SetupStatus: Equatable {
    case done
    case todo
    /// Une permission refusée, ou une étape qui attend une autre étape.
    case blocked
    case notApplicable
}

/// Ce qu'un tap sur l'étape déclenche.
enum SetupAction: Equatable {
    case requestLocation
    case requestNotifications
    case openSystemSettings
    case createFirstPlace
    case createEmployerDraft
    case openEmployment
    case openPay
    case openPlanningImport
    case openContractHours
}

struct SetupStep: Equatable {
    let id: SetupStepID
    let status: SetupStatus
    let title: String
    /// Pourquoi cette étape sert, en une ou deux phrases.
    let why: String
    /// Libellé du bouton. Nil quand l'étape est faite ou sans objet.
    let actionTitle: String?
    let action: SetupAction?
    /// Vrai si « Tout configurer pour moi » peut la faire sans que tu aies rien à écrire.
    let isAutomatic: Bool
}

struct SetupProgress: Equatable {
    let done: Int
    let total: Int

    /// « 3 sur 6 faits »
    var text: String {
        return "\(done) sur \(total) " + (done <= 1 ? "fait" : "faits")
    }

    var fraction: Double {
        if total <= 0 { return 1 }
        return Double(done) / Double(total)
    }
}

enum SetupChecklist {

    /// Les étapes dans l'ordre, y compris celles sans objet (statut notApplicable).
    static func steps(for facts: SetupFacts) -> [SetupStep] {
        return [
            locationStep(facts),
            notificationsStep(facts),
            firstPlaceStep(facts),
            employerStep(facts),
            payRateStep(facts),
            planningStep(facts),
            contractHoursStep(facts)
        ]
    }

    /// Seulement les étapes qui s'appliquent.
    static func applicableSteps(for facts: SetupFacts) -> [SetupStep] {
        return steps(for: facts).filter { (s: SetupStep) -> Bool in return s.status != .notApplicable }
    }

    static func progress(of steps: [SetupStep]) -> SetupProgress {
        let applicable: [SetupStep] = steps.filter { (s: SetupStep) -> Bool in return s.status != .notApplicable }
        let done: Int = applicable.filter { (s: SetupStep) -> Bool in return s.status == .done }.count
        return SetupProgress(done: done, total: applicable.count)
    }

    static func isComplete(_ steps: [SetupStep]) -> Bool {
        return !steps.contains { (s: SetupStep) -> Bool in return s.status == .todo || s.status == .blocked }
    }

    /// Première étape à faire (à faire ou bloquée), dans l'ordre.
    static func nextStep(in steps: [SetupStep]) -> SetupStep? {
        return steps.first { (s: SetupStep) -> Bool in return s.status == .todo || s.status == .blocked }
    }

    /// Étapes de permission bloquées (permission refusée ou insuffisante).
    static func blockedPermissionIDs(in steps: [SetupStep]) -> Set<String> {
        var result: Set<String> = []
        for s in steps where s.status == .blocked && s.id.isPermission {
            result.insert(s.id.rawValue)
        }
        return result
    }

    /// La carte de l'Accueil se montre tant que la configuration n'est pas finie, sauf si tu as dit « Plus tard ».
    /// Elle revient quand une permission se bloque alors qu'elle ne l'était pas au moment du « Plus tard ».
    static func shouldShowCard(steps: [SetupStep], isDismissed: Bool, dismissedBlockedIDs: Set<String>) -> Bool {
        if isComplete(steps) { return false }
        if !isDismissed { return true }
        let current: Set<String> = blockedPermissionIDs(in: steps)
        return !current.isSubset(of: dismissedBlockedIDs)
    }

    /// Message quand tout est fait.
    static func completionMessage(for facts: SetupFacts) -> String {
        if facts.hasSession {
            return "Tout est en place. Tu n'as plus rien à régler."
        }
        return "Tout est en place. Arrive à ton taf avec ton téléphone : ta première session se lancera toute seule."
    }

    // MARK: Étapes

    private static func locationStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Localisation « Toujours »"
        let why: String = "Sans « Toujours », l'app rate tes arrivées et tes départs quand l'écran est éteint. C'est ce qui lance et arrête tes sessions tout seul."
        switch f.location {
        case .always:
            return SetupStep(id: .location, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        case .notDetermined:
            return SetupStep(id: .location, status: .todo, title: title, why: why,
                             actionTitle: "Autoriser la localisation", action: .requestLocation, isAutomatic: true)
        case .whenInUse:
            return SetupStep(id: .location, status: .blocked, title: title,
                             why: "Tu as choisi « Pendant l'utilisation » : l'app rate les arrivées et départs écran éteint. iOS ne redemande pas, il faut passer sur « Toujours » dans les réglages.",
                             actionTitle: "Ouvrir les réglages iOS", action: .openSystemSettings, isAutomatic: false)
        case .denied:
            return SetupStep(id: .location, status: .blocked, title: title,
                             why: "La localisation est refusée : aucune arrivée ni aucun départ ne peut être détecté. Dans les réglages iOS, choisis « Toujours ».",
                             actionTitle: "Ouvrir les réglages iOS", action: .openSystemSettings, isAutomatic: false)
        }
    }

    private static func notificationsStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Notifications"
        let why: String = "Pour te prévenir quand une session démarre ou s'arrête, et quand un horaire est à vérifier. Rien n'est envoyé hors de ton téléphone."
        switch f.notifications {
        case .allowed:
            return SetupStep(id: .notifications, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        case .notDetermined:
            return SetupStep(id: .notifications, status: .todo, title: title, why: why,
                             actionTitle: "Autoriser les notifications", action: .requestNotifications, isAutomatic: true)
        case .denied:
            return SetupStep(id: .notifications, status: .blocked, title: title,
                             why: "Les notifications sont refusées : tu ne seras pas prévenu quand une session démarre. Tu peux les réactiver dans les réglages iOS.",
                             actionTitle: "Ouvrir les réglages iOS", action: .openSystemSettings, isAutomatic: false)
        }
    }

    private static func firstPlaceStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Ton premier lieu (taf)"
        let why: String = "Un lieu de type taf est ce qui permet à l'app de savoir quand tu arrives et quand tu pars. Sans lui, rien n'est détecté."
        if f.hasTafPlace {
            return SetupStep(id: .firstPlace, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        }
        let canLocate: Bool = (f.location == .always || f.location == .whenInUse)
        let detail: String = f.placeCount > 0
            ? "Tu as des lieux, mais aucun n'est de type taf. " + why
            : why
        return SetupStep(id: .firstPlace, status: .todo, title: title, why: detail,
                         actionTitle: canLocate ? "Créer à partir de ma position" : "Ajouter un lieu",
                         action: .createFirstPlace, isAutomatic: canLocate)
    }

    private static func employerStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Employeur et contrat"
        let why: String = "Pour compter tes heures face à ton contrat et préparer la paie. C'est facultatif, tes heures sont suivies sans."
        if !f.employmentActive {
            return notApplicable(.employer, title: title)
        }
        if f.hasEmployer && f.hasContract {
            return SetupStep(id: .employer, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        }
        if f.hasEmployer {
            return SetupStep(id: .employer, status: .todo, title: title, why: why,
                             actionTitle: "Ajouter mon contrat", action: .openEmployment, isAutomatic: false)
        }
        return SetupStep(id: .employer, status: .todo, title: title, why: why,
                         actionTitle: "Préparer mon employeur et mon contrat", action: .createEmployerDraft, isAutomatic: true)
    }

    private static func payRateStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Taux horaire"
        let why: String = "Sans taux horaire, l'estimation de ta paie ne peut pas être calculée. Recopie-le depuis ton contrat ou ta fiche de paie."
        if !f.payActive {
            return notApplicable(.payRate, title: title)
        }
        if f.hasPayRate {
            return SetupStep(id: .payRate, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        }
        if !f.hasContract {
            return SetupStep(id: .payRate, status: .blocked, title: title,
                             why: "Le taux s'attache à un contrat. Ajoute d'abord ton employeur et ton contrat.",
                             actionTitle: f.hasEmployer ? "Ajouter mon contrat" : "Préparer mon employeur et mon contrat",
                             action: f.hasEmployer ? .openEmployment : .createEmployerDraft,
                             isAutomatic: false)
        }
        return SetupStep(id: .payRate, status: .todo, title: title, why: why,
                         actionTitle: "Saisir mon taux horaire", action: .openPay, isAutomatic: false)
    }

    private static func planningStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Ton planning"
        let why: String = "Prends ton planning en photo : l'app lit les horaires et te prévient s'ils changent. Tu peux aussi les saisir à la main."
        if !f.planningOCRActive {
            return notApplicable(.planning, title: title)
        }
        if f.hasPlannedShift {
            return SetupStep(id: .planning, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        }
        return SetupStep(id: .planning, status: .todo, title: title, why: why,
                         actionTitle: "Importer mon planning", action: .openPlanningImport, isAutomatic: false)
    }

    private static func contractHoursStep(_ f: SetupFacts) -> SetupStep {
        let title: String = "Heures du contrat"
        let why: String = "Avec tes heures par semaine, l'app te montre où tu en es face à ton quota. Recopie le chiffre de ton contrat, je n'en invente aucun."
        if !f.contractHoursActive {
            return notApplicable(.contractHours, title: title)
        }
        if f.hasContractWeeklyHours {
            return SetupStep(id: .contractHours, status: .done, title: title, why: why, actionTitle: nil, action: nil, isAutomatic: false)
        }
        if !f.hasContract {
            return SetupStep(id: .contractHours, status: .blocked, title: title,
                             why: "Les heures se règlent dans un contrat. Ajoute d'abord ton employeur et ton contrat.",
                             actionTitle: f.hasEmployer ? "Ajouter mon contrat" : "Préparer mon employeur et mon contrat",
                             action: f.hasEmployer ? .openEmployment : .createEmployerDraft,
                             isAutomatic: false)
        }
        return SetupStep(id: .contractHours, status: .todo, title: title, why: why,
                         actionTitle: "Régler mes heures", action: .openEmployment, isAutomatic: false)
    }

    private static func notApplicable(_ id: SetupStepID, title: String) -> SetupStep {
        return SetupStep(id: id, status: .notApplicable, title: title, why: "", actionTitle: nil, action: nil, isAutomatic: false)
    }
}
