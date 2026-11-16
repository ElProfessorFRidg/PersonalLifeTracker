import SwiftUI

/// Carte à fond de surface. `isNow: true` donne la carte "Maintenant" en aplat d'accent (une seule par écran).
struct PLTCard<Content: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.pltDensity) private var density

    private let isNow: Bool
    private let content: Content

    init(isNow: Bool = false, @ViewBuilder content: () -> Content) {
        self.isNow = isNow
        self.content = content()
    }

    var body: some View {
        let padding: CGFloat = density == .compact ? Theme.Spacing.s + Theme.Spacing.xs : Theme.Spacing.m
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .foregroundStyle(isNow ? palette.accentOn : palette.textPrimary)
        .background(isNow ? palette.accent : palette.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

/// Conteneur de lignes PLTRow : fond de surface, coins arrondis, lignes collées.
struct PLTListGroup<Content: View>: View {
    @Environment(\.palette) private var palette
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

/// Titre de section (h2), avec un lien optionnel à droite.
struct PLTSectionHeader: View {
    @Environment(\.palette) private var palette
    private let title: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Spacing.s)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
        }
    }
}

/// Fond d'écran + défilement + marges latérales + titre de navigation. Les écrans de contenu s'appuient dessus.
struct PLTScreen<Content: View>: View {
    @Environment(\.palette) private var palette
    private let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                content
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}
