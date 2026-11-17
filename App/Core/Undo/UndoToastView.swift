import SwiftUI
import UIKit

/// Toast "Annuler" en bas de l'écran, au-dessus de la barre d'onglets. À poser en overlay dans RootView.
struct UndoToastView: View {
    @Environment(UndoCenter.self) private var center
    @Environment(\.palette) private var palette
    @Environment(\.pltReduceAnimations) private var reduceAnimations
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var motionOff: Bool { return reduceAnimations || systemReduceMotion }

    var body: some View {
        ZStack {
            if let toast = center.current {
                toastBody(toast)
                    .transition(motionOff ? AnyTransition.opacity
                                          : AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(motionOff ? nil : Animation.easeInOut(duration: 0.25), value: center.current)
        .onChange(of: center.current) { (_: UndoCenter.Toast?, newValue: UndoCenter.Toast?) in
            if let toast = newValue {
                UIAccessibility.post(notification: .announcement, argument: "\(toast.message). Bouton Annuler disponible.")
            }
        }
    }

    private func toastBody(_ toast: UndoCenter.Toast) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Annuler") {
                center.performUndo()
                UIAccessibility.post(notification: .announcement, argument: "Annulé")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.accent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Annuler : \(toast.message)")
        }
        .padding(.leading, Theme.Spacing.m)
        .padding(.trailing, Theme.Spacing.s)
        .background(palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .stroke(palette.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
