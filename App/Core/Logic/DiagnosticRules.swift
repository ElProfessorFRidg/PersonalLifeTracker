import Foundation

/// Règles pures de l'écran "Fiabilité et diagnostic" (section 52). Foundation seulement.
/// Aucune dépendance à SwiftData, CoreLocation ou SwiftUI : tout arrive en valeurs simples.

/// Autorisation de localisation, version propre à ce fichier.
enum DiagLocationState: Equatable {
    case always
    case whenInUse
    case denied
    case restricted
    case notDetermined
}

/// Gravité d'un point vérifié. L'ordre de déclaration sert à comparer.
enum DiagStatus: Int, Equatable, Comparable {
    case ok = 0
    case warning = 1
    case blocking = 2

    static func < (lhs: DiagStatus, rhs: DiagStatus) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .ok: return "OK"
        case .warning: return "À régler"
        case .blocking: return "Bloquant"
        }
    }
}

enum DiagCheckID: String, Equatable, CaseIterable {
    case location
    case precise
    case notifications
    case backgroundRefresh
    case lowPower
    case places
    case monitoring
    case monitoredCount
    case lastEvent
}

/// Action proposée pour corriger un point.
enum DiagFix: Equatable {
    case none
    case openSettings
    case restartMonitoring
}

struct DiagCheck: Equatable {
    let id: DiagCheckID
    let title: String
    let detail: String
    let status: DiagStatus
    let fix: DiagFix
    let fixTitle: String?
}

struct DiagInput: Equatable {
    var location: DiagLocationState
    /// Nil quand la localisation n'est pas autorisée (précision sans objet).
    var preciseLocation: Bool?
    var notificationsAllowed: Bool
    var backgroundRefreshAvailable: Bool
    var lowPowerMode: Bool
    var placeCount: Int
    var isMonitoring: Bool
    var monitoringError: String?
    var monitoredCount: Int
    var lastEventDate: Date?
    var now: Date
}

struct DiagSummary: Equatable {
    let isAllGood: Bool
    /// Identifiant du point le plus probable, nil si tout est bon.
    let causeID: DiagCheckID?
    let status: DiagStatus
    let title: String
    let message: String
}

/// Familles de filtre du journal.
enum DiagEventFamily: Equatable {
    case arrivalsAndDepartures
    case errors
    case other
}

enum DiagnosticRules {
    /// Limite iOS de régions surveillées par app.
    static let regionLimit: Int = 20
    /// Au bout de ce délai sans événement, on le signale.
    static let staleDelaySeconds: TimeInterval = 3 * 24 * 3600

    // MARK: Vérifications

    static func checks(_ input: DiagInput) -> [DiagCheck] {
        return [
            locationCheck(input),
            preciseCheck(input),
            notificationsCheck(input),
            backgroundCheck(input),
            lowPowerCheck(input),
            placesCheck(input),
            monitoringCheck(input),
            monitoredCountCheck(input),
            lastEventCheck(input)
        ]
    }

