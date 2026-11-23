import SwiftUI
import SwiftData

/// Cible d'une feuille d'édition : une note existante ou une nouvelle note.
struct NoteEditTarget: Identifiable {
    let id: UUID
    let noteID: UUID?
    let day: Date
    let sessionUID: UUID?
}

/// Écran `notes` (section 39) : notes de journée par jour, recherche par texte ou tag, modification et suppression annulables.
/// Poussé dans une NavigationStack existante.
struct NotesView: View {
    @Environment(\.palette) private var palette

    private let store: DayNoteStore = DayNoteStore.shared

    @State private var query: String = ""
    @State private var target: NoteEditTarget? = nil

    private var calendar: Calendar { return Calendar.current }

    var body: some View {
        let all: [DayNote] = store.notes
        let found: [DayNote] = DayNotesRules.search(all, query: query)
        let groups: [DayNoteGroup] = DayNotesRules.groupedByDay(found, calendar: calendar)
        return PLTScreen(title: "Notes de journée") {
            TextField("Chercher dans tes notes", text: $query)
                .font(.body)
                .padding(Theme.Spacing.m)
                .frame(minHeight: 44, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Chercher dans tes notes")

            Button {
                target = NoteEditTarget(id: UUID(), noteID: nil, day: Date(), sessionUID: nil)
            } label: {
                Label("Ajouter une note", systemImage: "plus")
            }
            .buttonStyle(.pltPrimary)

            if all.isEmpty {
                PLTEmptyState(symbol: "note.text",
                              title: "Pas encore de note",
                              message: "Une phrase par journée suffit : un rush, un client, une formation. Tu peux y ajouter des tags.")
            } else if groups.isEmpty {
                PLTEmptyState(symbol: "magnifyingglass",
                              title: "Aucun résultat",
                              message: "Aucune note ne contient « \(query) ».")
            } else {
                ForEach(groups, id: \.day) { (group: DayNoteGroup) in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        PLTSectionHeader(title: Formatting.dayTitle(group.day, calendar: calendar))
                        PLTListGroup {
                            ForEach(Array(group.notes.enumerated()), id: \.element.id) { item in
                                PLTRow(symbol: "note.text",
                                       title: item.element.text,
                                       subtitle: subtitle(item.element),
                                       showsChevron: true,
                                       showsSeparator: item.offset < group.notes.count - 1,
                                       action: {
                                           target = NoteEditTarget(id: item.element.id, noteID: item.element.id,
                                                                   day: item.element.day, sessionUID: item.element.sessionUID)
                                       })
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $target) { (t: NoteEditTarget) in
            NoteEditSheet(target: t)
        }
    }

    private func subtitle(_ note: DayNote) -> String? {
        var parts: [String] = []
        if !note.tags.isEmpty {
            parts.append(note.tags.map { (t: String) -> String in return "#" + t }.joined(separator: " "))
        }
        if note.sessionUID != nil {
            parts.append("Liée à une session")
        }
        if parts.isEmpty { return nil }
        return parts.joined(separator: ". ")
    }
}
