import Foundation
import SwiftData

/// Un taux horaire brut qui s'applique à partir d'une date, pour un contrat (lié par `contractUID`, pas de relation).
@Model
final class PayRate {
    var uid: UUID = UUID()
    var contractUID: UUID = UUID()
    var effectiveDate: Date = Date()
    var hourlyGross: Double = 0
    var note: String = ""

    init(contractUID: UUID, effectiveDate: Date, hourlyGross: Double, note: String = "") {
        self.uid = UUID()
        self.contractUID = contractUID
        self.effectiveDate = effectiveDate
        self.hourlyGross = hourlyGross
        self.note = note
    }
}
