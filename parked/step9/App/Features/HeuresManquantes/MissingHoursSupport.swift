import Foundation
import SwiftData

/// Conversion des modèles SwiftData vers la détection pure, partagée par l'écran et la carte Accueil.
enum MissingHoursSupport {

    static func items(shifts: [PlannedShift],
                      sessions: [WorkSession],
                      leaves: [LeaveEntry],
                      contracts: [Contract],
                      ignored: Set<String>,
                      now: Date,
                      calendar: Calendar) -> [MissingItem] {
        var missingShifts: [MissingShift] = []
        for s in shifts {
            missingShifts.append(MissingShift(slot: s.planSlot, placeUID: s.placeUID))
        }
        var real: [RealSlot] = []
        for s in sessions {
            real.append(s.planRealSlot)
        }
        var leaveDays: [DateInterval] = []
        for leave in leaves {
            let start: Date = calendar.startOfDay(for: leave.startDay)
            let lastDay: Date = calendar.startOfDay(for: leave.endDay)
            if let end = calendar.date(byAdding: .day, value: 1, to: lastDay), end > start {
                leaveDays.append(DateInterval(start: start, end: end))
            }
        }
        var missingContracts: [MissingContract] = []
        for c in contracts {
            missingContracts.append(MissingContract(id: c.uid, start: c.startDate, end: c.endDate, weeklyHours: c.weeklyHours))
        }
        return MissingHoursRules.detect(shifts: missingShifts, sessions: real, leaveDays: leaveDays,
                                        contracts: missingContracts, ignoredIDs: ignored, now: now, calendar: calendar)
    }
}

extension SessionService {
    /// Ajoute une session proposée par la détection d'heures manquantes : source manuelle, à confirmer.
    /// Ne vérifie pas les chevauchements : l'appelant le fait avec SessionRules.validate.
    @discardableResult
    func addProposedSession(activity: ActivityType, start: Date, end: Date, place: Place?) throws -> WorkSession {
        let session: WorkSession = WorkSession(activity: activity, start: start, end: end, place: place,
                                               source: .manual, isConfirmed: false)
        context.insert(session)
        try context.save()
        return session
    }
}
