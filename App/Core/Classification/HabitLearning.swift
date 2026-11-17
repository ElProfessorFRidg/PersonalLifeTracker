import Foundation
import SwiftData

/// Lien entre une session et l'apprentissage : seule une session d'un lieu de courses où l'utilisateur travaille aussi
/// apprend quelque chose (section 11 : lieu à double usage). Les autres types ne sont jamais ambigus.
enum HabitLearning {

    static func isDualUse(_ place: Place?) -> Bool {
        guard let place = place else { return false }
        return place.type == .courses && place.alsoWorksHere
    }

    /// Le travail et les courses sont les deux seules réponses qui apprennent quelque chose.
    /// nil = rien à apprendre (études, perso, trajet, autre).
    static func learnedLabel(for activity: ActivityType) -> Bool? {
        switch activity {
        case .work: return true
        case .shopping: return false
        case .education, .personal, .travel, .unknown: return nil
        }
    }

    /// À appeler quand l'utilisateur change le type d'une session ou la confirme.
    /// Renvoie vrai si une réponse a été enregistrée.
    @discardableResult
    static func recordFeedback(for session: WorkSession, store: HabitStore, now: Date = Date()) -> Bool {
        guard let place = session.place else { return false }
        if !isDualUse(place) { return false }
        guard let isWork = learnedLabel(for: session.activity) else { return false }
        store.record(sessionKey: session.uid.uuidString,
                     placeKey: place.uid.uuidString,
                     visitStart: session.startDate,
                     isWork: isWork,
                     now: now,
                     calendar: session.calendar)
        return true
    }
}
