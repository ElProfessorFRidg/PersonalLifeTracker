import XCTest
@testable import PersonalLifeTracker

// Alerte de planning tardif (section 70). Novembre 2026 : lundi 16, mardi 17, jeudi 19, dimanche 22, lundi 23.
// Moment habituel de publication dans ces tests : jeudi 18:00 (jour 5 du calendrier Apple, dimanche = 1).

final class LatePlanningRulesTests: XCTestCase {
    private let cal = TestCalendar.utc

    private func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        return makeDate(cal, 2026, 11, day, hour, minute)
    }

    private var thursdayEvening: LatePlanningSlot {
        return LatePlanningSlot(weekday: 5, minutes: 18 * 60)
    }

    private func context(now: Date,
                         enabled: Bool = true,
                         slot: LatePlanningSlot? = LatePlanningSlot(weekday: 5, minutes: 18 * 60),
                         neverRemind: Bool = false,
                         hasPlanning: Bool = false,
                         skipped: Date? = nil,
                         lastReminder: Date? = nil,
                         leave: Bool = false,
                         exam: Bool = false,
                         quiet: Bool = false) -> LatePlanningContext {
        return LatePlanningContext(now: now,
                                   calendar: cal,
                                   settings: LatePlanningSettings(isEnabled: enabled, slot: slot, neverRemind: neverRemind),
                                   hasPlanningForNextWeek: hasPlanning,
                                   skippedWeekStart: skipped,
                                   lastReminderAt: lastReminder,
                                   isOnLeaveOrVacation: leave,
                                   isExamMode: exam,
                                   isQuietHours: quiet)
    }

    // MARK: - Désactivé et sans créneau

    func testDisabledByDefaultStaysSilent() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 10, 0), enabled: false)), .silent(.disabled))
        let defaults = LatePlanningSettings()
        XCTAssertFalse(defaults.isEnabled, "le réglage est désactivé par défaut")
    }

    func testNeverRemindStaysSilent() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 10, 0), neverRemind: true)), .silent(.disabled))
    }

    func testNoSlotMeansNothingToCompareTo() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 10, 0), slot: nil)), .silent(.noSlot))
    }

    // MARK: - Échéance

    func testBeforeDeadlineIsSilent() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(17, 12, 0))), .silent(.beforeDeadline))
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(19, 17, 59))), .silent(.beforeDeadline))
    }

    func testRemindsExactlyAtDeadline() {
        let decision = LatePlanningRules.decide(context(now: at(19, 18, 0)))
        guard case .remind(let reminder) = decision else {
            XCTFail("attendu : un rappel à 18:00 pile")
            return
        }
        XCTAssertEqual(reminder.nextWeekStart, makeDate(cal, 2026, 11, 23, 0, 0))
    }

    func testReminderTextAndActions() {
        let decision = LatePlanningRules.decide(context(now: at(20, 9, 0)))
        guard case .remind(let reminder) = decision else {
            XCTFail("attendu : un rappel le vendredi matin")
            return
        }
        XCTAssertEqual(reminder.title, "Le planning de la semaine prochaine est pas encore là")
        XCTAssertEqual(reminder.message, "Tu l'as reçu ?")
        XCTAssertEqual(reminder.notificationBody, "Le planning de la semaine prochaine est pas encore là, tu l'as reçu ?")
        XCTAssertEqual(reminder.actions, [.importPhoto, .notReceivedYet, .skipThisWeek, .neverRemind])
        XCTAssertEqual(LatePlanningAction.importPhoto.title, "Importer une photo")
        XCTAssertEqual(LatePlanningAction.notReceivedYet.title, "Pas encore reçu")
        XCTAssertEqual(LatePlanningAction.skipThisWeek.title, "Pas cette semaine")
        XCTAssertEqual(LatePlanningAction.neverRemind.title, "Ne plus me le rappeler")
    }

    func testSundayDeadlineBelongsToTheMondayFirstWeek() {
        let sunday = LatePlanningSlot(weekday: 1, minutes: 20 * 60)
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(22, 19, 59), slot: sunday)), .silent(.beforeDeadline))
        let decision = LatePlanningRules.decide(context(now: at(22, 20, 0), slot: sunday))
        guard case .remind(let reminder) = decision else {
            XCTFail("attendu : un rappel le dimanche à 20:00")
            return
        }
        XCTAssertEqual(reminder.nextWeekStart, makeDate(cal, 2026, 11, 23, 0, 0))
    }

    func testMondayIsTheStartOfANewWeekWithItsOwnDeadline() {
        // Lundi 23 : l'échéance de cette semaine est jeudi 26 18:00, pas celle de la semaine passée.
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(23, 9, 0))), .silent(.beforeDeadline))
    }

    // MARK: - Raisons de se taire

    func testPlanningAlreadyThereIsSilent() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 9, 0), hasPlanning: true)), .silent(.planningPresent))
    }

    func testSkippedWeekIsSilentButOnlyForThatWeek() {
        let nextWeek = makeDate(cal, 2026, 11, 23, 0, 0)
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 9, 0), skipped: nextWeek)), .silent(.skippedWeek))
        // Une semaine ignorée plus tôt ne bloque pas celle-ci.
        let older = makeDate(cal, 2026, 11, 16, 0, 0)
        guard case .remind = LatePlanningRules.decide(context(now: at(20, 9, 0), skipped: older)) else {
            XCTFail("attendu : un rappel, la semaine ignorée est une autre")
            return
        }
    }

    func testLeaveVacationAndExamModeAreSilent() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 9, 0), leave: true)), .silent(.leaveOrVacation))
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 9, 0), exam: true)), .silent(.examMode))
    }

    func testQuietHoursAreSilent() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(19, 23, 0), quiet: true)), .silent(.quietHours))
    }

    func testAtMostOneReminderPerWeek() {
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(20, 10, 0), lastReminder: at(19, 18, 5))),
                       .silent(.alreadyRemindedThisWeek))
        // Dimanche soir encore la même semaine (lundi premier).
        XCTAssertEqual(LatePlanningRules.decide(context(now: at(22, 21, 0), lastReminder: at(19, 18, 5))),
                       .silent(.alreadyRemindedThisWeek))
    }

    func testReminderOfPreviousWeekDoesNotBlock() {
        guard case .remind(let reminder) = LatePlanningRules.decide(context(now: at(26, 18, 30), lastReminder: at(22, 23, 0))) else {
            XCTFail("attendu : un rappel, le dernier date de la semaine d'avant")
            return
        }
        XCTAssertEqual(reminder.nextWeekStart, makeDate(cal, 2026, 11, 30, 0, 0))
    }

    // MARK: - Semaine

    func testWeekStartIsAlwaysMonday() {
        let monday = makeDate(cal, 2026, 11, 16, 0, 0)
        XCTAssertEqual(LatePlanningRules.weekStart(of: at(16, 0, 0), calendar: cal), monday)
        XCTAssertEqual(LatePlanningRules.weekStart(of: at(18, 15, 30), calendar: cal), monday)
        XCTAssertEqual(LatePlanningRules.weekStart(of: at(22, 23, 59), calendar: cal), monday)
        XCTAssertEqual(LatePlanningRules.weekStart(of: at(23, 0, 0), calendar: cal), makeDate(cal, 2026, 11, 23, 0, 0))
        XCTAssertEqual(LatePlanningRules.nextWeekStart(after: at(22, 23, 59), calendar: cal), makeDate(cal, 2026, 11, 23, 0, 0))
    }

    func testSlotIsClamped() {
        let slot = LatePlanningSlot(weekday: 9, minutes: 5000)
        XCTAssertEqual(slot.weekday, 7)
        XCTAssertEqual(slot.minutes, 1439)
        let low = LatePlanningSlot(weekday: 0, minutes: -5)
        XCTAssertEqual(low.weekday, 1)
        XCTAssertEqual(low.minutes, 0)
    }

    // MARK: - Moment appris

    func testSuggestedSlotNeedsThreeImportsOnTheSameWeekday() {
        // Jeudis 5, 12 et 19 novembre 2026, vers 18 h.
        let imports = [at(5, 17, 50), at(12, 18, 10), at(19, 18, 20)]
        let slot = LatePlanningRules.suggestedSlot(importDates: imports, calendar: cal)
        XCTAssertEqual(slot, LatePlanningSlot(weekday: 5, minutes: 18 * 60))
    }

    func testSuggestedSlotNilWithTwoImports() {
        XCTAssertNil(LatePlanningRules.suggestedSlot(importDates: [at(5, 18, 0), at(12, 18, 0)], calendar: cal))
    }

    func testSuggestedSlotNilWhenWeekdaysAreScattered() {
        let imports = [at(5, 18, 0), at(10, 18, 0), at(18, 18, 0)]
        XCTAssertNil(LatePlanningRules.suggestedSlot(importDates: imports, calendar: cal))
    }

    func testSuggestedSlotToleratesOneOutlier() {
        // Trois jeudis et un lundi : 3 sur 4, la majorité l'emporte.
        let imports = [at(5, 18, 0), at(9, 8, 0), at(12, 18, 0), at(19, 18, 0)]
        XCTAssertEqual(LatePlanningRules.suggestedSlot(importDates: imports, calendar: cal),
                       LatePlanningSlot(weekday: 5, minutes: 18 * 60))
    }

    func testSuggestedSlotNilWhenMajorityIsTooThin() {
        // Trois jeudis sur six imports : pas assez pour supposer un rythme.
        let imports = [at(5, 18, 0), at(12, 18, 0), at(19, 18, 0), at(9, 8, 0), at(10, 9, 0), at(11, 10, 0)]
        XCTAssertNil(LatePlanningRules.suggestedSlot(importDates: imports, calendar: cal))
    }
}
