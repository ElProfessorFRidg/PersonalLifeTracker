import SwiftUI
import SwiftData

/// Écran `instantanes` : copies locales quotidiennes de tes lieux et sessions, restauration en deux étapes.
/// Écran poussé (pas de NavigationStack propre).
struct InstantanesView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query private var places: [Place]
    @Query private var sessions: [WorkSession]

    @State private var snapshots: [SnapshotInfo] = []
    @State private var restoreCandidate: SnapshotInfo? = nil
    @State private var deleteCandidate: SnapshotInfo? = nil
    @State private var errorMessage: String? = nil

    private let store: SnapshotStore = SnapshotStore(directory: SnapshotStore.defaultDirectory())

    var body: some View {
        PLTScreen(title: "Instantanés") {
            introCard
            if let message = errorMessage {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: message)
            }
            Button("Créer un instantané maintenant") { createNow() }
                .buttonStyle(.pltPrimary)
            listSection
        }
        .onAppear { reload() }
        .sheet(item: $restoreCandidate) { (info: SnapshotInfo) in
            RestoreConfirmSheet(info: info,
                                currentPlaces: places.count,
                                currentSessions: sessions.count,
                                onConfirm: { restore(info) })
        }
        .confirmationDialog("Supprimer cet instantané ?",
                            isPresented: deleteDialogBinding,
                            titleVisibility: .visible,
                            presenting: deleteCandidate) { (info: SnapshotInfo) in
            Button("Supprimer l'instantané", role: .destructive) { remove(info) }
            Button("Annuler", role: .cancel) { }
        } message: { (info: SnapshotInfo) in
            Text("Seule cette copie disparaît. Tes lieux et tes sessions ne bougent pas.")
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        return Binding<Bool>(
            get: { return deleteCandidate != nil },
            set: { (newValue: Bool) in
                if !newValue { deleteCandidate = nil }
            })
    }

    // MARK: Contenu

    private var introCard: some View {
        PLTCard {
            Text("Un filet de sécurité")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text("Une fois par jour, je garde une copie de tes lieux et de tes sessions sur ton iPhone, pendant \(SnapshotPlan.defaultRetentionDays) jours. Si tu te trompes dans une correction, tu peux revenir à une de ces copies. Avant chaque restauration, je garde aussi l'état actuel, donc tu peux toujours revenir en arrière.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Text("Ces copies restent sur cet appareil, protégées par le verrouillage de ton iPhone, et ne vont pas dans iCloud.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder
    private var listSection: some View {
        if snapshots.isEmpty {
            PLTEmptyState(symbol: "clock.arrow.circlepath",
                          title: "Pas encore d'instantané",
                          message: "Le premier arrive dès que tu as des données et que tu ouvres l'app. Tu peux aussi en créer un maintenant.")
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Tes instantanés")
                ForEach(snapshots) { (info: SnapshotInfo) in
                    snapshotCard(info)
                }
                Text("Taille totale : \(InstantanesView.sizeText(totalBytes))")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var totalBytes: Int {
        var total: Int = 0
        for s in snapshots { total += s.byteSize }
        return total
    }

    private func snapshotCard(_ info: SnapshotInfo) -> some View {
        PLTCard {
            Text(InstantanesView.dateText(info.createdAt))
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Text("\(SnapshotFormat.summary(places: info.placeCount, sessions: info.sessionCount)), \(InstantanesView.sizeText(info.byteSize))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(palette.textSecondary)
            Button("Restaurer cet instantané") { restoreCandidate = info }
                .buttonStyle(.pltSecondary)
                .accessibilityLabel("Restaurer l'instantané du \(InstantanesView.dateText(info.createdAt))")
            Button("Supprimer cet instantané") { deleteCandidate = info }
                .buttonStyle(.pltDestructive)
                .accessibilityLabel("Supprimer l'instantané du \(InstantanesView.dateText(info.createdAt))")
        }
    }

    // MARK: Actions

    private func reload() {
        snapshots = store.list()
    }

    private func createNow() {
        errorMessage = nil
        do {
            let document: ExportDocument = try UndoSnapshots.currentDocument(context: context, now: Date())
            try store.write(document)
            store.prune(now: Date(), calendar: Calendar.current)
        } catch {
            errorMessage = "Je n'ai pas pu écrire la copie. Vérifie l'espace libre sur ton iPhone."
        }
        reload()
    }

    private func remove(_ info: SnapshotInfo) {
        errorMessage = nil
        do {
            try store.delete(fileName: info.fileName)
        } catch {
            errorMessage = "Je n'ai pas pu supprimer cette copie."
        }
        reload()
    }

    /// Garde d'abord l'état actuel (instantané de sécurité), puis remplace, puis enregistre l'annulation.
    private func restore(_ info: SnapshotInfo) {
        errorMessage = nil
        let ctx: ModelContext = context
        do {
            let target: ExportDocument = try store.load(fileName: info.fileName)
            let before: ExportDocument = try UndoSnapshots.currentDocument(context: ctx, now: Date())
            try store.write(before)
            try UndoSnapshots.replaceAll(with: target, context: ctx)
            let label: String = InstantanesView.dateText(info.createdAt)
            undoCenter?.register(message: "Restauration faite : instantané du \(label)") {
                try? UndoSnapshots.replaceAll(with: before, context: ctx)
            }
        } catch {
            errorMessage = "La restauration n'a pas pu se faire, tes données n'ont pas changé."
        }
        reload()
    }

    // MARK: Formats

    static func dateText(_ date: Date) -> String {
        let style: Date.FormatStyle = Date.FormatStyle(date: .long, time: .shortened)
            .locale(Locale(identifier: "fr_FR"))
        return date.formatted(style)
    }

    static func sizeText(_ bytes: Int) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// Restauration en deux étapes : lecture de ce qui change, puis dernière confirmation.
private struct RestoreConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let info: SnapshotInfo
    let currentPlaces: Int
    let currentSessions: Int
    let onConfirm: () -> Void

    @State private var step: Int = 1

    var body: some View {
        NavigationStack {
            PLTScreen(title: step == 1 ? "Restaurer" : "Dernière vérification") {
                if step == 1 {
                    stepOne
                } else {
                    stepTwo
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

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTCard {
                Text("Maintenant")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                Text(SnapshotFormat.summary(places: currentPlaces, sessions: currentSessions))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                Text("Instantané du \(InstantanesView.dateText(info.createdAt))")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                Text(SnapshotFormat.summary(places: info.placeCount, sessions: info.sessionCount))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            Text("Tout ce que tu as ajouté ou changé depuis cette copie sera remplacé. Je garde d'abord l'état actuel dans un nouvel instantané, et tu pourras annuler juste après.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Button("Continuer") { step = 2 }
                .buttonStyle(.pltPrimary)
            Button("Annuler") { dismiss() }
                .buttonStyle(.pltSecondary)
        }
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTBanner(kind: .warning,
                      title: "Tes lieux et tes sessions vont être remplacés",
                      message: "Tu vas revenir à l'état du \(InstantanesView.dateText(info.createdAt)).")
            Button("Remplacer mes données") {
                onConfirm()
                dismiss()
            }
            .buttonStyle(.pltDestructive)
            Button("Finalement non") { dismiss() }
                .buttonStyle(.pltSecondary)
        }
    }
}
