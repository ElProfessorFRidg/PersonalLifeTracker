import SwiftUI

/// STUB. Écran `lieu` (détail). Poussé dans la NavigationStack de l'onglet : pas de NavigationStack propre.
struct LieuDetailView: View {
    let place: Place

    var body: some View {
        PLTScreen(title: place.name) {
            PLTEmptyState(symbol: "mappin.and.ellipse",
                          title: "Le détail du lieu arrive bientôt.",
                          message: "Type, rayon, stats du mois et dernières sessions.")
        }
    }
}
