import SwiftUI

// Squelette de la phase 1 (CI/CD). Remplacé en phase 2 par l'UI validée (design/SCREENS.md).
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Personal Life Tracker").font(.title2.bold())
            Text("Squelette technique. L'app arrive après validation de l'UI.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}
