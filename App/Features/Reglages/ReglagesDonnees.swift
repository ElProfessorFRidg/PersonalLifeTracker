import SwiftUI
import SwiftData

/// Passage des modèles SwiftData vers les structures pures de DataExport.
extension DataExport {
    static func document(places: [Place], sessions: [WorkSession], now: Date = Date()) -> ExportDocument {
        var exportedPlaces: [ExportedPlace] = []
        for p in places {
            exportedPlaces.append(ExportedPlace(uid: p.uid.uuidString, name: p.name, type: p.typeRaw,
                                                latitude: p.latitude, longitude: p.longitude, radius: p.radius,
                                                address: p.address, alsoWorksHere: p.alsoWorksHere,
                                                createdAt: p.createdAt))
        }
        var exportedSessions: [ExportedSession] = []
        for s in sessions {
            exportedSessions.append(ExportedSession(uid: s.uid.uuidString, activity: s.activityRaw,
                                                    start: s.startDate, end: s.endDate,
                                                    chosenStart: s.chosenStart, chosenEnd: s.chosenEnd,
                                                    source: s.sourceRaw, isConfirmed: s.isConfirmed, note: s.note,
                                                    timeZoneID: s.timeZoneID, createdAt: s.createdAt,
                                                    placeUID: s.place?.uid.uuidString))
        }
        return makeDocument(places: exportedPlaces, sessions: exportedSessions, exportedAt: now)
    }
}

/// Explication de la base de calcul des heures (section 13.1).
struct BaseCalculSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("L'heure exacte reste toujours enregistrée et affichée à côté. Tu peux changer quand tu veux, rien n'est perdu.")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    PLTListGroup {
                        PLTRow(title: "Heures pleines",
                               subtitle: "17:56 compte comme 18 h. Entre :15 et :45, c'est toi qui choisis.")
                        PLTRow(title: "Heure exacte",
                               subtitle: "À la minute près, sans arrondi.",
                               showsSeparator: false)
                    }
                    Button("OK") { dismiss() }
                        .buttonStyle(.pltPrimary)
                }
                .padding(Theme.Spacing.m)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Base de calcul")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

/// Suppression totale en deux étapes : lecture de ce qui part, puis saisie du mot SUPPRIMER.
struct SuppressionTotaleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let placeCount: Int
    let sessionCount: Int
    let onConfirm: () -> Void

    @State private var step: Int = 1
    @State private var typed: String = ""

    private var canConfirm: Bool {
        return typed.trimmingCharacters(in: .whitespaces).uppercased() == "SUPPRIMER"
    }

    private var summary: String {
        let lieux: String = placeCount > 1 ? "lieux" : "lieu"
        let sessions: String = sessionCount > 1 ? "sessions" : "session"
        return "\(placeCount) \(lieux) et \(sessionCount) \(sessions)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if step == 1 {
                        stepOne
                    } else {
                        stepTwo
                    }
                }
                .padding(Theme.Spacing.m)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Tout supprimer")
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
            Text("Étape 1 sur 2")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            Text("Ça efface \(summary) de ce tel. C'est définitif : sans export, impossible de revenir en arrière.")
                .font(.body)
                .foregroundStyle(palette.textPrimary)
            Button("Continuer") { step = 2 }
                .buttonStyle(.pltDestructive)
            Button("Garder mes données") { dismiss() }
                .buttonStyle(.pltSecondary)
        }
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Étape 2 sur 2")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            Text("Pour confirmer, écris SUPPRIMER ci-dessous.")
                .font(.body)
                .foregroundStyle(palette.textPrimary)
            TextField("SUPPRIMER", text: $typed)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Écris SUPPRIMER pour confirmer")
            Button("Tout supprimer") {
                onConfirm()
                dismiss()
            }
            .buttonStyle(.pltDestructive)
            .disabled(!canConfirm)
            .opacity(canConfirm ? 1 : 0.4)
            Button("Garder mes données") { dismiss() }
                .buttonStyle(.pltSecondary)
        }
    }
}
