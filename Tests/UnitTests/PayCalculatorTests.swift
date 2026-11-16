import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues calculées à la main (UTC, novembre 2026). Montants en centimes entiers.
/// Les tests qui citent le SMIC (12,02 au 1er janvier 2026) devront être mis à jour avec la constante quand le SMIC change.
final class PayCalculatorTests: XCTestCase {
    private let cal: Calendar = TestCalendar.utc

    private func dec(_ s: String) -> Decimal {
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        return makeDate(cal, y, m, day, h, min)
    }

    private func session(_ start: Date, _ end: Date?, chosenStart: Date? = nil, chosenEnd: Date? = nil, confirmed: Bool = true) -> PaySessionInput {
        return PaySessionInput(start: start, end: end, chosenStart: chosenStart, chosenEnd: chosenEnd, isConfirmed: confirmed)
    }

    private func rate(_ date: Date, _ value: String) -> PayRateEntry {
        return PayRateEntry(effectiveDate: date, hourlyGross: dec(value))
    }

    private func month(_ year: Int, _ m: Int, _ sessions: [PaySessionInput], _ rates: [PayRateEntry],
                       base: CalculationBase = .fullHours, ratio: String = "0.79", now: Date? = nil) -> PayMonthResult {
        return PayCalculator.month(year: year, month: m, sessions: sessions, rates: rates, base: base,
                                   netRatio: dec(ratio), now: now ?? d(2026, 12, 1), calendar: cal)
    }

    // MARK: totaux simples

    func testFullHoursMonthGrossAndNet() {
        // 08:05 à 12:02 donne 08:00 à 12:00 = 4 h. Puis 4 h et 3 h. Total 11 h = 39600 s. Exact : 14220 + 14400 + 10800 = 39420 s.
        let sessions = [session(d(2026, 11, 3, 8, 5), d(2026, 11, 3, 12, 2)),
                        session(d(2026, 11, 4, 9, 0), d(2026, 11, 4, 13, 0)),
                        session(d(2026, 11, 5, 14, 0), d(2026, 11, 5, 17, 0))]
        let r = month(2026, 11, sessions, [rate(d(2026, 10, 1), "12.02")])
        XCTAssertEqual(r.retainedSeconds, 39600)
        XCTAssertEqual(r.fullHoursSeconds, 39600)
        XCTAssertEqual(r.exactSeconds, 39420)
        XCTAssertEqual(r.sessionCount, 3)
        // 11 h x 12,02 = 132,22
        XCTAssertEqual(r.grossCents, 13222)
        // 13222 x 0,79 = 10445,38 centimes, arrondi à 10445
        XCTAssertEqual(r.netCents, 10445)
        XCTAssertEqual(r.days.count, 3)
        XCTAssertEqual(r.rateLines.count, 1)
        XCTAssertEqual(r.unratedSeconds, 0)
    }

    func testExactBaseUsesExactSeconds() {
        let sessions = [session(d(2026, 11, 3, 8, 5), d(2026, 11, 3, 12, 2)),
                        session(d(2026, 11, 4, 9, 0), d(2026, 11, 4, 13, 0)),
                        session(d(2026, 11, 5, 14, 0), d(2026, 11, 5, 17, 0))]
        let r = month(2026, 11, sessions, [rate(d(2026, 10, 1), "12.02")], base: .exact)
        XCTAssertEqual(r.retainedSeconds, 39420)
        // 39420 s = 10,95 h x 12,02 = 131,619 donne 131,62
        XCTAssertEqual(r.grossCents, 13162)
        XCTAssertEqual(r.fullHoursSeconds, 39600)
    }

    func testZeroSessions() {
        let r = month(2026, 11, [], [rate(d(2026, 10, 1), "12.02")])
        XCTAssertEqual(r.retainedSeconds, 0)
        XCTAssertEqual(r.grossCents, 0)
        XCTAssertEqual(r.netCents, 0)
        XCTAssertEqual(r.sessionCount, 0)
        XCTAssertFalse(r.hasAnySession)
        XCTAssertTrue(r.days.isEmpty)
        XCTAssertTrue(r.rateLines.isEmpty)
    }

