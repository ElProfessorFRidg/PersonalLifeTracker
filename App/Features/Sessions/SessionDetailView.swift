import SwiftUI

/// STUB. Écran `session` (détail et correction). Poussé dans une NavigationStack existante.
struct SessionDetailView: View {
    let session: WorkSession

    var body: some View {
        PLTScreen(title: session.activity.title) {
            PLTEmptyState(symbol: "clock",
                          title: "Le détail de la session arrive bientôt.",
                          message: "Heures exactes, heures pleines et correction.")
        }
    }
}
