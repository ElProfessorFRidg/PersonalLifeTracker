import MapKit

@MainActor
enum DiscoveredPlaceLookup {
    static func lookup(_ place: DiscoveredPlace, accuracy: Double, identifyVenue: Bool) async -> DiscoveredPlaceContext? {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let item: MKMapItem?
        if identifyVenue { item = await nearbyVenue(location, accuracy: accuracy) }
        else { item = nil }
        var address = item.flatMap { formattedAddress($0.placemark) }
        if address == nil && !Task.isCancelled {
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location) {
                address = placemarks.first.flatMap { formattedAddress($0) }
                return DiscoveredPlaceContext(name: item?.name, address: address, category: category(item))
            }
        }
        guard !Task.isCancelled, item != nil || address != nil else { return nil }
        return DiscoveredPlaceContext(name: item?.name, address: address, category: category(item))
    }

    private static func nearbyVenue(_ location: CLLocation, accuracy: Double) async -> MKMapItem? {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 100)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start() else { return nil }
        let matches = response.mapItems.compactMap { item -> (MKMapItem, CLLocationDistance)? in
            guard let point = item.placemark.location else { return nil }
            let distance = point.distance(from: location)
            return distance <= 80 ? (item, distance) : nil
        }.sorted { $0.1 < $1.1 }
        guard let nearest = matches.first, category(nearest.0) != nil,
              nearest.1 <= min(45, max(25, accuracy)) else { return nil }
        if matches.count > 1 && matches[1].1 - nearest.1 < 18 { return nil }
        return nearest.0
    }

    private static func category(_ item: MKMapItem?) -> PlaceType? {
        guard let category = item?.pointOfInterestCategory else { return nil }
        if #available(iOS 18, *) {
            switch category {
            case .brewery, .musicVenue, .theater: return .sortie
            case .stadium, .swimming, .tennis: return .sport
            default: break
            }
        }
        switch category {
        case .fitnessCenter: return .sport
        case .school, .university: return .cours
        case .nightlife, .restaurant, .cafe, .movieTheater, .museum: return .sortie
        case .store, .foodMarket, .pharmacy, .bakery: return .courses
        default: return nil
        }
    }

    private static func formattedAddress(_ placemark: CLPlacemark) -> String? {
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        let city = [placemark.postalCode, placemark.locality].compactMap { $0 }.joined(separator: " ")
        let address = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
        return address.isEmpty ? nil : address
    }
}
