import Foundation
import SwiftData

/// Une session (section 14). Les horodatages exacts ne sont jamais modifiés par l'arrondi (section 13.1) :
/// `chosenStart` et `chosenEnd` ne contiennent que le choix de l'utilisateur dans la zone de doute.
@Model
final class WorkSession {
    var uid: UUID = UUID()
    var activityRaw: String = ActivityType.work.rawValue
    /// Début exact, gardé tel quel.
    var startDate: Date = Date()
    /// Fin exacte, nil tant que la session est en cours.
    var endDate: Date?
    /// Heure pleine choisie pour le début quand il tombait dans la zone de doute (:15 à :45).
    var chosenStart: Date?
    /// Heure pleine choisie pour la fin quand elle tombait dans la zone de doute.
    var chosenEnd: Date?
    var sourceRaw: String = SessionSource.manual.rawValue
    /// Faux tant que l'utilisateur n'a pas confirmé une session détectée.
    var isConfirmed: Bool = true
    var note: String = ""
    /// Identifiant du fuseau horaire au moment de la session.
    var timeZoneID: String = TimeZone.current.identifier
    var createdAt: Date = Date()

    var place: Place?

    init(activity: ActivityType,
         start: Date,
         end: Date? = nil,
         place: Place? = nil,
         source: SessionSource = .manual,
         isConfirmed: Bool = true,
         note: String = "") {
        self.uid = UUID()
        self.activityRaw = activity.rawValue
        self.startDate = start
        self.endDate = end
        self.sourceRaw = source.rawValue
        self.isConfirmed = isConfirmed
        self.note = note
        self.timeZoneID = TimeZone.current.identifier
        self.createdAt = Date()
        self.place = place
    }

    var activity: ActivityType {
        get { return ActivityType(rawValue: activityRaw) ?? .unknown }
        set { activityRaw = newValue.rawValue }
    }

    var source: SessionSource {
        get { return SessionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var isOngoing: Bool { return endDate == nil }

    var timeZone: TimeZone { return TimeZone(identifier: timeZoneID) ?? TimeZone.current }

    /// Calendrier grégorien dans le fuseau de la session.
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    /// Fin utilisée pour les calculs : la fin exacte, ou `now` si la session est en cours.
    func effectiveEnd(now: Date) -> Date {
        return endDate ?? now
    }

    func exactSeconds(now: Date) -> Int {
        return SessionDurations.exactSeconds(start: startDate, end: effectiveEnd(now: now))
    }

    /// Durée normalisée en minutes, nil si une borne est en zone de doute sans choix.
    func normalizedMinutes(now: Date) -> Int? {
        return SessionDurations.normalizedMinutes(start: startDate, end: effectiveEnd(now: now),
                                                  chosenStart: chosenStart, chosenEnd: chosenEnd, calendar: calendar)
    }

    var hasUnresolvedDoubt: Bool {
        return SessionDurations.hasUnresolvedDoubt(start: startDate, end: endDate,
                                                   chosenStart: chosenStart, chosenEnd: chosenEnd, calendar: calendar)
    }

    var timelineInput: DayTimelineInput {
        return DayTimelineInput(start: startDate, end: endDate, activity: activity, isDoubt: hasUnresolvedDoubt)
    }
}
