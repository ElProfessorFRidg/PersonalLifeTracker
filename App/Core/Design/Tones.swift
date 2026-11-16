import SwiftUI

/// Couleur sémantique d'un élément. Taf = work, cours = study, courses = errand. L'accent n'est jamais une activité.
enum PLTTone {
    case work
    case study
    case errand
    case accent
    case danger
    case neutral

    func color(_ p: Palette) -> Color {
        switch self {
        case .work: return p.work
        case .study: return p.study
        case .errand: return p.errand
        case .accent: return p.accent
        case .danger: return p.danger
        case .neutral: return p.textSecondary
        }
    }

    func soft(_ p: Palette) -> Color {
        switch self {
        case .work: return p.workSoft
        case .study: return p.studySoft
        case .errand: return p.errandSoft
        case .accent: return p.accentSoft
        case .danger: return p.dangerSoft
        case .neutral: return p.fill
        }
    }
}

extension ActivityType {
    var tone: PLTTone {
        switch self {
        case .work: return .work
        case .education: return .study
        case .shopping: return .errand
        case .personal, .travel, .unknown: return .neutral
        }
    }

    /// Nom d'un SF Symbol.
    var symbolName: String {
        switch self {
        case .work: return "briefcase.fill"
        case .education: return "book.fill"
        case .shopping: return "cart.fill"
        case .personal: return "person.fill"
        case .travel: return "figure.walk"
        case .unknown: return "questionmark"
        }
    }
}

extension PlaceType {
    var tone: PLTTone { return defaultActivity.tone }
    var symbolName: String { return defaultActivity.symbolName }
}
