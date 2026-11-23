import XCTest
@testable import PersonalLifeTracker

/// Section 140 : ClockChecker (pur). Les valeurs sont calculées à la main : écart mural moins écart monotone.
final class ClockCheckTests: XCTestCase {
    private func obs(_ wall: Date, uptime: TimeInterval, zone: String = "UTC", offset: Int = 0) -> ClockObservation {
        return ClockObservation(wall: wall, uptime: uptime, timeZoneID: zone, utcOffsetSeconds: offset)
    }

    func testFirstObservationHasNothingToCompare() {
        let r = ClockChecker.compare(previous: nil, current: obs(nov16(10, 0), uptime: 1000))
        XCTAssertTrue(r.isClean)
        XCTAssertFalse(r.rebootDetected)
    }

    func testConsistentClocksAreClean() {
        // 10 minutes réelles des deux côtés.
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000), current: obs(nov16(10, 10), uptime: 1600))
        XCTAssertTrue(r.isClean)
    }

    func testForwardJumpOfFourMinutes() {
        // Mural +14 min (840 s), monotone +10 min (600 s) : l'heure a avancé de 240 s.
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000), current: obs(nov16(10, 14), uptime: 1600))
        guard let jump = r.jump else {
            XCTFail("un saut avant de 4 min était attendu")
            return
        }
        XCTAssertEqual(jump.shiftSeconds, 240, accuracy: 0.001)
        XCTAssertEqual(jump.direction, .forward)
        XCTAssertEqual(jump.windowStart, nov16(10, 0))
        XCTAssertEqual(jump.windowEnd, nov16(10, 14))
        XCTAssertEqual(ClockText.jumpTitle(jump), "Ton horloge semble décalée de 4 min")
    }

    func testBackwardJumpOfOneHour() {
        // Mural -50 min (écart -3000 s) alors que le monotone a avancé de 10 min : -3600 s.
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000), current: obs(nov16(9, 10), uptime: 1600))
        guard let jump = r.jump else {
            XCTFail("un saut arrière d'une heure était attendu")
            return
        }
        XCTAssertEqual(jump.shiftSeconds, -3600, accuracy: 0.001)
        XCTAssertEqual(jump.direction, .backward)
        XCTAssertEqual(jump.windowStart, nov16(9, 10), "fenêtre triée même si le temps a reculé")
        XCTAssertEqual(jump.windowEnd, nov16(10, 0))
    }

    func testDriftWithinToleranceIsIgnored() {
        // Écart de 30 s exactement : toléré (le seuil est strict).
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000), current: obs(nov16(10, 10, 30), uptime: 1600))
        XCTAssertNil(r.jump)
        let backward = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000), current: obs(nov16(10, 9, 30), uptime: 1600))
        XCTAssertNil(backward.jump)
    }

    func testOneSecondBeyondToleranceIsAJump() {
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000), current: obs(nov16(10, 10, 31), uptime: 1600))
        XCTAssertEqual(r.jump?.shiftSeconds ?? 0, 31, accuracy: 0.001)
    }

    func testCustomTolerance() {
        let prev = obs(nov16(10, 0), uptime: 1000)
        let cur = obs(nov16(10, 11), uptime: 1600)
        XCTAssertNil(ClockChecker.compare(previous: prev, current: cur, toleranceSeconds: 60).jump, "60 s d'écart, seuil 60 s")
        XCTAssertNotNil(ClockChecker.compare(previous: prev, current: cur, toleranceSeconds: 59).jump)
    }

    func testRebootIsUnknownNotAJump() {
        // Le monotone est repassé de 50 000 à 90 : redémarrage. Le mural a avancé de 2 h, ce n'est pas un saut.
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 50_000), current: obs(nov16(12, 0), uptime: 90))
        XCTAssertTrue(r.rebootDetected)
        XCTAssertNil(r.jump)
        XCTAssertNil(r.timeZoneChange)
    }

    func testTimeZoneChange() {
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000, zone: "Europe/Paris", offset: 3600),
                                     current: obs(nov16(10, 10), uptime: 1600, zone: "America/New_York", offset: -18000))
        XCTAssertNil(r.jump)
        XCTAssertEqual(r.timeZoneChange?.kind, .zone)
        XCTAssertEqual(r.timeZoneChange?.fromOffsetSeconds, 3600)
        XCTAssertEqual(r.timeZoneChange?.toOffsetSeconds, -18000)
        XCTAssertFalse(r.isClean)
    }

    func testDaylightSavingChangeKeepsSameZoneID() {
        let r = ClockChecker.compare(previous: obs(nov16(10, 0), uptime: 1000, zone: "Europe/Paris", offset: 7200),
                                     current: obs(nov16(10, 10), uptime: 1600, zone: "Europe/Paris", offset: 3600))
        XCTAssertNil(r.jump, "l'instant n'a pas bougé, seul le décalage change")
        XCTAssertEqual(r.timeZoneChange?.kind, .daylightSaving)
    }

    func testRealParisDaylightSavingOffsetsFromObservationHelper() {
        // Passage à l'heure d'hiver 2026 : 25 octobre 2026. Avant 02:00 UTC+2, après UTC+1.
        let paris = TimeZone(identifier: "Europe/Paris")!
        let summer = ClockChecker.observation(wall: makeDate(TestCalendar.utc, 2026, 10, 24, 12, 0), uptime: 10, timeZone: paris)
        let winter = ClockChecker.observation(wall: makeDate(TestCalendar.utc, 2026, 10, 26, 12, 0), uptime: 10 + 172_800, timeZone: paris)
        XCTAssertEqual(summer.utcOffsetSeconds, 7200)
        XCTAssertEqual(winter.utcOffsetSeconds, 3600)
        let r = ClockChecker.compare(previous: summer, current: winter)
        XCTAssertNil(r.jump)
        XCTAssertEqual(r.timeZoneChange?.kind, .daylightSaving)
    }

    // MARK: Sessions concernées

    func testSessionsSpanningTheJumpWindow() {
        let jump = ClockJump(shiftSeconds: 240, direction: .forward, windowStart: nov16(10, 0), windowEnd: nov16(10, 14))
        let now = nov16(12, 0)
        XCTAssertTrue(ClockChecker.isAffected(sessionStart: nov16(9, 0), sessionEnd: nov16(11, 0), jump: jump, now: now), "chevauche")
        XCTAssertTrue(ClockChecker.isAffected(sessionStart: nov16(9, 0), sessionEnd: nil, jump: jump, now: now), "en cours")
        XCTAssertTrue(ClockChecker.isAffected(sessionStart: nov16(10, 5), sessionEnd: nov16(10, 8), jump: jump, now: now), "dedans")
        XCTAssertFalse(ClockChecker.isAffected(sessionStart: nov16(8, 0), sessionEnd: nov16(9, 59), jump: jump, now: now), "finie avant")
        XCTAssertFalse(ClockChecker.isAffected(sessionStart: nov16(10, 15), sessionEnd: nov16(11, 0), jump: jump, now: now), "commence après")
    }

    // MARK: Textes et seuil réglable

    func testTextFormats() {
        XCTAssertEqual(ClockText.magnitude(seconds: 45), "45 s")
        XCTAssertEqual(ClockText.magnitude(seconds: -240), "4 min")
        XCTAssertEqual(ClockText.magnitude(seconds: 3900), "1 h 05")
        XCTAssertEqual(ClockText.offset(3600), "UTC+1")
        XCTAssertEqual(ClockText.offset(-18000), "UTC-5")
        XCTAssertEqual(ClockText.offset(19800), "UTC+5:30")
    }

    func testStoreToleranceDefaultAndOverride() {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let store = ClockCheckStore(defaults: iso.defaults)
        XCTAssertEqual(store.toleranceSeconds, 30)
        iso.defaults.set(120.0, forKey: ClockCheckStore.toleranceKey)
        XCTAssertEqual(store.toleranceSeconds, 120)
    }

    func testAlertDismissIsPersisted() {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let store = ClockCheckStore(defaults: iso.defaults)
        let alert = ClockAlert(id: UUID(), detectedAt: nov16(10, 14), jump: nil, timeZoneChange: nil, affectedSessionCount: 0, isDismissed: false)
        store.saveAlert(alert)
        XCTAssertEqual(store.loadAlert()?.isDismissed, false)
        store.dismissAlert()
        XCTAssertEqual(store.loadAlert()?.isDismissed, true)
    }
}
