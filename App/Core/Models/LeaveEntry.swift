import Foundation
import SwiftData

/// Un congé (section 91) : de `startDay` à `endDay` inclus (débuts de jour).
/// `kindRaw` : paid, unpaid, sick ou other.
@Model
final class LeaveEntry {
    var uid: UUID = UUID()
    var startDay: Date = Date()
    var endDay: Date = Date()
    var kindRaw: String = "paid"
    var note: String = ""
    var employerUID: UUID?
    var createdAt: Date = Date()

    init(startDay: Date,
         endDay: Date,
         kindRaw: String = "paid",
         note: String = "",
         employerUID: UUID? = nil) {
        self.uid = UUID()
        self.startDay = startDay
        self.endDay = endDay
        self.kindRaw = kindRaw
        self.note = note
        self.employerUID = employerUID
        self.createdAt = Date()
    }
}
