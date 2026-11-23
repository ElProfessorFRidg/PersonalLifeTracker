import SwiftUI
import SwiftData

/// Feuille d'ajout et de modification d'une note. Porte sa NavigationStack et un bouton Fermer.
/// Enregistrer, modifier et supprimer passent par UndoCenter.
struct NoteEditSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]

    let target: NoteEditTarget

    private let store: DayNoteStore = DayNoteStore.shared

    @State private var day: Date
    @State private var text: String = ""
    @State private var tagsText: String = ""
    @State private var sessionUID: UUID?
    @State private var loaded: Bool = false
    @State private var showDeleteDialog: Bool = false

    init(target: NoteEditTarget) {
        self.target = target
        _day = State(initialValue: target.day)
        _sessionUID = State(initialValue: target.sessionUID)
    }

    private var calendar: Calendar { return Calendar.current }
    private var isEditing: Bool { return target.noteID != nil }

    private var daySessions: [WorkSession] {
        return sessions.filter { (s: WorkSession) -> Bool in
            return calendar.isDate(s.startDate, inSameDayAs: day)
        }
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: isEditing ? "Modifier la note" : "Nouvelle note") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    DatePicker("Jour", selection: $day, in: ...Date(), displayedComponents: .date)
                        .frame(minHeight: 44)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                    TextField("Une phrase sur ta journée", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.body)
                        .padding(Theme.Spacing.m)
                        .frame(minHeight: 44, alignment: .leading)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                        .accessibilityLabel("Texte de la note")
                    Text("\(text.count) sur \(DayNotesRules.maxTextLength) signes")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                    TextField("Tags, séparés par des virgules", text: $tagsText)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .padding(Theme.Spacing.m)
                        .frame(minHeight: 44, alignment: .leading)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                        .accessibilityLabel("Tags de la note")
                    if !daySessions.isEmpty {
                        HStack {
                            Text("Session liée")
                                .font(.body)
                                .foregroundStyle(palette.textPrimary)
                            Spacer(minLength: Theme.Spacing.s)
                            Picker("Session liée", selection: $sessionUID) {
                                Text("Aucune").tag(Optional<UUID>.none)
                                ForEach(daySessions) { (s: WorkSession) in
                                    Text(sessionLabel(s)).tag(Optional<UUID>.some(s.uid))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minHeight: 44)
                        }
                    }
                }

                Button("Enregistrer") { save() }
                    .buttonStyle(.pltPrimary)
                    .disabled(!DayNotesRules.isValid(text: text))

                if isEditing {
                    Button("Supprimer cette note") { showDeleteDialog = true }
                        .buttonStyle(.pltDestructive)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .confirmationDialog("Supprimer cette note ?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { deleteNote() }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Tu pourras annuler juste après.")
            }
            .onAppear { loadIfNeeded() }
        }
    }

    private func sessionLabel(_ s: WorkSession) -> String {
        let start: String = Formatting.clock(s.startDate, calendar: s.calendar)
        return "\(s.activity.title) dès \(start)"
    }

    private func loadIfNeeded() {
        if loaded { return }
        loaded = true
        if let id = target.noteID, let note = store.note(id: id) {
            text = note.text
            tagsText = DayNotesRules.tagsText(note.tags)
            day = note.day
            sessionUID = note.sessionUID
        }
    }

    private func save() {
        let tags: [String] = DayNotesRules.parseTags(tagsText)
        let cal: Calendar = calendar
        let center: UndoCenter? = undoCenter
        let notes: DayNoteStore = store
        if let id = target.noteID {
            if let old = notes.update(id: id, day: day, text: text, tags: tags, sessionUID: sessionUID, calendar: cal) {
                center?.register(message: "Note modifiée") {
                    notes.restore(old)
                }
            }
        } else {
            if let created = notes.add(day: day, text: text, tags: tags, sessionUID: sessionUID, calendar: cal) {
                let createdID: UUID = created.id
                center?.register(message: "Note ajoutée") {
                    _ = notes.delete(id: createdID)
                }
            }
        }
        dismiss()
    }

    private func deleteNote() {
        guard let id = target.noteID else { return }
        let center: UndoCenter? = undoCenter
        let notes: DayNoteStore = store
        if let removed = notes.delete(id: id) {
            center?.register(message: "Note supprimée") {
                notes.restore(removed)
            }
        }
        dismiss()
    }
}
