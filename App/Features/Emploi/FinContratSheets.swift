import SwiftUI

/// Cases cochées de la checklist de fin de contrat, gardées dans UserDefaults (par contrat). Rien d'important : ça ne bloque rien.
enum EndChecklistStore {
    private static func key(_ contractUID: UUID) -> String {
        return "plt.employment.checklist.\(contractUID.uuidString)"
    }

    static func checked(for contractUID: UUID) -> [String] {
        return UserDefaults.standard.stringArray(forKey: key(contractUID)) ?? []
    }

    static func save(_ ids: [String], for contractUID: UUID) {
        UserDefaults.standard.set(ids, forKey: key(contractUID))
    }
}

/// Feuille "Fin de contrat, les papiers" (prototype 50_emploi.html).
struct FinContratChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let contractUID: UUID
    @State private var checked: [String] = []

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Fin de contrat") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Fin de contrat, les papiers")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Coche au fur et à mesure. Chaque ligne dit à quoi ça sert.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                PLTListGroup {
                    ForEach(ContractRules.endChecklist, id: \.id) { (item: EndChecklistItem) in
                        PLTRow(symbol: checked.contains(item.id) ? "checkmark.square.fill" : "square",
                               tone: checked.contains(item.id) ? .accent : .neutral,
                               title: item.title,
                               subtitle: item.purpose,
                               showsSeparator: item.id != ContractRules.endChecklist.last?.id,
                               action: { toggle(item.id) })
                            .accessibilityValue(checked.contains(item.id) ? "Coché" : "Pas coché")
                    }
                }
                Text("\(ContractRules.checklistDoneCount(checkedIDs: checked)) sur \(ContractRules.endChecklist.count) cochés. Cette liste t'aide à ne rien oublier, elle n'est pas un avis juridique.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                checked = EndChecklistStore.checked(for: contractUID)
            }
        }
    }

    private func toggle(_ id: String) {
        if let index = checked.firstIndex(of: id) {
            checked.remove(at: index)
        } else {
            checked.append(id)
        }
        EndChecklistStore.save(checked, for: contractUID)
    }
}

/// Feuille "Indemnité de fin de contrat". Aucun calcul : les règles vérifiées ne sont pas encore dans l'app.
struct IndemniteInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Indemnité de fin de contrat") {
                PLTBanner(kind: .info,
                          title: "Peut-être applicable, à vérifier",
                          message: "Selon ton type de contrat et ta situation, une indemnité de fin de contrat peut t'être due. Elle ne l'est pas toujours, par exemple pour certains jobs saisonniers ou d'étudiant.")
                PLTCard {
                    Text("Je ne calcule rien pour l'instant")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("Les règles générales doivent venir d'une source officielle vérifiée, et elles ne sont pas encore dans l'app. Plutôt que de te donner un chiffre faux, je préfère ne rien afficher.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    Text("Pour savoir, regarde ton contrat, puis service-public.fr et code.travail.gouv.fr. Ta fiche de paie finale fait foi.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                Text("Je t'informe, je ne donne pas de conseil juridique.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
