import SwiftUI

/// STUB. Écran Fonctionnalités (liste des modules, section 3). Poussé depuis Réglages.
/// Données : ModuleRegistry.all, état : @Environment(ModuleStore.self).
struct FonctionnalitesView: View {
    var body: some View {
        PLTScreen(title: "Fonctionnalités") {
            PLTEmptyState(symbol: "square.grid.2x2",
                          title: "La liste des fonctionnalités arrive bientôt.",
                          message: "Tu pourras activer ou couper chaque fonctionnalité.")
        }
    }
}
