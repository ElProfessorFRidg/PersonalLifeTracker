import SwiftUI

/// En-tête des onglets racine, comme la maquette : petite ligne au-dessus (date, semaine...), grand titre, boutons ronds à droite.
/// À mettre en premier dans le contenu d'un `PLTScreen(title:hidesNavigationBar: true)`.
struct PLTRootHeader<Trailing: View>: View {
    @Environment(\.palette) private var palette
    private let eyebrow: String?
    private let title: String
    private let trailing: Trailing

    init(eyebrow: String? = nil, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow = eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.footnote.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(palette.textSecondary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: Theme.Spacing.s)
            HStack(spacing: Theme.Spacing.s) {
                trailing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PLTRootHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String) {
        self.init(eyebrow: eyebrow, title: title, trailing: { EmptyView() })
    }
}

/// Bouton rond de 44 pt (fond de carte, glyphe d'accent), comme `iconbtn` de la maquette.
struct PLTIconButton: View {
    @Environment(\.palette) private var palette
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(palette.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
