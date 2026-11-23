import SwiftUI
import SwiftData

struct PlannedWorkReviewSection: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Query(sort: \PlannedShift.start) private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]
    @Query private var leaves: [LeaveEntry]
    @AppStorage("plt.planning.dismissedWorkReviews") private var dismissedData = Data()
    @State private var editing: Suggestion?
    @State private var answering: Suggestion?

    let week: Date

    private struct Suggestion: Identifiable {
        let shift: PlannedShift
        let interval: DateInterval

        var id: String {
            "\(shift.uid):\(interval.start.timeIntervalSinceReferenceDate):\(interval.end.timeIntervalSinceReferenceDate)"
        }

        var isPartial: Bool { interval.start != shift.start || interval.end != shift.end }
    }

    private struct Dismissal: Codable {
        let date: Date
        let reason: String
    }

    private var dismissals: [String: Dismissal] {
        (try? JSONDecoder().decode([String: Dismissal].self, from: dismissedData)) ?? [:]
    }

    private func suggestions(now: Date) -> [Suggestion] {
        guard modules.isActive("missing_hours"), !modules.isActive("vacation_mode") else { return [] }
        let calendar = PlanningSupport.calendar
        let end = PlanningRules.shiftWeek(week, by: 1, calendar: calendar)
        let recorded = sessions.map(\.planRealSlot)
        let hidden = dismissals
        let leaveDays = leaves.compactMap { leave -> DateInterval? in
            let start = calendar.startOfDay(for: leave.startDay)
            let lastDay = calendar.startOfDay(for: leave.endDay)
            guard let end = calendar.date(byAdding: .day, value: 1, to: lastDay), end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
        return shifts.filter { $0.start >= week && $0.start < end }.flatMap { shift in
            PlannedWorkReview.gaps(in: shift.planSlot, sessions: recorded, leaveDays: leaveDays,
                                   now: now, calendar: calendar).map { Suggestion(shift: shift, interval: $0) }
        }.filter { hidden[$0.id] == nil }
    }

    var body: some View {
        let items = suggestions(now: Date())
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PLTSectionHeader(title: "Créneaux à vérifier")
                ForEach(items) { item in
                    PLTCard {
                        Label(PlanningSupport.dayShort(item.interval.start), systemImage: "clock.badge.questionmark")
                            .font(.headline)
                        Text(PlanningSupport.range(start: item.interval.start, end: item.interval.end))
                            .font(.subheadline.monospacedDigit())
                        Text(item.isPartial ? "Une partie du service prévu reste à vérifier." : "Tu as travaillé sur ce créneau prévu ?")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                        Button("Vérifier et ajouter") { editing = item }
                            .buttonStyle(.pltPrimary)
                        Button("Je n’ai pas travaillé") { answering = item }
                            .buttonStyle(.pltSecondary)
                        Button("Ignorer") { dismiss(item, reason: "Ignoré") }
                            .frame(minHeight: 44)
                    }
                }
            }
            .sheet(item: $editing) { item in
                SessionAjoutView(plannedShift: item.shift, suggestedInterval: item.interval)
            }
            .confirmationDialog("Pourquoi ce créneau n’a pas été travaillé ?",
                                isPresented: Binding(get: { answering != nil },
                                                     set: { if !$0 { answering = nil } }),
                                titleVisibility: .visible, presenting: answering) { item in
                ForEach(["Congé", "Maladie", "Planning annulé", "Remplacement ou échange", "Autre"], id: \.self) { reason in
                    Button(reason) { dismiss(item, reason: reason) }
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    private func dismiss(_ item: Suggestion, reason: String) {
        let now = Date()
        var values = dismissals.filter { now.timeIntervalSince($0.value.date) < 30 * 86400 }
        values[item.id] = Dismissal(date: now, reason: reason)
        if let encoded = try? JSONEncoder().encode(values) { dismissedData = encoded }
        answering = nil
    }
}
