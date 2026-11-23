import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues calculées à la main (UTC, novembre et décembre 2026). Montants en centimes entiers.
/// Les pourcentages et seuils des tests sont des DONNÉES DE TEST, pas des valeurs légales.
/// Calendrier : lundi 16 novembre 2026, dimanche 22 novembre 2026, lundi 30 novembre 2026, mardi 1er décembre 2026.
final class PayRulesTests: XCTestCase {
    private let cal: Calendar = TestCalendar.utc

    private func dec(_ s: String) -> Decimal {
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        return makeDate(cal, y, m, day, h, min)
    }

    private func iv(_ start: Date, _ end: Date) -> PayInterval {
        return PayInterval(start: start, end: end)
    }

    private let night25: PackNightRule = PackNightRule(startMinute: 21 * 60, endMinute: 6 * 60, percent: 25, source: "Test")
    private let sunday50: PackPercentRule = PackPercentRule(percent: 50, source: "Test")
    private let holidayAll100: PackHolidayRule = PackHolidayRule(scope: PackHolidayRule.scopeAll, percent: 100, source: "Test")
    private let overtime35: PackOvertimeRule = PackOvertimeRule(
        weeklyThresholdMinutes: 2100,
        bands: [PackOvertimeBand(overMinutes: 480, percent: 25), PackOvertimeBand(overMinutes: nil, percent: 50)],
        source: "Test")

    private func run(_ ivs: [PayInterval], rules: ConventionRules, from: Date, to: Date, rate: Decimal? = Decimal(10)) -> PayRulesResult {
        return PayRules.compute(intervals: ivs, periodStart: from, periodEnd: to, rules: rules,
                                rateOnDay: { (_: Date) -> Decimal? in rate }, calendar: cal)
    }

    private func november(_ ivs: [PayInterval], rules: ConventionRules, rate: Decimal? = Decimal(10)) -> PayRulesResult {
        return run(ivs, rules: rules, from: d(2026, 11, 1), to: d(2026, 12, 1), rate: rate)
    }

    // MARK: nuit, bornes des deux côtés

    func testNightStartBoundaryOneMinuteEachSide() {
        // 20:59 à 21:01 : 20:59 à 21:00 normal (60 s), 21:00 à 21:01 nuit (60 s).
        let r = november([iv(d(2026, 11, 16, 20, 59), d(2026, 11, 16, 21, 1))], rules: ConventionRules(night: night25))
        XCTAssertEqual(r.seconds(.normal), 60)
        XCTAssertEqual(r.seconds(.night), 60)
        XCTAssertEqual(r.totalSeconds, 120)
    }

    func testNightEndBoundaryOneMinuteEachSide() {
        // 05:59 à 06:01 : 05:59 à 06:00 nuit (60 s), 06:00 à 06:01 normal (60 s). La fin de la fenêtre est exclue.
        let r = november([iv(d(2026, 11, 17, 5, 59), d(2026, 11, 17, 6, 1))], rules: ConventionRules(night: night25))
        XCTAssertEqual(r.seconds(.night), 60)
        XCTAssertEqual(r.seconds(.normal), 60)
    }

    func testIntervalEndingExactlyWhenNightStartsHasNoNight() {
        let r = november([iv(d(2026, 11, 16, 20, 0), d(2026, 11, 16, 21, 0))], rules: ConventionRules(night: night25))
        XCTAssertEqual(r.seconds(.night), 0)
        XCTAssertEqual(r.seconds(.normal), 3600)
    }

    func testIntervalStartingExactlyWhenNightEndsHasNoNight() {
        let r = november([iv(d(2026, 11, 17, 6, 0), d(2026, 11, 17, 7, 0))], rules: ConventionRules(night: night25))
        XCTAssertEqual(r.seconds(.night), 0)
        XCTAssertEqual(r.seconds(.normal), 3600)
    }

    func testNightWindowAcrossMidnightIsOneNightBlock() {
        // 22:00 lundi à 02:00 mardi : 4 h de nuit = 14400 s.
        let r = november([iv(d(2026, 11, 16, 22, 0), d(2026, 11, 17, 2, 0))], rules: ConventionRules(night: night25))
        XCTAssertEqual(r.seconds(.night), 14400)
        XCTAssertEqual(r.seconds(.normal), 0)
    }

    func testNightWindowWithoutCrossingMidnight() {
        // Fenêtre 01:00 à 05:00 : une session de 00:00 à 06:00 donne 1 h normal, 4 h nuit, 1 h normal.
        let night = PackNightRule(startMinute: 60, endMinute: 300, percent: 25, source: "Test")
        let r = november([iv(d(2026, 11, 16, 0, 0), d(2026, 11, 16, 6, 0))], rules: ConventionRules(night: night))
        XCTAssertEqual(r.seconds(.night), 14400)
        XCTAssertEqual(r.seconds(.normal), 7200)
    }

    func testNightMajorationRoundsHalfUpToTheCent() {
        // 1 h de nuit à 12,02 avec +25 % : 12,02 x 0,25 = 3,005 EUR donc 300,5 centimes, arrondi à 301.
        let r = november([iv(d(2026, 11, 16, 22, 0), d(2026, 11, 16, 23, 0))], rules: ConventionRules(night: night25), rate: dec("12.02"))
        XCTAssertEqual(r.lines.count, 1)
        XCTAssertEqual(r.lines[0].category, .night)
        XCTAssertEqual(r.lines[0].seconds, 3600)
        XCTAssertEqual(r.lines[0].majorationCents, 301)
        XCTAssertEqual(r.majorationCents, 301)
    }

    func testNightMajorationOneHourAtTenEuros() {
        // 1 h x 10,00 x 25 % = 2,50 EUR = 250 centimes.
        let r = november([iv(d(2026, 11, 16, 22, 0), d(2026, 11, 16, 23, 0))], rules: ConventionRules(night: night25))
        XCTAssertEqual(r.majorationCents, 250)
    }

