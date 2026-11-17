import SwiftUI

enum PLTChipKind {
    case work
    case study
    case errand
    case doubt     // pointillés : l'incertain ("À confirmer")
    case neutral
}

/// Pastille de texte. Le texte porte toujours l'information, pas seulement la couleur.
struct PLTChip: View {
    @Environment(\.palette) private var palette
    private let text: String
    private let kind: PLTChipKind

    init(_ text: String, kind: PLTChipKind = .neutral) {
        self.text = text
        self.kind = kind
    }

    private var foreground: Color {
        switch kind {
        case .work: return palette.work
        case .study: return palette.study
        case .errand: return palette.errand
        case .doubt: return palette.textSecondary
        case .neutral: return palette.textSecondary
        }
    }

    private var background: Color {
        switch kind {
        case .work: return palette.workSoft
        case .study: return palette.studySoft
        case .errand: return palette.errandSoft
        case .doubt: return palette.surface
        case .neutral: return palette.fill
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Spacing.s + Theme.Spacing.xxs)
            .padding(.vertical, Theme.Spacing.xs)
            .background(background, in: Capsule())
            .overlay {
                if kind == .doubt {
                    Capsule().strokeBorder(palette.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
    }
}

extension ActivityType {
    var chipKind: PLTChipKind {
        switch self {
        case .work: return .work
        case .education: return .study
        case .shopping: return .errand
        case .personal, .travel, .unknown: return .neutral
        }
    }
}
