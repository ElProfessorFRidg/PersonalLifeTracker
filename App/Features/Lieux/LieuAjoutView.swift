import SwiftUI

/// STUB. Écran `lieu-ajout`. Présenté en feuille : il porte sa propre NavigationStack.
struct LieuAjoutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Nouveau lieu") {
                PLTEmptyState(symbol: "mappin.and.ellipse",
                              title: "L'ajout de lieu arrive bientôt.",
                              message: "Tu pourras choisir un point sur la carte, un nom et un rayon.")
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
