import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues calculées à la main (spec 106 et 109). Contrat de 13 h = 780 minutes par semaine.
/// Repères de calendrier 2026 : le 16 novembre est un lundi (semaine ISO 47). Le 28 décembre 2026 est un lundi (semaine 53).
final class ContractHoursBalanceTests: XCTestCase {
    private let utc: Calendar = TestCalendar.utc
    private let paris: Calendar = TestCalendar.paris

    private func u(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        return makeDate(utc, y, m, d, h, mi)
    }

    private func session(_ start: Date, hours: Int) -> HoursSessionInput {
        return HoursSessionInput(start: start, end: start.addingTimeInterval(Double(hours) * 3600), minutes: hours * 60)
    }

    private func contract(start: Date, end: Date? = nil) -> HoursContractInput {
        return HoursContractInput(weeklyMinutes: 780, start: start, end: end)
    }

    private func run(_ c: HoursContractInput,
                     sessions: [HoursSessionInput],
                     planned: [HoursPlannedShift] = [],
                     today: Date,
                     rule: HoursCarryRule = .unknown,
                     calendar: Calendar? = nil) -> ContractHoursReport {
        return ContractHoursBalance.report(contract: c, sessions: sessions, planned: planned, today: today,
                                           rule: rule, calendar: calendar ?? utc)
    }

    private func week(_ r: ContractHoursReport, starting d: Date) -> WeekBalance? {
        return r.weeks.first(where: { (w: WeekBalance) -> Bool in w.weekStart == d })
    }

    // MARK: Exactement 13 h, en dessous, au-dessus