    // MARK: dimanche

    func testSaturdayNightIntoSundayOnlySundayRule() {
        // Samedi 21 22:00 à dimanche 22 02:00, règle dimanche seule : 2 h normales (samedi), 2 h dimanche.
        let r = november([iv(d(2026, 11, 21, 22, 0), d(2026, 11, 22, 2, 0))], rules: ConventionRules(sunday: sunday50))
        XCTAssertEqual(r.seconds(.normal), 7200)
        XCTAssertEqual(r.seconds(.sunday), 7200)
    }

    func testSundayNightIntoMondayOnlySundayRule() {
        // Dimanche 22 22:00 à lundi 23 02:00 : 2 h dimanche, 2 h normales (lundi).
        let r = november([iv(d(2026, 11, 22, 22, 0), d(2026, 11, 23, 2, 0))], rules: ConventionRules(sunday: sunday50))
        XCTAssertEqual(r.seconds(.sunday), 7200)
        XCTAssertEqual(r.seconds(.normal), 7200)
    }

    func testSundayMajorationAmount() {
        // 2 h dimanche à 10,00 avec +50 % : 2 x 10 x 0,5 = 10,00 EUR = 1000 centimes.
        let r = november([iv(d(2026, 11, 22, 10, 0), d(2026, 11, 22, 12, 0))], rules: ConventionRules(sunday: sunday50))
        XCTAssertEqual(r.majorationCents, 1000)
    }

    func testSundayAndNightTakeTheHighestByDefault() {
        // Samedi 22:00 à dimanche 02:00, nuit 25 % et dimanche 50 % : samedi 2 h nuit, dimanche 2 h dimanche (50, pas 75).
        let rules = ConventionRules(night: night25, sunday: sunday50)
        let r = november([iv(d(2026, 11, 21, 22, 0), d(2026, 11, 22, 2, 0))], rules: rules)
        XCTAssertEqual(r.seconds(.night), 7200)
        XCTAssertEqual(r.seconds(.sunday), 7200)
        let sundaySegments: [PaySegment] = r.segments.filter { (s: PaySegment) -> Bool in s.category == .sunday }
        XCTAssertEqual(sundaySegments.count, 1)
        XCTAssertEqual(sundaySegments[0].percent, Decimal(50))
        // 2 h x 10 x 25 % = 5,00 EUR et 2 h x 10 x 50 % = 10,00 EUR : 1500 centimes.
        XCTAssertEqual(r.majorationCents, 1500)
    }

    func testSundayAndNightAddUpWhenCumulationIsSum() {
        let rules = ConventionRules(night: night25, sunday: sunday50, cumulation: "sum")
        let r = november([iv(d(2026, 11, 22, 0, 0), d(2026, 11, 22, 2, 0))], rules: rules)
        XCTAssertEqual(r.segments.count, 1)
        XCTAssertEqual(r.segments[0].category, .sunday)
        XCTAssertEqual(r.segments[0].percent, Decimal(75))
        // 2 h x 10 x 75 % = 15,00 EUR.
        XCTAssertEqual(r.majorationCents, 1500)
    }

    // MARK: jours fériés

    func testEasterDates() {
        XCTAssertEqual(FrenchHolidays.easter(year: 2024).month, 3)
        XCTAssertEqual(FrenchHolidays.easter(year: 2024).day, 31)
        XCTAssertEqual(FrenchHolidays.easter(year: 2025).month, 4)
        XCTAssertEqual(FrenchHolidays.easter(year: 2025).day, 20)
        XCTAssertEqual(FrenchHolidays.easter(year: 2026).month, 4)
        XCTAssertEqual(FrenchHolidays.easter(year: 2026).day, 5)
    }

    func testHolidayList2026() {
        let all = PackHolidayRule.scopeAll
        func h(_ m: Int, _ day: Int) -> Bool { return FrenchHolidays.isHoliday(year: 2026, month: m, day: day, scope: all, calendar: cal) }
        XCTAssertTrue(h(1, 1))
        XCTAssertTrue(h(4, 6))   // lundi de Pâques (Pâques le 5 avril)
        XCTAssertFalse(h(4, 5))  // dimanche de Pâques : pas dans la liste des 11
        XCTAssertTrue(h(5, 1))
        XCTAssertTrue(h(5, 8))
        XCTAssertTrue(h(5, 14))  // Ascension : Pâques + 39 jours
        XCTAssertTrue(h(5, 25))  // lundi de Pentecôte : Pâques + 50 jours
        XCTAssertTrue(h(7, 14))
        XCTAssertTrue(h(8, 15))
        XCTAssertTrue(h(11, 1))
        XCTAssertTrue(h(11, 11))
        XCTAssertTrue(h(12, 25))
        XCTAssertFalse(h(12, 26))
        XCTAssertFalse(h(11, 16))
    }

    func testMayFirstOnlyScope() {
        XCTAssertTrue(FrenchHolidays.isHoliday(year: 2026, month: 5, day: 1, scope: PackHolidayRule.scopeMayFirstOnly, calendar: cal))
        XCTAssertFalse(FrenchHolidays.isHoliday(year: 2026, month: 11, day: 1, scope: PackHolidayRule.scopeMayFirstOnly, calendar: cal))
    }

    func testHolidayBeatsSundayWhenHigher() {
        // Dimanche 1er novembre 2026 est férié (+100 %) et dimanche (+50 %) : férié.
        let rules = ConventionRules(sunday: sunday50, publicHoliday: holidayAll100)
        let r = run([iv(d(2026, 11, 1, 10, 0), d(2026, 11, 1, 12, 0))], rules: rules, from: d(2026, 11, 1), to: d(2026, 12, 1))
        XCTAssertEqual(r.seconds(.holiday), 7200)
        XCTAssertEqual(r.seconds(.sunday), 0)
        // 2 h x 10 x 100 % = 20,00 EUR.
        XCTAssertEqual(r.majorationCents, 2000)
    }

