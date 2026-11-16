import Foundation
import SwiftData

/// Un lieu (section 10) : taf, cours ou courses, avec sa position et son rayon.
@Model
final class Place {
    var uid: UUID = UUID()
    var name: String = ""
    var typeRaw: String = PlaceType.taf.rawValue
    var latitude: Double = 0
    var longitude: Double = 0
    /// Rayon en mètres (défaut 100).
    var radius: Double = 100
    var address: String = ""
    /// "J'y travaille aussi" : lieu de courses où l'on peut aussi travailler.
    var alsoWorksHere: Bool = false
    var createdAt: Date = Date()

    /// Supprimer un lieu ne supprime jamais ses sessions : elles gardent leurs heures, sans lieu.
    @Relationship(deleteRule: .nullify, inverse: \WorkSession.place)
    var sessions: [WorkSession] = []

    init(name: String,
         type: PlaceType,
         latitude: Double = 0,
         longitude: Double = 0,
         radius: Double = 100,
         address: String = "",
         alsoWorksHere: Bool = false) {
        self.uid = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.address = address
        self.alsoWorksHere = alsoWorksHere
        self.createdAt = Date()
    }

    var type: PlaceType {
        get { return PlaceType(rawValue: typeRaw) ?? .taf }
        set { typeRaw = newValue.rawValue }
    }
}
