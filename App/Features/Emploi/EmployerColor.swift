import SwiftUI

/// Couleur d'un employeur : un ton de la palette (jamais une couleur en dur). La clé est stockée dans `Employer.colorHex`.
struct EmployerColorChoice: Identifiable {
    let key: String
    let title: String
    let tone: PLTTone
    var id: String { return key }

    static let all: [EmployerColorChoice] = [
        EmployerColorChoice(key: "work", title: "Vert", tone: .work),
        EmployerColorChoice(key: "accent", title: "Bleu", tone: .accent),
        EmployerColorChoice(key: "study", title: "Violet", tone: .study),
        EmployerColorChoice(key: "errand", title: "Ocre", tone: .errand),
    ]

    static func tone(forKey key: String?) -> PLTTone {
        guard let key = key else { return .work }
        for choice in all where choice.key == key { return choice.tone }
        return .work
    }
}
