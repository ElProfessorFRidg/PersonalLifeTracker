import SwiftUI

/// STUB. Écran `session-ajout` (saisie manuelle). Présenté en feuille : il porte sa propre NavigationStack.
struct SessionAjoutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Nouvelle session") {
                PLTEmptyState(symbol: "plus.circle",
                              title: "La saisie manuelle arrive bientôt.",
                              message: "Tu pourras choisir un lieu, un type, un début et une fin.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
