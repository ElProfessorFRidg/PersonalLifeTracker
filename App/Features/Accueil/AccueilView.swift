import SwiftUI

/// STUB. Onglet Accueil (écran `accueil` de design/SCREENS.md). Garde le bouton Réglages de la barre d'outils.
struct AccueilView: View {
    var body: some View {
        PLTScreen(title: "Accueil") {
            PLTEmptyState(symbol: "house",
                          title: "L'accueil arrive bientôt.",
                          message: "Ici tu verras ta journée d'un coup d'œil.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ReglagesView()
                } label: {
                    Image(systemName: "gearshape")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Réglages")
            }
        }
    }
}
