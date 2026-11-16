import SwiftUI
import SwiftData

/// Feuille "Démarrer" : choix de l'activité (Taf ou Cours) et d'un lieu facultatif, puis démarrage manuel.
/// Porte sa propre NavigationStack et un bouton Fermer.
struct DemarrerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query(sort: \Place.name) private var places: [Place]

    @State private var activity: ActivityType = .work
    @State private var placeUID: UUID?
    @State private var errorMessage: String?

    private static let choices: [ActivityType] = [.work, .education]

    private var matchingPlaces: [Place] {
        return places.filter { $0.type.defaultActivity == activity }
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Démarrer") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PLTSectionHeader(title: "Tu fais quoi ?")
                    Picker("Activité", selection: $activity) {
                        ForEach(DemarrerSheet.choices) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PLTSectionHeader(title: "Où ?")
                    if matchingPlaces.isEmpty {
                        Text("Pas de lieu enregistré pour ça. Tu peux démarrer sans, tu pourras corriger après.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        PLTCard {
                            Picker("Lieu", selection: $placeUID) {
                                Text("Aucun lieu").tag(Optional<UUID>.none)
                                ForEach(matchingPlaces) { place in
                                    Text(place.name).tag(Optional<UUID>.some(place.uid))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minHeight: 44)
                        }
                    }
                }

                if let message = errorMessage {
                    PLTBanner(kind: .error, title: message)
                }

                Button {
                    startSession()
                } label: {
                    Label("Démarrer", systemImage: "play.fill")
                }
                .buttonStyle(.pltPrimary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: activity) {
                placeUID = nil
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func startSession() {
        var chosen: Place? = nil
        for place in matchingPlaces where place.uid == placeUID {
            chosen = place
        }
        let service = SessionService(context: context)
        do {
            _ = try service.start(activity: activity, place: chosen, now: Date())
            dismiss()
        } catch SessionServiceError.alreadyRunning {
            errorMessage = "Une session tourne déjà. Arrête-la avant d'en démarrer une autre."
        } catch {
            errorMessage = "Impossible de démarrer la session. Réessaie."
        }
    }
}