    func testSessionsOfOtherMonthsDoNotCount() {
        let sessions = [session(d(2026, 10, 20, 8, 0), d(2026, 10, 20, 12, 0)),
                        session(d(2026, 12, 2, 8, 0), d(2026, 12, 2, 12, 0))]
        let r = month(2026, 11, sessions, [rate(d(2026, 10, 1), "12.02")])
        XCTAssertEqual(r.sessionCount, 0)
        XCTAssertEqual(r.retainedSeconds, 0)
    }

    // MARK: frontières de mois et minuit

    func testSessionAcrossMonthBoundaryIsSplitBetweenMonths() {
        // 31 octobre 22:00 à 1er novembre 02:00 : 2 h en octobre, 2 h en novembre.
        // 30 novembre 23:00 à 1er décembre 01:00 : 1 h en novembre, 1 h en décembre.
        let sessions = [session(d(2026, 10, 31, 22, 0), d(2026, 11, 1, 2, 0)),
                        session(d(2026, 11, 30, 23, 0), d(2026, 12, 1, 1, 0))]
        let rates = [rate(d(2026, 1, 1), "10.00")]
        let nov = month(2026, 11, sessions, rates)
        XCTAssertEqual(nov.retainedSeconds, 10800)         // 2 h + 1 h
        XCTAssertEqual(nov.grossCents, 3000)                // 3 h x 10,00
        XCTAssertEqual(nov.sessionCount, 2)
        let oct = month(2026, 10, sessions, rates)
        XCTAssertEqual(oct.retainedSeconds, 7200)           // 22:00 à 24:00 le 31
        XCTAssertEqual(oct.grossCents, 2000)
        XCTAssertEqual(oct.sessionCount, 1)
        let december = month(2026, 12, sessions, rates)
        XCTAssertEqual(december.retainedSeconds, 3600)
        XCTAssertEqual(december.grossCents, 1000)
    }

