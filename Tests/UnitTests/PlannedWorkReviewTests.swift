import XCTest
@testable import PersonalLifeTracker

final class PlannedWorkReviewTests: XCTestCase {
    func testDatedWorkShiftCanBeReviewedWithoutAnyLocationHistory() {
        let shift = PlanSlot(id: UUID(), start: nov16(8, 0), end: nov16(12, 0), activity: .work)
        XCTAssertTrue(PlannedWorkReview.hasUnloggedWork(shift, sessions: [], leaveDays: [],
                                                       now: nov17(8, 0), calendar: TestCalendar.utc))
        XCTAssertFalse(PlannedWorkReview.hasUnloggedWork(shift, sessions: [], leaveDays: [],
                                                        now: nov16(15, 0), calendar: TestCalendar.utc))
        let recorded = RealSlot(start: nov16(8, 5), end: nov16(12, 0), activity: .work)
        XCTAssertFalse(PlannedWorkReview.hasUnloggedWork(shift, sessions: [recorded], leaveDays: [],
                                                        now: nov17(8, 0), calendar: TestCalendar.utc))
    }

    func testLeaveAndHolidaySuppressTheReviewPrompt() {
        let start = nov16(8, 0)
        let shift = PlanSlot(id: UUID(), start: start, end: nov16(12, 0), activity: .work)
        let leave = DateInterval(start: nov16(0, 0), end: nov17(0, 0))
        XCTAssertFalse(PlannedWorkReview.hasUnloggedWork(shift, sessions: [], leaveDays: [leave],
                                                        now: nov17(8, 0), calendar: TestCalendar.utc))
        let holidayStart = makeDate(TestCalendar.utc, 2026, 11, 11, 8, 0)
        let holidayShift = PlanSlot(id: UUID(), start: holidayStart,
                                    end: holidayStart.addingTimeInterval(4 * 3600), activity: .work)
        XCTAssertFalse(PlannedWorkReview.hasUnloggedWork(holidayShift, sessions: [], leaveDays: [],
                                                        now: nov16(8, 0), calendar: TestCalendar.utc))
    }
}
