import Foundation
import SwiftData
@testable import PersonalLifeTracker

/// Éléments du jeu d'exemple dont les captures ont besoin (écrans qui prennent un objet en paramètre).
struct ScreenSnapshotSeedHandles {
    let tafPlace: Place
    let coursPlace: Place
    let ongoingSession: WorkSession
    let doubtSession: WorkSession
    let employer: Employer
    let contract: Contract
}

/// Jeu d'exemple de la maquette (design/prototype/README.md, "Données d'exemple communes").
/// Tout est calculé à partir de `now` : "maintenant" vaut 19:10 dans la maquette, ici c'est l'heure réelle de la CI,
/// et les écarts sont gardés (taf en cours depuis 1 h 14, cours de 3 h 57, etc.). Les écrans lisent Date() eux-mêmes,
/// donc on ne peut pas figer l'horloge : c'est pour cela que les données sont relatives à `now`.
@MainActor
enum ScreenSnapshotSeed {

    static func seed(into container: ModelContainer, now: Date, calendar: Calendar) throws -> ScreenSnapshotSeedHandles {
        let context: ModelContext = container.mainContext
        let today: Date = calendar.startOfDay(for: now)

        func day(_ offset: Int, _ hour: Int, _ minute: Int) -> Date {
            let base: Date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        func ago(minutes: Int) -> Date {
            return now.addingTimeInterval(-Double(minutes) * 60.0)
        }

        // Lieux
        let taf: Place = Place(name: "Supérette du Canal", type: .taf, latitude: 48.8885, longitude: 2.3695,
                               radius: 100, address: "12 quai de la Loire, 75019 Paris")
        let cours: Place = Place(name: "Fac de lettres", type: .cours, latitude: 48.8466, longitude: 2.3446,
                                 radius: 150, address: "1 rue Victor Cousin, 75005 Paris")
        let courses: Place = Place(name: "Marché du Canal", type: .courses, latitude: 48.8879, longitude: 2.3711,
                                   radius: 80, address: "Place de la Bataille de Stalingrad, 75019 Paris")
        context.insert(taf)
        context.insert(cours)
        context.insert(courses)

        // Aujourd'hui (lundi 16 novembre dans la maquette)
        let ongoing: WorkSession = WorkSession(activity: .work, start: ago(minutes: 74), end: nil,
                                               place: taf, source: .gps, isConfirmed: true)
        let morningCourse: WorkSession = WorkSession(activity: .education,
                                                     start: ago(minutes: 11 * 60 + 5), end: ago(minutes: 7 * 60 + 8),
                                                     place: cours, source: .gps, isConfirmed: true)
        let errand: WorkSession = WorkSession(activity: .shopping,
                                              start: ago(minutes: 6 * 60 + 50), end: ago(minutes: 6 * 60 + 25),
                                              place: courses, source: .gps, isConfirmed: true)
        context.insert(ongoing)
        context.insert(morningCourse)
        context.insert(errand)

        // Jours précédents. Hier : un début à 14:28 tombe dans la zone de doute (écran Doute).
        let doubt: WorkSession = WorkSession(activity: .work, start: day(-1, 14, 28), end: day(-1, 18, 3),
                                             place: taf, source: .gps, isConfirmed: true)
        let earlier: [WorkSession] = [
            doubt,
            WorkSession(activity: .education, start: day(-1, 8, 5), end: day(-1, 11, 58), place: cours, source: .gps),
            WorkSession(activity: .work, start: day(-2, 17, 58), end: day(-2, 21, 2), place: taf, source: .gps),
            WorkSession(activity: .education, start: day(-3, 8, 10), end: day(-3, 12, 0), place: cours, source: .gps),
            WorkSession(activity: .work, start: day(-3, 17, 55), end: day(-3, 21, 0), place: taf, source: .manual),
            WorkSession(activity: .work, start: day(-5, 18, 0), end: day(-5, 21, 5), place: taf, source: .gps),
            WorkSession(activity: .education, start: day(-6, 8, 0), end: day(-6, 12, 3), place: cours, source: .gps)
        ]
        for s in earlier { context.insert(s) }

        // Employeur, contrat de 13 h par semaine (CDD jusqu'au 9 décembre 2026) et taux horaire
        let employer: Employer = Employer(name: "Supérette du Canal")
        employer.colorHex = "work"
        var startParts: DateComponents = DateComponents()
        startParts.year = 2026
        startParts.month = 9
        startParts.day = 1
        var endParts: DateComponents = DateComponents()
        endParts.year = 2026
        endParts.month = 12
        endParts.day = 9
        let contractStart: Date = calendar.date(from: startParts) ?? today
        let contractEnd: Date = calendar.date(from: endParts) ?? today
        let contract: Contract = Contract(kind: .cdd, startDate: contractStart, endDate: contractEnd,
                                          weeklyHours: 13, employer: employer)
        contract.hourlyGrossRate = 12.0
        contract.placeUIDs = [taf.uid]
        context.insert(employer)
        context.insert(contract)
        context.insert(PayRate(contractUID: contract.uid, effectiveDate: contractStart, hourlyGross: 12.0))

        // Planning : 18:00 à 21:00 au taf plusieurs soirs, dont aujourd'hui
        let planned: [PlannedShift] = [
            PlannedShift(start: day(-3, 18, 0), end: day(-3, 21, 0), activity: .work, placeUID: taf.uid, employerUID: employer.uid),
            PlannedShift(start: day(-2, 18, 0), end: day(-2, 21, 0), activity: .work, placeUID: taf.uid, employerUID: employer.uid),
            PlannedShift(start: day(0, 18, 0), end: day(0, 21, 0), activity: .work, placeUID: taf.uid, employerUID: employer.uid),
            PlannedShift(start: day(1, 18, 0), end: day(1, 21, 0), activity: .work, placeUID: taf.uid, employerUID: employer.uid),
            PlannedShift(start: day(3, 18, 0), end: day(3, 21, 0), activity: .work, placeUID: taf.uid, employerUID: employer.uid),
            PlannedShift(start: day(8, 18, 0), end: day(8, 21, 0), activity: .work, placeUID: taf.uid, employerUID: employer.uid)
        ]
        for p in planned { context.insert(p) }

        // Un congé payé à venir
        context.insert(LeaveEntry(startDay: day(10, 0, 0), endDay: day(11, 0, 0), kindRaw: "paid",
                                  note: "", employerUID: employer.uid))

        // Journal de détection (écrans Diagnostic et Lieu)
        let events: [DetectionEvent] = [
            DetectionEvent(kind: .monitoringStarted, date: ago(minutes: 12 * 60), detail: "3 lieux surveillés"),
            DetectionEvent(kind: .regionEntered, date: ago(minutes: 76), placeName: taf.name, placeUID: taf.uid, accuracyMeters: 18),
            DetectionEvent(kind: .arrivalConfirmed, date: ago(minutes: 74), placeName: taf.name, placeUID: taf.uid,
                           detail: "Arrivée confirmée", accuracyMeters: 12),
            DetectionEvent(kind: .sessionStarted, date: ago(minutes: 74), placeName: taf.name, placeUID: taf.uid),
            DetectionEvent(kind: .ignoredShortVisit, date: ago(minutes: 6 * 60 + 20), placeName: courses.name,
                           placeUID: courses.uid, detail: "Visite courte")
        ]
        for e in events { context.insert(e) }

        try context.save()
        return ScreenSnapshotSeedHandles(tafPlace: taf, coursPlace: cours, ongoingSession: ongoing,
                                         doubtSession: doubt, employer: employer, contract: contract)
    }
}
