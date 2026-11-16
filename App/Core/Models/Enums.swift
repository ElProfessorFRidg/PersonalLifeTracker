import Foundation

/// Type d'un lieu (section 10). Taf = travail, cours = études, courses = commerce.
enum PlaceType: String, CaseIterable, Codable, Identifiable {
    case taf
    case cours
    case courses
    case domicile
    case autre

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taf: return "Taf"
        case .cours: return "Cours"
        case .courses: return "Courses"
        case .domicile: return "Domicile"
        case .autre: return "Autre"
        }
    }

    /// Activité d'une session démarrée dans ce lieu.
    var defaultActivity: ActivityType {
        switch self {
        case .taf: return .work
        case .cours: return .education
        case .courses: return .shopping
        case .domicile, .autre: return .personal
        }
    }
}

/// Types d'activité d'une session (section 14).
enum ActivityType: String, CaseIterable, Codable, Identifiable {
    case work
    case education
    case shopping
    case personal
    case travel
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: return "Taf"
        case .education: return "Cours"
        case .shopping: return "Courses"
        case .personal: return "Perso"
        case .travel: return "Trajet"
        case .unknown: return "Autre"
        }
    }
}

/// Origine d'une session (section 14).
enum SessionSource: String, CaseIterable, Codable, Identifiable {
    case gps
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gps: return "Détectée"
        case .manual: return "Saisie à la main"
        }
    }
}

/// Base de calcul des heures (section 13.1).
enum CalculationBase: String, CaseIterable, Codable, Identifiable {
    case fullHours
    case exact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHours: return "Heures pleines"
        case .exact: return "Heure exacte"
        }
    }
}
