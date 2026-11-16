import SwiftUI

/// STUB. Écran `doute` (zone de doute 13.1). Présenté en feuille : il porte sa propre NavigationStack.
struct DouteView: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkSession

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Heure à confirmer") {
                PLTEmptyState(symbol: "questionmark.circle",
                              title: "Le choix de l'heure pleine arrive bientôt.",
                              message: "Tu choisiras l'heure pleine quand l'arrivée ou le départ tombe entre :15 et :45.")
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
