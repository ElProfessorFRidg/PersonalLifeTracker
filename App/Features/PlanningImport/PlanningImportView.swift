import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PlanningImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @AppStorage("plt.planning.profileNames") private var profileNames = ""
    @State private var model = PlanningImportModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsFiles = false
    @State private var showsScanner = false
    @State private var editingID: UUID?
    @State private var startText = ""
    @State private var endText = ""
    @State private var editError: String?
    @State private var message = ""
    @State private var messageWeek: Date
    @State private var acceptedSkippedLines = false

    init(week: Date = Date()) {
        _messageWeek = State(initialValue: week)
    }

    var body: some View {
        PLTScreen(title: "Importer un planning") {
            switch model.phase {
            case .idle:
                importSources
            case .loading:
                PLTCard {
                    ProgressView("Lecture du planning…", value: model.progress)
                    Button("Annuler") { model.cancelReading() }
                        .buttonStyle(.pltSecondary)
                }
            case .failed(let title, let message):
                PLTBanner(kind: .error, title: title, message: message)
                if model.image != nil { rotatePhotoButton }
                importSources
            case .result:
                review
            case .saved(let count, let skipped):
                PLTCard {
                    Label("Planning enregistré", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                    Text("\(PlanningImportFormat.shiftCount(count)) ajouté(s).")
                    if skipped > 0 { Text("\(PlanningImportFormat.shiftCount(skipped)) déjà dans ton planning.") }
                    Button("Retour au planning") { dismiss() }
                        .buttonStyle(.pltPrimary)
                }
            }
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                guard let image = UIImage(data: try Data(contentsOf: url, options: .mappedIfSafe)) else {
                    failImage()
                    return
                }
                startReading(image)
            } catch {
                failImage()
            }
        }
        .fullScreenCover(isPresented: $showsScanner) {
            DocumentScannerView { image, pageCount in
                showsScanner = false
                if let image {
                    let notice = pageCount > 1 ? "Seule la première page a été lue. Importe les suivantes séparément." : nil
                    startReading(image, notice: notice)
                } else {
                    failImage()
                }
            } onCancel: {
                showsScanner = false
            }
            .ignoresSafeArea()
        }
        .task(id: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            let data = try? await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled, selectedPhoto == item else { return }
            selectedPhoto = nil
            if let data, let image = UIImage(data: data) {
                startReading(image)
            } else {
                failImage()
            }
        }
    }

    @ViewBuilder
    private var importSources: some View {
        if modules.isActive("planning_text") {
            PLTCard {
                Label("Coller un message", systemImage: "doc.on.clipboard")
                    .font(.headline)
                DatePicker("Semaine du planning", selection: $messageWeek, displayedComponents: .date)
                Text("Colle tes propres horaires, un jour par ligne. Exemple : « Samedi 8h–12h / 14h–18h ».")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                TextEditor(text: $message)
                    .frame(minHeight: 112)
                    .padding(Theme.Spacing.xs)
                    .accessibilityLabel("Texte du planning")
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.separator).allowsHitTesting(false))
                Button("Lire les horaires") {
                    acceptedSkippedLines = false
                    model.readMessage(String(message.prefix(12_000)), week: messageWeek)
                }
                .buttonStyle(.pltPrimary)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.count > 12_000)
                if message.count > 12_000 {
                    Text("Colle une seule semaine par import.")
                        .font(.footnote)
                        .foregroundStyle(palette.danger)
                }
            }
        } else {
            Button {
                modules.setEnabled("planning_text", true)
            } label: {
                Label("Activer le collage d’un planning", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.pltSecondary)
        }
        sources
    }

    private var sources: some View {
        PLTCard {
            Label("Choisis une photo de ton planning", systemImage: "photo.on.rectangle")
                .font(.headline)
            TextField("Prénom, nom, initiales (facultatif)", text: $profileNames)
                .textFieldStyle(.roundedBorder)
            Text("Sépare les variantes par des virgules. La photo est lue sur ton iPhone.")
                .font(.footnote)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choisir dans Photos", systemImage: "photo")
                    .frame(minHeight: 44)
            }
            .disabled(selectedPhoto != nil)
            Button("Choisir dans Fichiers") { showsFiles = true }
                .buttonStyle(.pltSecondary)
                .disabled(selectedPhoto != nil)
            if DocumentScannerView.isAvailable,
               let purpose = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
               !purpose.isEmpty {
                Button("Scanner le planning") { showsScanner = true }
                    .buttonStyle(.pltSecondary)
                    .disabled(selectedPhoto != nil)
            }
        }
    }

    private var rotatePhotoButton: some View {
        Button {
            editingID = nil
            model.rotatePhoto()
        } label: {
            Label("Pivoter la photo", systemImage: "rotate.right")
        }
        .buttonStyle(.pltSecondary)
    }

    @ViewBuilder
    private var review: some View {
        if let image = model.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 260)
                .accessibilityLabel("Photo du planning d’origine")
            rotatePhotoButton
        }
        if let warnings = model.parse?.warnings, !warnings.isEmpty {
            PLTCard {
                ForEach(warnings, id: \.self) { warning in
                    Text(warning).font(.subheadline)
                }
            }
        }
        if let notice = model.notice { Text(notice).font(.footnote) }
        if let parse = model.parse, !parse.rowNames.isEmpty {
            PLTCard {
                Menu(model.chosenRowName ?? "Choisir ma ligne") {
                    ForEach(parse.rowNames.indices, id: \.self) { index in
                        Button(parse.rowNames[index]) {
                            editingID = nil
                            model.chooseRow(index)
                        }
                    }
                }
                if !model.lineConfirmed && !model.needsLineSelection {
                    Button("C’est bien ma ligne") { model.confirmLine() }
                        .buttonStyle(.pltSecondary)
                }
            }
        }
        if let weekStart = model.parse?.weekStart {
            PLTCard {
                Text("Semaine du \(PlanningImportFormat.dayLabel(weekStart))")
                    .font(.headline)
                HStack {
                    Button("Précédente") { changeWeek(by: -1) }
                    Spacer()
                    Button("Suivante") { changeWeek(by: 1) }
                }
                .frame(minHeight: 44)
                if model.drafts.contains(where: { $0.wasEdited }) {
                    Text("Changer de semaine ou de ligne remet tes corrections à zéro.")
                        .font(.footnote)
                }
            }
        }
        if let week = model.messageWeek {
            PLTSectionHeader(title: "Semaine du \(PlanningImportFormat.dayLabel(week))")
        }
        if !model.skippedMessageLines.isEmpty {
            PLTCard {
                Text("Lignes à relire").font(.headline)
                ForEach(Array(model.skippedMessageLines.enumerated()), id: \.offset) { item in
                    Text(item.element).font(.subheadline)
                }
                if !model.drafts.isEmpty {
                    Toggle("Importer les lignes reconnues", isOn: $acceptedSkippedLines)
                }
            }
        }
        PLTSectionHeader(title: "Créneaux à vérifier")
        if model.drafts.isEmpty {
            Text(model.needsLineSelection ? "Choisis la ligne qui correspond à ton nom." : "Aucun créneau lisible sur cette ligne.")
        }
        ForEach(model.drafts) { draft in
            PLTCard {
                if editingID == draft.id {
                    Text(PlanningImportFormat.dayLabel(draft.day)).font(.headline)
                    PlanningShiftEditor(startText: $startText, endText: $endText, error: editError,
                                        onSave: { saveEdit(draft.id) }, onCancel: { editingID = nil })
                } else {
                    PlanningDraftRow(draft: draft, onConfirmAsIs: { model.markOK(draft.id) },
                                     onEdit: { edit(draft) }, onRemove: { model.remove(draft.id) })
                }
            }
        }
        if let error = model.errorMessage {
            PLTBanner(kind: .error, title: "Créneaux non enregistrés", message: error)
        }
        Button("Enregistrer les créneaux") { model.keep(in: context) }
            .buttonStyle(.pltPrimary)
            .disabled(!model.canKeep || editingID != nil || (!model.skippedMessageLines.isEmpty && !acceptedSkippedLines))
        Button(model.messageWeek == nil ? "Choisir une autre photo" : "Modifier le message") {
            editingID = nil
            model.reset()
        }
        .buttonStyle(.pltSecondary)
    }

    private func edit(_ draft: PlanningShiftDraft) {
        startText = draft.startMinutes.map { Formatting.clock(minutesFromMidnight: $0 % 1440) } ?? ""
        endText = draft.endMinutes.map { Formatting.clock(minutesFromMidnight: $0 % 1440) } ?? ""
        editError = nil
        editingID = draft.id
    }

    private func saveEdit(_ id: UUID) {
        editError = model.applyEdit(id: id, startText: startText, endText: endText)
        if editError == nil { editingID = nil }
    }

    private func changeWeek(by offset: Int) {
        editingID = nil
        model.shiftWeek(by: offset)
    }

    private func startReading(_ image: UIImage, notice: String? = nil) {
        model.start(image: image, names: PlanningImportModel.parseNames(profileNames), notice: notice)
    }

    private func failImage() {
        model.failWith(title: "Photo illisible", message: "Essaie avec une photo nette du planning, prise de face.")
    }
}