    func testNovemberFirstIsNotHolidayWhenScopeIsMayFirstOnly() {
        let holiday = PackHolidayRule(scope: PackHolidayRule.scopeMayFirstOnly, percent: 100, source: "Test")
        let r = run([iv(d(2026, 11, 1, 10, 0), d(2026, 11, 1, 12, 0))], rules: ConventionRules(publicHoliday: holiday),
                    from: d(2026, 11, 1), to: d(2026, 12, 1))
        XCTAssertEqual(r.seconds(.holiday), 0)
        XCTAssertEqual(r.seconds(.normal), 7200)
    }

    // MARK: semaine ISO

    func testIsoWeekKeys() {
        XCTAssertEqual(PayRules.weekKey(d(2026, 11, 16, 0, 0), calendar: cal), PayRules.weekKey(d(2026, 11, 22, 23, 59), calendar: cal))
        XCTAssertNotEqual(PayRules.weekKey(d(2026, 11, 22, 23, 59), calendar: cal), PayRules.weekKey(d(2026, 11, 23, 0, 0), calendar: cal))
        // 2026 commence un jeudi : la semaine 1 de 2026 commence le lundi 29 décembre 2025 et 2026 a 53 semaines.
        XCTAssertEqual(PayRules.weekKey(d(2025, 12, 29, 0, 0), calendar: cal), 202601)
        XCTAssertEqual(PayRules.weekKey(d(2026, 1, 1, 0, 0), calendar: cal), 202601)
        XCTAssertEqual(PayRules.weekKey(d(2026, 12, 31, 0, 0), calendar: cal), 202653)
        XCTAssertEqual(PayRules.weekKey(d(2027, 1, 1, 0, 0), calendar: cal), 202653)
        XCTAssertEqual(PayRules.weekKey(d(2027, 1, 4, 0, 0), calendar: cal), 202701)
    }

    func testWeekStartIsMonday() {
        XCTAssertEqual(PayRules.weekStart(of: d(2026, 11, 22, 15, 0), calendar: cal), d(2026, 11, 16, 0, 0))
        XCTAssertEqual(PayRules.weekStart(of: d(2026, 12, 1, 9, 0), calendar: cal), d(2026, 11, 30, 0, 0))
    }

    // MARK: heures au-delà du seuil

    func testOvertimeSplitThresholdExactlyReached() {
        // 34 h faites (122400 s), 1 h de plus : 35 h pile, aucune heure au-delà.
        let pieces = PayRules.overtimeSplit(weekSecondsBefore: 122400, segmentSeconds: 3600, rule: overtime35)
        XCTAssertEqual(pieces, [OvertimePiece(band: nil, seconds: 3600)])
    }

    func testOvertimeSplitOneSecondOverTheThreshold() {
        let pieces = PayRules.overtimeSplit(weekSecondsBefore: 122400, segmentSeconds: 3601, rule: overtime35)
        XCTAssertEqual(pieces, [OvertimePiece(band: nil, seconds: 3600), OvertimePiece(band: 0, seconds: 1)])
    }

    func testOvertimeSplitAlreadyAtThreshold() {
        let pieces = PayRules.overtimeSplit(weekSecondsBefore: 126000, segmentSeconds: 100, rule: overtime35)
        XCTAssertEqual(pieces, [OvertimePiece(band: 0, seconds: 100)])
    }

    func testOvertimeSplitCrossesFirstBand() {
        // Au seuil (126000 s) plus 28700 s : il reste 100 s dans la première tranche (8 h = 28800 s), 100 s passent dans la seconde.
        let pieces = PayRules.overtimeSplit(weekSecondsBefore: 126000 + 28700, segmentSeconds: 200, rule: overtime35)
        XCTAssertEqual(pieces, [OvertimePiece(band: 0, seconds: 100), OvertimePiece(band: 1, seconds: 100)])
    }

    func testOvertimeSplitInLastBand() {
        let pieces = PayRules.overtimeSplit(weekSecondsBefore: 126000 + 28800, segmentSeconds: 50, rule: overtime35)
        XCTAssertEqual(pieces, [OvertimePiece(band: 1, seconds: 50)])
    }

    func testOvertimeSplitWithoutRule() {
        let pieces = PayRules.overtimeSplit(weekSecondsBefore: 999999, segmentSeconds: 500, rule: nil)
        XCTAssertEqual(pieces, [OvertimePiece(band: nil, seconds: 500)])
    }

    func testWeekOf40HoursHasFiveOvertimeHours() {
        // Lundi 16 à vendredi 20, 08:00 à 16:00 chaque jour : 40 h. Seuil 35 h : les 5 dernières heures sont à +25 %.
        var ivs: [PayInterval] = []
        for day in 16...20 { ivs.append(iv(d(2026, 11, day, 8, 0), d(2026, 11, day, 16, 0))) }
        let r = november(ivs, rules: ConventionRules(overtime: overtime35))
        XCTAssertEqual(r.totalSeconds, 144000)
        XCTAssertEqual(r.overtimeSeconds, 18000)
        XCTAssertEqual(r.lines.count, 1)
        XCTAssertEqual(r.lines[0].band, 0)
        XCTAssertEqual(r.lines[0].seconds, 18000)
        // 5 h x 10,00 x 25 % = 12,50 EUR.
        XCTAssertEqual(r.majorationCents, 1250)
    }

