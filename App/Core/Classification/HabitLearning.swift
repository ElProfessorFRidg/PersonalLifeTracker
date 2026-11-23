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
    /// Type de lieu correspondant à l'activité choisie pour une session (nil : l'activité n'apprend rien sur le lieu).
    static func placeType(for activity: ActivityType) -> PlaceType? {
        switch activity {
        case .work: return .taf
        case .education: return .cours
        case .shopping: return .courses
        case .personal, .travel, .unknown: return nil
        }
    }

    /// Corriger ou confirmer une session apprend aussi le type du lieu autour de sa position
    /// (une même session ne compte qu'une fois). Renvoie vrai si une leçon a été enregistrée.
    @discardableResult
    static func recordPlaceKind(for session: WorkSession, kindStore: PlaceKindStore, now: Date = Date()) -> Bool {
        guard let place = session.place, let chosen = placeType(for: session.activity) else { return false }
        kindStore.recordChoice(key: "session-" + session.uid.uuidString,
                               latitude: place.latitude, longitude: place.longitude,
                               chosen: chosen, suggested: place.type, patternKey: nil, now: now)
        return true
    }

    /// À appeler quand l'utilisateur change le type d'une session ou la confirme.
    /// Renvoie vrai si une réponse a été enregistrée dans l'apprentissage des lieux à double usage.
    @discardableResult
    static func recordFeedback(for session: WorkSession, store: HabitStore, now: Date = Date(),
                               kindStore: PlaceKindStore = PlaceKindStore.shared) -> Bool {
        recordPlaceKind(for: session, kindStore: kindStore, now: now)
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
