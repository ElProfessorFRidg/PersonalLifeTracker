import Foundation
import SwiftData

/// Un employeur (section 18.1). Module `employment`. Rien d'obligatoire : le noyau ne dépend pas de ce modèle.
/// `colorHex` garde en réalité un nom de ton de la palette ("work", "study", "errand", "accent"), jamais une couleur en dur.
/// `conventionID` : identifiant de convention collective facultatif (par exemple "2216"), pour plus tard.
@Model
final class Employer {
    var uid: UUID = UUID()
    var name: String = ""
    var colorHex: String? = nil
    var conventionID: String? = nil
    var createdAt: Date = Date()

    /// Supprimer un employeur supprime ses contrats (cascade). L'app archive plutôt qu'elle ne supprime : voir EmploiView.
    @Relationship(deleteRule: .cascade, inverse: \Contract.employer)
    var contracts: [Contract] = []

    init(name: String) {
        self.uid = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
