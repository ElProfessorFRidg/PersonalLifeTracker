import Foundation
import Observation
import CoreLocation
import UserNotifications
import UIKit

/// Autorisation de localisation, version lisible.
enum LocationAccess: Equatable {
    case always
    case whenInUse
    case denied
    case restricted
    case notDetermined

    var title: String {
        switch self {
        case .always: return "Toujours"
        case .whenInUse: return "Pendant l'utilisation"
        case .denied: return "Refusée"
        case .restricted: return "Restreinte"
        case .notDetermined: return "Pas encore demandée"
        }
    }
}

enum NotificationAccess: Equatable {
    case allowed
    case provisional
    case denied
    case notDetermined

    var title: String {
        switch self {
        case .allowed: return "Autorisées"
        case .provisional: return "En silence"
        case .denied: return "Refusées"
        case .notDetermined: return "Pas encore demandées"
        }
    }
}

enum BackgroundRefreshAccess: Equatable {
    case available
    case denied
    case restricted

    var title: String {
        switch self {
        case .available: return "Activée"
        case .denied: return "Désactivée"
        case .restricted: return "Restreinte"
        }
    }
}

/// Lit ce que l'iPhone autorise vraiment. Lecture seule : ne demande JAMAIS une permission
/// (les demandes sont faites ailleurs). Appeler `refresh()` à l'apparition de l'écran et quand l'app redevient active.
/// À utiliser depuis le fil principal.
@Observable
final class CapabilityService {
    private(set) var location: LocationAccess = .notDetermined
    /// Nil tant que la localisation n'est pas autorisée (la précision n'a alors pas de sens).
    private(set) var hasPreciseLocation: Bool? = nil
    private(set) var notifications: NotificationAccess = .notDetermined
    private(set) var backgroundRefresh: BackgroundRefreshAccess = .available
    private(set) var isLowPowerMode: Bool = false

    @ObservationIgnored private let locationManager: CLLocationManager = CLLocationManager()

    init() {
    }

    /// Vrai quand la détection d'arrivée et de départ peut marcher écran éteint.
    var hasAlwaysLocation: Bool { return location == .always }

    static func locationAccess(from status: CLAuthorizationStatus) -> LocationAccess {
        switch status {
        case .authorizedAlways: return .always
        case .authorizedWhenInUse: return .whenInUse
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func notificationAccess(from status: UNAuthorizationStatus) -> NotificationAccess {
        switch status {
        case .authorized: return .allowed
        case .provisional: return .provisional
        case .ephemeral: return .allowed
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func backgroundAccess(from status: UIBackgroundRefreshStatus) -> BackgroundRefreshAccess {
        switch status {
        case .available: return .available
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    /// Relit tous les états. Les notifications répondent un peu plus tard (appel asynchrone).
    func refresh() {
        let status: CLAuthorizationStatus = locationManager.authorizationStatus
        location = CapabilityService.locationAccess(from: status)
        if location == .always || location == .whenInUse {
            hasPreciseLocation = (locationManager.accuracyAuthorization == .fullAccuracy)
        } else {
            hasPreciseLocation = nil
        }
        backgroundRefresh = CapabilityService.backgroundAccess(from: UIApplication.shared.backgroundRefreshStatus)
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        Task { @MainActor [weak self] in
            let settings: UNNotificationSettings = await UNUserNotificationCenter.current().notificationSettings()
            self?.notifications = CapabilityService.notificationAccess(from: settings.authorizationStatus)
        }
    }
}