    func testWeekOf35HoursExactlyHasNoOvertime() {
        // 5 jours de 7 h = 35 h pile.
        var ivs: [PayInterval] = []
        for day in 16...20 { ivs.append(iv(d(2026, 11, day, 8, 0), d(2026, 11, day, 15, 0))) }
        let r = november(ivs, rules: ConventionRules(overtime: overtime35))
        XCTAssertEqual(r.totalSeconds, 126000)
        XCTAssertEqual(r.overtimeSeconds, 0)
        XCTAssertEqual(r.majorationCents, 0)
    }

    func testWeekOf48HoursUsesBothBands() {
        // Lundi à samedi, 8 h par jour = 48 h. Seuil à 35 h : 13 h au-delà, dont 8 h à 25 % et 5 h à 50 %.
        var ivs: [PayInterval] = []
        for day in 16...21 { ivs.append(iv(d(2026, 11, day, 8, 0), d(2026, 11, day, 16, 0))) }
        let r = november(ivs, rules: ConventionRules(overtime: overtime35))
        XCTAssertEqual(r.overtimeSeconds, 46800)
        XCTAssertEqual(r.lines.count, 2)
        XCTAssertEqual(r.lines[0].band, 0)
        XCTAssertEqual(r.lines[0].seconds, 28800)
        XCTAssertEqual(r.lines[0].majorationCents, 2000)
        XCTAssertEqual(r.lines[1].band, 1)
        XCTAssertEqual(r.lines[1].seconds, 18000)
        XCTAssertEqual(r.lines[1].majorationCents, 2500)
        XCTAssertEqual(r.majorationCents, 4500)
    }

    func testOvertimeIsCountedPerWeekNotPerMonth() {
        // Deux semaines de 20 h : aucune heure au-delà de 35 h, même si le total du mois est de 40 h.
        let ivs: [PayInterval] = [iv(d(2026, 11, 16, 8, 0), d(2026, 11, 16, 18, 0)), iv(d(2026, 11, 17, 8, 0), d(2026, 11, 17, 18, 0)),
                                  iv(d(2026, 11, 23, 8, 0), d(2026, 11, 23, 18, 0)), iv(d(2026, 11, 24, 8, 0), d(2026, 11, 24, 18, 0))]
        let r = november(ivs, rules: ConventionRules(overtime: overtime35))
        XCTAssertEqual(r.totalSeconds, 144000)
        XCTAssertEqual(r.overtimeSeconds, 0)
    }

    func testWeekSpanningTwoMonthsCountsTheEarlierDays() {
        // Semaine du lundi 30 novembre au dimanche 6 décembre : 8 h du lundi au vendredi (40 h).
        // Pour décembre (du 1er au 31), le lundi 30 novembre compte dans le seuil : le vendredi 4 est à 3 h normales puis 5 h au-delà.
        var full: [PayInterval] = [iv(d(2026, 11, 30, 8, 0), d(2026, 11, 30, 16, 0))]
        for day in 1...4 { full.append(iv(d(2026, 12, day, 8, 0), d(2026, 12, day, 16, 0))) }
        let december = run(full, rules: ConventionRules(overtime: overtime35), from: d(2026, 12, 1), to: d(2027, 1, 1))
        XCTAssertEqual(december.totalSeconds, 115200)
        XCTAssertEqual(december.overtimeSeconds, 18000)
        // Sans le lundi (intervalle absent), le seuil n'est jamais atteint : c'est pourquoi l'appelant doit passer la semaine entière.
        let withoutMonday: [PayInterval] = Array(full.dropFirst())
        let partial = run(withoutMonday, rules: ConventionRules(overtime: overtime35), from: d(2026, 12, 1), to: d(2027, 1, 1))
        XCTAssertEqual(partial.overtimeSeconds, 0)
    }

    func testMonthDetailIncludesPreviousMonthDaysOfTheSameWeek() {
        // Mêmes sessions que ci-dessus via monthDetail, taux 10,00 depuis le 1er janvier 2026, base exacte.
        var sessions: [PaySessionInput] = [PaySessionInput(start: d(2026, 11, 30, 8, 0), end: d(2026, 11, 30, 16, 0))]
        for day in 1...4 { sessions.append(PaySessionInput(start: d(2026, 12, day, 8, 0), end: d(2026, 12, day, 16, 0))) }
        let rates: [PayRateEntry] = [PayRateEntry(effectiveDate: d(2026, 1, 1), hourlyGross: Decimal(10))]
        let r = PayCalculator.monthDetail(year: 2026, month: 12, sessions: sessions, rates: rates, base: .exact,
                                          netRatio: dec("0.79"), rules: ConventionRules(overtime: overtime35), premiums: [],
                                          now: d(2027, 1, 5), calendar: cal)
        // Base : 4 jours x 8 h x 10,00 = 320,00 EUR. Majoration : 5 h x 10,00 x 25 % = 12,50 EUR. Brut 332,50 EUR.
        XCTAssertEqual(r.baseGrossCents, 32000)
        XCTAssertEqual(r.rules.majorationCents, 1250)
        XCTAssertEqual(r.grossCents, 33250)
        // Net : 332,50 x 0,79 = 262,675 EUR, arrondi à 262,68 EUR.
        XCTAssertEqual(r.netCents, 26268)
    }

