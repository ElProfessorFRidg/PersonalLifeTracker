import SwiftUI
import SwiftData

/// Feuille pour poser un congé sur une plage de jours.
struct PlanningLeaveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette

    @State private var startDay: Date
    @State private var endDay: Date
    @State private var kind: String = "paid"
    @State private var note: String = ""

    init(defaultDay: Date) {
        let d: Date = PlanningSupport.calendar.startOfDay(for: defaultDay)
        _startDay = State(initialValue: d)
        _endDay = State(initialValue: d)
    }

    private var isValid: Bool {
        let cal: Calendar = PlanningSupport.calendar
        return cal.startOfDay(for: endDay) >= cal.startOfDay(for: startDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Jours") {
                    DatePicker("Premier jour", selection: $startDay, displayedComponents: [.date])
                    DatePicker("Dernier jour", selection: $endDay, displayedComponents: [.date])
                }
                if !isValid {
                    Section { PLTBanner(kind: .error, title: "Le dernier jour doit être après le premier") }
                }
                Section("Type") {
                    Picker("Type de congé", selection: $kind) {
                        Text("Payé").tag("paid")
                        Text("Sans solde").tag("unpaid")
                        Text("Maladie").tag("sick")
                        Text("Autre").tag("other")
                    }
                }
                Section("Note") {
                    TextField("Facultatif", text: $note)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Poser un congé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if !isValid { return }
        let cal: Calendar = PlanningSupport.calendar
        let entry = LeaveEntry(startDay: cal.startOfDay(for: startDay),
                               endDay: cal.startOfDay(for: endDay),
                               kindRaw: kind, note: note)
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
