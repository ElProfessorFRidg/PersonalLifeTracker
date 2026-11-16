import SwiftUI

/// Placeholder. Onglet Statistiques : le module vient à une étape suivante.
struct StatsView: View {
    var body: some View {
        PLTScreen(title: "Statistiques") {
            PLTEmptyState(symbol: "chart.bar",
                          title: "Les statistiques arrivent plus tard.",
                          message: "Cette fonctionnalité sera ajoutée à une étape suivante.")
        }
    }
}
