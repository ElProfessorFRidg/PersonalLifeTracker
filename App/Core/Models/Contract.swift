import Foundation
import SwiftData

/// Type de contrat (section 18.2).
enum ContractKind: String, CaseIterable {
    case cdi
    case cdd
    case interim
    case apprentissage
    case stage
    case saisonnier
    case autre

    var title: String {
        switch self {
        case .cdi: return "CDI"
        case .cdd: return "CDD"
        case .interim: return "Intérim"
        case .apprentissage: return "Alternance"
        case .stage: return "Stage"
        case .saisonnier: return "Saisonnier"
        case .autre: return "Autre"
        }
    }
}

/// Un contrat (sections 18.2 et 19). Un contrat terminé reste en base : il est archivé, jamais supprimé.
@Model
final class Contract {
    var uid: UUID = UUID()
    var kindRaw: String = ContractKind.cdi.rawValue
    var startDate: Date = Date()
    /// nil pour un CDI ou tout contrat sans date de fin.
    var endDate: Date? = nil
    /// Heures au contrat par semaine (par exemple 13).
    var weeklyHours: Double = 0
    /// Taux horaire brut saisi par l'utilisateur (facultatif). La fiche de paie fait foi.
    var hourlyGrossRate: Double? = nil
    var trialEndDate: Date? = nil
    var employer: Employer? = nil
    /// Lieux (Place.uid) rattachés à ce contrat. Liste d'UUID, pas de relation SwiftData vers Place.
    var placeUIDs: [UUID] = []
    var createdAt: Date = Date()

    init(kind: ContractKind, startDate: Date, endDate: Date?, weeklyHours: Double, employer: Employer?) {
        self.uid = UUID()
        self.kindRaw = kind.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.weeklyHours = weeklyHours
        self.employer = employer
        self.createdAt = Date()
    }

    var kind: ContractKind {
        get { return ContractKind(rawValue: kindRaw) ?? .autre }
        set { kindRaw = newValue.rawValue }
    }
}