    private static func locationCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Localisation sur « Toujours »"
        switch input.location {
        case .always:
            return DiagCheck(id: .location, title: title, detail: "Réglée sur Toujours.",
                             status: .ok, fix: .none, fixTitle: nil)
        case .whenInUse:
            return DiagCheck(id: .location, title: title,
                             detail: "Réglée sur « Pendant l'utilisation ». Je rate tes arrivées et tes départs quand l'app est fermée.",
                             status: .blocking, fix: .openSettings, fixTitle: "Passer sur Toujours")
        case .denied:
            return DiagCheck(id: .location, title: title,
                             detail: "La localisation est refusée. Sans elle, je ne détecte rien.",
                             status: .blocking, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
        case .restricted:
            return DiagCheck(id: .location, title: title,
                             detail: "Une restriction de l'iPhone bloque la localisation.",
                             status: .blocking, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
        case .notDetermined:
            return DiagCheck(id: .location, title: title,
                             detail: "Tu n'as pas encore choisi. Tant que c'est le cas, je ne détecte rien.",
                             status: .blocking, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
        }
    }

    private static func preciseCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Position exacte"
        guard let precise = input.preciseLocation else {
            return DiagCheck(id: .precise, title: title,
                             detail: "Inconnue tant que la localisation n'est pas autorisée.",
                             status: .warning, fix: .none, fixTitle: nil)
        }
        if precise {
            return DiagCheck(id: .precise, title: title, detail: "Activée.",
                             status: .ok, fix: .none, fixTitle: nil)
        }
        return DiagCheck(id: .precise, title: title,
                         detail: "Désactivée. Sans elle, je peux confondre deux lieux proches.",
                         status: .warning, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
    }

    private static func notificationsCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Notifications"
        if input.notificationsAllowed {
            return DiagCheck(id: .notifications, title: title, detail: "Autorisées.",
                             status: .ok, fix: .none, fixTitle: nil)
        }
        return DiagCheck(id: .notifications, title: title,
                         detail: "Pas autorisées. Je ne peux pas te demander de confirmer une arrivée.",
                         status: .warning, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
    }

    private static func backgroundCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Actualisation en arrière-plan"
        if input.backgroundRefreshAvailable {
            return DiagCheck(id: .backgroundRefresh, title: title, detail: "Activée.",
                             status: .ok, fix: .none, fixTitle: nil)
        }
        return DiagCheck(id: .backgroundRefresh, title: title,
                         detail: "Coupée. Sans elle, je peux rater une sortie quand l'app dort.",
                         status: .warning, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
    }

    private static func lowPowerCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Mode économie d'énergie"
        if input.lowPowerMode {
            return DiagCheck(id: .lowPower, title: title,
                             detail: "Actif. La détection peut avoir quelques minutes de retard.",
                             status: .warning, fix: .openSettings, fixTitle: "Ouvrir les réglages iOS")
        }
        return DiagCheck(id: .lowPower, title: title, detail: "Inactif.",
                         status: .ok, fix: .none, fixTitle: nil)
    }

    private static func placesCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Au moins un lieu"
        if input.placeCount > 0 {
            let detail: String = input.placeCount == 1 ? "1 lieu enregistré." : "\(input.placeCount) lieux enregistrés."
            return DiagCheck(id: .places, title: title, detail: detail,
                             status: .ok, fix: .none, fixTitle: nil)
        }
        return DiagCheck(id: .places, title: title,
                         detail: "Aucun lieu. Ajoute-en un dans l'onglet Lieux pour que je sache quoi surveiller.",
                         status: .blocking, fix: .none, fixTitle: nil)
    }

