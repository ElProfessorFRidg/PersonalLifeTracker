import SwiftUI

// Palette et réglages d'affichage, disponibles dans toutes les vues sous `.pltTheme()`.
// Lecture : `@Environment(\.palette) private var palette`.

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = Theme.light
}

private struct DensityKey: EnvironmentKey {
    static let defaultValue: Density = .comfortable
}

private struct ReduceAnimationsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var palette: Palette {
        get { return self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }

    var pltDensity: Density {
        get { return self[DensityKey.self] }
        set { self[DensityKey.self] = newValue }
    }

    var pltReduceAnimations: Bool {
        get { return self[ReduceAnimationsKey.self] }
        set { self[ReduceAnimationsKey.self] = newValue }
    }
}

/// Résout la palette depuis AppSettings (choix de thème) et le réglage du système, puis la diffuse.
/// Nécessite `.environment(settings)` plus haut (fait par PersonalLifeTrackerApp).
struct PLTThemeModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var systemScheme

    private var systemIsDark: Bool { return systemScheme == .dark }

    private var preferredScheme: ColorScheme? {
        switch settings.themeChoice {
        case .auto: return nil
        case .light: return .light
        case .dark, .amoled: return .dark
        }
    }

    func body(content: Content) -> some View {
        let palette: Palette = Theme.palette(settings.themeChoice.themeMode(systemIsDark: systemIsDark))
        return content
            .environment(\.palette, palette)
            .environment(\.pltDensity, settings.density)
            .environment(\.pltReduceAnimations, settings.reduceAnimations)
            .preferredColorScheme(preferredScheme)
            .tint(palette.accent)
    }
}

extension View {
    /// À appliquer une fois à la racine (déjà fait dans RootView). Les feuilles héritent de l'environnement.
    func pltTheme() -> some View {
        return modifier(PLTThemeModifier())
    }
}
