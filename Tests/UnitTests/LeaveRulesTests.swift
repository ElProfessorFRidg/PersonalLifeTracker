import XCTest
@testable import PersonalLifeTracker

/// Valeurs écrites à la main. Repères de calendrier : le 16 novembre 2026 est un lundi, le 1er novembre 2026 un
/// dimanche, le 31 mai 2027 un lundi (196 jours, soit 28 semaines, après le 16 novembre 2026).
final class LeaveRulesTests: XCTestCase {
    private let cal: Calendar = TestCalendar.utc
    private let ouvrable: LeaveParameters = LeaveParameters.defaults(unit: .ouvrable)

    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
        return makeDate(cal, y, m, day, 0, 0)
    }

    // MARK: Période de référence

    func testReferencePeriodInNovember() {
        let p: LeavePeriod = LeaveRules.referencePeriod(containing: d(2026, 11, 17), startMonth: 6, calendar: cal)
        XCTAssertEqual(p.start, d(2026, 6, 1))
        XCTAssertEqual(p.end, d(2027, 5, 31))
    }

    func testReferencePeriodInMarchStartsPreviousYear() {
        let p: LeavePeriod = LeaveRules.referencePeriod(containing: d(2026, 3, 15), startMonth: 6, calendar: cal)
        XCTAssertEqual(p.start, d(2025, 6, 1))
        XCTAssertEqual(p.end, d(2026, 5, 31))
    }

    func testReferencePeriodFirstAndLastDay() {
        let first: LeavePeriod = LeaveRules.referencePeriod(containing: d(2026, 6, 1), startMonth: 6, calendar: cal)
        XCTAssertEqual(first.start, d(2026, 6, 1))
        let last: LeavePeriod = LeaveRules.referencePeriod(containing: d(2027, 5, 31), startMonth: 6, calendar: cal)
        XCTAssertEqual(last.start, d(2026, 6, 1))
        XCTAssertEqual(last.end, d(2027, 5, 31))
    }

    func testReferencePeriodCustomStartJanuary() {
        let p: LeavePeriod = LeaveRules.referencePeriod(containing: d(2026, 11, 17), startMonth: 1, calendar: cal)
        XCTAssertEqual(p.start, d(2026, 1, 1))
        XCTAssertEqual(p.end, d(2026, 12, 31))
    }

    // MARK: Acquisition

    func testFullPeriodGivesThirtyOuvrables() {
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2025, 1, 1), end: nil)]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        let v: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2027, 5, 31), params: ouvrable, calendar: cal)
        XCTAssertEqual(v, 30, accuracy: 1e-9)
    }

    func testFullPeriodOuvresGivesTwentyFive() {
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2025, 1, 1), end: nil)]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        let v: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2027, 5, 31), params: LeaveParameters.defaults(unit: .ouvre), calendar: cal)
        XCTAssertEqual(v, 25, accuracy: 1e-9)
    }

    func testPartialPeriodSeptemberToMid17November() {
        // Septembre 30/30 + octobre 31/31 + novembre 17/30 = 2,56667 mois, x 2,5 = 6,41667 ; arrondi au jour supérieur : 7.
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2026, 9, 1), end: nil)]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        let v: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2026, 11, 17), params: ouvrable, calendar: cal)
        XCTAssertEqual(v, 7, accuracy: 1e-9)
        var exact: LeaveParameters = ouvrable
        exact.roundUpToWholeDay = false
        let e: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2026, 11, 17), params: exact, calendar: cal)
        XCTAssertEqual(e, 6.416667, accuracy: 1e-5)
    }

    func testShortContractInsidePeriod() {
        // 15 janvier au 31 mars 2027 : 17/31 + 28/28 + 31/31 = 2,548387 mois, x 2,5 = 6,370968 ; arrondi : 7.
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2027, 1, 15), end: d(2027, 3, 31))]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        var exact: LeaveParameters = ouvrable
        exact.roundUpToWholeDay = false
        let e: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2027, 5, 31), params: exact, calendar: cal)
        XCTAssertEqual(e, 6.370968, accuracy: 1e-5)
        let r: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2027, 5, 31), params: ouvrable, calendar: cal)
        XCTAssertEqual(r, 7, accuracy: 1e-9)
    }

    func testEndedContractStopsAcquiring() {
        // 1er juin au 31 août 2026 : 3 mois pleins, x 2,5 = 7,5 ; arrondi : 8, même 3 mois plus tard.
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2026, 6, 1), end: d(2026, 8, 31))]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        let v: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2026, 11, 17), params: ouvrable, calendar: cal)
        XCTAssertEqual(v, 8, accuracy: 1e-9)
    }

    func testNoAcquisitionBeforeContract() {
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2026, 12, 1), end: nil)]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        let v: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2026, 11, 17), params: ouvrable, calendar: cal)
        XCTAssertEqual(v, 0, accuracy: 1e-9)
    }

    func testAcquisitionIsCappedAtMaximum() {
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2025, 1, 1), end: nil)]
        let p: LeavePeriod = LeavePeriod(start: d(2026, 6, 1), end: d(2027, 5, 31))
        var big: LeaveParameters = ouvrable
        big.daysPerMonth = 4
        let v: Double = LeaveRules.acquiredDays(spans: spans, period: p, asOf: d(2027, 5, 31), params: big, calendar: cal)
        XCTAssertEqual(v, 30, accuracy: 1e-9)
    }

    // MARK: Décompte des jours pris

    func testCountAcrossWeekend() {
        // Vendredi 27, samedi 28, dimanche 29, lundi 30 novembre 2026.
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 27), to: d(2026, 11, 30), unit: .ouvrable, calendar: cal), 3)
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 27), to: d(2026, 11, 30), unit: .ouvre, calendar: cal), 2)
    }

    func testCountAcrossMonthBoundary() {
        // Vendredi 30 octobre au mardi 3 novembre 2026 : ven, sam, (dim 1er), lun, mar.
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 10, 30), to: d(2026, 11, 3), unit: .ouvrable, calendar: cal), 4)
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 10, 30), to: d(2026, 11, 3), unit: .ouvre, calendar: cal), 3)
    }

    func testCountAcrossDaylightSavingChangeInParis() {
        // Vendredi 23 au lundi 26 octobre 2026, changement d'heure le dimanche 25 : ven, sam, lun.
        let paris: Calendar = TestCalendar.paris
        let s: Date = makeDate(paris, 2026, 10, 23, 0, 0)
        let e: Date = makeDate(paris, 2026, 10, 26, 0, 0)
        XCTAssertEqual(LeaveRules.countedDays(from: s, to: e, unit: .ouvrable, calendar: paris), 3)
    }

    func testCountSingleDaysAndInvalidRange() {
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 16), to: d(2026, 11, 16), unit: .ouvre, calendar: cal), 1)
        // Dimanche 29 novembre seul : 0.
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 29), to: d(2026, 11, 29), unit: .ouvrable, calendar: cal), 0)
        // Samedi 28 : ouvrable oui, ouvré non.
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 28), to: d(2026, 11, 28), unit: .ouvrable, calendar: cal), 1)
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 28), to: d(2026, 11, 28), unit: .ouvre, calendar: cal), 0)
        // Fin avant début : 0.
        XCTAssertEqual(LeaveRules.countedDays(from: d(2026, 11, 20), to: d(2026, 11, 18), unit: .ouvrable, calendar: cal), 0)
    }

    func testCountIsClampedToPeriod() {
        // Du mardi 25 mai au samedi 5 juin 2027, coupé au 31 mai : mar, mer, jeu, ven, sam, lun = 6.
        let r: LeaveRange = LeaveRange(start: d(2027, 5, 25), end: d(2027, 6, 5), kind: .paid)
        XCTAssertEqual(LeaveRules.countedDays(of: r, from: d(2026, 6, 1), to: d(2027, 5, 31), unit: .ouvrable, calendar: cal), 6)
    }

    // MARK: Solde

    private let spansSeptember: [LeaveSpan] = [LeaveSpan(start: makeDate(TestCalendar.utc, 2026, 9, 1, 0, 0), end: nil)]

    func testBalanceTakenPlannedAndRemaining() {
        // Acquis 7. Pris : 9 au 11 novembre (lun, mar, mer) = 3. Prévus : 23 et 24 novembre = 2. Maladie ignorée.
        let ranges: [LeaveRange] = [
            LeaveRange(start: d(2026, 11, 9), end: d(2026, 11, 11), kind: .paid),
            LeaveRange(start: d(2026, 11, 23), end: d(2026, 11, 24), kind: .paid),
            LeaveRange(start: d(2026, 11, 12), end: d(2026, 11, 12), kind: .sick)
        ]
        let b: LeaveBalance = LeaveRules.balance(spans: spansSeptember, ranges: ranges, asOf: d(2026, 11, 17), params: ouvrable, calendar: cal)
        XCTAssertEqual(b.acquired, 7, accuracy: 1e-9)
        XCTAssertEqual(b.taken, 3, accuracy: 1e-9)
        XCTAssertEqual(b.planned, 2, accuracy: 1e-9)
        XCTAssertEqual(b.remaining, 2, accuracy: 1e-9)
        XCTAssertFalse(b.isOverdrawn)
        XCTAssertEqual(b.period.end, d(2027, 5, 31))
    }

    func testBalanceNeverSilentlyNegative() {
        // Pris : 2 au 7 novembre (6) + 9 au 14 novembre (6) = 12 pour 7 acquis : reste -5, dépassement de 5.
        let ranges: [LeaveRange] = [
            LeaveRange(start: d(2026, 11, 2), end: d(2026, 11, 7), kind: .paid),
            LeaveRange(start: d(2026, 11, 9), end: d(2026, 11, 14), kind: .paid)
        ]
        let b: LeaveBalance = LeaveRules.balance(spans: spansSeptember, ranges: ranges, asOf: d(2026, 11, 17), params: ouvrable, calendar: cal)
        XCTAssertEqual(b.acquired, 7, accuracy: 1e-9)
        XCTAssertEqual(b.remaining, -5, accuracy: 1e-9)
        XCTAssertTrue(b.isOverdrawn)
        XCTAssertEqual(b.overdrawnBy, 5, accuracy: 1e-9)
        XCTAssertEqual(b.risk.daysAtRisk, 0, accuracy: 1e-9)
        XCTAssertFalse(b.risk.isAlert)
    }

    func testRiskAlertWindow() {
        // Il reste 7 jours. Fin de période le 31 mai 2027 : 195 jours après le 17 novembre 2026.
        var tight: LeaveParameters = ouvrable
        tight.alertDays = 200
        let b: LeaveBalance = LeaveRules.balance(spans: spansSeptember, ranges: [], asOf: d(2026, 11, 17), params: tight, calendar: cal)
        XCTAssertEqual(b.risk.daysUntilExpiry, 195)
        XCTAssertEqual(b.risk.daysAtRisk, 7, accuracy: 1e-9)
        XCTAssertTrue(b.risk.isAlert)
        let far: LeaveBalance = LeaveRules.balance(spans: spansSeptember, ranges: [], asOf: d(2026, 11, 17), params: ouvrable, calendar: cal)
        XCTAssertFalse(far.risk.isAlert)
    }

    func testRiskAlertBoundaryExactly60Days() {
        // 1er avril 2027 : 60 jours avant le 31 mai (avril 29 + mai 31 = 60). 60 alerte, 59 jours de marge en moins n'en change pas.
        let b: LeaveBalance = LeaveRules.balance(spans: spansSeptember, ranges: [], asOf: d(2027, 4, 1), params: ouvrable, calendar: cal)
        XCTAssertEqual(b.risk.daysUntilExpiry, 60)
        XCTAssertTrue(b.risk.isAlert)
        let before: LeaveBalance = LeaveRules.balance(spans: spansSeptember, ranges: [], asOf: d(2027, 3, 31), params: ouvrable, calendar: cal)
        XCTAssertEqual(before.risk.daysUntilExpiry, 61)
        XCTAssertFalse(before.risk.isAlert)
    }

    // MARK: Validation

    func testValidationEndBeforeStart() {
        let issues: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 20), end: d(2026, 11, 18), others: [], spans: spansSeptember, calendar: cal)
        XCTAssertEqual(issues, [LeaveIssue.endBeforeStart])
    }

    func testValidationOverlap() {
        let others: [LeaveRange] = [LeaveRange(start: d(2026, 11, 10), end: d(2026, 11, 12), kind: .paid)]
        let touching: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 12), end: d(2026, 11, 14), others: others, spans: spansSeptember, calendar: cal)
        XCTAssertEqual(touching, [LeaveIssue.overlapsOther])
        let adjacent: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 13), end: d(2026, 11, 14), others: others, spans: spansSeptember, calendar: cal)
        XCTAssertEqual(adjacent, [])
    }

    func testValidationOutsideContract() {
        let spans: [LeaveSpan] = [LeaveSpan(start: d(2026, 9, 1), end: d(2026, 11, 30))]
        let over: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 28), end: d(2026, 12, 2), others: [], spans: spans, calendar: cal)
        XCTAssertEqual(over, [LeaveIssue.outsideContract])
        let before: [LeaveIssue] = LeaveRules.validate(start: d(2026, 8, 31), end: d(2026, 9, 2), others: [], spans: spans, calendar: cal)
        XCTAssertEqual(before, [LeaveIssue.outsideContract])
        let inside: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 2), end: d(2026, 11, 3), others: [], spans: spans, calendar: cal)
        XCTAssertEqual(inside, [])
        let lastDay: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 30), end: d(2026, 11, 30), others: [], spans: spans, calendar: cal)
        XCTAssertEqual(lastDay, [])
    }

    func testValidationWithoutContract() {
        let issues: [LeaveIssue] = LeaveRules.validate(start: d(2026, 11, 2), end: d(2026, 11, 3), others: [], spans: [], calendar: cal)
        XCTAssertEqual(issues, [LeaveIssue.noContract])
        XCTAssertTrue(LeaveRules.hasBlockingIssue(issues))
    }

    // MARK: Paramètres utilisateur

    func testParametersRoundTripAndReset() {
        let iso: (defaults: UserDefaults, name: String) = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        XCTAssertEqual(LeaveParameters.load(from: iso.defaults), LeaveParameters.defaults(unit: .ouvrable))

        var p: LeaveParameters = LeaveParameters.defaults(unit: .ouvre)
        p.referenceStartMonth = 1
        p.daysPerMonth = 2
        p.save(to: iso.defaults)
        let loaded: LeaveParameters = LeaveParameters.load(from: iso.defaults)
        XCTAssertEqual(loaded.unit, .ouvre)
        XCTAssertEqual(loaded.referenceStartMonth, 1)
        XCTAssertEqual(loaded.daysPerMonth, 2, accuracy: 1e-9)
        XCTAssertEqual(loaded.maxPerPeriod, 25, accuracy: 1e-9)

        LeaveParameters.reset(in: iso.defaults)
        XCTAssertEqual(LeaveParameters.load(from: iso.defaults), LeaveParameters.defaults(unit: .ouvrable))
    }

    func testDefaultsAreNotWrittenWhenUnchanged() {
        let iso: (defaults: UserDefaults, name: String) = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        LeaveParameters.defaults(unit: .ouvrable).save(to: iso.defaults)
        XCTAssertNil(iso.defaults.object(forKey: LeaveParameters.perMonthKey))
        XCTAssertNil(iso.defaults.object(forKey: LeaveParameters.monthKey))
    }

    func testInvalidStoredValuesFallBackToDefaults() {
        let iso: (defaults: UserDefaults, name: String) = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        iso.defaults.set(13, forKey: LeaveParameters.monthKey)
        iso.defaults.set(-2.0, forKey: LeaveParameters.perMonthKey)
        let p: LeaveParameters = LeaveParameters.load(from: iso.defaults)
        XCTAssertEqual(p.referenceStartMonth, 6)
        XCTAssertEqual(p.daysPerMonth, 2.5, accuracy: 1e-9)
    }
}
