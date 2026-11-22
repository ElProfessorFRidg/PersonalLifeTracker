import Foundation
import CoreLocation
import UserNotifications
import Observation
import UIKit

/// Position simple et Sendable, pour passer une coordonnée sans exposer CLLocation aux vues.
struct PermissionCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

/// Demandes de permissions (localisation, notifications) et états observables.
/// Aucune demande n'est faite tant qu'une méthode `request...` n'est pas appelée : les écrans expliquent d'abord.
@MainActor
@Observable
final class PermissionRequester: NSObject, CLLocationManagerDelegate {

    /// État de la localisation, mis à jour par le delegate.
    private(set) var location: LocationAccessLevel = .notDetermined
    /// État des notifications, mis à jour après chaque demande ou `refreshNotifications()`.
    private(set) var notifications: NotificationAccessLevel = .notDetermined

    @ObservationIgnored private let manager: CLLocationManager = CLLocationManager()
    @ObservationIgnored private var locationWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var coordinateWaiter: CheckedContinuation<PermissionCoordinate?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        location = PermissionRequester.level(for: manager.authorizationStatus)
    }

    // MARK: Localisation

    /// Demande "Pendant l'utilisation" puis "Toujours". iOS décide de l'affichage de la seconde fenêtre
    /// (parfois plus tard) : l'état réel est celui de `location`, toujours à jour.
    func requestLocationAccess() async {
        if location == .notDetermined {
            manager.requestWhenInUseAuthorization()
            await waitForLocationChange(timeoutSeconds: nil)
        }
        if location == .whenInUse {
            manager.requestAlwaysAuthorization()
            await waitForLocationChange(timeoutSeconds: 2)
        }
    }

    /// Position actuelle, une seule fois. Nil si non autorisée, impossible à obtenir ou trop longue (10 s).
    func currentCoordinate() async -> PermissionCoordinate? {
        guard location == .whenInUse || location == .always else { return nil }
        if coordinateWaiter != nil { return nil }
        let result: PermissionCoordinate? = await withCheckedContinuation { (continuation: CheckedContinuation<PermissionCoordinate?, Never>) in
            self.coordinateWaiter = continuation
            self.manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self?.finishCoordinate(nil)
            }
        }
        return result
    }

    private func finishCoordinate(_ value: PermissionCoordinate?) {
        guard let waiter = coordinateWaiter else { return }
        coordinateWaiter = nil
        waiter.resume(returning: value)
    }

    private func waitForLocationChange(timeoutSeconds: Double?) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.locationWaiters.append(continuation)
            if let seconds = timeoutSeconds {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    self?.resumeLocationWaiters()
                }
            }
        }
    }

    private func resumeLocationWaiters() {
        let waiters = locationWaiters
        locationWaiters = []
        for w in waiters { w.resume() }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        let level = PermissionRequester.level(for: status)
        guard level != location else { return }
        location = level
        resumeLocationWaiters()
    }

    static func level(for status: CLAuthorizationStatus) -> LocationAccessLevel {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedAlways: return .always
        case .authorizedWhenInUse: return .whenInUse
        @unknown default: return .denied
        }
    }

    // Callbacks CoreLocation : hors de l'acteur principal, on y revient avec des valeurs simples.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var coordinate: PermissionCoordinate? = nil
        if let last = locations.last {
            coordinate = PermissionCoordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        }
        let value: PermissionCoordinate? = coordinate
        Task { @MainActor [weak self] in
            self?.finishCoordinate(value)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishCoordinate(nil)
        }
    }

    // MARK: Notifications

    /// Lit l'état actuel sans rien demander.
    func refreshNotifications() async {
        let settings: UNNotificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = PermissionRequester.level(for: settings.authorizationStatus)
    }

    /// Fenêtre iOS : alertes, sons, pastilles.
    func requestNotifications() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Une erreur se lit comme un refus : l'état est relu ci-dessous.
        }
        await refreshNotifications()
    }

    static func level(for status: UNAuthorizationStatus) -> NotificationAccessLevel {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    // MARK: Réglages iOS

    /// Ouvre les réglages iOS de l'app.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
