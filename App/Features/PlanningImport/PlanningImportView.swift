import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Planning par photo (sections 16 et 138). Écran poussé, sans NavigationStack propre.
/// Tout se lit sur l'appareil. Rien n'est enregistré tant que l'utilisateur n'a pas validé chaque créneau incertain.
struct PlanningImportView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("plt.planning.profileNames") private var profileNamesText: String = ""
    @State private var model = PlanningImportModel()
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showScanner = false
    @State private var showLineSheet = false
    @State private var showDiscard = false
    @State private var sheetSelection: Int? = nil
    @State private var editingID: UUID? = nil
    @State private var editStart = ""
    @State private var editEnd = ""
    @State private var editError: String? = nil

    var body: some View {
        PLTScreen(title: "Planning par photo") {
            content
        }
        .onChange(of: pickerItem) { _, newItem in
            if let item = newItem {
                loadPicked(item)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(
                onFinish: { image, pageCount in
                    showScanner = false
                    if let image = image {
                        let notice: String? = pageCount > 1
                            ? "Tu as scanné \(pageCount) pages : je lis seulement la première. L'assemblage de plusieurs pages n'est pas encore là."
                            : nil
                        begin(image, notice: notice)
                    } else {
                        model.failWith(title: "Le scan n'a rien donné",
                                       message: "Je n'ai reçu aucune page. Rien n'a été enregistré. Tu peux réessayer ou choisir une photo.")
                    }
                },
                onCancel: {
                    showScanner = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLineSheet) {
            lineSheet
        }
        .confirmationDialog("Jeter cette lecture ?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Jeter la lecture", role: .destructive) {
                editingID = nil
                model.reset()
            }
            Button("Revenir aux créneaux", role: .cancel) {
            }
        } message: {
            Text("Les créneaux lus ne sont pas gardés et ton planning ne change pas. Tu pourras réimporter la photo quand tu veux.")
        }
    }

    // MARK: - États

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            idleSection
        case .loading:
            photoSection(highlight: nil)
            loadingSection
        case .failed(let title, let message):
            failedSection(title: title, message: message)
        case .result:
            photoSection(highlight: model.parse?.highlight)
            resultSection
        case .saved(let count, let skipped):
            savedSection(count: count, skipped: skipped)
        }
    }

    private var idleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTCard {
                Text("Comment ton nom est écrit sur le planning ?")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Prénom, nom, initiales, surnom : sépare les variantes par des virgules. Je ne devine jamais ta ligne tout seul.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                TextField("Léo, Léo Martin, LM", text: $profileNamesText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, Theme.Spacing.s + Theme.Spacing.xs)
                    .frame(minHeight: 44)
                    .background(palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .accessibilityLabel("Ton nom sur le planning")
            }

            pickerButton(title: "Choisir une photo", style: .primary)

            if DocumentScannerView.isAvailable {
                Button {
                    showScanner = true
                } label: {
                    Label("Scanner un planning papier", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.pltSecondary)
            } else {
                Text("Le scanner de documents n'est pas dispo sur cet appareil. Choisis une photo ou une capture d'écran.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            Text("La lecture se fait sur ton tel. La photo reste chez toi, je ne l'envoie nulle part.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var loadingSection: some View {
        PLTCard {
            Text("Je lis ta photo…")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Ça se passe sur ton tel, ça prend quelques secondes. Rien n'est enregistré tant que t'as pas validé.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            ProgressView(value: min(1.0, max(0.0, model.progress)))
                .tint(palette.accent)
                .accessibilityLabel("Analyse de la photo")
            Button("Annuler") {
                model.cancelReading()
            }
            .buttonStyle(.pltSecondary)
        }
    }

    private func failedSection(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTBanner(kind: .error, title: title, message: message)
            PLTListGroup {
                PLTRow(symbol: "sun.max.fill", tone: .accent, title: "Plus de lumière",
                       subtitle: "Évite l'ombre de ton tel sur le papier.")
                PLTRow(symbol: "camera.fill", tone: .accent, title: "Incline un peu le téléphone",
                       subtitle: "Ça fait disparaître les reflets sur le plastique.")
                PLTRow(symbol: "tablecells", tone: .accent, title: "Cadre tout le tableau",
                       subtitle: "Les titres des colonnes doivent rester visibles.", showsSeparator: false)
            }
            if DocumentScannerView.isAvailable {
                Button {
                    model.reset()
                    showScanner = true
                } label: {
                    Label("Reprendre une photo", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.pltPrimary)
            }
            pickerButton(title: "Choisir une autre image", style: .secondary)
            Button("Revenir au planning") {
                dismiss()
            }
            .buttonStyle(.pltSecondary)
        }
    }

    private func savedSection(count: Int, skipped: Int) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            PLTEmptyState(symbol: "checkmark.circle",
                          title: "C'est noté",
                          message: savedMessage(count: count, skipped: skipped),
                          actionTitle: "Terminer") {
                dismiss()
            }
        }
    }

    private func savedMessage(count: Int, skipped: Int) -> String {
        var text = count == 0
            ? "Aucun nouveau créneau : ils étaient déjà dans ton planning."
            : "\(PlanningImportFormat.shiftCount(count)) ajouté\(count == 1 ? "" : "s") à ton planning prévu."
        if skipped > 0 && count > 0 {
            text += " \(skipped) étai\(skipped == 1 ? "t" : "ent") déjà là."
        }
        return text
    }

    // MARK: - Photo

    private func photoSection(highlight: NormalizedRect?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .overlay {
                        GeometryReader { geometry in
                            if let rect = highlight {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                        .fill(palette.accent.opacity(0.14))
                                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                        .strokeBorder(palette.accent, lineWidth: 3)
                                }
                                .frame(width: rect.width * geometry.size.width,
                                       height: rect.height * geometry.size.height)
                                .offset(x: rect.x * geometry.size.width,
                                        y: rect.y * geometry.size.height)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .padding(Theme.Spacing.s)
                    .background(palette.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    .accessibilityLabel(highlight == nil ? "Photo du planning" : "Photo du planning. Ta ligne est surlignée.")
                if highlight != nil {
                    Text("Ta ligne est surlignée. La photo reste sur ton tel, je ne l'envoie nulle part.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    // MARK: - Résultat

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(resultTitle)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Theme.Spacing.s)
                Text(PlanningImportFormat.shiftCount(model.drafts.count))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }

            if let notice = model.notice {
                PLTBanner(kind: .info, title: notice)
            }

            lineBanner
            weekBanner
            otherWarnings

            if model.drafts.isEmpty {
                if !model.needsLineSelection {
                    Text("Je n'ai trouvé aucun créneau sur ta ligne. Elle est peut-être vide cette semaine, regarde la photo.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(model.drafts) { draft in
                        draftBlock(draft)
                    }
                }
            }

            restLine

            if !model.drafts.isEmpty {
                PLTBanner(kind: .info,
                          title: "Avec ces créneaux, ta semaine ferait \(Formatting.duration(minutes: model.totalMinutes))",
                          message: "Je te le signale, c'est toi qui décides.")
            }

            keepSection
        }
    }

    private var resultTitle: String {
        if let name = model.chosenRowName {
            return "Ce que j'ai lu pour \(name)"
        }
        return "Ce que j'ai lu"
    }

    private func draftBlock(_ draft: PlanningShiftDraft) -> some View {
        VStack(spacing: 0) {
            PlanningDraftRow(draft: draft,
                             onConfirmAsIs: { model.markOK(draft.id) },
                             onEdit: { startEditing(draft) },
                             onRemove: { remove(draft) })
            if editingID == draft.id {
                PlanningShiftEditor(startText: $editStart,
                                    endText: $editEnd,
                                    error: editError,
                                    onSave: { saveEdit(draft) },
                                    onCancel: { editingID = nil })
            }
            Rectangle()
                .fill(palette.separator)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var lineBanner: some View {
        if let result = model.parse {
            if model.needsLineSelection {
                PLTBanner(kind: .info,
                          title: "Quelle ligne est la tienne ?",
                          message: lineChoiceMessage(result),
                          actionTitle: "Choisir ma ligne") {
                    openLineSheet()
                }
            } else if result.candidates.count >= 2 {
                let name = model.chosenRowName ?? ""
                PLTBanner(kind: .info,
                          title: result.candidates.count == 2 ? "Deux lignes ressemblent à ton nom" : "Plusieurs lignes ressemblent à ton nom",
                          message: model.lineConfirmed
                              ? "J'ai gardé « \(name) ». Dis-moi si je me suis trompé."
                              : "J'ai pris « \(name) ». Confirme que c'est bien ta ligne avant de garder.",
                          actionTitle: model.lineConfirmed ? "Changer de ligne" : "Vérifier ma ligne") {
                    openLineSheet()
                }
            }
        }
    }

    private func lineChoiceMessage(_ result: ScheduleParseResult) -> String {
        if result.rowNames.isEmpty {
            return "Je ne vois aucune ligne de nom dans le tableau."
        }
        if result.candidates.count >= 2 {
            let names = result.candidates.map { "« \($0.name) »" }.joined(separator: ", ")
            return "Je vois \(names) : je ne devine jamais le bon nom tout seul."
        }
        return "Je n'ai pas reconnu ton nom. Choisis ta ligne dans le tableau."
    }

    @ViewBuilder
    private var weekBanner: some View {
        if let result = model.parse, result.datesGuessed, let start = result.weekStart {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTBanner(kind: .warning,
                          title: "Je n'ai pas trouvé les dates",
                          message: "J'ai pris la semaine du \(PlanningImportFormat.shortDay(start)). Vérifie, ou décale d'une semaine.")
                HStack(spacing: Theme.Spacing.s) {
                    Button("Semaine d'avant") {
                        editingID = nil
                        model.shiftWeek(by: -1)
                    }
                    .buttonStyle(.pltSecondary)
                    Button("Semaine d'après") {
                        editingID = nil
                        model.shiftWeek(by: 1)
                    }
                    .buttonStyle(.pltSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var otherWarnings: some View {
        if let result = model.parse {
            let others = result.warnings.filter { !$0.hasPrefix("Je n'ai pas trouvé les dates") }
            if !others.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(others, id: \.self) { warning in
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var restLine: some View {
        if let result = model.parse, !result.restDays.isEmpty {
            let days = result.restDays.map { PlanningImportFormat.dayLabel($0.day) }.joined(separator: ", ")
            Text("Repos ou congé lu : \(days). Ces jours ne créent aucun créneau.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var keepSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            if let message = model.errorMessage {
                PLTBanner(kind: .error, title: message)
            }
            Button("Garder ces créneaux") {
                editingID = nil
                model.keep(in: context)
            }
            .buttonStyle(.pltPrimary)
            .disabled(!model.canKeep)
            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Button("Jeter la lecture") {
                showDiscard = true
            }
            .buttonStyle(.pltSecondary)
        }
    }

    private var statusLine: String {
        if model.needsLineSelection { return "Choisis d'abord ta ligne." }
        if !model.lineConfirmed { return "Confirme d'abord que c'est bien ta ligne." }
        if model.drafts.isEmpty { return "Il n'y a rien à garder pour l'instant." }
        let pending = model.pendingCount
        if pending == 1 { return "1 créneau à vérifier avant de continuer." }
        if pending > 1 { return "\(pending) créneaux à vérifier avant de continuer." }
        return "Tout est vérifié, tu peux garder."
    }

    // MARK: - Actions

    private func begin(_ image: UIImage, notice: String?) {
        editingID = nil
        model.start(image: image,
                    names: PlanningImportModel.parseNames(profileNamesText),
                    notice: notice)
    }

    private func loadPicked(_ item: PhotosPickerItem) {
        Task {
            var picked: UIImage? = nil
            if let data = try? await item.loadTransferable(type: Data.self) {
                picked = UIImage(data: data)
            }
            pickerItem = nil
            if let image = picked {
                begin(image, notice: nil)
            } else {
                model.failWith(title: "Je n'arrive pas à ouvrir cette image",
                               message: "Le fichier est illisible. Rien n'a été enregistré. Choisis une photo ou une capture d'écran.")
            }
        }
    }

    private func startEditing(_ draft: PlanningShiftDraft) {
        editingID = draft.id
        editError = nil
        if let s = draft.startMinutes {
            editStart = Formatting.clock(minutesFromMidnight: s % 1440)
        } else {
            editStart = ""
        }
        if let e = draft.endMinutes {
            editEnd = Formatting.clock(minutesFromMidnight: e % 1440)
        } else {
            editEnd = ""
        }
    }

    private func saveEdit(_ draft: PlanningShiftDraft) {
        if let error = model.applyEdit(id: draft.id, startText: editStart, endText: editEnd) {
            editError = error
        } else {
            editError = nil
            editingID = nil
        }
    }

    private func remove(_ draft: PlanningShiftDraft) {
        if editingID == draft.id {
            editingID = nil
        }
        model.remove(draft.id)
    }

    private func openLineSheet() {
        sheetSelection = model.parse?.chosenRowIndex
        showLineSheet = true
    }

    private func applyLineChoice() {
        guard let selection = sheetSelection, let result = model.parse else { return }
        editingID = nil
        if selection == result.chosenRowIndex && model.forcedRow == nil {
            model.confirmLine()
        } else {
            model.chooseRow(selection)
        }
        if profileNamesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, selection < result.rowNames.count {
            profileNamesText = result.rowNames[selection]
        }
        showLineSheet = false
    }

    // MARK: - Sous-vues

    private enum PickerStyle {
        case primary
        case secondary
    }

    private func pickerButton(title: String, style: PickerStyle) -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(title, systemImage: "photo.on.rectangle")
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(style == .primary ? palette.accentOn : palette.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Theme.Spacing.m)
                .background(style == .primary ? palette.accent : palette.accentSoft,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
    }

    private var lineSheet: some View {
        NavigationStack {
            PLTScreen(title: "Ta ligne") {
                Text("Quelle ligne est la tienne ?")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Je ne devine jamais le bon nom tout seul. Choisis la ligne à lire.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                PLTListGroup {
                    let names: [String] = model.parse?.rowNames ?? []
                    ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                        PLTRow(symbol: sheetSelection == index ? "checkmark.circle.fill" : "circle",
                               tone: .accent,
                               title: name,
                               subtitle: "\(PlanningImportFormat.ordinal(index + 1)) ligne du tableau",
                               showsSeparator: index < names.count - 1,
                               action: { sheetSelection = index })
                            .accessibilityAddTraits(sheetSelection == index ? .isSelected : [])
                    }
                }
                Button("OK") {
                    applyLineChoice()
                }
                .buttonStyle(.pltPrimary)
                .disabled(sheetSelection == nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        showLineSheet = false
                    }
                }
            }
        }
    }
}
