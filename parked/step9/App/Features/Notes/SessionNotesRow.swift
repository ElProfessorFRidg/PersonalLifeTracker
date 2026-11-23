import SwiftUI

/// Notes d'une journée dans le détail d'une session : liste des notes du jour et ajout d'une note liée à la session.
/// N'affiche rien si le module notes n'est pas actif.
struct SessionNotesRow: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette

    let session: WorkSession

    private let store: DayNoteStore = DayNoteStore.shared

    @State private var target: NoteEditTarget? = nil

    var body: some View {
        Group {
            if modules.isActive("notes") {
                content
            }
        }
    }

    private var content: some View {
        let cal: Calendar = Calendar.current
        let dayNotes: [DayNote] = DayNotesRules.notes(on: session.startDate, in: store.notes, calendar: cal)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Notes du jour")
            PLTListGroup {
                ForEach(Array(dayNotes.enumerated()), id: \.element.id) { item in
                    PLTRow(symbol: "note.text",
                           title: item.element.text,
                           subtitle: item.element.tags.isEmpty ? nil : item.element.tags.map { (t: String) -> String in return "#" + t }.joined(separator: " "),
                           showsChevron: true,
                           showsSeparator: true,
                           action: {
                               target = NoteEditTarget(id: item.element.id, noteID: item.element.id,
                                                       day: item.element.day, sessionUID: item.element.sessionUID)
                           })
                }
                PLTRow(symbol: "plus",
                       tone: .accent,
                       title: "Ajouter une note",
                       subtitle: "Liée à cette session",
                       showsChevron: true,
                       showsSeparator: false,
                       action: {
                           target = NoteEditTarget(id: UUID(), noteID: nil, day: session.startDate, sessionUID: session.uid)
                       })
            }
        }
        .sheet(item: $target) { (t: NoteEditTarget) in
            NoteEditSheet(target: t)
        }
    }
}

/// Ligne discrète des notes d'un jour, pour le détail d'un jour du Planning. N'affiche rien sans note ou sans module.
struct DayNotesPlanningRow: View {
    @Environment(ModuleStore.self) private var modules

    let day: Date

    private let store: DayNoteStore = DayNoteStore.shared

    var body: some View {
        let dayNotes: [DayNote] = DayNotesRules.notes(on: day, in: store.notes, calendar: Calendar.current)
        return Group {
            if modules.isActive("notes") && !dayNotes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PLTSectionHeader(title: dayNotes.count == 1 ? "Note du jour" : "Notes du jour")
                    PLTListGroup {
                        ForEach(Array(dayNotes.enumerated()), id: \.element.id) { item in
                            PLTRow(symbol: "note.text",
                                   title: item.element.text,
                                   showsSeparator: item.offset < dayNotes.count - 1)
                        }
                    }
                }
            }
        }
    }
}
