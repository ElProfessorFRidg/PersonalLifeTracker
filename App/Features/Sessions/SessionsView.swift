import SwiftUI

/// STUB. Écran `sessions` (historique). Poussé dans une NavigationStack existante.
struct SessionsView: View {
    var body: some View {
        PLTScreen(title: "Sessions") {
            PLTEmptyState(symbol: "clock",
                          title: "Aucune session pour l'instant.",
                          message: "Tes sessions de taf, de cours et de courses apparaîtront ici.")
        }
    }
}
