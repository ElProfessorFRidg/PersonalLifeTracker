import XCTest
@testable import PersonalLifeTracker

final class StudySlotsTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris

    /// Lundi 16 novembre 2026, heure de Paris.
    private func nov(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        return makeDate(paris, 2026, 11, d, h, m)
    }

    private func oneDay() -> StudySlotConfig {
        var c = StudySlotConfig()
        c.horizonDays = 1
        return c
    }

    private func spans(_ slots: [StudySlot]) -> [String] {
        return slots.map { "\(Formatting.clock($0.start, calendar: paris))-\(Formatting.clock($0.end, calendar: paris))" }
    }

    // Journée vide 08:00 à 21:00, blocs de 120 min, pauses de 15 min : le dernier bloc fait 105 min.
    func testEmptyDayIsCutInBlocks() {
        let slots: [StudySlot] = StudySlotsRules.slots(now: nov(16, 6), busy: [], exams: [], config: oneDay(), calendar: paris)
        XCTAssertEqual(spans(slots), ["08:00-10:00", "10:15-12:15", "12:30-14:30", "14:45-16:45", "17:00-19:00", "19:15-21:00"])
        XCTAssertEqual(slots.map { $0.minutes }, [120, 120, 120, 120, 120, 105])
    }

    // Cours 12:00 à 14:00, marge de 15 min : libre 08:00 à 11:45, puis 14:15 à 21:00.
    func testBusyIntervalWithMargin() {
        let busy: [StudyBusy] = [StudyBusy(start: nov(16, 12), end: nov(16, 14))]
        let slots: [StudySlot] = StudySlotsRules.slots(now: nov(16, 6), busy: busy, exams: [], config: oneDay(), calendar: paris)
        XCTAssertEqual(spans(slots), ["08:00-10:00", "10:15-11:45", "14:15-16:15", "16:30-18:30", "18:45-20:45"])
        XCTAssertEqual(slots.map { $0.minutes }, [120, 90, 120, 120, 120])
    }

    // Trou de 30 min entre deux occupations (09:15 à 09:45 après marges) : refusé sous 31 min, accepté à 30.
    func testMinimumLengthBoundary() {
        let busy: [StudyBusy] = [StudyBusy(start: nov(16, 8), end: nov(16, 9)), StudyBusy(start: nov(16, 10), end: nov(16, 21))]
        var config: StudySlotConfig = oneDay()
        config.minMinutes = 31
        XCTAssertEqual(StudySlotsRules.slots(now: nov(16, 6), busy: busy, exams: [], config: config, calendar: paris).count, 0)
        config.minMinutes = 30
        let slots: [StudySlot] = StudySlotsRules.slots(now: nov(16, 6), busy: busy, exams: [], config: config, calendar: paris)
        XCTAssertEqual(spans(slots), ["09:15-09:45"])
        // Défaut de la spec : 45 minutes.
        XCTAssertEqual(StudySlotConfig().minMinutes, 45)
    }

    func testNothingBeforeNow() {
        let slots: [StudySlot] = StudySlotsRules.slots(now: nov(16, 15, 10), busy: [], exams: [], config: oneDay(), calendar: paris)
        XCTAssertEqual(spans(slots), ["15:10-17:10", "17:25-19:25", "19:40-21:00"])
    }

    func testNoSlotOutsideQuietHoursOverAWeek() {
        let slots: [StudySlot] = StudySlotsRules.slots(now: nov(16, 3), busy: [], exams: [], config: StudySlotConfig(), calendar: paris)
        XCTAssertEqual(slots.count, 42)
        for s in slots {
            let startMinutes: Int = paris.component(.hour, from: s.start) * 60 + paris.component(.minute, from: s.start)
            let endMinutes: Int = paris.component(.hour, from: s.end) * 60 + paris.component(.minute, from: s.end)
            XCTAssertGreaterThanOrEqual(startMinutes, 8 * 60)
            XCTAssertLessThanOrEqual(endMinutes, 21 * 60)
        }
    }

    // L'épreuve du 18 à 09:00 dure 120 min supposées, marge 15 : libre jusqu'à 08:45 puis dès 11:15.
    func testExamBecomesBusyAndSlotsKnowTheirExam() {
        let exams: [StudyExam] = [StudyExam(title: "Maths", start: nov(18, 9))]
        var config: StudySlotConfig = StudySlotConfig()
        config.horizonDays = 3
        let slots: [StudySlot] = StudySlotsRules.slots(now: nov(16, 6), busy: [], exams: exams, config: config, calendar: paris)
        // Le 17 : premier créneau 08:00-10:00, l'épreuve est dans 1 jour.
        let tuesday: [StudySlot] = slots.filter { paris.isDate($0.start, inSameDayAs: nov(17, 12)) }
        XCTAssertEqual(Formatting.clock(tuesday[0].start, calendar: paris), "08:00")
        XCTAssertEqual(tuesday[0].examTitle, "Maths")
        XCTAssertEqual(tuesday[0].daysToExam, 1)
        // Le 18 : 08:00-08:45 (45 min) puis 11:15 (11:00 + marge), rien pendant l'épreuve.
        let wednesday: [StudySlot] = slots.filter { paris.isDate($0.start, inSameDayAs: nov(18, 12)) }
        XCTAssertEqual(spans(wednesday).first, "08:00-08:45")
        XCTAssertEqual(wednesday[0].daysToExam, 0)
        XCTAssertEqual(spans(wednesday)[1], "11:15-13:15")
        XCTAssertNil(wednesday[1].examTitle)
    }

    func testHintsAndLabels() {
        let slot = StudySlot(start: nov(17, 17), end: nov(17, 18, 30), examTitle: "Maths", daysToExam: 2)
        XCTAssertEqual(StudySlotsRules.examHint(slot), "Avant Maths, dans 2 jours")
        XCTAssertEqual(StudySlotsRules.examHint(StudySlot(start: nov(17, 17), end: nov(17, 18), examTitle: "Maths", daysToExam: 1)), "Avant Maths, demain")
        XCTAssertNil(StudySlotsRules.examHint(StudySlot(start: nov(17, 17), end: nov(17, 18), examTitle: nil, daysToExam: nil)))
        XCTAssertEqual(slot.minutes, 90)
        XCTAssertEqual(StudySlotsRules.dayLabel(nov(16, 0), now: nov(16, 9), calendar: paris), "Aujourd'hui")
        XCTAssertEqual(StudySlotsRules.dayLabel(nov(17, 0), now: nov(16, 9), calendar: paris), "Demain")
        XCTAssertEqual(StudySlotsRules.dayLabel(nov(19, 0), now: nov(16, 9), calendar: paris), "jeudi 19 novembre")
    }

    func testBlocksSplitting() {
        let config: StudySlotConfig = StudySlotConfig()
        // 100 min : un bloc de 100.
        XCTAssertEqual(StudySlotsRules.blocks(in: StudyBusy(start: nov(16, 8), end: nov(16, 9, 40)), config: config).map { $0.end.timeIntervalSince($0.start) / 60 }, [100])
        // 160 min : 120, puis 25 min restants après la pause, trop court.
        XCTAssertEqual(StudySlotsRules.blocks(in: StudyBusy(start: nov(16, 8), end: nov(16, 10, 40)), config: config).count, 1)
        // 180 min : 120, pause 15, puis 45 min.
        let three: [StudyBusy] = StudySlotsRules.blocks(in: StudyBusy(start: nov(16, 8), end: nov(16, 11)), config: config)
        XCTAssertEqual(three.count, 2)
        XCTAssertEqual(three[1].start, nov(16, 10, 15))
        XCTAssertEqual(three[1].end, nov(16, 11))
    }

    func testMergedAndFreeIntervals() {
        let merged: [StudyBusy] = StudySlotsRules.merged([
            StudyBusy(start: nov(16, 14), end: nov(16, 16)),
            StudyBusy(start: nov(16, 8), end: nov(16, 10)),
            StudyBusy(start: nov(16, 10), end: nov(16, 11)),
            StudyBusy(start: nov(16, 15), end: nov(16, 15, 30)),
            StudyBusy(start: nov(16, 12), end: nov(16, 12))
        ])
        XCTAssertEqual(merged, [StudyBusy(start: nov(16, 8), end: nov(16, 11)), StudyBusy(start: nov(16, 14), end: nov(16, 16))])
        // Une occupation qui a commencé avant la fenêtre la raccourcit.
        let free: [StudyBusy] = StudySlotsRules.freeIntervals(from: nov(16, 9), to: nov(16, 12),
                                                              busy: [StudyBusy(start: nov(16, 7), end: nov(16, 10))], marginMinutes: 0)
        XCTAssertEqual(free, [StudyBusy(start: nov(16, 10), end: nov(16, 12))])
        // Occupation entièrement hors fenêtre : tout est libre.
        let all: [StudyBusy] = StudySlotsRules.freeIntervals(from: nov(16, 9), to: nov(16, 12),
                                                             busy: [StudyBusy(start: nov(16, 13), end: nov(16, 14))], marginMinutes: 0)
        XCTAssertEqual(all, [StudyBusy(start: nov(16, 9), end: nov(16, 12))])
    }

    // 29 mars 2026 : passage à l'heure d'été à 02:00. Les heures calmes restent 08:00 à 21:00 à l'horloge.
    func testSpringForwardDayKeepsWallClockWindow() {
        let now: Date = makeDate(paris, 2026, 3, 29, 6, 0)
        let slots: [StudySlot] = StudySlotsRules.slots(now: now, busy: [], exams: [], config: oneDay(), calendar: paris)
        XCTAssertEqual(slots.count, 6)
        XCTAssertEqual(slots[0].start, makeDate(paris, 2026, 3, 29, 8, 0))
        XCTAssertEqual(slots[5].end, makeDate(paris, 2026, 3, 29, 21, 0))
        // 08:00 CEST = 06:00 UTC.
        XCTAssertEqual(slots[0].start, makeDate(TestCalendar.utc, 2026, 3, 29, 6, 0))
        XCTAssertEqual(slots[0].minutes, 120)
    }

    // 25 octobre 2026 : retour à l'heure d'hiver à 03:00. 08:00 CET = 07:00 UTC.
    func testFallBackDayKeepsWallClockWindow() {
        let now: Date = makeDate(paris, 2026, 10, 25, 1, 0)
        let slots: [StudySlot] = StudySlotsRules.slots(now: now, busy: [], exams: [], config: oneDay(), calendar: paris)
        XCTAssertEqual(slots.count, 6)
        XCTAssertEqual(slots[0].start, makeDate(TestCalendar.utc, 2026, 10, 25, 7, 0))
        XCTAssertEqual(slots[5].end, makeDate(TestCalendar.utc, 2026, 10, 25, 20, 0))
    }

    func testReservedConstants() {
        XCTAssertEqual(StudySlotsRules.reservedNote, "Révision")
        XCTAssertEqual(StudySlotsRules.reservedSource, "manual")
    }
}
