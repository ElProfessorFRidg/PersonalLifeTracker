import Foundation

/// A dated shift offers a review even before the app has seen its first GPS visit.
enum PlannedWorkReview {
    static func hasUnloggedWork(_ shift: PlanSlot, sessions: [RealSlot], leaveDays: [DateInterval],
                                now: Date, calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: now)
        guard let earliest = calendar.date(byAdding: .day, value: -7, to: today),
              shift.activity == .work, shift.start >= earliest, shift.end <= today,
              shift.end > shift.start,
              !leaveDays.contains(where: { $0.start < shift.end && $0.end > shift.start }) else { return false }

        let lastDay = calendar.startOfDay(for: shift.end.addingTimeInterval(-1))
        for date in [calendar.startOfDay(for: shift.start), lastDay] {
            let civil = calendar.dateComponents([.year, .month, .day], from: date)
            if FrenchHolidays.isHoliday(year: civil.year ?? 0, month: civil.month ?? 0, day: civil.day ?? 0,
                                       scope: PackHolidayRule.scopeAll, calendar: calendar) { return false }
        }

        return !sessions.contains { session in
            session.start < shift.end && (session.end ?? now) > shift.start
        }
    }
}
