import Foundation
import SwiftData

/// Genre d'une ligne du journal de détection (section 52).
enum DetectionEventKind: String, CaseIterable {
    case regionEntered
    case regionExited
    case arrivalConfirmed
    case visitNoted
    case entryRejected
    case departureConfirmed
    case sessionStarted
    case sessionStopped
    case ignoredShortVisit
    case monitoringStarted
    case monitoringFailed
    case authorizationChanged
    case notificationSent
    case userCorrected
}

/// Une ligne du journal de détection : ce que le système a reçu et ce que l'app en a fait.
@Model
final class DetectionEvent {
    var uid: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = DetectionEventKind.monitoringFailed.rawValue
    var placeName: String?
    var placeUID: UUID?
    var detail: String = ""
    var accuracyMeters: Double?

    init(kind: DetectionEventKind,
         date: Date = Date(),
         placeName: String? = nil,
         placeUID: UUID? = nil,
         detail: String = "",
         accuracyMeters: Double? = nil) {
        self.uid = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
        self.placeName = placeName
        self.placeUID = placeUID
        self.detail = detail
        self.accuracyMeters = accuracyMeters
    }

    var kind: DetectionEventKind {
        return DetectionEventKind(rawValue: kindRaw) ?? .monitoringFailed
    }
}
