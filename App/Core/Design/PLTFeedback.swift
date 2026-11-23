import SwiftUI

/// État vide : icône, titre, explication et bouton optionnel.
struct PLTEmptyState: View {
    @Environment(\.palette) private var palette
    private let symbol: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(palette.accent)
                .frame(width: 64, height: 64)
                .background(palette.accentSoft, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.pltPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.l)
    }
}

enum PLTBannerKind {
    case error
    case warning
    case info
}

/// Bandeau : ce qui se passe, et comment le régler.
struct PLTBanner: View {
    @Environment(\.palette) private var palette
    private let kind: PLTBannerKind
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(kind: PLTBannerKind, title: String, message: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.kind = kind
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    private var foreground: Color {
        switch kind {
        case .error: return palette.danger
        case .warning: return palette.warning
        case .info: return palette.accent
        }
    }

    private var background: Color {
        switch kind {
        case .error: return palette.dangerSoft
        case .warning: return palette.warningSoft
        case .info: return palette.accentSoft
        }
    }

    private var symbol: String {
        switch kind {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s + Theme.Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(foreground)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foreground)
                if let message = message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(foreground)
                }
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(foreground)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

enum ReliabilityLevel {
    case high
    case mid
    case low

    var title: String {
        switch self {
        case .high: return "Fiable"
        case .mid: return "À vérifier"
        case .low: return "Incertain"
        }
    }

    var filledBars: Int {
        switch self {
        case .high: return 3
        case .mid: return 2
        case .low: return 1
        }
    }
}

/// Fiabilité : trois barres et un mot (la couleur ne porte jamais seule l'information).
struct ReliabilityBadge: View {
    @Environment(\.palette) private var palette
    private let level: ReliabilityLevel

    init(_ level: ReliabilityLevel) {
        self.level = level
    }

    private var tint: Color {
        switch level {
        case .high: return palette.success
        case .mid: return palette.warning
        case .low: return palette.danger
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs + Theme.Spacing.xxs) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(index < level.filledBars ? tint : palette.fill)
                        .frame(width: 4, height: CGFloat(6 + index * 4))
                }
            }
            .accessibilityHidden(true)
            Text(level.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fiabilité : \(level.title)")
    }
}
