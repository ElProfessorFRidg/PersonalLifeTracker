import SwiftUI

private func pltButtonBody(label: AnyView, fill: Color, foreground: Color, pressed: Bool, enabled: Bool) -> some View {
    label
        .font(.headline)
        .foregroundStyle(foreground)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, Theme.Spacing.m)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .opacity(enabled ? (pressed ? 0.8 : 1) : 0.4)
}

/// Action principale : une seule par écran.
struct PLTPrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        pltButtonBody(label: AnyView(configuration.label), fill: palette.accent, foreground: palette.accentOn,
                      pressed: configuration.isPressed, enabled: isEnabled)
    }
}

struct PLTSecondaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        pltButtonBody(label: AnyView(configuration.label), fill: palette.accentSoft, foreground: palette.accent,
                      pressed: configuration.isPressed, enabled: isEnabled)
    }
}

/// Suppression et actions irréversibles. Toujours précédée d'une confirmation ou d'un "Annuler".
struct PLTDestructiveButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        pltButtonBody(label: AnyView(configuration.label), fill: palette.danger, foreground: palette.dangerOn,
                      pressed: configuration.isPressed, enabled: isEnabled)
    }
}

extension ButtonStyle where Self == PLTPrimaryButtonStyle {
    static var pltPrimary: PLTPrimaryButtonStyle { return PLTPrimaryButtonStyle() }
}

extension ButtonStyle where Self == PLTSecondaryButtonStyle {
    static var pltSecondary: PLTSecondaryButtonStyle { return PLTSecondaryButtonStyle() }
}

extension ButtonStyle where Self == PLTDestructiveButtonStyle {
    static var pltDestructive: PLTDestructiveButtonStyle { return PLTDestructiveButtonStyle() }
}
