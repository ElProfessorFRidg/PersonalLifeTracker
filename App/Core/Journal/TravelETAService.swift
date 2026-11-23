import Foundation
import MapKit
import CoreLocation

/// Appel MKDirections isolé : une seule requête d'ETA, jamais de polling (spec 35).
/// Renvoie nil hors ligne, sans itinéraire ou en cas d'erreur : l'appelant se replie sur le vol d'oiseau.
enum TravelETAService {

    static func transportType(for mode: TravelMode) -> MKDirectionsTransportType {
        switch mode {
        case .walking: return MKDirectionsTransportType.walking
        case .driving: return MKDirectionsTransportType.automobile
        case .transit: return MKDirectionsTransportType.transit
        }
    }

    /// Temps de trajet estimé en secondes, en partant maintenant.
    static func expectedTravelSeconds(fromLatitude: Double, fromLongitude: Double,
                                      toLatitude: Double, toLongitude: Double,
                                      mode: TravelMode) async -> Int? {
        let source: MKMapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: fromLatitude, longitude: fromLongitude)))
        let destination: MKMapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: toLatitude, longitude: toLongitude)))
        let request: MKDirections.Request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = transportType(for: mode)
        let directions: MKDirections = MKDirections(request: request)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            directions.calculateETA { (response: MKDirections.ETAResponse?, error: Error?) in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                if let response = response {
                    continuation.resume(returning: Int(response.expectedTravelTime.rounded()))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
