import XCTest
import SwiftData
@testable import PersonalLifeTracker

/// Valeurs attendues calculées à la main (calendrier du 1er septembre 2026 au 9 décembre 2026 : 99 jours).
final class ContractRulesTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris

    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        return makeDate(paris, y, m, day, h, min)
    }

    // MARK: Jours restants

    func testDaysRemainingNov16ToDec9Is23() {
        XCTAssertEqual(ContractRules.daysRemaining(end: d(2026, 12, 9), now: d(2026, 11, 16, 10), calendar: paris), 23)
    }

    func testDaysRemainingLastDayIsZeroAndDayAfterIsMinusOne() {
        XCTAssertEqual(ContractRules.daysRemaining(end: d(2026, 12, 9, 8), now: d(2026, 12, 9, 22), calendar: paris), 0)
        XCTAssertEqual(ContractRules.daysRemaining(end: d(2026, 12, 9), now: d(2026, 12, 10, 1), calendar: paris), -1)
    }

    func testDaysRemainingAtOneMinuteToMidnightIsOne() {
        XCTAssertEqual(ContractRules.daysRemaining(end: d(2026, 11, 17, 0, 0), now: d(2026, 11, 16, 23, 59), calendar: paris), 1)
    }

    func testDaysRemainingAcrossAutumnTimeChange() {
        // 25 octobre 2026 : retour à l'heure d'hiver, la nuit dure 25 h. Du 24 à midi au 26 à 00:00 : 2 jours calendaires.
        XCTAssertEqual(ContractRules.daysRemaining(end: d(2026, 10, 26, 0, 0), now: d(2026, 10, 24, 12), calendar: paris), 2)
        XCTAssertEqual(ContractRules.daysRemaining(end: d(2026, 11, 1), now: d(2026, 10, 24, 12), calendar: paris), 8)
    }

    func testDaysRemainingNilWithoutEnd() {
        XCTAssertNil(ContractRules.daysRemaining(end: nil, now: d(2026, 11, 16), calendar: paris))
    }

    // MARK: Contrat actif

    func testIsActiveIncludesFirstAndLastDay() {
        let start: Date = d(2026, 9, 1, 0, 0)
        let end: Date = d(2026, 12, 9, 0, 0)
        XCTAssertTrue(ContractRules.isActive(start: start, end: end, at: d(2026, 9, 1, 0, 0), calendar: paris))
        XCTAssertTrue(ContractRules.isActive(start: start, end: end, at: d(2026, 12, 9, 23, 59), calendar: paris))
        XCTAssertFalse(ContractRules.isActive(start: start, end: end, at: d(2026, 8, 31, 23, 59), calendar: paris))
        XCTAssertFalse(ContractRules.isActive(start: start, end: end, at: d(2026, 12, 10, 0, 0), calendar: paris))
    }

    func testIsActiveWithoutEndStaysActive() {
        XCTAssertTrue(ContractRules.isActive(start: d(2020, 1, 6), end: nil, at: d(2026, 11, 16), calendar: paris))
    }

    func testActiveIndexPicksMostRecentStartWhenOverlapping() {
        let a: ContractSpan = ContractSpan(id: UUID(), start: d(2026, 1, 5), end: nil)
        let b: ContractSpan = ContractSpan(id: UUID(), start: d(2026, 9, 1), end: d(2026, 12, 9))
        let c: ContractSpan = ContractSpan(id: UUID(), start: d(2025, 1, 1), end: d(2025, 6, 30))
        XCTAssertEqual(ContractRules.activeIndex(in: [a, b, c], at: d(2026, 11, 16), calendar: paris), 1)
        XCTAssertEqual(ContractRules.activeIndex(in: [a, b, c], at: d(2026, 3, 1), calendar: paris), 0)
        XCTAssertNil(ContractRules.activeIndex(in: [b, c], at: d(2027, 1, 1), calendar: paris))
        XCTAssertNil(ContractRules.activeIndex(in: [], at: d(2026, 11, 16), calendar: paris))
    }

    // MARK: Avancement

    func testProgressMatchesPrototype() {
        let p: Double? = ContractRules.progress(start: d(2026, 9, 1), end: d(2026, 12, 9), now: d(2026, 11, 16), calendar: paris)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? -1, 76.0 / 99.0, accuracy: 0.000001)
    }

    func testProgressIsClamped() {
        XCTAssertEqual(ContractRules.progress(start: d(2026, 9, 1), end: d(2026, 12, 9), now: d(2026, 8, 1), calendar: paris) ?? -1, 0, accuracy: 0.000001)
        XCTAssertEqual(ContractRules.progress(start: d(2026, 9, 1), end: d(2026, 12, 9), now: d(2027, 2, 1), calendar: paris) ?? -1, 1, accuracy: 0.000001)
        XCTAssertNil(ContractRules.progress(start: d(2026, 9, 1), end: nil, now: d(2026, 11, 16), calendar: paris))
    }

    // MARK: Statut

    func testStatusTable() {
        let start: Date = d(2026, 9, 1)
        let end: Date = d(2026, 12, 9)
        let trial: Date = d(2026, 9, 15)
        func st(_ now: Date) -> ContractStatus {
            return ContractRules.status(start: start, end: end, trialEnd: trial, now: now, calendar: paris)
        }
        XCTAssertEqual(st(d(2026, 8, 31)), .upcoming)
        XCTAssertEqual(st(d(2026, 9, 1)), .trial)
        XCTAssertEqual(st(d(2026, 9, 15, 23, 0)), .trial)
        XCTAssertEqual(st(d(2026, 9, 16)), .ongoing)
        XCTAssertEqual(st(d(2026, 11, 16)), .ongoing)
        XCTAssertEqual(st(d(2026, 12, 9, 23, 0)), .endingSoon)
        XCTAssertEqual(st(d(2026, 12, 10)), .ended)
    }

    func testEndingSoonBoundaryIs14Days() {
        // Fin le 9 décembre : le 25 novembre il reste 14 jours (bientôt terminé), le 24 il en reste 15 (en cours).
        XCTAssertEqual(ContractRules.status(start: d(2026, 9, 1), end: d(2026, 12, 9), trialEnd: nil, now: d(2026, 11, 25), calendar: paris), .endingSoon)
        XCTAssertEqual(ContractRules.status(start: d(2026, 9, 1), end: d(2026, 12, 9), trialEnd: nil, now: d(2026, 11, 24), calendar: paris), .ongoing)
    }

    func testCdiNeverEndsNorEndsSoon() {
        XCTAssertEqual(ContractRules.status(start: d(2026, 1, 5), end: nil, trialEnd: nil, now: d(2030, 1, 1), calendar: paris), .ongoing)
    }

    // MARK: Période d'essai

    func testTrialStatus() {
        let start: Date = d(2026, 9, 1)
        let trial: Date = d(2026, 9, 15)
        XCTAssertEqual(ContractRules.trialStatus(start: start, trialEnd: nil, now: d(2026, 9, 5), calendar: paris), .none)
        XCTAssertEqual(ContractRules.trialStatus(start: start, trialEnd: trial, now: d(2026, 8, 30), calendar: paris), .notStarted)
        XCTAssertEqual(ContractRules.trialStatus(start: start, trialEnd: trial, now: d(2026, 9, 5), calendar: paris), .inProgress(daysLeft: 10))
        XCTAssertEqual(ContractRules.trialStatus(start: start, trialEnd: trial, now: d(2026, 9, 15, 23, 0), calendar: paris), .inProgress(daysLeft: 0))
        XCTAssertEqual(ContractRules.trialStatus(start: start, trialEnd: trial, now: d(2026, 9, 16), calendar: paris), .finished)
    }

    // MARK: Rappels

    func testEndReminders14And3DaysBefore() {
        let r: [ContractReminder] = ContractRules.reminders(kind: .cdd, end: d(2026, 12, 9), trialEnd: nil, now: d(2026, 11, 16, 10), calendar: paris)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[0].target, .contractEnd)
        XCTAssertEqual(r[0].daysBefore, 14)
        XCTAssertEqual(r[0].fireDate, d(2026, 11, 25, 9, 0))
        XCTAssertEqual(r[1].daysBefore, 3)
        XCTAssertEqual(r[1].fireDate, d(2026, 12, 6, 9, 0))
    }

    func testPastRemindersAreDropped() {
        let r: [ContractReminder] = ContractRules.reminders(kind: .cdd, end: d(2026, 12, 9), trialEnd: nil, now: d(2026, 11, 30), calendar: paris)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].daysBefore, 3)
    }

    func testTrialRemindersAndSorting() {
        let r: [ContractReminder] = ContractRules.reminders(kind: .cdd, end: d(2026, 12, 9), trialEnd: d(2026, 9, 15), now: d(2026, 9, 1, 8), calendar: paris)
        XCTAssertEqual(r.count, 4)
        XCTAssertEqual(r[0].target, .trialEnd)
        XCTAssertEqual(r[0].fireDate, d(2026, 9, 8, 9, 0))
        XCTAssertEqual(r[1].fireDate, d(2026, 9, 13, 9, 0))
        XCTAssertEqual(r[2].target, .contractEnd)
    }

    func testNoEndReminderForCdi() {
        let r: [ContractReminder] = ContractRules.reminders(kind: .cdi, end: d(2026, 12, 9), trialEnd: nil, now: d(2026, 11, 1), calendar: paris)
        XCTAssertEqual(r.count, 0)
    }

    // MARK: Validation

    func testValidContractHasNoIssue() {
        let issues: [ContractIssue] = ContractRules.validate(kind: .cdd, start: d(2026, 9, 1), end: d(2026, 12, 9), weeklyHours: 13, trialEnd: d(2026, 9, 15), hourlyRate: 12.02, calendar: paris)
        XCTAssertEqual(issues, [])
    }

    func testEndBeforeStartIsBlocking() {
        let issues: [ContractIssue] = ContractRules.validate(kind: .cdd, start: d(2026, 9, 1), end: d(2026, 8, 1), weeklyHours: 13, trialEnd: nil, hourlyRate: nil, calendar: paris)
        XCTAssertEqual(issues, [.endBeforeStart])
        XCTAssertTrue(ContractRules.hasBlockingIssue(issues))
    }

    func testSameDayStartAndEndIsAllowed() {
        let issues: [ContractIssue] = ContractRules.validate(kind: .autre, start: d(2026, 9, 1, 8), end: d(2026, 9, 1, 20), weeklyHours: 5, trialEnd: nil, hourlyRate: nil, calendar: paris)
        XCTAssertEqual(issues, [])
    }

    func testWeeklyHoursLimits() {
        func h(_ v: Double) -> [ContractIssue] {
            return ContractRules.validate(kind: .cdi, start: d(2026, 9, 1), end: nil, weeklyHours: v, trialEnd: nil, hourlyRate: nil, calendar: paris)
        }
        XCTAssertEqual(h(0), [.weeklyHoursInvalid])
        XCTAssertEqual(h(-3), [.weeklyHoursInvalid])
        XCTAssertEqual(h(Double.nan), [.weeklyHoursInvalid])
        XCTAssertEqual(h(0.5), [])
        XCTAssertEqual(h(80), [])
        XCTAssertEqual(h(80.5), [.weeklyHoursImplausible])
    }

    func testTrialDatesMustFitInContract() {
        let before: [ContractIssue] = ContractRules.validate(kind: .cdd, start: d(2026, 9, 1), end: d(2026, 12, 9), weeklyHours: 13, trialEnd: d(2026, 8, 20), hourlyRate: nil, calendar: paris)
        XCTAssertEqual(before, [.trialEndBeforeStart])
        let after: [ContractIssue] = ContractRules.validate(kind: .cdd, start: d(2026, 9, 1), end: d(2026, 12, 9), weeklyHours: 13, trialEnd: d(2026, 12, 20), hourlyRate: nil, calendar: paris)
        XCTAssertEqual(after, [.trialEndAfterContractEnd])
    }

    func testNegativeRateAndMissingEndWarning() {
        let neg: [ContractIssue] = ContractRules.validate(kind: .cdi, start: d(2026, 9, 1), end: nil, weeklyHours: 13, trialEnd: nil, hourlyRate: -1, calendar: paris)
        XCTAssertEqual(neg, [.negativeRate])
        let cdd: [ContractIssue] = ContractRules.validate(kind: .cdd, start: d(2026, 9, 1), end: nil, weeklyHours: 13, trialEnd: nil, hourlyRate: nil, calendar: paris)
        XCTAssertEqual(cdd, [.missingEnd(.cdd)])
        XCTAssertFalse(ContractRules.hasBlockingIssue(cdd))
    }

    // MARK: Texte de décompte

    func testCountdownTexts() {
        let end: Date = d(2026, 12, 9)
        XCTAssertEqual(ContractRules.countdownText(kind: .cdd, end: end, now: d(2026, 11, 16), calendar: paris), "Fin de ton CDD dans 23 jours")
        XCTAssertEqual(ContractRules.countdownText(kind: .cdd, end: end, now: d(2026, 12, 8), calendar: paris), "Fin de ton CDD demain")
        XCTAssertEqual(ContractRules.countdownText(kind: .stage, end: end, now: d(2026, 12, 9), calendar: paris), "Dernier jour de ton stage")
        XCTAssertEqual(ContractRules.countdownText(kind: .cdd, end: end, now: d(2026, 12, 10), calendar: paris), "C'est fini pour ton CDD")
        XCTAssertNil(ContractRules.countdownText(kind: .cdi, end: nil, now: d(2026, 12, 10), calendar: paris))
    }

    // MARK: Suite du contrat

    func testProposedActions() {
        XCTAssertEqual(ContractRules.proposedActions(kind: .cdd, status: .ongoing), [])
        XCTAssertEqual(ContractRules.proposedActions(kind: .cdd, status: .trial), [])
        XCTAssertEqual(ContractRules.proposedActions(kind: .cdd, status: .endingSoon), [.renew, .switchToCDI, .prepareChecklist])
        XCTAssertEqual(ContractRules.proposedActions(kind: .cdd, status: .ended), [.prepareChecklist, .renew, .switchToCDI])
        XCTAssertEqual(ContractRules.proposedActions(kind: .cdi, status: .endingSoon), [])
        XCTAssertEqual(ContractRules.proposedActions(kind: .cdi, status: .ended), [.prepareChecklist])
    }

    func testRenewalDraftKeepsLengthStartsNextDay() {
        let draft: ContractDraft = ContractDraft(kind: .cdd, startDate: d(2026, 9, 1), endDate: d(2026, 12, 9), weeklyHours: 13, hourlyGrossRate: 12.02)
        let next: ContractDraft = ContractRules.renewalDraft(from: draft, now: d(2026, 11, 16), calendar: paris)
        XCTAssertEqual(next.kind, .cdd)
        XCTAssertEqual(next.startDate, makeDate(paris, 2026, 12, 10, 0, 0))
        // 99 jours après le 10 décembre 2026 : 19 mars 2027.
        XCTAssertEqual(next.endDate, makeDate(paris, 2027, 3, 19, 0, 0))
        XCTAssertEqual(next.weeklyHours, 13)
        XCTAssertEqual(next.hourlyGrossRate, 12.02)
    }

    func testCdiDraftStartsNextDayWithoutEnd() {
        let draft: ContractDraft = ContractDraft(kind: .cdd, startDate: d(2026, 9, 1), endDate: d(2026, 12, 9), weeklyHours: 13, hourlyGrossRate: nil)
        let next: ContractDraft = ContractRules.cdiDraft(from: draft, now: d(2026, 11, 16), calendar: paris)
        XCTAssertEqual(next.kind, .cdi)
        XCTAssertNil(next.endDate)
        XCTAssertEqual(next.startDate, makeDate(paris, 2026, 12, 10, 0, 0))
        XCTAssertNil(next.hourlyGrossRate)
    }

    // MARK: Checklist

    func testChecklistHasSevenUniqueItemsWithPurpose() {
        XCTAssertEqual(ContractRules.endChecklist.count, 7)
        XCTAssertEqual(Set(ContractRules.endChecklist.map { $0.id }).count, 7)
        for item in ContractRules.endChecklist {
            XCTAssertFalse(item.purpose.isEmpty, item.id)
        }
    }

    func testChecklistDoneCountIgnoresUnknownAndDuplicates() {
        XCTAssertEqual(ContractRules.checklistDoneCount(checkedIDs: []), 0)
        XCTAssertEqual(ContractRules.checklistDoneCount(checkedIDs: ["certificat", "solde", "solde", "inconnu"]), 2)
    }

    // MARK: Modèles

    func testContractKindFallbackAndTitles() {
        let c: Contract = Contract(kind: .cdd, startDate: d(2026, 9, 1), endDate: d(2026, 12, 9), weeklyHours: 13, employer: nil)
        XCTAssertEqual(c.kind, .cdd)
        c.kindRaw = "inconnu"
        XCTAssertEqual(c.kind, .autre)
        XCTAssertEqual(ContractKind.apprentissage.title, "Alternance")
        XCTAssertEqual(ContractKind.allCases.count, 7)
    }

    func testEmployerContractsInverseRelationship() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let employer: Employer = Employer(name: "Supérette du Canal")
        context.insert(employer)
        let contract: Contract = Contract(kind: .cdd, startDate: d(2026, 9, 1), endDate: d(2026, 12, 9), weeklyHours: 13, employer: employer)
        context.insert(contract)
        try context.save()
        XCTAssertEqual(employer.contracts.count, 1)
        XCTAssertEqual(employer.contracts.first?.uid, contract.uid)
    }
}
