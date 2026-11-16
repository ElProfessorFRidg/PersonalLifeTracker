import Foundation
import CoreLocation

/// Position unique (une seule demande, autorisation "pendant l'utilisation"). Sert au bouton "Ma position".
/// Refuser la localisation ne bloque jamais l'ajout d'un lieu : l'état `denied` sert juste à afficher un bandeau.
@MainActor
final class LocationOnce: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case locating
        case denied
        case failed
        case located(latitude: Double, longitude: Double)
    }

    @Published private(set) var state: State = .idle

    private let manager: CLLocationManager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Vrai si l'utilisateur a refusé la localisation (ou si elle est restreinte).
    static func isDenied() -> Bool {
        let status: CLAuthorizationStatus = CLLocationManager().authorizationStatus
        return status == .denied || status == .restricted
    }

    /// Lance une demande de position unique.
    func request() {
        let status: CLAuthorizationStatus = manager.authorizationStatus
        switch status {
        case .notDetermined:
            state = .locating
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            state = .locating
            manager.requestLocation()
        @unknown default:
            state = .failed
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat: Double = last.coordinate.latitude
        let lon: Double = last.coordinate.longitude
        Task { @MainActor in
            self.state = .located(latitude: lat, longitude: lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied: Bool = (error as? CLError)?.code == CLError.Code.denied
        Task { @MainActor in
            self.state = denied ? .denied : .failed
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        // Ne réagit que si une demande est en cours.
        guard state == .locating else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            state = .denied
        case .notDetermined:
            break
        @unknown default:
            state = .failed
        }
    }
}
