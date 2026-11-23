import Foundation
import SwiftData

extension Place {
    /// Copie en valeurs simples pour les règles pures. Les sessions terminées donnent les passages (début, fin).
    var snapshot: PlaceSnapshot {
        var visits: [PlaceVisitObservation] = []
        for session in sessions {
            guard let end = session.endDate, end > session.startDate else { continue }
            visits.append(PlaceVisitObservation(arrival: session.startDate, departure: end, accuracy: 0))
        }
        return PlaceSnapshot(id: uid, name: name, type: type, latitude: latitude, longitude: longitude,
                             radius: radius, alsoWorksHere: alsoWorksHere, sessionCount: sessions.count, visits: visits)
    }
}
