import SwiftUI
import SwiftData

/// Copie explicite d'une semaine vers une autre. Rien n'est effacé : la copie s'ajoute.
struct PlanningCopyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query(sort: \PlannedShift.start) private var allShifts: [PlannedShift]

    private let sourceWeekStart: Date
    @State private var targetDate: Date

    init(sourceWeekStart: Date) {
        self.sourceWeekStart = sourceWeekStart
        let next: Date = PlanningRules.shiftWeek(sourceWeekStart, by: 1, calendar: PlanningSupport.calendar)
        _targetDate = State(initialValue: next)
    }

    private var calendar: Calendar { return PlanningSupport.calendar }
    private var targetWeekStart: Date { return PlanningRules.weekStart(for: targetDate, calendar: calendar) }

    private func shifts(inWeek start: Date) -> [PlannedShift] {
        let end: Date = PlanningRules.shiftWeek(start, by: 1, calendar: calendar)
        var result: [PlannedShift] = []
        for s in allShifts where s.start >= start && s.start < end { result.append(s) }
        return result
    }

    var body: some View {
        let sources: [PlannedShift] = shifts(inWeek: sourceWeekStart)
        let existing: Int = shifts(inWeek: targetWeekStart).count
        let sameWeek: Bool = targetWeekStart == sourceWeekStart

        return NavigationStack {
            Form {
                Section("Semaine à copier") {
                    Text(PlanningRules.weekTitle(weekStart: sourceWeekStart, calendar: calendar))
                    Text("\(sources.count) créneau(x)")
                        .foregroundStyle(palette.textSecondary)
                }
                Section("Copier vers") {
                    DatePicker("Un jour de la semaine cible", selection: $targetDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    Text(PlanningRules.weekTitle(weekStart: targetWeekStart, calendar: calendar))
                        .font(.headline)
                }
                if sameWeek {
                    Section { PLTBanner(kind: .error, title: "Choisis une autre semaine") }
                } else if existing > 0 {
                    Section {
                        PLTBanner(kind: .warning,
                                  title: "Cette semaine a déjà \(existing) créneau(x)",
                                  message: "La copie s'ajoute, rien n'est effacé. Ensuite, tu peux tout modifier.")
                    }
                }
                Section {
                    Button("Copier") { copy(sources) }
                        .frame(minHeight: 44)
                        .disabled(sameWeek || sources.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Copier la semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func copy(_ sources: [PlannedShift]) {
        for s in sources {
            let copied: [PlanSlot] = PlanningRules.copyWeek(slots: [s.planSlot],
                                                            fromWeekStart: sourceWeekStart,
                                                            toWeekStart: targetWeekStart,
                                                            calendar: calendar)
            if let slot = copied.first {
                let created = PlannedShift(start: slot.start, end: slot.end, activity: s.activity,
                                           placeUID: s.placeUID, employerUID: s.employerUID,
                                           source: "manual", note: s.note)
                context.insert(created)
            }
        }
        try? context.save()
        dismiss()
    }
}