    func testMonthDetailWithoutRulesNorPremiumsEqualsTheBaseCalculation() {
        let sessions: [PaySessionInput] = [PaySessionInput(start: d(2026, 11, 22, 10, 0), end: d(2026, 11, 22, 14, 0)),
                                           PaySessionInput(start: d(2026, 11, 23, 22, 0), end: d(2026, 11, 24, 2, 0))]
        let rates: [PayRateEntry] = [PayRateEntry(effectiveDate: d(2026, 1, 1), hourlyGross: dec("12.02"))]
        let detail = PayCalculator.monthDetail(year: 2026, month: 11, sessions: sessions, rates: rates, base: .exact,
                                               netRatio: dec("0.79"), rules: ConventionRules(), premiums: [],
                                               now: d(2026, 12, 1), calendar: cal)
        let basis = PayCalculator.month(year: 2026, month: 11, sessions: sessions, rates: rates, base: .exact,
                                        netRatio: dec("0.79"), now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(detail.grossCents, basis.grossCents)
        XCTAssertEqual(detail.netCents, basis.netCents)
        XCTAssertEqual(detail.rules.totalSeconds, basis.exactSeconds)
        XCTAssertEqual(detail.rules.majorationCents, 0)
    }

    func testRulesTotalSecondsMatchesTheMonthRetainedSeconds() {
        // Base heures pleines : 08:05 à 12:02 donne 08:00 à 12:00 (4 h) dans les deux calculs.
        let sessions: [PaySessionInput] = [PaySessionInput(start: d(2026, 11, 3, 8, 5), end: d(2026, 11, 3, 12, 2)),
                                           PaySessionInput(start: d(2026, 11, 4, 9, 0), end: d(2026, 11, 4, 13, 0))]
        let rates: [PayRateEntry] = [PayRateEntry(effectiveDate: d(2026, 1, 1), hourlyGross: Decimal(10))]
        let detail = PayCalculator.monthDetail(year: 2026, month: 11, sessions: sessions, rates: rates, base: .fullHours,
                                               netRatio: dec("0.79"), rules: ConventionRules(), premiums: [],
                                               now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(detail.month.retainedSeconds, 28800)
        XCTAssertEqual(detail.rules.totalSeconds, 28800)
    }

    // MARK: sans taux

    func testNoRateMeansNoMajorationMoneyButSecondsAreCounted() {
        let r = november([iv(d(2026, 11, 22, 10, 0), d(2026, 11, 22, 12, 0))], rules: ConventionRules(sunday: sunday50), rate: nil)
        XCTAssertEqual(r.seconds(.sunday), 7200)
        XCTAssertEqual(r.unratedSeconds, 7200)
        XCTAssertEqual(r.majorationCents, 0)
        XCTAssertTrue(r.lines.isEmpty)
    }

    func testEmptyRulesGiveOnlyNormalHours() {
        let r = november([iv(d(2026, 11, 22, 22, 0), d(2026, 11, 23, 3, 0))], rules: ConventionRules())
        XCTAssertEqual(r.seconds(.normal), 18000)
        XCTAssertEqual(r.majorationCents, 0)
    }

    func testPeriodFiltersSegmentsByStart() {
        // Session du 30 novembre 22:00 au 1er décembre 02:00, période novembre : seulement les 2 h du 30 novembre.
        let r = november([iv(d(2026, 11, 30, 22, 0), d(2026, 12, 1, 2, 0))], rules: ConventionRules())
        XCTAssertEqual(r.totalSeconds, 7200)
    }

    // MARK: intervalles retenus

    func testRetainedIntervalsFullHoursRoundsAndExactKeepsMinutes() {
        let s = PaySessionInput(start: d(2026, 11, 3, 8, 5), end: d(2026, 11, 3, 12, 2))
        let full = PayRules.retainedIntervals(sessions: [s], base: .fullHours, now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(full.count, 1)
        XCTAssertEqual(full[0].start, d(2026, 11, 3, 8, 0))
        XCTAssertEqual(full[0].end, d(2026, 11, 3, 12, 0))
        let exact = PayRules.retainedIntervals(sessions: [s], base: .exact, now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(exact[0].start, d(2026, 11, 3, 8, 5))
        XCTAssertEqual(exact[0].end, d(2026, 11, 3, 12, 2))
    }

    func testRetainedIntervalsSkipUnconfirmedAndUseNowForLive() {
        let unconfirmed = PaySessionInput(start: d(2026, 11, 3, 8, 0), end: d(2026, 11, 3, 12, 0), isConfirmed: false)
        let live = PaySessionInput(start: d(2026, 11, 4, 8, 7), end: nil)
        let out = PayRules.retainedIntervals(sessions: [unconfirmed, live], base: .fullHours, now: d(2026, 11, 4, 9, 30), calendar: cal)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].start, d(2026, 11, 4, 8, 7))
        XCTAssertEqual(out[0].end, d(2026, 11, 4, 9, 30))
    }

    // MARK: primes

    private func premiumsFor(_ list: [PayPremium], _ ivs: [PayInterval], base: Int = 0,
                             from: Date? = nil, to: Date? = nil) -> PremiumsResult {
        let start: Date = from ?? d(2026, 11, 1)
        let end: Date = to ?? d(2026, 12, 1)
        let r = run(ivs, rules: ConventionRules(), from: start, to: end, rate: nil)
        return PayRules.premiums(list, periodStart: start, periodEnd: end, intervals: ivs, segments: r.segments,
                                 grossBaseCents: base, calendar: cal)
    }

    private func weekdaySessions() -> [PayInterval] {
        // 3 novembre 08-12 et 14-17, 4 novembre 09-13, 5 novembre 09-10 : 4 sessions, 3 jours, 4 + 3 + 4 + 1 = 12 h.
        return [iv(d(2026, 11, 3, 8, 0), d(2026, 11, 3, 12, 0)), iv(d(2026, 11, 3, 14, 0), d(2026, 11, 3, 17, 0)),
                iv(d(2026, 11, 4, 9, 0), d(2026, 11, 4, 13, 0)), iv(d(2026, 11, 5, 9, 0), d(2026, 11, 5, 10, 0))]
    }

    func testPremiumPerDayCountsDistinctWorkedDays() {
        let p = PayPremium(employerKey: "e", name: "Panier", kind: .panier, amountCents: 500, frequency: .perDay)
        let r = premiumsFor([p], weekdaySessions())
        XCTAssertEqual(r.lines.count, 1)
        XCTAssertEqual(r.lines[0].cents, 1500)
        XCTAssertEqual(r.lines[0].quantityText, "3 jours")
        XCTAssertEqual(r.grossCents, 1500)
        XCTAssertEqual(r.netCents, 0)
    }

    func testPremiumPerSession() {
        let p = PayPremium(employerKey: "e", name: "Repas", kind: .repas, amountCents: 200, frequency: .perSession)
        let r = premiumsFor([p], weekdaySessions())
        XCTAssertEqual(r.grossCents, 800)
        XCTAssertEqual(r.lines[0].quantityText, "4 sessions")
    }

    func testPremiumPerHour() {
        // 12 h x 0,50 EUR = 6,00 EUR.
        let p = PayPremium(employerKey: "e", name: "Prime horaire", amountCents: 50, frequency: .perHour)
        XCTAssertEqual(premiumsFor([p], weekdaySessions()).grossCents, 600)
    }

    func testPremiumMonthlyFixed() {
        let p = PayPremium(employerKey: "e", name: "Transport", kind: .transport, amountCents: 10000, frequency: .monthly)
        let r = premiumsFor([p], [])
        XCTAssertEqual(r.grossCents, 10000)
        XCTAssertEqual(r.lines[0].quantityText, "1 mois")
    }

    func testPremiumPercentOfGrossBase() {
        // 10 % de 332,50 EUR = 33,25 EUR.
        let p = PayPremium(employerKey: "e", name: "Objectifs", kind: .objectifs, amountType: .percentOfGross, percent: 10, frequency: .monthly)
        XCTAssertEqual(premiumsFor([p], [], base: 33250).grossCents, 3325)
    }

    func testPremiumNetGoesToNetOnly() {
        let p = PayPremium(employerKey: "e", name: "Remboursement transport", kind: .transport, amountCents: 2000, frequency: .monthly, basis: .net)
        let r = premiumsFor([p], [])
        XCTAssertEqual(r.grossCents, 0)
        XCTAssertEqual(r.netCents, 2000)
    }

    func testPremiumSundayConditionPerDayAndPerHour() {
        let sessions: [PayInterval] = [iv(d(2026, 11, 21, 10, 0), d(2026, 11, 21, 14, 0)), iv(d(2026, 11, 22, 10, 0), d(2026, 11, 22, 14, 0))]
        let perDay = PayPremium(employerKey: "e", name: "Prime dimanche", amountCents: 500, frequency: .perDay, condition: .sunday)
        XCTAssertEqual(premiumsFor([perDay], sessions).grossCents, 500)
        // 4 h le dimanche x 0,50 EUR = 2,00 EUR.
        let perHour = PayPremium(employerKey: "e", name: "Heure dimanche", amountCents: 50, frequency: .perHour, condition: .sunday)
        XCTAssertEqual(premiumsFor([perHour], sessions).grossCents, 200)
        let perSession = PayPremium(employerKey: "e", name: "Session dimanche", amountCents: 300, frequency: .perSession, condition: .sunday)
        XCTAssertEqual(premiumsFor([perSession], sessions).grossCents, 300)
    }

    func testPremiumEveningConditionUsesTheUserStartMinute() {
        // Soirée à partir de 20:00. 3 novembre 18:00 à 20:30 : touche la soirée. 4 novembre 18:00 à 20:00 pile : ne la touche pas.
        let sessions: [PayInterval] = [iv(d(2026, 11, 3, 18, 0), d(2026, 11, 3, 20, 30)), iv(d(2026, 11, 4, 18, 0), d(2026, 11, 4, 20, 0))]
        let perDay = PayPremium(employerKey: "e", name: "Prime soirée", amountCents: 500, frequency: .perDay,
                                condition: .evening, eveningStartMinute: 1200)
        XCTAssertEqual(premiumsFor([perDay], sessions).grossCents, 500)
        let perSession = PayPremium(employerKey: "e", name: "Prime soirée", amountCents: 200, frequency: .perSession,
                                    condition: .evening, eveningStartMinute: 1200)
        XCTAssertEqual(premiumsFor([perSession], sessions).grossCents, 200)
        // 30 min dans la soirée x 0,50 EUR = 0,25 EUR.
        let perHour = PayPremium(employerKey: "e", name: "Heure soirée", amountCents: 50, frequency: .perHour,
                                 condition: .evening, eveningStartMinute: 1200)
        XCTAssertEqual(premiumsFor([perHour], sessions).grossCents, 25)
    }

    func testPremiumEveningWithoutStartMinuteIsNotCountedAndSaysWhy() {
        let p = PayPremium(employerKey: "e", name: "Prime soirée", amountCents: 500, frequency: .perDay, condition: .evening)
        let r = premiumsFor([p], weekdaySessions())
        XCTAssertEqual(r.grossCents, 0)
        XCTAssertTrue(r.lines.isEmpty)
        XCTAssertEqual(r.notCounted.count, 1)
        XCTAssertEqual(r.notCounted[0].name, "Prime soirée")
    }

    func testPremiumPercentPerDayIsNotCounted() {
        let p = PayPremium(employerKey: "e", name: "Incohérente", amountType: .percentOfGross, percent: 5, frequency: .perDay)
        let r = premiumsFor([p], weekdaySessions(), base: 10000)
        XCTAssertEqual(r.grossCents, 0)
        XCTAssertEqual(r.notCounted.count, 1)
    }

    func testPremiumAnnualAndOneOffOnlyInTheirMonth() {
        let anchor: Date = d(2026, 11, 10, 0, 0)
        let annual = PayPremium(employerKey: "e", name: "13e mois", kind: .treizieme, amountCents: 100000, frequency: .annual, anchorDate: anchor)
        let oneOff = PayPremium(employerKey: "e", name: "Bonus", amountCents: 5000, frequency: .oneOff, anchorDate: anchor)
        XCTAssertEqual(premiumsFor([annual, oneOff], []).grossCents, 105000)
        let december = premiumsFor([annual, oneOff], [], from: d(2026, 12, 1), to: d(2027, 1, 1))
        XCTAssertEqual(december.grossCents, 0)
        // Une prime annuelle revient le même mois l'année suivante.
        let nextNovember = premiumsFor([annual], [], from: d(2027, 11, 1), to: d(2027, 12, 1))
        XCTAssertEqual(nextNovember.grossCents, 100000)
        // Le bonus ponctuel, lui, ne revient pas.
        XCTAssertEqual(premiumsFor([oneOff], [], from: d(2027, 11, 1), to: d(2027, 12, 1)).grossCents, 0)
    }

    func testPremiumAnnualWithoutMonthIsNotCounted() {
        let p = PayPremium(employerKey: "e", name: "13e mois", amountCents: 100000, frequency: .annual)
        let r = premiumsFor([p], [])
        XCTAssertEqual(r.grossCents, 0)
        XCTAssertEqual(r.notCounted.count, 1)
    }

    func testPremiumOutsideItsDatesIsNotCounted() {
        let ended = PayPremium(employerKey: "e", name: "Finie", amountCents: 1000, frequency: .monthly, endDate: d(2026, 10, 31, 0, 0))
        let future = PayPremium(employerKey: "e", name: "Future", amountCents: 1000, frequency: .monthly, startDate: d(2026, 12, 1, 0, 0))
        let current = PayPremium(employerKey: "e", name: "En cours", amountCents: 1000, frequency: .monthly,
                                 startDate: d(2026, 11, 30, 0, 0), endDate: d(2026, 12, 31, 0, 0))
        let r = premiumsFor([ended, future, current], [])
        XCTAssertEqual(r.lines.count, 1)
        XCTAssertEqual(r.lines[0].name, "En cours")
    }

    func testPremiumPerDayRespectsStartDate() {
        // Prime par jour depuis le 4 novembre : seuls le 4 et le 5 comptent (2 jours).
        let p = PayPremium(employerKey: "e", name: "Panier", amountCents: 500, frequency: .perDay, startDate: d(2026, 11, 4, 0, 0))
        XCTAssertEqual(premiumsFor([p], weekdaySessions()).grossCents, 1000)
    }

    func testMonthDetailAddsPremiumsToGrossAndNet() {
        // 4 h le 3 novembre à 10,00 = 40,00 EUR. Prime fixe brute 5,00 EUR (500) et prime nette 2,00 EUR (200).
        let sessions: [PaySessionInput] = [PaySessionInput(start: d(2026, 11, 3, 8, 0), end: d(2026, 11, 3, 12, 0))]
        let rates: [PayRateEntry] = [PayRateEntry(effectiveDate: d(2026, 1, 1), hourlyGross: Decimal(10))]
        let gross = PayPremium(employerKey: "e", name: "Panier", amountCents: 500, frequency: .monthly)
        let netOnly = PayPremium(employerKey: "e", name: "Transport", kind: .transport, amountCents: 200, frequency: .monthly, basis: .net)
        let r = PayCalculator.monthDetail(year: 2026, month: 11, sessions: sessions, rates: rates, base: .exact, netRatio: dec("0.80"),
                                          rules: ConventionRules(), premiums: [gross, netOnly], now: d(2026, 12, 1), calendar: cal)
        XCTAssertEqual(r.baseGrossCents, 4000)
        XCTAssertEqual(r.grossCents, 4500)
        // Net : 45,00 x 0,80 = 36,00 EUR, plus 2,00 EUR net = 38,00 EUR.
        XCTAssertEqual(r.netCents, 3800)
    }

    // MARK: saisies

    func testParseMoneyCents() {
        XCTAssertEqual(PayRules.parseMoneyCents("5"), 500)
        XCTAssertEqual(PayRules.parseMoneyCents("5,50"), 550)
        XCTAssertEqual(PayRules.parseMoneyCents("5.5"), 550)
        XCTAssertEqual(PayRules.parseMoneyCents("1 250,5"), 125050)
        XCTAssertEqual(PayRules.parseMoneyCents("100000"), 10000000)
        XCTAssertNil(PayRules.parseMoneyCents("100001"))
        XCTAssertNil(PayRules.parseMoneyCents("0"))
        XCTAssertNil(PayRules.parseMoneyCents(""))
        XCTAssertNil(PayRules.parseMoneyCents("abc"))
        XCTAssertNil(PayRules.parseMoneyCents("5,555"))
        XCTAssertNil(PayRules.parseMoneyCents("1,2,3"))
        XCTAssertNil(PayRules.parseMoneyCents("-5"))
    }

    func testParsePercent() {
        XCTAssertEqual(PayRules.parsePercent("25"), 25)
        XCTAssertEqual(PayRules.parsePercent("12,5"), 12.5)
        XCTAssertEqual(PayRules.parsePercent("0"), 0)
        XCTAssertEqual(PayRules.parsePercent("300"), 300)
        XCTAssertNil(PayRules.parsePercent("301"))
        XCTAssertNil(PayRules.parsePercent("-1"))
        XCTAssertNil(PayRules.parsePercent(""))
        XCTAssertNil(PayRules.parsePercent("vingt"))
    }

    func testParseHoursToMinutes() {
        XCTAssertEqual(PayRules.parseHoursToMinutes("35"), 2100)
        XCTAssertEqual(PayRules.parseHoursToMinutes("7,5"), 450)
        XCTAssertNil(PayRules.parseHoursToMinutes("0"))
        XCTAssertNil(PayRules.parseHoursToMinutes("169"))
        XCTAssertNil(PayRules.parseHoursToMinutes("x"))
    }

    func testMinimumRateAlert() {
        let rules = ConventionRules(minimumRate: PackMinimumRate(hourlyCents: 1250, label: "Minimum de test", source: "Test"))
        XCTAssertTrue(PayRules.isBelowMinimum(hourlyGross: dec("12.49"), rules: rules))
        XCTAssertFalse(PayRules.isBelowMinimum(hourlyGross: dec("12.50"), rules: rules))
        XCTAssertFalse(PayRules.isBelowMinimum(hourlyGross: dec("5"), rules: ConventionRules()))
    }

    // MARK: relevé d'heures

    private func statement(_ sessions: [PaySessionInput], rules: ConventionRules, base: CalculationBase = .exact) -> HoursStatement {
        return HoursStatementBuilder.build(year: 2026, month: 11, sessions: sessions, base: base, rules: rules,
                                           employerName: "Employeur test", packName: "Pack test",
                                           now: d(2026, 12, 1), calendar: cal)
    }

    func testStatementSplitsADaySpanningSundayAndNight() {
        // Dimanche 22 22:00 à lundi 23 02:00, règles dimanche 50 % et nuit 25 % : dimanche 2 h (la plus haute), lundi 2 h de nuit.
        let rules = ConventionRules(night: night25, sunday: sunday50)
        let st = statement([PaySessionInput(start: d(2026, 11, 22, 22, 0), end: d(2026, 11, 23, 2, 0))], rules: rules)
        XCTAssertEqual(st.days.count, 2)
        XCTAssertEqual(st.days[0].day, d(2026, 11, 22, 0, 0))
        XCTAssertEqual(st.days[0].seconds(.sunday), 7200)
        XCTAssertEqual(st.days[0].sessions.count, 1)
        XCTAssertEqual(st.days[1].day, d(2026, 11, 23, 0, 0))
        XCTAssertEqual(st.days[1].seconds(.night), 7200)
        XCTAssertEqual(st.days[1].sessions.count, 0)
        XCTAssertEqual(st.total(.sunday), 7200)
        XCTAssertEqual(st.total(.night), 7200)
        XCTAssertEqual(st.totalSeconds, 14400)
        XCTAssertEqual(st.sessionCount, 1)
    }

    func testStatementCSVLines() {
        let rules = ConventionRules(night: night25, sunday: sunday50)
        let st = statement([PaySessionInput(start: d(2026, 11, 22, 22, 0), end: d(2026, 11, 23, 2, 0))], rules: rules)
        let csv: String = HoursStatementBuilder.csv(st, calendar: cal)
        XCTAssertTrue(csv.hasSuffix("\r\n"))
        let lines: [String] = csv.components(separatedBy: "\r\n")
        XCTAssertTrue(lines.contains("2026-11-22;22:00 à 02:00;0,00;0,00;2,00;0,00;0,00;2,00"))
        XCTAssertTrue(lines.contains("2026-11-23;suite de la veille;0,00;2,00;0,00;0,00;0,00;2,00"))
        XCTAssertTrue(lines.contains("Total;;0,00;2,00;2,00;0,00;0,00;4,00"))
        XCTAssertTrue(lines[1].hasPrefix("ESTIMATION;"))
    }

    func testStatementTextSaysItIsAnEstimateAndListsTheDays() {
        let st = statement([PaySessionInput(start: d(2026, 11, 16, 8, 0), end: d(2026, 11, 16, 12, 30))], rules: ConventionRules())
        let text: String = HoursStatementBuilder.text(st, calendar: cal)
        XCTAssertTrue(text.contains("ESTIMATION"))
        XCTAssertTrue(text.contains("novembre 2026"))
        XCTAssertTrue(text.contains("08:00 à 12:30"))
        XCTAssertTrue(text.contains("Total du mois : 4 h 30"))
        XCTAssertTrue(text.contains("Pack test"))
    }

    func testStatementFullHoursShowsRetainedBoundsAndCountsDoubt() {
        // 08:05 à 12:02 : retenu 08:00 à 12:00 (heures pleines).
        let st = statement([PaySessionInput(start: d(2026, 11, 3, 8, 5), end: d(2026, 11, 3, 12, 2))], rules: ConventionRules(), base: .fullHours)
        XCTAssertEqual(st.totalSeconds, 14400)
        let text: String = HoursStatementBuilder.text(st, calendar: cal)
        XCTAssertTrue(text.contains("08:05 à 12:02 (retenu 08:00 à 12:00)"))
    }

    func testStatementExcludesUnconfirmedAndReportsThem() {
        let s = PaySessionInput(start: d(2026, 11, 3, 8, 0), end: d(2026, 11, 3, 12, 0), isConfirmed: false)
        let st = statement([s], rules: ConventionRules())
        XCTAssertTrue(st.days.isEmpty)
        XCTAssertEqual(st.unconfirmedSessionCount, 1)
        XCTAssertEqual(st.totalSeconds, 0)
    }

    func testStatementOvertimeColumn() {
        var sessions: [PaySessionInput] = []
        for day in 16...20 { sessions.append(PaySessionInput(start: d(2026, 11, day, 8, 0), end: d(2026, 11, day, 16, 0))) }
        let st = statement(sessions, rules: ConventionRules(overtime: overtime35))
        XCTAssertEqual(st.overtimeSeconds, 18000)
        XCTAssertEqual(st.days.last?.overtimeSeconds, 18000)
        XCTAssertEqual(st.days.first?.overtimeSeconds, 0)
        let csv: String = HoursStatementBuilder.csv(st, calendar: cal)
        XCTAssertTrue(csv.components(separatedBy: "\r\n").contains("2026-11-20;08:00 à 16:00;8,00;0,00;0,00;0,00;5,00;8,00"))
    }
}
