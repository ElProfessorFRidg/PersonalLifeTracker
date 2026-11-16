import SwiftUI

/// STUB. Onboarding (7 étapes dans design/SCREENS.md). Appelle `onDone` à la fin : RootView affiche alors les onglets.
struct OnboardingView: View {
    let onDone: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            PLTEmptyState(symbol: "hand.wave",
                          title: "Bienvenue.",
                          message: "Tout reste sur ton téléphone, sans compte.")
            Button("C'est parti") { onDone() }
                .buttonStyle(.pltPrimary)
                .padding(.horizontal, Theme.Spacing.m)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}