    func testExactly13HoursIsPile() {
        let sessions: [HoursSessionInput] = [
            session(u(2026, 11, 9, 9), hours: 4),
            session(u(2026, 11, 11, 9), hours: 8),
            session(u(2026, 11, 13, 9), hours: 1)
        ]
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: sessions, today: u(2026, 11, 18, 12))
        XCTAssertEqual(r.weeks.count, 3)
        guard let w = week(r, starting: u(2026, 11, 9)) else { return XCTFail("semaine du 9 novembre absente") }
        XCTAssertEqual(w.doneMinutes, 780)
        XCTAssertEqual(w.quotaMinutes, 780)
        XCTAssertEqual(w.status, .inContract)
        XCTAssertEqual(w.dayDone, [240, 0, 480, 0, 60, 0, 0])
        XCTAssertEqual(ContractHoursText.headline(w), "13 h au total, ton contrat est atteint pile.")
    }

    func testTenHoursIsThreeUnder() {
        let sessions: [HoursSessionInput] = [
            session(u(2026, 11, 2, 9), hours: 4),
            session(u(2026, 11, 7, 9), hours: 6)
        ]
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: sessions, today: u(2026, 11, 18, 12))
        guard let w = week(r, starting: u(2026, 11, 2)) else { return XCTFail("semaine du 2 novembre absente") }
        XCTAssertEqual(w.doneMinutes, 600)
        XCTAssertEqual(w.deltaMinutes, -180)
        XCTAssertEqual(w.status, .under)
        XCTAssertEqual(ContractHoursText.headline(w), "Il te manque 3 h pour tes 13 h.")
    }

    func testEighteenHoursIsFiveOverAndCounters() {
        let sessions: [HoursSessionInput] = [
            session(u(2026, 11, 9, 9), hours: 6),
            session(u(2026, 11, 11, 9), hours: 6),
            session(u(2026, 11, 13, 9), hours: 6)
        ]
        let c: HoursContractInput = contract(start: u(2026, 11, 2))
        let r: ContractHoursReport = run(c, sessions: sessions, today: u(2026, 11, 18, 12), rule: .paid)
        guard let w = week(r, starting: u(2026, 11, 9)) else { return XCTFail("semaine du 9 novembre absente") }
        XCTAssertEqual(w.doneMinutes, 1080)
        XCTAssertEqual(w.deltaMinutes, 300)
        XCTAssertEqual(w.status, .over)
        XCTAssertEqual(ContractHoursText.headline(w), "5 h au-dessus de ton contrat.")
        // Règle "payé en heures en plus" : 300 minutes sur novembre (la semaine du 2 est vide, le manque n'est pas reporté).
        XCTAssertEqual(r.counters.paidExtraMinutes, 300)
        XCTAssertEqual(r.counters.advanceMinutes, 0)
        XCTAssertEqual(r.counters.catchUpMinutes, 0)
        // Règle inconnue : l'app ne présume rien.
        let unknown: ContractHoursReport = run(c, sessions: sessions, today: u(2026, 11, 18, 12), rule: .unknown)
        XCTAssertEqual(unknown.counters.advanceMinutes, 0)
        XCTAssertEqual(unknown.counters.catchUpMinutes, 0)
        XCTAssertEqual(unknown.counters.paidExtraMinutes, 0)
    }

    // MARK: Rééquilibrage (106.3)

    func testFridayFourHoursWithPlanningProjectsSeventeen() {
        // Contrat 13 h, planning vendredi 5 h, samedi 8 h, dimanche 5 h. Vendredi réalisé 4 h (10:00 à 14:00), il est 18:00.
        let sessions: [HoursSessionInput] = [session(u(2026, 11, 20, 10), hours: 4)]
        let planned: [HoursPlannedShift] = [
            HoursPlannedShift(start: u(2026, 11, 20, 10), end: u(2026, 11, 20, 15)),
            HoursPlannedShift(start: u(2026, 11, 21, 9), end: u(2026, 11, 21, 17)),
            HoursPlannedShift(start: u(2026, 11, 22, 9), end: u(2026, 11, 22, 14))
        ]
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: sessions, planned: planned, today: u(2026, 11, 20, 18))
        guard let w = r.current else { return XCTFail("pas de semaine en cours") }
        XCTAssertEqual(w.weekStart, u(2026, 11, 16))
        XCTAssertEqual(w.doneMinutes, 240)
        XCTAssertEqual(w.plannedRemainingMinutes, 780)
        XCTAssertEqual(w.projectedMinutes, 1020)
        XCTAssertEqual(w.status, .over)
        XCTAssertEqual(w.dayPlanned, [0, 0, 0, 0, 300, 480, 300])
        XCTAssertEqual(w.remainingDays, 3)
        XCTAssertEqual(ContractHoursText.headline(w),
                       "Il te reste 9 h pour tes 13 h, ton planning en prévoit 13 h, tu finiras à 17 h, soit 4 h de plus que ton contrat.")
        XCTAssertEqual(ContractHoursBalance.suggestions(for: w), [HoursSuggestion.explainOver(minutes: 240)])
    }

    func testFridayNotDoneStillReachesContractExactly() {
        // Vendredi non fait, samedi 8 h et dimanche 5 h faits : 13 h pile. Le lundi suivant la semaine est finie.
        let sessions: [HoursSessionInput] = [
            session(u(2026, 11, 21, 9), hours: 8),
            session(u(2026, 11, 22, 9), hours: 5)
        ]
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: sessions, today: u(2026, 11, 23, 9))
        guard let w = week(r, starting: u(2026, 11, 16)) else { return XCTFail("semaine du 16 novembre absente") }
        XCTAssertTrue(w.isComplete)
        XCTAssertEqual(w.doneMinutes, 780)
        XCTAssertEqual(w.status, .inContract)
        XCTAssertEqual(ContractHoursText.headline(w), "13 h au total, ton contrat est atteint pile.")
    }

    func testOngoingSessionCountsAndNoPlanningIsInProgressNotMissing() {
        let ongoing: HoursSessionInput = HoursSessionInput(start: u(2026, 11, 18, 9), end: nil, minutes: 180)
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: [ongoing], today: u(2026, 11, 18, 12))
        guard let w = r.current else { return XCTFail("pas de semaine en cours") }
        XCTAssertEqual(w.doneMinutes, 180)
        XCTAssertEqual(w.status, .inProgress)
        XCTAssertEqual(ContractHoursText.headline(w), "Il te reste 10 h pour tes 13 h.")
        // Mercredi (aujourd'hui compris), jeudi, vendredi, samedi, dimanche : 5 jours, 600 minutes, 120 par jour.
        XCTAssertEqual(ContractHoursBalance.suggestions(for: w), [HoursSuggestion.placeMissing(minutes: 600, days: 5)])
        XCTAssertEqual(ContractHoursBalance.evenSplitMinutes(missing: 600, days: 5), 120)
        XCTAssertEqual(ContractHoursBalance.evenSplitMinutes(missing: 601, days: 5), 121)
    }

    func testSessionToConfirmIsExcludedAndFlagged() {
        let doubt: HoursSessionInput = HoursSessionInput(start: u(2026, 11, 3, 9), end: u(2026, 11, 3, 13), minutes: nil)
        let unconfirmed: HoursSessionInput = HoursSessionInput(start: u(2026, 11, 4, 9), end: u(2026, 11, 4, 11), minutes: 120, isConfirmed: false)
        let ok: HoursSessionInput = session(u(2026, 11, 5, 9), hours: 3)
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: [doubt, unconfirmed, ok],
                                         today: u(2026, 11, 18, 12), rule: .carried)
        guard let w = week(r, starting: u(2026, 11, 2)) else { return XCTFail("semaine du 2 novembre absente") }
        XCTAssertEqual(w.doneMinutes, 180)
        XCTAssertEqual(w.pendingCount, 2)
        XCTAssertEqual(w.status, .toConfirm)
        XCTAssertEqual(r.counters.weeksSkippedPending, 1)
    }

    // MARK: Alerte de proximité (109)

    func testAlertThresholdBothSides() {
        // Quota 780 minutes, seuil 2 h (120 minutes restantes).
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 659, limitMinutes: 780, thresholdsMinutes: [120], suppressed: false), .off)
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 660, limitMinutes: 780, thresholdsMinutes: [120], suppressed: false),
                       .remaining(minutes: 120))
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 661, limitMinutes: 780, thresholdsMinutes: [120], suppressed: false),
                       .remaining(minutes: 119))
        // Seuil 1 h : à 2 h restantes rien, à 1 h pile oui.
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 660, limitMinutes: 780, thresholdsMinutes: [60], suppressed: false), .off)
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 720, limitMinutes: 780, thresholdsMinutes: [60], suppressed: false),
                       .remaining(minutes: 60))
        // Seuil "atteint" seul : 1 minute avant, rien ; pile, atteint ; au-delà, dépassé.
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 779, limitMinutes: 780, thresholdsMinutes: [0], suppressed: false), .off)
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 780, limitMinutes: 780, thresholdsMinutes: [0], suppressed: false), .reached)
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 781, limitMinutes: 780, thresholdsMinutes: [0], suppressed: false),
                       .exceeded(overMinutes: 1))
    }

    func testAlertOffOrSuppressedGivesNothingAndTexts() {
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 770, limitMinutes: 780, thresholdsMinutes: [], suppressed: false), .off)
        XCTAssertEqual(ContractHoursBalance.quotaAlert(doneMinutes: 770, limitMinutes: 780, thresholdsMinutes: [120], suppressed: true), .off)
        XCTAssertEqual(ContractHoursText.alertTitle(.remaining(minutes: 120)), "Plus que 2 h avant ton quota de la semaine.")
        XCTAssertEqual(ContractHoursText.alertTitle(.reached), "Ton quota de la semaine est atteint.")
        XCTAssertEqual(ContractHoursText.alertTitle(.exceeded(overMinutes: 60)), "Tu es 1 h au-dessus de ton quota de la semaine.")
    }

    // MARK: Semaines partielles

    func testPartialFirstWeekQuotaIsFourSevenths() {
        // Contrat qui commence le jeudi 5 novembre : jeudi, vendredi, samedi, dimanche = 4 jours sur 7. 780 x 4 / 7 = 445,71 donc 446.
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 5, 10)),
                                         sessions: [session(u(2026, 11, 6, 9), hours: 6)],
                                         today: u(2026, 11, 11, 12))
        XCTAssertEqual(r.weeks.count, 2)
        guard let first = week(r, starting: u(2026, 11, 2)) else { return XCTFail("première semaine absente") }
        XCTAssertTrue(first.isPartial)
        XCTAssertEqual(first.quotaMinutes, 446)
        XCTAssertEqual(first.doneMinutes, 360)
        XCTAssertEqual(first.deltaMinutes, -86)
        XCTAssertEqual(first.status, .under)
        XCTAssertEqual(ContractHoursText.headline(first), "Il te manque 1 h 26 pour tes 7 h 26.")
        guard let second = week(r, starting: u(2026, 11, 9)) else { return XCTFail("deuxième semaine absente") }
        XCTAssertFalse(second.isPartial)
        XCTAssertEqual(second.quotaMinutes, 780)
    }

    func testPartialLastWeekAndEndedContract() {
        // Fin le mercredi 11 novembre : lundi, mardi, mercredi = 3 jours. 780 x 3 / 7 = 334,29 donc 334.
        let c: HoursContractInput = contract(start: u(2026, 11, 2), end: u(2026, 11, 11))
        let r: ContractHoursReport = run(c, sessions: [], today: u(2026, 11, 18, 12))
        XCTAssertEqual(r.state, .ended)
        XCTAssertEqual(r.weeks.count, 2)
        XCTAssertNil(r.current)
        guard let last = r.weeks.last else { return XCTFail("pas de semaine") }
        XCTAssertTrue(last.isPartial)
        XCTAssertEqual(last.quotaMinutes, 334)
        // Dans la semaine de fin : pas de jour restant dans le contrat.
        let during: ContractHoursReport = run(c, sessions: [], today: u(2026, 11, 13, 12))
        XCTAssertEqual(during.state, .ended)
        XCTAssertEqual(during.current?.remainingDays, 0)
    }

    func testBeforeContractStartHasNoWeeks() {
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)), sessions: [], today: u(2026, 10, 30, 12))
        XCTAssertEqual(r.state, .notStarted)
        XCTAssertTrue(r.weeks.isEmpty)
        XCTAssertNil(r.current)
    }

    // MARK: Semaines à cheval sur un mois, une année

    func testIsoWeekHelpersAcrossYears() {
        XCTAssertEqual(ContractHoursBalance.weekStart(of: u(2027, 1, 1, 15), calendar: utc), u(2026, 12, 28))
        XCTAssertEqual(ContractHoursBalance.weekStart(of: u(2026, 11, 22, 23), calendar: utc), u(2026, 11, 16))
        let w53: (year: Int, week: Int) = ContractHoursBalance.isoWeek(weekStart: u(2026, 12, 28), calendar: utc)
        XCTAssertEqual(w53.year, 2026)
        XCTAssertEqual(w53.week, 53)
        let w1: (year: Int, week: Int) = ContractHoursBalance.isoWeek(weekStart: u(2027, 1, 4), calendar: utc)
        XCTAssertEqual(w1.year, 2027)
        XCTAssertEqual(w1.week, 1)
        // Le lundi 30 décembre 2024 ouvre la semaine 1 de 2025 (son jeudi est le 2 janvier 2025).
        let w2025: (year: Int, week: Int) = ContractHoursBalance.isoWeek(weekStart: u(2024, 12, 30), calendar: utc)
        XCTAssertEqual(w2025.year, 2025)
        XCTAssertEqual(w2025.week, 1)
        let w2026: (year: Int, week: Int) = ContractHoursBalance.isoWeek(weekStart: u(2025, 12, 29), calendar: utc)
        XCTAssertEqual(w2026.year, 2026)
        XCTAssertEqual(w2026.week, 1)
    }

    func testYearBoundaryWeekSplitsSessionsByDayAndByWeek() {
        let sessions: [HoursSessionInput] = [
            // Jeudi 31 déc. 20:00 à vendredi 1er janv. 02:00 : 360 minutes, 240 le jeudi et 120 le vendredi.
            HoursSessionInput(start: u(2026, 12, 31, 20), end: u(2027, 1, 1, 2), minutes: 360),
            // Vendredi 1er janvier 10:00 à 14:00.
            session(u(2027, 1, 1, 10), hours: 4),
            // Dimanche 3 janv. 22:00 à lundi 4 janv. 02:00 : 240 minutes, 120 dans la semaine 53 et 120 dans la semaine 1.
            HoursSessionInput(start: u(2027, 1, 3, 22), end: u(2027, 1, 4, 2), minutes: 240)
        ]
        let r: ContractHoursReport = run(contract(start: u(2026, 12, 14)), sessions: sessions, today: u(2027, 1, 5, 10))
        XCTAssertEqual(r.weeks.map { (w: WeekBalance) -> Int in w.isoWeek }, [51, 52, 53, 1])
        XCTAssertEqual(r.weeks.map { (w: WeekBalance) -> Int in w.isoYear }, [2026, 2026, 2026, 2027])
        XCTAssertEqual(r.weeks[2].monthKey, 202612)
        XCTAssertEqual(r.weeks[3].monthKey, 202701)
        XCTAssertEqual(r.weeks[2].dayDone, [0, 0, 0, 240, 360, 0, 120])
        XCTAssertEqual(r.weeks[2].doneMinutes, 720)
        XCTAssertEqual(r.weeks[3].doneMinutes, 120)
        XCTAssertEqual(r.weeks[3].dayDone[0], 120)
        XCTAssertTrue(r.weeks[3].isCurrent)
    }

    func testMonthCrossingWeeksAndCounterRules() {
        // Semaines : 26 oct. (jeudi 29 octobre, donc octobre), 2 nov., 9 nov. finies, 16 nov. en cours.
        let sessions: [HoursSessionInput] = [
            session(u(2026, 10, 26, 9), hours: 14),   // +60
            session(u(2026, 11, 2, 9), hours: 10),    // -180
            session(u(2026, 11, 9, 9), hours: 13)     // 0
        ]
        let c: HoursContractInput = contract(start: u(2026, 10, 26))
        let today: Date = u(2026, 11, 18, 12)
        let carried: ContractHoursReport = run(c, sessions: sessions, today: today, rule: .carried)
        XCTAssertEqual(carried.weeks.count, 4)
        XCTAssertEqual(carried.weeks[0].monthKey, 202610)
        XCTAssertEqual(carried.weeks[1].monthKey, 202611)
        XCTAssertEqual(carried.counters.weeksCounted, 3)
        // Reporté : 60 - 180 + 0 = -120, soit 120 minutes à rattraper.
        XCTAssertEqual(carried.counters.catchUpMinutes, 120)
        XCTAssertEqual(carried.counters.advanceMinutes, 0)
        // Lissé sur le mois (novembre) : -180 + 0 = -180.
        let smoothed: ContractHoursReport = run(c, sessions: sessions, today: today, rule: .smoothedMonth)
        XCTAssertEqual(smoothed.counters.catchUpMinutes, 180)
        XCTAssertEqual(smoothed.counters.advanceMinutes, 0)
        // Non reporté et à renseigner : zéro partout.
        for rule in [HoursCarryRule.notCarried, HoursCarryRule.unknown] {
            let other: ContractHoursReport = run(c, sessions: sessions, today: today, rule: rule)
            XCTAssertEqual(other.counters.catchUpMinutes, 0)
            XCTAssertEqual(other.counters.advanceMinutes, 0)
        }
        // Avance : seulement la semaine du 26 oct. à 14 h, les suivantes pile.
        let advance: ContractHoursReport = run(c, sessions: [session(u(2026, 10, 26, 9), hours: 14),
                                                              session(u(2026, 11, 2, 9), hours: 13),
                                                              session(u(2026, 11, 9, 9), hours: 13)],
                                               today: today, rule: .carried)
        XCTAssertEqual(advance.counters.advanceMinutes, 60)
        XCTAssertEqual(advance.counters.catchUpMinutes, 0)
    }

    // MARK: Changement d'heure

    func testDaylightSavingWeekIs169HoursAndSplitsRealDuration() {
        // Heure d'été terminée le dimanche 25 octobre 2026 à 03:00 (Paris) : la semaine du 19 dure 169 h.
        let sessions: [HoursSessionInput] = [
            // Samedi 22:00 à dimanche 06:00 heure locale : 9 h réelles (540 min). 120 le samedi, 420 le dimanche.
            HoursSessionInput(start: makeDate(paris, 2026, 10, 24, 22, 0), end: makeDate(paris, 2026, 10, 25, 6, 0), minutes: 540),
            // Dimanche 23:00 à lundi 01:00 : 120 min, 60 dans la semaine 43 et 60 dans la semaine 44.
            HoursSessionInput(start: makeDate(paris, 2026, 10, 25, 23, 0), end: makeDate(paris, 2026, 10, 26, 1, 0), minutes: 120)
        ]
        let c: HoursContractInput = HoursContractInput(weeklyMinutes: 780, start: makeDate(paris, 2026, 10, 12, 8, 0), end: nil)
        let r: ContractHoursReport = ContractHoursBalance.report(contract: c, sessions: sessions, planned: [],
                                                                  today: makeDate(paris, 2026, 10, 28, 12, 0),
                                                                  rule: .unknown, calendar: paris)
        XCTAssertEqual(r.weeks.count, 3)
        XCTAssertEqual(r.weeks[0].weekEnd.timeIntervalSince(r.weeks[0].weekStart), 604800)
        XCTAssertEqual(r.weeks[1].weekEnd.timeIntervalSince(r.weeks[1].weekStart), 608400)
        XCTAssertEqual(r.weeks[1].weekEnd, r.weeks[2].weekStart)
        XCTAssertEqual(r.weeks[1].weekStart, makeDate(paris, 2026, 10, 19, 0, 0))
        XCTAssertEqual(r.weeks[1].dayDone, [0, 0, 0, 0, 0, 120, 480])
        XCTAssertEqual(r.weeks[1].doneMinutes, 600)
        XCTAssertEqual(r.weeks[2].doneMinutes, 60)
        XCTAssertEqual(r.weeks[2].dayDone[0], 60)
        XCTAssertEqual(r.weeks[1].isoWeek, 43)
        XCTAssertEqual(r.weeks[2].isoWeek, 44)
    }

    func testShareSplitsSumExactly() {
        // 100 minutes sur 9 h coupées en trois tiers : 33, 34, 33 (arrondi cumulé, la somme reste 100).
        let start: Date = u(2026, 11, 16, 0)
        let end: Date = u(2026, 11, 16, 9)
        let a: Int = ContractHoursBalance.share(minutes: 100, start: start, end: end, from: u(2026, 11, 16, 0), to: u(2026, 11, 16, 3))
        let b: Int = ContractHoursBalance.share(minutes: 100, start: start, end: end, from: u(2026, 11, 16, 3), to: u(2026, 11, 16, 6))
        let c: Int = ContractHoursBalance.share(minutes: 100, start: start, end: end, from: u(2026, 11, 16, 6), to: u(2026, 11, 16, 9))
        XCTAssertEqual([a, b, c], [33, 34, 33])
        XCTAssertEqual(a + b + c, 100)
    }

    // MARK: Distribution (106.6)

    private func eightWeeks(_ hours: [Int]) -> ContractHoursReport {
        var sessions: [HoursSessionInput] = []
        for (i, h) in hours.enumerated() {
            let monday: Date = ContractHoursBalance.addDays(7 * i, to: u(2026, 9, 21), calendar: utc)
            let start: Date = monday.addingTimeInterval(9 * 3600)
            sessions.append(session(start, hours: h))
        }
        return run(contract(start: u(2026, 9, 21)), sessions: sessions, today: u(2026, 11, 18, 12))
    }

    func testDistributionOverEightWeeks() {
        let r: ContractHoursReport = eightWeeks([13, 13, 18, 13, 11, 18, 13, 15])
        guard let d = r.distribution else { return XCTFail("pas de distribution") }
        XCTAssertEqual(d.weeksCount, 8)
        XCTAssertEqual(d.averageMinutes, 855)   // 114 h sur 8 = 14 h 15
        XCTAssertEqual(d.minMinutes, 660)
        XCTAssertEqual(d.maxMinutes, 1080)
        XCTAssertEqual(d.overCount, 3)
        XCTAssertFalse(d.recurrentOver)
        XCTAssertEqual(ContractHoursText.distributionSentence(d, quotaMinutes: 780), "Tu as dépassé tes 13 h 3 semaines sur 8.")
    }

    func testRecurrentOverIsFlaggedSoftly() {
        let r: ContractHoursReport = eightWeeks([18, 18, 18, 18, 18, 13, 13, 13])
        guard let d = r.distribution else { return XCTFail("pas de distribution") }
        XCTAssertEqual(d.overCount, 5)
        XCTAssertTrue(d.recurrentOver)
        XCTAssertTrue(ContractHoursText.distributionSentence(d, quotaMinutes: 780).contains("un avenant a peut-être été prévu"))
    }

    func testTwoWeeksNeverFlagRecurrentOver() {
        let r: ContractHoursReport = run(contract(start: u(2026, 11, 2)),
                                         sessions: [session(u(2026, 11, 2, 9), hours: 18), session(u(2026, 11, 9, 9), hours: 18)],
                                         today: u(2026, 11, 18, 12))
        XCTAssertEqual(r.distribution?.weeksCount, 2)
        XCTAssertEqual(r.distribution?.recurrentOver, false)
    }

    // MARK: Textes

    func testHoursText() {
        XCTAssertEqual(ContractHoursText.hours(780), "13 h")
        XCTAssertEqual(ContractHoursText.hours(74), "1 h 14")
        XCTAssertEqual(ContractHoursText.hours(45), "45 min")
        XCTAssertEqual(ContractHoursText.hours(0), "0 h")
        XCTAssertEqual(ContractHoursText.hours(-5), "0 h")
        XCTAssertEqual(ContractHoursText.shortHours(780), "13")
        XCTAssertEqual(ContractHoursText.shortHours(690), "11,5")
    }
}
