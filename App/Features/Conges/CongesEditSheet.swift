import SwiftUI

/// Feuille d'ajout ou de modification d'un congé. Porte sa NavigationStack et un bouton Fermer.
/// Elle ne touche pas à SwiftData : CongesView enregistre via `onSave` et `onDelete`.
struct CongesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let isNew: Bool
    let others: [LeaveRange]
    let spans: [LeaveSpan]
    let params: LeaveParameters
    let onSave: (Date, Date, LeaveKindChoice, String) -> Void
    let onDelete: (() -> Void)?

    @State private var startDay: Date
    @State private var endDay: Date
    @State private var kind: LeaveKindChoice
    @State private var note: String
    @State private var showDelete: Bool = false

    init(isNew: Bool,
         start: Date,
         end: Date,
         kind: LeaveKindChoice,
         note: String,
         others: [LeaveRange],
         spans: [LeaveSpan],
         params: LeaveParameters,
         onSave: @escaping (Date, Date, LeaveKindChoice, String) -> Void,
         onDelete: (() -> Void)?) {
        self.isNew = isNew
        self.others = others
        self.spans = spans
        self.params = params
        self.onSave = onSave
        self.onDelete = onDelete
        _startDay = State(initialValue: start)
        _endDay = State(initialValue: end)
        _kind = State(initialValue: kind)
        _note = State(initialValue: note)
    }

    private var calendar: Calendar { return Calendar.current }

    private var issues: [LeaveIssue] {
        return LeaveRules.validate(start: startDay, end: endDay, others: others, spans: spans, calendar: calendar)
    }

    private var countedDays: Int {
        return LeaveRules.countedDays(from: startDay, to: endDay, unit: params.unit, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: isNew ? "Poser un congé" : "Ton congé") {
                kindSection
                datesSection
                if !issues.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        ForEach(Array(issues.enumerated()), id: \.offset) { item in
                            PLTBanner(kind: .error, title: item.element.message)
                        }
                    }
                }
                noteSection
                Button("Enregistrer") {
                    onSave(startDay, endDay, kind, note)
                    dismiss()
                }
                .buttonStyle(.pltPrimary)
                .disabled(LeaveRules.hasBlockingIssue(issues))
                if let del = onDelete {
                    Button("Supprimer ce congé") { showDelete = true }
                        .buttonStyle(.pltDestructive)
                        .confirmationDialog("Supprimer ce congé ?", isPresented: $showDelete, titleVisibility: .visible) {
                            Button("Supprimer", role: .destructive) {
                                del()
                                dismiss()
                            }
                            Button("Annuler", role: .cancel) { }
                        } message: {
                            Text("Tu pourras annuler juste après.")
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Type")
            PLTCard {
                HStack {
                    Text("Nature")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Nature du congé", selection: $kind) {
                        ForEach(LeaveKindChoice.allCases, id: \.self) { (k: LeaveKindChoice) in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 44)
            }
            if !kind.consumesBalance {
                Text("Ce type ne retire rien à ton solde de congés payés.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Dates")
            PLTCard {
                DatePicker("Premier jour", selection: $startDay, displayedComponents: .date)
                    .font(.body)
                    .frame(minHeight: 44)
                    .onChange(of: startDay) { (_: Date, newValue: Date) in
                        if endDay < newValue { endDay = newValue }
                    }
                DatePicker("Dernier jour", selection: $endDay, displayedComponents: .date)
                    .font(.body)
                    .frame(minHeight: 44)
            }
            Text("\(CongesFormat.days(Double(countedDays))) décompté\(countedDays >= 2 ? "s" : "") en \(params.unit == .ouvrable ? "jours ouvrables" : "jours ouvrés"). Estimation : les jours fériés ne sont pas retirés.")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Note")
            PLTCard {
                TextField("Facultatif", text: $note)
                    .font(.body)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Note du congé")
            }
        }
    }
}
