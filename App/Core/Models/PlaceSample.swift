import Foundation
import SwiftData

/// Genre d'une mesure de calibration (section 130).
enum PlaceSampleKind: String, CaseIterable {
    case arrival
    case departure
    case manualConfirm
}

/// Une mesure agrégée par arrivée ou départ confirmé : où la détection a eu lieu, avec quelle précision.
/// Ce n'est jamais une trace GPS : une seule ligne par événement, et seulement les 40 plus récentes par lieu.
@Model
final class PlaceSample {
    var uid: UUID = UUID()
    var placeUID: UUID = UUID()
    var date: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    var horizontalAccuracy: Double = 0
    var kindRaw: String = PlaceSampleKind.arrival.rawValue

    init(placeUID: UUID,
         date: Date = Date(),
         latitude: Double,
         longitude: Double,
         horizontalAccuracy: Double,
         kind: PlaceSampleKind) {
        self.uid = UUID()
        self.placeUID = placeUID
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.kindRaw = kind.rawValue
    }

    var kind: PlaceSampleKind {
        get { return PlaceSampleKind(rawValue: kindRaw) ?? .arrival }
        set { kindRaw = newValue.rawValue }
    }
}
