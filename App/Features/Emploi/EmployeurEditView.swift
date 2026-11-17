import SwiftUI
import SwiftData

/// Feuille d'ajout ou de modification d'un employeur (nom, couleur). Les lieux se rattachent dans le contrat.
struct EmployeurEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette

    let employer: Employer?

    @State private var name: String
    @State private var colorKey: String
    @State private var saveFailed: Bool = false
    @State private var showDelete: Bool = false

    init(employer: Employer?) {
        self.employer = employer
        _name = State(initialValue: employer?.name ?? "")
        _colorKey = State(initialValue: employer?.colorHex ?? "work")
    }

    private var trimmedName: String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canDelete: Bool {
        guard let employer = employer else { return false }
        return employer.contracts.isEmpty
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: employer == nil ? "Nouvel employeur" : "Ton employeur") {
                nameSection
                colorSection
                if saveFailed {
                    PLTBanner(kind: .error, title: "Oups, ça a pas marché.", message: "Rien n'a été enregistré. Réessaie ?")
                }
                Button("Enregistrer") { save() }
                    .buttonStyle(.pltPrimary)
                    .disabled(trimmedName.isEmpty)
                if canDelete {
                    Button("Supprimer cet employeur") { showDelete = true }
                        .buttonStyle(.pltDestructive)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .confirmationDialog("Supprimer cet employeur ?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { deleteEmployer() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Il n'a aucun contrat. Tes sessions ne bougent pas.")
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Nom de l'employeur")
            TextField("Par exemple : Supérette du Canal", text: $name)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Nom de l'employeur")
            if trimmedName.isEmpty {
                Text("Il faut un nom pour l'enregistrer.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Couleur")
            HStack(spacing: Theme.Spacing.m) {
                ForEach(EmployerColorChoice.all) { choice in
                    Button {
                        colorKey = choice.key
                    } label: {
                        Circle()
                            .fill(choice.tone.color(palette))
                            .frame(width: 44, height: 44)
                            .overlay {
                                if colorKey == choice.key {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(palette.surface)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(colorKey == choice.key ? .isSelected : [])
                }
            }
            Text("Pour reconnaître cet employeur d'un coup d'oeil.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func save() {
        if trimmedName.isEmpty { return }
        if let existing = employer {
            existing.name = trimmedName
            existing.colorHex = colorKey
        } else {
            let created: Employer = Employer(name: trimmedName)
            created.colorHex = colorKey
            context.insert(created)
        }
        do {
            try context.save()
            dismiss()
        } catch {
            saveFailed = true
        }
    }

    private func deleteEmployer() {
        guard let employer = employer else { return }
        context.delete(employer)
        do {
            try context.save()
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
