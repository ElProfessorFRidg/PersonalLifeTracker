import SwiftUI

/// Ligne de liste : icône optionnelle, titre, sous-titre, valeur (chiffres mono) et chevron.
/// Avec `action`, la ligne est un bouton de 44 pt minimum. À placer dans un PLTListGroup.
struct PLTRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.pltDensity) private var density

    let symbol: String?
    let tone: PLTTone
    let title: String
    let subtitle: String?
    let value: String?
    let showsChevron: Bool
    let showsSeparator: Bool
    let action: (() -> Void)?

    init(symbol: String? = nil,
         tone: PLTTone = .accent,
         title: String,
         subtitle: String? = nil,
         value: String? = nil,
         showsChevron: Bool = false,
         showsSeparator: Bool = true,
         action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.tone = tone
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.showsChevron = showsChevron
        self.showsSeparator = showsSeparator
        self.action = action
    }

    var body: some View {
        if let action = action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        let vertical: CGFloat = density == .compact ? Theme.Spacing.xs : Theme.Spacing.s
        return HStack(spacing: Theme.Spacing.m) {
            if let symbol = symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone.color(palette))
                    .frame(width: 36, height: 36)
                    .background(tone.soft(palette), in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            if let value = value {
                Text(value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, vertical)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
