import XCTest
@testable import PersonalLifeTracker

final class DayTimelineTests: XCTestCase {
    private let cal = TestCalendar.utc

    private func input(_ start: Date, _ end: Date?, _ activity: ActivityType, doubt: Bool = false) -> DayTimelineInput {
        return DayTimelineInput(start: start, end: end, activity: activity, isDoubt: doubt)
    }

    func testSpecSampleDay() {
        // Données communes de la maquette : cours 08:05 à 12:02, taf depuis 17:56, il est 19:10.
        let segs = DayTimeline.segments(
            day: nov16(12, 0),
            inputs: [input(nov16(17, 56), nil, .work), input(nov16(8, 5), nov16(12, 2), .education)],
            now: nov16(19, 10), calendar: cal)
        XCTAssertEqual(segs.count, 2)
        XCTAssertEqual(segs[0].activity, .education)
        XCTAssertEqual(segs[0].startHour, 8.0833, accuracy: 0.001)
        XCTAssertEqual(segs[0].endHour, 12.0333, accuracy: 0.001)
        XCTAssertFalse(segs[0].isLive)
        XCTAssertEqual(segs[1].activity, .work)
        XCTAssertEqual(segs[1].startHour, 17.9333, accuracy: 0.001)
        XCTAssertEqual(segs[1].endHour, 19.1667, accuracy: 0.001)
        XCTAssertTrue(segs[1].isLive)
    }

    func testSessionCrossingMidnightIsSplitOverTwoDays() {
        let night = [input(nov16(22, 0), nov17(2, 0), .work)]
        let first = DayTimeline.segments(day: nov16(9, 0), inputs: night, now: nov17(12, 0), calendar: cal)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].startHour, 22, accuracy: 0.0001)
        XCTAssertEqual(first[0].endHour, 24, accuracy: 0.0001)
        let second = DayTimeline.segments(day: nov17(9, 0), inputs: night, now: nov17(12, 0), calendar: cal)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].startHour, 0, accuracy: 0.0001)
        XCTAssertEqual(second[0].endHour, 2, accuracy: 0.0001)
    }

    func testSessionOfAnotherDayIsIgnored() {
        let other = [input(makeDate(cal, 2026, 11, 15, 9, 0), makeDate(cal, 2026, 11, 15, 17, 0), .work)]
        XCTAssertTrue(DayTimeline.segments(day: nov16(9, 0), inputs: other, now: nov16(20, 0), calendar: cal).isEmpty)
    }

    func testZeroLengthSessionIsIgnored() {
        let zero = [input(nov16(10, 0), nov16(10, 0), .shopping)]
        XCTAssertTrue(DayTimeline.segments(day: nov16(9, 0), inputs: zero, now: nov16(20, 0), calendar: cal).isEmpty)
    }

    func testSegmentsAreSortedByStart() {
        let segs = DayTimeline.segments(
            day: nov16(9, 0),
            inputs: [input(nov16(14, 0), nov16(15, 0), .shopping), input(nov16(9, 0), nov16(10, 0), .work)],
            now: nov16(20, 0), calendar: cal)
        XCTAssertEqual(segs.map { $0.activity }, [.work, .shopping])
    }

    func testDoubtFlagIsKept() {
        let segs = DayTimeline.segments(day: nov16(9, 0), inputs: [input(nov16(9, 0), nov16(17, 30), .work, doubt: true)],
                                        now: nov16(20, 0), calendar: cal)
        XCTAssertTrue(segs[0].isDoubt)
    }

    func testVisibleRangeDefaultsToSixToMidnight() {
        let segs = DayTimeline.segments(day: nov16(9, 0), inputs: [input(nov16(9, 0), nov16(10, 0), .work)],
                                        now: nov16(20, 0), calendar: cal)
        XCTAssertEqual(DayTimeline.visibleRange(segments: segs), HourRange(from: 6, to: 24))
    }

    func testVisibleRangeWidensForEarlySession() {
        let segs = DayTimeline.segments(day: nov16(9, 0), inputs: [input(nov16(5, 30), nov16(7, 0), .work)],
                                        now: nov16(20, 0), calendar: cal)
        XCTAssertEqual(DayTimeline.visibleRange(segments: segs), HourRange(from: 5, to: 24))
    }

    func testSummaryForVoiceOver() {
        let segs = DayTimeline.segments(
            day: nov16(9, 0),
            inputs: [input(nov16(8, 5), nov16(12, 2), .education), input(nov16(17, 56), nil, .work)],
            now: nov16(19, 10), calendar: cal)
        XCTAssertEqual(DayTimeline.summary(segments: segs), "Cours de 08:05 à 12:02. Taf de 17:56 à maintenant.")
        XCTAssertEqual(DayTimeline.summary(segments: []), "Aucune session ce jour-là.")
    }

    func testNowHourOnlyInsideTheDay() {
        XCTAssertEqual(DayTimeline.nowHour(day: nov16(9, 0), now: nov16(19, 10), calendar: cal) ?? -1, 19.1667, accuracy: 0.001)
        XCTAssertNil(DayTimeline.nowHour(day: nov16(9, 0), now: nov17(1, 0), calendar: cal))
    }
}
