import Foundation

/// A dated shift offers a review even before the app has seen its first GPS visit.
enum PlannedWorkReview {
    static func hasUnloggedWork(_ shift: PlanSlot, sessions: [RealSlot], leaveDays: [DateInterval],
                                now: Date, calendar: Calendar) -> Bool {
        !gaps(in: shift, sessions: sessions, leaveDays: leaveDays, now: now, calendar: calendar).isEmpty
    }

    static func gaps(in shift: PlanSlot, sessions: [RealSlot], leaveDays: [DateInterval],
                     now: Date, calendar: Calendar) -> [DateInterval] {
        let today = calendar.startOfDay(for: now)
        guard let earliest = calendar.date(byAdding: .day, value: -7, to: today),
              shift.activity == .work, shift.start >= earliest, shift.end <= today,
              shift.end > shift.start,
              !leaveDays.contains(where: { $0.start < shift.end && $0.end > shift.start }) else { return [] }

        let lastDay = calendar.startOfDay(for: shift.end.addingTimeInterval(-1))
        for date in [calendar.startOfDay(for: shift.start), lastDay] {
            let civil = calendar.dateComponents([.year, .month, .day], from: date)
            if FrenchHolidays.isHoliday(year: civil.year ?? 0, month: civil.month ?? 0, day: civil.day ?? 0,
                                       scope: PackHolidayRule.scopeAll, calendar: calendar) { return [] }
        }

        let occupied: [DateInterval] = sessions.compactMap { session in
            let start = max(session.start, shift.start)
            let end = min(session.end ?? now, shift.end)
            return end > start ? DateInterval(start: start, end: end) : nil
        }.sorted { $0.start < $1.start }
        if occupied.isEmpty { return [DateInterval(start: shift.start, end: shift.end)] }

        // Allow ordinary breaks and small recording differences.
        let minimumGap: TimeInterval = 60 * 60
        var cursor = shift.start
        var gaps: [DateInterval] = []
        for interval in occupied {
            if interval.start.timeIntervalSince(cursor) >= minimumGap {
                gaps.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if shift.end.timeIntervalSince(cursor) >= minimumGap {
            gaps.append(DateInterval(start: cursor, end: shift.end))
        }
        return gaps
    }
}
