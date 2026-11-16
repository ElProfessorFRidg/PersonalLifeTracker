import SwiftUI

/// STUB. Onglet Lieux (écran `lieux`). Montre comment ouvrir LieuAjoutView en feuille.
struct LieuxView: View {
    @State private var showsAdd: Bool = false

    var body: some View {
        PLTScreen(title: "Lieux") {
            PLTEmptyState(symbol: "mappin.and.ellipse",
                          title: "Aucun lieu pour l'instant.",
                          message: "Ajoute ton taf ou ta fac pour commencer.",
                          actionTitle: "Ajouter un lieu",
                          action: { showsAdd = true })
        }
        .sheet(isPresented: $showsAdd) {
            LieuAjoutView()
        }
    }
}
