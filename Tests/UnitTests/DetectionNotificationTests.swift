import XCTest
@testable import PersonalLifeTracker

final class DetectionNotificationTests: XCTestCase {
    private let utc = TestCalendar.utc

    func testArrivalTextOutsideDoubtZone() {
        let t = DetectionNotificationRules.text(kind: .arrival, placeName: "Taf", placeType: .taf,
                                                bound: nov16(17, 56), calendar: utc)
        XCTAssertEqual(t.body, "T'es arrivé au taf à 17:56, c'est bon ?")
        XCTAssertEqual(t.title, "Arrivée détectée")
    }

    func testDepartureTextOutsideDoubtZone() {
        let t = DetectionNotificationRules.text(kind: .departure, placeName: "Supérette du Canal", placeType: .taf,
                                                bound: nov16(22, 3), calendar: utc)
        XCTAssertEqual(t.body, "T'es parti du taf (Supérette du Canal) à 22:03, c'est bon ?")
    }

    func testCoursesAndCoursPhrases() {
        XCTAssertEqual(DetectionNotificationRules.placePhraseAt(name: "Lycée Pasteur", type: .cours), "en cours (Lycée Pasteur)")
        XCTAssertEqual(DetectionNotificationRules.placePhraseFrom(name: "Lycée Pasteur", type: .cours), "du cours (Lycée Pasteur)")
        XCTAssertEqual(DetectionNotificationRules.placePhraseAt(name: "Carrefour", type: .courses), "à Carrefour")
        XCTAssertEqual(DetectionNotificationRules.placePhraseFrom(name: "Carrefour", type: .courses), "de Carrefour")
    }

    func testDoubtZoneBoundaries() {
        XCTAssertFalse(DetectionNotificationRules.isInDoubtZone(nov16(6, 14), calendar: utc))
        XCTAssertTrue(DetectionNotificationRules.isInDoubtZone(nov16(6, 15), calendar: utc))
        XCTAssertTrue(DetectionNotificationRules.isInDoubtZone(nov16(6, 45), calendar: utc))
        XCTAssertFalse(DetectionNotificationRules.isInDoubtZone(nov16(6, 46), calendar: utc))
        XCTAssertFalse(DetectionNotificationRules.isInDoubtZone(nov16(7, 0), calendar: utc))
    }

    func testDoubtTextAsksToChooseHour() {
        let a = DetectionNotificationRules.text(kind: .arrival, placeName: "Taf", placeType: .taf,
                                                bound: nov16(17, 30), calendar: utc)
        XCTAssertEqual(a.body, "Ton arrivée au taf est vers 17:30. Tu choisis l'heure ?")
        let d = DetectionNotificationRules.text(kind: .departure, placeName: "Taf", placeType: .taf,
                                                bound: nov16(22, 15), calendar: utc)
        XCTAssertEqual(d.body, "Ton départ du taf est vers 22:15. Tu choisis l'heure ?")
    }

    func testTextUsesCalendarTimeZone() {
        // 17:56 UTC est 18:56 à Paris en novembre (UTC+1).
        let t = DetectionNotificationRules.text(kind: .arrival, placeName: "Taf", placeType: .taf,
                                                bound: nov16(17, 56), calendar: TestCalendar.paris)
        XCTAssertEqual(t.body, "T'es arrivé au taf à 18:56, c'est bon ?")
    }

    func testNoEmDashInTexts() {
        let t = DetectionNotificationRules.text(kind: .departure, placeName: "Lycée", placeType: .cours,
                                                bound: nov16(16, 50), calendar: utc)
        XCTAssertFalse(t.body.contains("\u{2014}"))
        XCTAssertFalse(t.title.contains("\u{2014}"))
    }

    func testQuietHoursBoundaries() {
        XCTAssertTrue(DetectionNotificationRules.isQuietHour(nov16(4, 59), calendar: utc))
        XCTAssertFalse(DetectionNotificationRules.isQuietHour(nov16(5, 0), calendar: utc))
        XCTAssertFalse(DetectionNotificationRules.isQuietHour(nov16(21, 59), calendar: utc))
        XCTAssertTrue(DetectionNotificationRules.isQuietHour(nov16(22, 0), calendar: utc))
        XCTAssertTrue(DetectionNotificationRules.isQuietHour(nov16(0, 0), calendar: utc))
    }

    func testVerdictQuietHours() {
        XCTAssertEqual(DetectionNotificationRules.verdict(now: nov16(23, 30), sentDates: [], calendar: utc), .quietHours)
    }

    func testVerdictDailyLimit() {
        var sent: [Date] = []
        for h in 6..<11 { sent.append(nov16(h, 0)) }          // 5 envoyées
        XCTAssertEqual(DetectionNotificationRules.verdict(now: nov16(12, 0), sentDates: sent, calendar: utc), .send)
        sent.append(nov16(11, 0))                              // 6 envoyées
        XCTAssertEqual(DetectionNotificationRules.verdict(now: nov16(12, 0), sentDates: sent, calendar: utc), .dailyLimitReached)
    }

    func testDailyLimitCountsOnlyTheSameDay() {
        var sent: [Date] = []
        for h in 6..<12 { sent.append(nov16(h, 0)) }           // 6 la veille
        XCTAssertEqual(DetectionNotificationRules.verdict(now: nov17(8, 0), sentDates: sent, calendar: utc), .send)
    }

    func testDayBoundaryUsesCalendarTimeZone() {
        let now: Date = makeDate(TestCalendar.paris, 2026, 11, 17, 9, 0)
        // 22:30 UTC le 16 est 23:30 à Paris le 16 : jour précédent pour l'utilisateur, la limite ne s'applique pas.
        var before: [Date] = []
        for m in 30..<36 { before.append(nov16(22, m)) }
        XCTAssertEqual(DetectionNotificationRules.verdict(now: now, sentDates: before, calendar: TestCalendar.paris), .send)
        // 23:30 UTC le 16 est 00:30 à Paris le 17 : même jour que `now`, la limite s'applique.
        var same: [Date] = []
        for m in 30..<36 { same.append(nov16(23, m)) }
        XCTAssertEqual(DetectionNotificationRules.verdict(now: now, sentDates: same, calendar: TestCalendar.paris), .dailyLimitReached)
        XCTAssertEqual(DetectionNotificationRules.maxPerDay, 6)
    }

    func testPendingCorrectionStoreRoundTrip() {
        let isolated = makeIsolatedDefaults()
        defer { isolated.defaults.removePersistentDomain(forName: isolated.name) }
        let store = PendingCorrectionStore(defaults: isolated.defaults)
        XCTAssertNil(store.sessionUID)
        let uid = UUID()
        store.set(uid)
        XCTAssertEqual(store.sessionUID, uid)
        store.clear()
        XCTAssertNil(store.sessionUID)
    }
}