    private static func monitoringCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Surveillance active"
        if input.placeCount == 0 {
            return DiagCheck(id: .monitoring, title: title,
                             detail: "Rien à surveiller tant que tu n'as pas de lieu.",
                             status: .ok, fix: .none, fixTitle: nil)
        }
        if let error = input.monitoringError, !error.isEmpty {
            return DiagCheck(id: .monitoring, title: title,
                             detail: "Dernière erreur : \(error)",
                             status: .blocking, fix: .restartMonitoring, fixTitle: "Relancer la surveillance")
        }
        if !input.isMonitoring {
            return DiagCheck(id: .monitoring, title: title,
                             detail: "La surveillance n'est pas démarrée. Je ne vois ni tes arrivées ni tes départs.",
                             status: .blocking, fix: .restartMonitoring, fixTitle: "Relancer la surveillance")
        }
        return DiagCheck(id: .monitoring, title: title, detail: "En cours.",
                         status: .ok, fix: .none, fixTitle: nil)
    }

    private static func monitoredCountCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Lieux surveillés"
        if input.placeCount > regionLimit {
            return DiagCheck(id: .monitoredCount, title: title,
                             detail: "Tu as \(input.placeCount) lieux, mais iOS n'en surveille que \(regionLimit). Les autres ne sont pas détectés.",
                             status: .warning, fix: .restartMonitoring, fixTitle: "Relancer la surveillance")
        }
        return DiagCheck(id: .monitoredCount, title: title,
                         detail: "\(input.monitoredCount) sur \(regionLimit) possibles.",
                         status: .ok, fix: .none, fixTitle: nil)
    }

    private static func lastEventCheck(_ input: DiagInput) -> DiagCheck {
        let title: String = "Dernier événement reçu"
        guard let last = input.lastEventDate else {
            return DiagCheck(id: .lastEvent, title: title,
                             detail: "Aucun événement pour l'instant.",
                             status: .ok, fix: .none, fixTitle: nil)
        }
        let age: TimeInterval = input.now.timeIntervalSince(last)
        if age >= staleDelaySeconds {
            let days: Int = Int(age / 86_400)
            return DiagCheck(id: .lastEvent, title: title,
                             detail: "Rien reçu depuis \(days) jours. Si tu as bougé entre-temps, la détection a peut-être décroché.",
                             status: .warning, fix: .restartMonitoring, fixTitle: "Relancer la surveillance")
        }
        return DiagCheck(id: .lastEvent, title: title, detail: "Reçu récemment.",
                         status: .ok, fix: .none, fixTitle: nil)
    }

    // MARK: Résumé

    /// Cause la plus probable : le premier point bloquant, sinon le premier point à régler (ordre de la liste).
    static func summary(_ input: DiagInput) -> DiagSummary {
        return summary(for: checks(input))
    }

    static func summary(for checks: [DiagCheck]) -> DiagSummary {
        var cause: DiagCheck? = nil
        for check in checks where check.status == .blocking {
            cause = check
            break
        }
        if cause == nil {
            for check in checks where check.status == .warning {
                cause = check
                break
            }
        }
        guard let found = cause else {
            return DiagSummary(isAllGood: true, causeID: nil, status: .ok,
                               title: "Tout est bon",
                               message: "Tout ce que j'ai vérifié est en ordre. Si une arrivée est ratée, regarde le journal plus bas.")
        }
        return DiagSummary(isAllGood: false, causeID: found.id, status: found.status,
                           title: "Cause la plus probable : \(causeName(found.id))",
                           message: found.detail)
    }

    static func causeName(_ id: DiagCheckID) -> String {
        switch id {
        case .location: return "la localisation"
        case .precise: return "la position exacte"
        case .notifications: return "les notifications"
        case .backgroundRefresh: return "l'actualisation en arrière-plan"
        case .lowPower: return "le mode économie d'énergie"
        case .places: return "l'absence de lieu"
        case .monitoring: return "la surveillance arrêtée"
        case .monitoredCount: return "la limite de 20 lieux"
        case .lastEvent: return "le manque d'événements récents"
        }
    }

    // MARK: Journal

    /// Phrase lisible pour un type d'événement (valeur brute de DetectionEventKind).
    static func sentence(forKind rawKind: String, placeName: String?) -> String {
        let name: String = cleanName(placeName)
        switch rawKind {
        case "regionEntered":
            return name.isEmpty ? "Entrée dans une zone" : "Entrée dans la zone : \(name)"
        case "regionExited":
            return name.isEmpty ? "Sortie d'une zone" : "Sortie de la zone : \(name)"
        case "arrivalConfirmed":
            return name.isEmpty ? "Arrivée confirmée" : "Arrivée confirmée : \(name)"
        case "departureConfirmed":
            return name.isEmpty ? "Départ confirmé" : "Départ confirmé : \(name)"
        case "sessionStarted":
            return name.isEmpty ? "Session démarrée" : "Session démarrée : \(name)"
        case "sessionStopped":
            return name.isEmpty ? "Session terminée" : "Session terminée : \(name)"
        case "ignoredShortVisit":
            return name.isEmpty ? "Passage trop court, ignoré" : "Passage trop court ignoré : \(name)"
        case "monitoringStarted":
            return "Surveillance démarrée"
        case "monitoringFailed":
            return "La surveillance a échoué"
        case "authorizationChanged":
            return "L'autorisation de localisation a changé"
        case "notificationSent":
            return "Notification envoyée"
        case "userCorrected":
            return name.isEmpty ? "Tu as corrigé à la main" : "Tu as corrigé à la main : \(name)"
        default:
            return "Événement inconnu"
        }
    }

    static func family(forKind rawKind: String) -> DiagEventFamily {
        switch rawKind {
        case "regionEntered", "regionExited", "arrivalConfirmed", "departureConfirmed",
             "sessionStarted", "sessionStopped", "ignoredShortVisit":
            return .arrivalsAndDepartures
        case "monitoringFailed", "authorizationChanged":
            return .errors
        default:
            return .other
        }
    }

    /// Texte de précision, arrondi au mètre ("± 35 m"). Nil si inconnue ou négative.
    static func accuracyText(_ meters: Double?) -> String? {
        guard let meters = meters, meters >= 0, meters.isFinite else { return nil }
        return "± \(Int(meters.rounded())) m"
    }

    private static func cleanName(_ name: String?) -> String {
        guard let name = name else { return "" }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
