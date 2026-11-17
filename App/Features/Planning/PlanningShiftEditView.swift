import SwiftUI
import SwiftData

/// Feuille d'ajout ou de modification d'un créneau prévu. Passer minuit est permis.
struct PlanningShiftEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query(sort: \PlannedShift.start) private var allShifts: [PlannedShift]

    private let shift: PlannedShift?
    @State private var start: Date
    @State private var end: Date
    @State private var activity: ActivityType
    @State private var note: String
    @State private var confirmDelete: Bool = false

    init(shift: PlannedShift?, defaultDay: Date) {
        self.shift = shift
        if let s = shift {
            _start = State(initialValue: s.start)
            _end = State(initialValue: s.end)
            _activity = State(initialValue: s.activity)
            _note = State(initialValue: s.note)
        } else {
            let cal: Calendar = PlanningSupport.calendar
            let base: Date = cal.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDay) ?? defaultDay
            _start = State(initialValue: base)
            _end = State(initialValue: base.addingTimeInterval(4 * 3600))
            _activity = State(initialValue: ActivityType.work)
            _note = State(initialValue: "")
        }
    }

    private var validation: ShiftValidation {
        return PlanningRules.validate(start: start, end: end)
    }

    private var overlaps: [PlanSlot] {
        if validation != .valid { return [] }
        var slots: [PlanSlot] = []
        for s in allShifts { slots.append(s.planSlot) }
        return PlanningRules.overlapping(start: start, end: end, in: slots, excluding: shift?.uid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Activité", selection: $activity) {
                        ForEach(ActivityType.allCases) { a in
                            Text(a.title).tag(a)
                        }
                    }
                    Text("Seuls Taf et Cours comptent dans les totaux prévu et fait.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
                Section("Horaires") {
                    DatePicker("Début", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Fin", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    Text("Si ça finit après minuit, mets la date du lendemain.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
                if validation == .endNotAfterStart {
                    Section {
                        PLTBanner(kind: .error, title: "La fin doit être après le début")
                    }
                } else if validation == .tooLong {
                    Section {
                        PLTBanner(kind: .error, title: "Un créneau ne dépasse pas 24 h")
                    }
                } else if !overlaps.isEmpty {
                    Section {
                        PLTBanner(kind: .warning,
                                  title: "Ça chevauche un autre créneau",
                                  message: "Tu peux enregistrer quand même.")
                    }
                }
                Section("Note") {
                    TextField("Facultatif", text: $note)
                }
                if shift != nil {
                    Section {
                        Button("Supprimer ce créneau", role: .destructive) { confirmDelete = true }
                            .frame(minHeight: 44)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(shift == nil ? "Nouveau créneau" : "Modifier le créneau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(validation != .valid)
                }
            }
            .confirmationDialog("Supprimer ce créneau ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { delete() }
                Button("Annuler", role: .cancel) { }
            }
            .onChange(of: start) { oldValue, newValue in
                end = end.addingTimeInterval(newValue.timeIntervalSince(oldValue))
            }
        }
    }

    private func save() {
        if validation != .valid { return }
        if let s = shift {
            s.start = start
            s.end = end
            s.activityRaw = activity.rawValue
            s.note = note
        } else {
            let created = PlannedShift(start: start, end: end, activity: activity, note: note)
            context.insert(created)
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        if let s = shift {
            context.delete(s)
            try? context.save()
        }
        dismiss()
    }
}
