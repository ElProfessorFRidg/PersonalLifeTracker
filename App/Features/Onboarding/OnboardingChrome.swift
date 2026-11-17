import SwiftUI

/// Barre de progression en segments : étapes faites et courante en accent, le reste en fond neutre.
struct OnboardingProgressBar: View {
    @Environment(\.palette) private var palette
    let number: Int
    let total: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.s - 2) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < number ? palette.accent : palette.fill)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Étape \(number) sur \(total)")
    }
}

/// Pastille ronde avec un symbole, en haut des étapes.
struct OnboardingHero: View {
    enum Kind {
        case accent
        case ok
        case warning
        case error
    }

    @Environment(\.palette) private var palette
    let symbol: String
    let kind: Kind

    init(symbol: String, kind: Kind = .accent) {
        self.symbol = symbol
        self.kind = kind
    }

    private var foreground: Color {
        switch kind {
        case .accent: return palette.accent
        case .ok: return palette.success
        case .warning: return palette.warning
        case .error: return palette.danger
        }
    }

    private var background: Color {
        switch kind {
        case .accent, .ok: return palette.accentSoft
        case .warning: return palette.warningSoft
        case .error: return palette.dangerSoft
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.title)
            .foregroundStyle(foreground)
            .frame(width: 64, height: 64)
            .background(background, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Titre et texte d'introduction d'une étape.
struct OnboardingTitle: View {
    @Environment(\.palette) private var palette
    let title: String
    let lead: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(lead)
                .font(.body)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Ligne "icône, titre, détail" des listes d'arguments.
struct OnboardingPoint: View {
    @Environment(\.palette) private var palette
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
