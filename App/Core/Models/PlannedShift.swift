import Foundation
import SwiftData

/// Un créneau prévu (section 91) : daté, indépendant des autres semaines.
/// `sourceRaw` : manual, photo, text ou rotation. `activityRaw` : rawValue d'ActivityType.
@Model
final class PlannedShift {
    var uid: UUID = UUID()
    var start: Date = Date()
    var end: Date = Date()
    var activityRaw: String = ActivityType.work.rawValue
    var placeUID: UUID?
    var employerUID: UUID?
    var sourceRaw: String = "manual"
    var note: String = ""
    var createdAt: Date = Date()

    init(start: Date,
         end: Date,
         activity: ActivityType,
         placeUID: UUID? = nil,
         employerUID: UUID? = nil,
         source: String = "manual",
         note: String = "") {
        self.uid = UUID()
        self.start = start
        self.end = end
        self.activityRaw = activity.rawValue
        self.placeUID = placeUID
        self.employerUID = employerUID
        self.sourceRaw = source
        self.note = note
        self.createdAt = Date()
    }

    var activity: ActivityType {
        return ActivityType(rawValue: activityRaw) ?? .unknown
    }
}