    func testSessionAcrossMidnightRoundsThenSplitsByDay() {
        // 21:50 donne 22:00, 02:10 donne 02:00. Jour 10 : 22:00 à 24:00 = 2 h. Jour 11 : 00:00 à 02:00 = 2 h.
        // Exact : 21:50 à 02:10 = 4 h 20 = 15600 s, soit 7800 s par jour.
        let s = session(d(2026, 11, 10, 21, 50), d(2026, 11, 11, 2, 10))
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "10.00")])
        XCTAssertEqual(r.retainedSeconds, 14400)
        XCTAssertEqual(r.exactSeconds, 15600)
        XCTAssertEqual(r.days.count, 2)
        XCTAssertEqual(r.days[0].retainedSeconds, 7200)
        XCTAssertEqual(r.days[1].retainedSeconds, 7200)
        XCTAssertEqual(r.days[0].exactSeconds, 7800)
        XCTAssertEqual(r.sessionCount, 1)
        XCTAssertEqual(r.grossCents, 4000)
    }

    // MARK: taux

    func testRateChangeInTheMiddleOfTheMonth() {
        // 12,00 jusqu'au 15 inclus, 13,00 à partir du 16 (date d'effet à 00:00).
        let rates = [rate(d(2026, 1, 1), "12.00"), rate(d(2026, 11, 16), "13.00")]
        let sessions = [session(d(2026, 11, 10, 8, 0), d(2026, 11, 10, 12, 0)),    // 4 h à 12,00
                        session(d(2026, 11, 15, 23, 0), d(2026, 11, 16, 1, 0)),    // 1 h le 15 à 12,00, 1 h le 16 à 13,00
                        session(d(2026, 11, 16, 8, 0), d(2026, 11, 16, 12, 0)),    // 4 h à 13,00
                        session(d(2026, 11, 20, 8, 0), d(2026, 11, 20, 10, 0))]    // 2 h à 13,00
        let r = month(2026, 11, sessions, rates)
        XCTAssertEqual(r.rateLines.count, 2)
        XCTAssertEqual(r.rateLines[0].hourlyGross, dec("12.00"))
        XCTAssertEqual(r.rateLines[0].seconds, 18000)      // 5 h
        XCTAssertEqual(r.rateLines[0].grossCents, 6000)    // 5 x 12
        XCTAssertEqual(r.rateLines[1].hourlyGross, dec("13.00"))
        XCTAssertEqual(r.rateLines[1].seconds, 25200)      // 7 h
        XCTAssertEqual(r.rateLines[1].grossCents, 9100)    // 7 x 13
        XCTAssertEqual(r.grossCents, 15100)
        XCTAssertEqual(r.netCents, 11929)                  // 15100 x 0,79 = 11929,00
    }

    func testPastMonthDoesNotChangeWhenANewRateIsAdded() {
        let sessions = [session(d(2026, 10, 20, 8, 0), d(2026, 10, 20, 12, 0))]
        let before = month(2026, 10, sessions, [rate(d(2026, 1, 1), "12.00")])
        let after = month(2026, 10, sessions, [rate(d(2026, 1, 1), "12.00"), rate(d(2026, 11, 16), "13.00")])
        XCTAssertEqual(before.grossCents, 4800)
        XCTAssertEqual(after.grossCents, 4800)
    }

    func testRateOnDayUsesStartOfEffectiveDayAndNilBeforeFirstRate() {
        let rates = [rate(d(2026, 11, 16, 14, 30), "13.00"), rate(d(2026, 1, 1), "12.00")]
        XCTAssertEqual(PayCalculator.rate(on: d(2026, 11, 16, 8, 0), rates: rates, calendar: cal), dec("13.00"))
        XCTAssertEqual(PayCalculator.rate(on: d(2026, 11, 15, 23, 59), rates: rates, calendar: cal), dec("12.00"))
        XCTAssertNil(PayCalculator.rate(on: d(2025, 12, 31, 12, 0), rates: rates, calendar: cal))
        XCTAssertNil(PayCalculator.rate(on: d(2026, 11, 16), rates: [], calendar: cal))
    }

    func testHoursBeforeFirstRateAreCountedButNotPaid() {
        let rates = [rate(d(2026, 11, 10), "10.00")]
        let sessions = [session(d(2026, 11, 5, 8, 0), d(2026, 11, 5, 10, 0)),
                        session(d(2026, 11, 12, 8, 0), d(2026, 11, 12, 10, 0))]
        let r = month(2026, 11, sessions, rates)
        XCTAssertEqual(r.retainedSeconds, 14400)
        XCTAssertEqual(r.unratedSeconds, 7200)
        XCTAssertEqual(r.grossCents, 2000)                 // seulement 2 h x 10,00
        XCTAssertEqual(r.rateLines.count, 1)
        XCTAssertNil(r.days[0].hourlyGross)
        XCTAssertEqual(r.days[1].hourlyGross, dec("10.00"))
    }

    func testNoRateGivesNoAmount() {
        let r = month(2026, 11, [session(d(2026, 11, 5, 8, 0), d(2026, 11, 5, 10, 0))], [])
        XCTAssertEqual(r.retainedSeconds, 7200)
        XCTAssertEqual(r.unratedSeconds, 7200)
        XCTAssertEqual(r.grossCents, 0)
        XCTAssertFalse(r.hasRate)
    }

    // MARK: zone de doute, en cours, non confirmées

    func testDoubtSessionIsCountedExactAndFlagged() {
        // 17:56 donne 18:00, 21:20 est en zone de doute sans choix : exact 17:56 à 21:20 = 3 h 24 = 12240 s.
        let s = session(d(2026, 11, 5, 17, 56), d(2026, 11, 5, 21, 20))
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "10.00")])
        XCTAssertEqual(r.retainedSeconds, 12240)
        XCTAssertEqual(r.doubtSessionCount, 1)
        XCTAssertTrue(r.days[0].isProvisional)
        // 12240 s = 3,4 h x 10,00 = 34,00
        XCTAssertEqual(r.grossCents, 3400)
    }

    func testDoubtResolvedByChoiceIsNotFlagged() {
        // Choix de 21:00 pour la fin : 17:56 donne 18:00, fin 21:00 = 3 h = 10800 s.
        let s = session(d(2026, 11, 5, 17, 56), d(2026, 11, 5, 21, 20), chosenEnd: d(2026, 11, 5, 21, 0))
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "10.00")])
        XCTAssertEqual(r.retainedSeconds, 10800)
        XCTAssertEqual(r.doubtSessionCount, 0)
        XCTAssertFalse(r.days[0].isProvisional)
        XCTAssertEqual(r.grossCents, 3000)
    }

    func testDoubtIsNotFlaggedInExactBase() {
        let s = session(d(2026, 11, 5, 17, 56), d(2026, 11, 5, 21, 20))
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "10.00")], base: .exact)
        XCTAssertEqual(r.retainedSeconds, 12240)
        XCTAssertEqual(r.doubtSessionCount, 0)
        XCTAssertFalse(r.days[0].isProvisional)
    }

    func testUnconfirmedSessionsAreExcludedAndCounted() {
        let sessions = [session(d(2026, 11, 5, 8, 0), d(2026, 11, 5, 10, 0)),
                        session(d(2026, 11, 6, 8, 0), d(2026, 11, 6, 10, 0), confirmed: false)]
        let r = month(2026, 11, sessions, [rate(d(2026, 1, 1), "10.00")])
        XCTAssertEqual(r.retainedSeconds, 7200)
        XCTAssertEqual(r.sessionCount, 1)
        XCTAssertEqual(r.unconfirmedSessionCount, 1)
        XCTAssertEqual(r.grossCents, 2000)
    }

    func testLiveSessionCountsExactUntilNow() {
        // Début 08:00, maintenant 10:30 : 2 h 30 = 9000 s, 2,5 h x 10,00 = 25,00.
        let s = session(d(2026, 11, 16, 8, 0), nil)
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "10.00")], now: d(2026, 11, 16, 10, 30))
        XCTAssertEqual(r.retainedSeconds, 9000)
        XCTAssertEqual(r.liveSessionCount, 1)
        XCTAssertTrue(r.days[0].hasLive)
        XCTAssertEqual(r.grossCents, 2500)
    }

    // MARK: arrondis

    func testRoundingToCents() {
        // Exact : 08:00 à 08:20 = 1200 s, 12,02 / 3 = 4,00666 donne 4,01.
        let s = session(d(2026, 11, 5, 8, 0), d(2026, 11, 5, 8, 20))
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "12.02")], base: .exact)
        XCTAssertEqual(r.grossCents, 401)
    }

    func testNetHalfCentRoundsUp() {
        // 3 minutes à 10,00 = 0,50 brut. 50 x 0,79 = 39,5 centimes, arrondi commercial à 40.
        let s = session(d(2026, 11, 5, 8, 0), d(2026, 11, 5, 8, 3))
        let r = month(2026, 11, [s], [rate(d(2026, 1, 1), "10.00")], base: .exact)
        XCTAssertEqual(r.grossCents, 50)
        XCTAssertEqual(r.netCents, 40)
    }

    func testRoundedCentsAvoidsBinaryErrors() {
        XCTAssertEqual(PayMath.roundedCents(dec("0.005")), 1)
        XCTAssertEqual(PayMath.roundedCents(dec("0.004")), 0)
        XCTAssertEqual(PayMath.roundedCents(dec("2.675")), 268)   // en binaire, 2.675 donnerait 2,67
        XCTAssertEqual(PayMath.roundedCents(dec("1.005")), 101)   // en binaire, 1.005 donnerait 1,00
        XCTAssertEqual(PayMath.roundedCents(dec("348.58")), 34858)
    }

    func testDecimalFromDoubleIsClean() {
        XCTAssertEqual(PayMath.decimal(0.79), dec("0.79"))
        XCTAssertEqual(PayMath.decimal(12.02), dec("12.02"))
        XCTAssertEqual(PayMath.decimal(11.88), dec("11.88"))
    }

    // MARK: saisie et conversions

    func testParseAmount() {
        XCTAssertEqual(PayCalculator.parseAmount("12,02"), dec("12.02"))
        XCTAssertEqual(PayCalculator.parseAmount("12.02"), dec("12.02"))
        XCTAssertEqual(PayCalculator.parseAmount(" 12 "), dec("12"))
        XCTAssertEqual(PayCalculator.parseAmount("12,0215"), dec("12.0215"))
        XCTAssertEqual(PayCalculator.parseAmount("999,99"), dec("999.99"))
        XCTAssertNil(PayCalculator.parseAmount("12,02156"))
        XCTAssertNil(PayCalculator.parseAmount(""))
        XCTAssertNil(PayCalculator.parseAmount("abc"))
        XCTAssertNil(PayCalculator.parseAmount("0"))
        XCTAssertNil(PayCalculator.parseAmount("-5"))
        XCTAssertNil(PayCalculator.parseAmount("1000"))
        XCTAssertNil(PayCalculator.parseAmount("1,2,3"))
        XCTAssertNil(PayCalculator.parseAmount("12,02 €"))
        XCTAssertNil(PayCalculator.parseAmount("."))
    }

    func testGrossNetConversion() {
        // 9,50 / 0,79 = 12,025316... arrondi à 4 décimales : 12,0253
        XCTAssertEqual(PayCalculator.grossFromNet(net: dec("9.50"), ratio: dec("0.79")), dec("12.0253"))
        // 12,02 x 0,79 = 9,4958
        XCTAssertEqual(PayCalculator.netFromGross(gross: dec("12.02"), ratio: dec("0.79")), dec("9.4958"))
    }

    func testPercentChange() {
        // (12,02 - 11,88) / 11,88 = 1,1784 %, arrondi à 1,2
        XCTAssertEqual(PayCalculator.percentChange(from: dec("11.88"), to: dec("12.02")), dec("1.2"))
        XCTAssertEqual(PayCalculator.percentChange(from: dec("10"), to: dec("10")), dec("0"))
        // (10 - 12) / 12 = -16,666 %, arrondi à -16,7
        XCTAssertEqual(PayCalculator.percentChange(from: dec("12"), to: dec("10")), dec("-16.7"))
        XCTAssertNil(PayCalculator.percentChange(from: dec("0"), to: dec("10")))
    }

    // MARK: SMIC

    func testSmicReference() {
        XCTAssertEqual(SmicReference.hourlyGross, dec("12.02"))
        XCTAssertEqual(SmicReference.effectiveDate(calendar: cal), d(2026, 1, 1))
        let plain = SmicReference.resolved(overrideValue: nil)
        XCTAssertEqual(plain.hourlyGross, dec("12.02"))
        XCTAssertFalse(plain.isOverride)
        let custom = SmicReference.resolved(overrideValue: 11.88)
        XCTAssertEqual(custom.hourlyGross, dec("11.88"))
        XCTAssertTrue(custom.isOverride)
        XCTAssertFalse(SmicReference.resolved(overrideValue: 0).isOverride)
    }

    func testSmicEffectiveDateIsNeverBeforeTheSmicDateNorTheContract() {
        XCTAssertEqual(PayCalculator.smicEffectiveDate(contractStart: d(2025, 6, 10), calendar: cal), d(2026, 1, 1))
        XCTAssertEqual(PayCalculator.smicEffectiveDate(contractStart: d(2026, 3, 15, 8, 30), calendar: cal), d(2026, 3, 15))
    }

    func testSmicStaleAfterSixMonths() {
        XCTAssertFalse(SmicReference.isOlderThanSixMonths(now: d(2026, 6, 30, 23, 59), calendar: cal))
        XCTAssertTrue(SmicReference.isOlderThanSixMonths(now: d(2026, 7, 1, 0, 0), calendar: cal))
    }

    // MARK: réglages

    func testNetRatioPreferences() {
        XCTAssertEqual(PayPreferences.clampedRatio(0.2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(PayPreferences.clampedRatio(1.5), 1.0, accuracy: 1e-9)
        XCTAssertEqual(PayPreferences.clampedRatio(0.79), 0.79, accuracy: 1e-9)
        XCTAssertEqual(PayPreferences.clampedRatio(Double.nan), 0.79, accuracy: 1e-9)

        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(PayPreferences.netRatio(defaults: defaults), 0.79, accuracy: 1e-9)
        defaults.set(0.8, forKey: PayPreferences.Key.netRatio)
        XCTAssertEqual(PayPreferences.netRatio(defaults: defaults), 0.8, accuracy: 1e-9)
        defaults.set(5.0, forKey: PayPreferences.Key.netRatio)
        XCTAssertEqual(PayPreferences.netRatio(defaults: defaults), 1.0, accuracy: 1e-9)

        XCTAssertNil(PayPreferences.smicOverride(defaults: defaults))
        defaults.set(11.5, forKey: PayPreferences.Key.smicOverride)
        XCTAssertEqual(PayPreferences.smicOverride(defaults: defaults) ?? 0, 11.5, accuracy: 1e-9)
        defaults.set(0.0, forKey: PayPreferences.Key.smicOverride)
        XCTAssertNil(PayPreferences.smicOverride(defaults: defaults))
    }

    // MARK: prévu contre réel

    func testPlannedVersusRealWithPlannedSlots() {
        // Prévu : le 16 de 08:00 à 12:00 (4 h) et du 16 23:00 au 17 01:00 (1 h le 16, 1 h le 17).
        // Réel : le 16 de 09:00 à 13:00 = 4 h.
        let planned = [PlannedSlot(start: d(2026, 11, 16, 8, 0), end: d(2026, 11, 16, 12, 0)),
                       PlannedSlot(start: d(2026, 11, 16, 23, 0), end: d(2026, 11, 17, 1, 0))]
        let real = [session(d(2026, 11, 16, 9, 0), d(2026, 11, 16, 13, 0))]
        let rows = PayCalculator.plannedVersusReal(year: 2026, month: 11, planned: planned, sessions: real,
                                                   base: .fullHours, now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].day, d(2026, 11, 16))
        XCTAssertEqual(rows[0].plannedSeconds, 18000)   // 4 h + 1 h
        XCTAssertEqual(rows[0].realSeconds, 14400)
        XCTAssertEqual(rows[0].differenceSeconds, -3600)
        XCTAssertEqual(rows[1].day, d(2026, 11, 17))
        XCTAssertEqual(rows[1].plannedSeconds, 3600)
        XCTAssertEqual(rows[1].realSeconds, 0)
    }

    func testPlannedVersusRealWithEmptyPlanningOnlyShowsRealDays() {
        let real = [session(d(2026, 11, 16, 9, 0), d(2026, 11, 16, 13, 0))]
        let rows = PayCalculator.plannedVersusReal(year: 2026, month: 11, planned: [], sessions: real,
                                                   base: .fullHours, now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].plannedSeconds, 0)
        XCTAssertEqual(rows[0].differenceSeconds, 14400)
    }
}
