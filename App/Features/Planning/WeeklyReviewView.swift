import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Environment(\.palette) private var palette
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]
    @State private var week: Date

    init(week: Date = Date()) {
        _week = State(initialValue: PlanningRules.weekStart(for: week, calendar: PlanningSupport.calendar))
    }

    static func needsReview(_ session: WorkSession) -> Bool {
        !session.isConfirmed || session.hasUnresolvedDoubt || session.activity == .unknown
    }

    var body: some View {
        let calendar = PlanningSupport.calendar
        let end = PlanningRules.shiftWeek(week, by: 1, calendar: calendar)
        let finished = sessions.filter { session in
            guard let finish = session.endDate else { return false }
            return session.startDate < end && finish > week
        }
        let pending = finished.filter(Self.needsReview)

        PLTScreen(title: "Revue de la semaine") {
            HStack {
                Button { week = PlanningRules.shiftWeek(week, by: -1, calendar: calendar) } label: {
                    Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Semaine précédente")
                Spacer()
                Text(PlanningRules.weekTitle(weekStart: week, calendar: calendar))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Spacer()
                Button { week = end } label: {
                    Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Semaine suivante")
                .disabled(end > Date())
            }

            if pending.isEmpty {
                PLTCard {
                    Label(finished.isEmpty ? "Aucune session terminée" : "Tout est vérifié",
                          systemImage: finished.isEmpty ? "calendar" : "checkmark.circle.fill")
                        .font(.headline)
                    if finished.isEmpty {
                        Text("Les sessions à vérifier apparaîtront ici après leur fin.")
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            } else {
                PLTSectionHeader(title: pending.count == 1 ? "1 session à vérifier" : "\(pending.count) sessions à vérifier")
                PLTListGroup {
                    ForEach(pending) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            PLTRow(symbol: session.activity.symbolName, tone: session.activity.tone,
                                   title: session.place?.name ?? session.activity.title,
                                   subtitle: subtitle(for: session), showsChevron: true,
                                   showsSeparator: session.uid != pending.last?.uid)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func subtitle(for session: WorkSession) -> String {
        let date = PlanningSupport.dayShort(session.startDate)
        let calendar = session.calendar
        let start = Formatting.clock(session.startDate, calendar: calendar)
        let times = session.endDate.map { end in
            let clock = Formatting.clock(end, calendar: calendar)
            if calendar.isDate(end, inSameDayAs: session.startDate) { return "\(start) à \(clock)" }
            return "\(start) à \(PlanningSupport.dayShort(end)) \(clock)"
        } ?? start
        let reason = session.activity == .unknown ? "Activité à choisir"
            : (session.hasUnresolvedDoubt ? "Horaires à vérifier" : "Session à confirmer")
        return "\(date) · \(times)\n\(reason)"
    }
}
