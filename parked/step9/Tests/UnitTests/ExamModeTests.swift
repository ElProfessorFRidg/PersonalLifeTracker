import XCTest
@testable import PersonalLifeTracker

final class ExamModeTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris

    private func at(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        return makeDate(paris, 2026, m, d, h, min)
    }

    /// Période du lundi 8 juin au vendredi 19 juin 2026, avec deux épreuves.
    private func period() -> ExamPeriod {
        let maths = ExamEntry(id: UUID(), title: "Maths", start: at(6, 10, 8, 0))
        let histoire = ExamEntry(id: UUID(), title: "Histoire", start: at(6, 9, 14, 0))
        return ExamPeriod(title: "Bac blanc", startDay: at(6, 8), endDay: at(6, 19), exams: [maths, histoire])
    }

    func testPhaseBoundaries() {
        let p: ExamPeriod = period()
        XCTAssertEqual(ExamModeRules.phase(of: p, now: at(6, 1, 12, 0), calendar: paris), .upcoming(daysUntilStart: 7))
        XCTAssertEqual(ExamModeRules.phase(of: p, now: at(6, 7, 23, 59), calendar: paris), .upcoming(daysUntilStart: 1))
        XCTAssertEqual(ExamModeRules.phase(of: p, now: at(6, 8, 0, 0), calendar: paris), .active)
        XCTAssertEqual(ExamModeRules.phase(of: p, now: at(6, 19, 23, 59), calendar: paris), .active)
        XCTAssertEqual(ExamModeRules.phase(of: p, now: at(6, 20, 0, 0), calendar: paris), .over)
    }

    func testCoversAndValidate() {
        let p: ExamPeriod = period()
        XCTAssertTrue(ExamModeRules.covers(p, day: at(6, 19, 22, 0), calendar: paris))
        XCTAssertFalse(ExamModeRules.covers(p, day: at(6, 7, 22, 0), calendar: paris))
        XCTAssertTrue(ExamModeRules.validate(startDay: at(6, 8), endDay: at(6, 8, 18, 0), calendar: paris))
        XCTAssertFalse(ExamModeRules.validate(startDay: at(6, 8), endDay: at(6, 7, 23, 0), calendar: paris))
    }

    func testNextExamPicksEarliestNotPast() {
        let p: ExamPeriod = period()
        XCTAssertEqual(ExamModeRules.nextExam(in: p, now: at(6, 1))?.title, "Histoire")
        XCTAssertEqual(ExamModeRules.nextExam(in: p, now: at(6, 9, 14, 0))?.title, "Histoire")
        XCTAssertEqual(ExamModeRules.nextExam(in: p, now: at(6, 9, 14, 1))?.title, "Maths")
        XCTAssertNil(ExamModeRules.nextExam(in: p, now: at(6, 10, 8, 1)))
    }

    func testNotificationsOnlyEssentialDuringPeriod() {
        let p: ExamPeriod = period()
        XCTAssertFalse(ExamModeRules.allows(.reminder, period: p, now: at(6, 12, 10, 0), calendar: paris))
        XCTAssertTrue(ExamModeRules.allows(.essential, period: p, now: at(6, 12, 10, 0), calendar: paris))
        XCTAssertTrue(ExamModeRules.allows(.reminder, period: p, now: at(6, 7, 10, 0), calendar: paris))
        XCTAssertTrue(ExamModeRules.allows(.reminder, period: p, now: at(6, 20, 10, 0), calendar: paris))
        XCTAssertTrue(ExamModeRules.allows(.reminder, period: nil, now: at(6, 12, 10, 0), calendar: paris))
        XCTAssertTrue(ExamModeRules.quietsSuggestions(p, now: at(6, 15, 9, 0), calendar: paris))
        XCTAssertFalse(ExamModeRules.quietsSuggestions(nil, now: at(6, 15, 9, 0), calendar: paris))
    }

    func testGoalsSuspendedAndStatsNote() {
        let p: ExamPeriod = period()
        XCTAssertTrue(ExamModeRules.goalsSuspended(p, day: at(6, 8, 7, 0), calendar: paris))
        XCTAssertFalse(ExamModeRules.goalsSuspended(p, day: at(6, 20, 7, 0), calendar: paris))
        XCTAssertFalse(ExamModeRules.goalsSuspended(nil, day: at(6, 8), calendar: paris))
        XCTAssertEqual(ExamModeRules.statsNote(p, day: at(6, 12), calendar: paris), "Période d'examens : Bac blanc")
        XCTAssertNil(ExamModeRules.statsNote(p, day: at(6, 22), calendar: paris))
        let unnamed = ExamPeriod(title: "  ", startDay: at(6, 8), endDay: at(6, 19))
        XCTAssertEqual(ExamModeRules.statsNote(unnamed, day: at(6, 12), calendar: paris), "Période d'examens")
    }

    func testPeriodText() {
        let p: ExamPeriod = period()
        XCTAssertEqual(ExamModeRules.periodText(p, now: at(6, 12), calendar: paris), "Période d'examens en cours")
        XCTAssertEqual(ExamModeRules.periodText(p, now: at(6, 7, 9, 0), calendar: paris), "La période commence demain")
        // 14 jours avant : affiché. 15 jours avant : pas encore.
        XCTAssertEqual(ExamModeRules.periodText(p, now: at(5, 25, 9, 0), calendar: paris), "La période commence dans 14 jours")
        XCTAssertNil(ExamModeRules.periodText(p, now: at(5, 24, 9, 0), calendar: paris))
        XCTAssertNil(ExamModeRules.periodText(p, now: at(6, 20, 9, 0), calendar: paris))
    }

    func testExamText() {
        let maths = ExamEntry(title: "Maths", start: at(6, 10, 8, 0))
        XCTAssertEqual(ExamModeRules.examText(maths, now: at(6, 10, 6, 0), calendar: paris), "Maths : aujourd'hui à 08:00")
        XCTAssertEqual(ExamModeRules.examText(maths, now: at(6, 9, 22, 0), calendar: paris), "Maths : demain à 08:00")
        XCTAssertEqual(ExamModeRules.examText(maths, now: at(6, 5, 12, 0), calendar: paris), "Maths : dans 5 jours")
        let blank = ExamEntry(title: " ", start: at(6, 10, 8, 0))
        XCTAssertEqual(ExamModeRules.examText(blank, now: at(6, 9, 22, 0), calendar: paris), "Épreuve : demain à 08:00")
    }

    func testSkipToday() {
        XCTAssertTrue(ExamModeRules.isSkipped(skippedDay: "2026-06-12", now: at(6, 12, 23, 30), calendar: paris))
        XCTAssertFalse(ExamModeRules.isSkipped(skippedDay: "2026-06-12", now: at(6, 13, 0, 5), calendar: paris))
        XCTAssertFalse(ExamModeRules.isSkipped(skippedDay: nil, now: at(6, 12), calendar: paris))
    }

    func testStoreRoundTripAndSkip() {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let store = ExamModeStore(defaults: iso.defaults)
        XCTAssertNil(store.period())
        let p: ExamPeriod = period()
        store.save(p)
        XCTAssertEqual(store.period(), p)
        store.skipToday(now: at(6, 12, 9, 0), calendar: paris)
        XCTAssertEqual(store.skippedDay, "2026-06-12")
        store.clearSkip()
        XCTAssertNil(store.skippedDay)
        store.save(nil)
        XCTAssertNil(store.period())
    }

    func testFacadeFollowsStore() {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let store = ExamModeStore(defaults: iso.defaults)
        XCTAssertFalse(ExamMode.isActive(now: at(6, 12), calendar: paris, store: store))
        XCTAssertTrue(ExamMode.allows(.reminder, now: at(6, 12), calendar: paris, store: store))
        store.save(period())
        XCTAssertTrue(ExamMode.isActive(now: at(6, 12), calendar: paris, store: store))
        XCTAssertFalse(ExamMode.allows(.reminder, now: at(6, 12), calendar: paris, store: store))
        XCTAssertTrue(ExamMode.allows(.essential, now: at(6, 12), calendar: paris, store: store))
    }
}
