import SwiftUI

/// Placeholder. Onglet Planning : le module vient à l'étape 7 (planning_ocr).
struct PlanningView: View {
    var body: some View {
        PLTScreen(title: "Planning") {
            PLTEmptyState(symbol: "calendar",
                          title: "Le planning arrive plus tard.",
                          message: "Cette fonctionnalité sera ajoutée à une étape suivante. Tu pourras l'activer dans les Fonctionnalités.")
        }
    }
}
