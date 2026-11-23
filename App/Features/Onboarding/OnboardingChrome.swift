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
                    .opacity(index == number - 1 ? 0.55 : 1)
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
    let isLarge: Bool

    init(symbol: String, kind: Kind = .accent, isLarge: Bool = false) {
        self.symbol = symbol
        self.kind = kind
        self.isLarge = isLarge
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
            .font(isLarge ? .largeTitle : .title)
            .foregroundStyle(foreground)
            .frame(width: isLarge ? 88 : 64, height: isLarge ? 88 : 64)
            .background(background, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Titre et texte d'introduction d'une étape.
struct OnboardingTitle: View {
    @Environment(\.palette) private var palette
    let title: String
    let lead: String
    let centered: Bool

    init(title: String, lead: String, centered: Bool = false) {
        self.title = title
        self.lead = lead
        self.centered = centered
    }

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(centered ? .center : .leading)
                .accessibilityAddTraits(.isHeader)
            Text(lead)
                .font(.body)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(centered ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 36, height: 36)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
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
