import XCTest

final class PlanningRulesTests: XCTestCase {
    private let utc: Calendar = TestCalendar.utc
    private let paris: Calendar = TestCalendar.paris

    private func slot(_ start: Date, _ end: Date, _ activity: ActivityType = .work) -> PlanSlot {
        return PlanSlot(id: UUID(), start: start, end: end, activity: activity)
    }

    func testWeekStartIsMonday() {
        let monday: Date = makeDate(utc, 2026, 11, 16, 0, 0)
        XCTAssertEqual(PlanningRules.weekStart(for: makeDate(utc, 2026, 11, 18, 14, 30), calendar: utc), monday)
        XCTAssertEqual(PlanningRules.weekStart(for: makeDate(utc, 2026, 11, 22, 23, 30), calendar: utc), monday)
        XCTAssertEqual(PlanningRules.weekStart(for: monday, calendar: utc), monday)
        XCTAssertEqual(PlanningRules.weekStart(for: makeDate(utc, 2026, 11, 23, 0, 0), calendar: utc),
                       makeDate(utc, 2026, 11, 23, 0, 0))
    }

    func testDaysOfWeek() {
        let days: [Date] = PlanningRules.days(ofWeekStarting: makeDate(utc, 2026, 11, 16, 0, 0), calendar: utc)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days[6], makeDate(utc, 2026, 11, 22, 0, 0))
    }

    func testSlotsInWeekUseStartDay() {
        let weekStart: Date = makeDate(utc, 2026, 11, 16, 0, 0)
        let inside: PlanSlot = slot(makeDate(utc, 2026, 11, 22, 22, 0), makeDate(utc, 2026, 11, 23, 2, 0))
        let before: PlanSlot = slot(makeDate(utc, 2026, 11, 15, 22, 0), makeDate(utc, 2026, 11, 16, 2, 0))
        let after: PlanSlot = slot(makeDate(utc, 2026, 11, 23, 8, 0), makeDate(utc, 2026, 11, 23, 12, 0))
        let result: [PlanSlot] = PlanningRules.slots(inWeekStarting: weekStart, slots: [after, before, inside], calendar: utc)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, inside.id)
    }

    func testSlotsOnDayIncludesMidnightCrossingAndAllActivities() {
        let night: PlanSlot = slot(makeDate(utc, 2026, 11, 16, 22, 0), makeDate(utc, 2026, 11, 17, 2, 0))
        let shop: PlanSlot = slot(makeDate(utc, 2026, 11, 17, 12, 0), makeDate(utc, 2026, 11, 17, 13, 0), .shopping)
        let other: PlanSlot = slot(makeDate(utc, 2026, 11, 18, 8, 0), makeDate(utc, 2026, 11, 18, 9, 0))
        let result: [PlanSlot] = PlanningRules.slots(onDay: makeDate(utc, 2026, 11, 17, 10, 0), slots: [other, shop, night], calendar: utc)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, night.id)
        XCTAssertEqual(result[1].id, shop.id)
    }

    func testPlannedMinutesSplitAtMidnight() {
        let s: PlanSlot = slot(makeDate(utc, 2026, 11, 16, 22, 0), makeDate(utc, 2026, 11, 17, 2, 0))
        XCTAssertEqual(PlanningRules.plannedMinutes(day: makeDate(utc, 2026, 11, 16, 9, 0), slots: [s], calendar: utc), 120)
        XCTAssertEqual(PlanningRules.plannedMinutes(day: makeDate(utc, 2026, 11, 17, 9, 0), slots: [s], calendar: utc), 120)
        XCTAssertEqual(PlanningRules.plannedMinutes(weekStarting: makeDate(utc, 2026, 11, 16, 0, 0), slots: [s], calendar: utc), 240)
    }

    func testPlannedMinutesOnDstDayCountsRealElapsedTime() {
        // Dimanche 25 octobre 2026, Paris : 00:00 (UTC+2) à 08:00 (UTC+1) = 9 h réelles.
        let s: PlanSlot = slot(makeDate(paris, 2026, 10, 25, 0, 0), makeDate(paris, 2026, 10, 25, 8, 0))
        XCTAssertEqual(PlanningRules.plannedMinutes(day: makeDate(paris, 2026, 10, 25, 12, 0), slots: [s], calendar: paris), 540)
    }

    func testOnlyWorkAndEducationAreCounted() {
        let shop: PlanSlot = slot(makeDate(utc, 2026, 11, 16, 12, 0), makeDate(utc, 2026, 11, 16, 13, 0), .shopping)
        let edu: PlanSlot = slot(makeDate(utc, 2026, 11, 16, 8, 0), makeDate(utc, 2026, 11, 16, 12, 0), .education)
        XCTAssertEqual(PlanningRules.plannedMinutes(day: makeDate(utc, 2026, 11, 16, 0, 0), slots: [shop, edu], calendar: utc), 240)
    }

    func testDoneMinutesOngoingSessionUsesNow() {
        let r: RealSlot = RealSlot(start: makeDate(utc, 2026, 11, 16, 17, 56), end: nil, activity: .work)
        let now: Date = makeDate(utc, 2026, 11, 16, 19, 10)
        XCTAssertEqual(PlanningRules.doneMinutes(day: makeDate(utc, 2026, 11, 16, 0, 0), real: [r], now: now, calendar: utc), 74)
    }

    func testComparisonDifference() {
        let planned: PlanSlot = slot(makeDate(utc, 2026, 11, 16, 18, 0), makeDate(utc, 2026, 11, 16, 21, 0))
        let real: RealSlot = RealSlot(start: makeDate(utc, 2026, 11, 16, 17, 56), end: nil, activity: .work)
        let now: Date = makeDate(utc, 2026, 11, 16, 19, 10)
        let result: [DayComparison] = PlanningRules.comparison(weekStarting: makeDate(utc, 2026, 11, 16, 0, 0),
                                                               slots: [planned], real: [real], now: now, calendar: utc)
        XCTAssertEqual(result.count, 7)
        XCTAssertEqual(result[0].plannedMinutes, 180)
        XCTAssertEqual(result[0].doneMinutes, 74)
        XCTAssertEqual(result[0].differenceMinutes, -106)
        XCTAssertEqual(result[1].plannedMinutes, 0)
        XCTAssertEqual(result[1].differenceMinutes, 0)
    }

    func testValidation() {
        let start: Date = makeDate(utc, 2026, 11, 16, 22, 0)
        XCTAssertEqual(PlanningRules.validate(start: start, end: start), .endNotAfterStart)
        XCTAssertEqual(PlanningRules.validate(start: start, end: makeDate(utc, 2026, 11, 16, 21, 0)), .endNotAfterStart)
        XCTAssertEqual(PlanningRules.validate(start: start, end: makeDate(utc, 2026, 11, 17, 6, 0)), .valid)
        XCTAssertEqual(PlanningRules.validate(start: start, end: makeDate(utc, 2026, 11, 17, 22, 0)), .valid)
        XCTAssertEqual(PlanningRules.validate(start: start, end: makeDate(utc, 2026, 11, 17, 22, 1)), .tooLong)
    }

    func testOverlapDetection() {
        let existing: PlanSlot = slot(makeDate(utc, 2026, 11, 16, 8, 0), makeDate(utc, 2026, 11, 16, 12, 0))
        let touching: [PlanSlot] = PlanningRules.overlapping(start: makeDate(utc, 2026, 11, 16, 12, 0),
                                                             end: makeDate(utc, 2026, 11, 16, 13, 0),
                                                             in: [existing], excluding: nil)
        XCTAssertEqual(touching.count, 0)
        let overlapping: [PlanSlot] = PlanningRules.overlapping(start: makeDate(utc, 2026, 11, 16, 11, 59),
                                                                end: makeDate(utc, 2026, 11, 16, 13, 0),
                                                                in: [existing], excluding: nil)
        XCTAssertEqual(overlapping.count, 1)
        let selfOnly: [PlanSlot] = PlanningRules.overlapping(start: makeDate(utc, 2026, 11, 16, 9, 0),
                                                          end: makeDate(utc, 2026, 11, 16, 10, 0),
                                                          in: [existing], excluding: existing.id)
        XCTAssertEqual(selfOnly.count, 0)
    }

    func testCopyWeekKeepsWallClockAcrossDst() {
        // Semaine du 19 octobre (heure d'été) copiée vers celle du 26 (heure d'hiver).
        let monday: PlanSlot = slot(makeDate(paris, 2026, 10, 19, 8, 0), makeDate(paris, 2026, 10, 19, 12, 0), .education)
        let night: PlanSlot = slot(makeDate(paris, 2026, 10, 24, 22, 0), makeDate(paris, 2026, 10, 25, 6, 0), .work)
        let outside: PlanSlot = slot(makeDate(paris, 2026, 10, 12, 8, 0), makeDate(paris, 2026, 10, 12, 12, 0))
        let copy: [PlanSlot] = PlanningRules.copyWeek(slots: [monday, night, outside],
                                                      fromWeekStart: makeDate(paris, 2026, 10, 19, 0, 0),
                                                      toWeekStart: makeDate(paris, 2026, 10, 26, 0, 0),
                                                      calendar: paris)
        XCTAssertEqual(copy.count, 2)
        XCTAssertEqual(copy[0].start, makeDate(paris, 2026, 10, 26, 8, 0))
        XCTAssertEqual(copy[0].end, makeDate(paris, 2026, 10, 26, 12, 0))
        XCTAssertEqual(copy[0].activity, .education)
        XCTAssertNotEqual(copy[0].id, monday.id)
        XCTAssertEqual(copy[1].start, makeDate(paris, 2026, 10, 31, 22, 0))
        XCTAssertEqual(copy[1].end, makeDate(paris, 2026, 11, 1, 6, 0))
    }

    func testWeekTitle() {
        XCTAssertEqual(PlanningRules.weekTitle(weekStart: makeDate(utc, 2026, 11, 16, 0, 0), calendar: utc), "Du 16 au 22 novembre")
        XCTAssertEqual(PlanningRules.weekTitle(weekStart: makeDate(utc, 2026, 11, 30, 0, 0), calendar: utc), "Du 30 novembre au 6 décembre")
    }

    func testLeaveCoversInclusiveDays() {
        let start: Date = makeDate(utc, 2026, 11, 16, 0, 0)
        let end: Date = makeDate(utc, 2026, 11, 18, 0, 0)
        XCTAssertTrue(PlanningRules.leaveCovers(day: makeDate(utc, 2026, 11, 18, 12, 0), startDay: start, endDay: end, calendar: utc))
        XCTAssertTrue(PlanningRules.leaveCovers(day: makeDate(utc, 2026, 11, 16, 0, 0), startDay: start, endDay: end, calendar: utc))
        XCTAssertFalse(PlanningRules.leaveCovers(day: makeDate(utc, 2026, 11, 19, 0, 0), startDay: start, endDay: end, calendar: utc))
        XCTAssertFalse(PlanningRules.leaveCovers(day: makeDate(utc, 2026, 11, 15, 23, 59), startDay: start, endDay: end, calendar: utc))
    }
}
