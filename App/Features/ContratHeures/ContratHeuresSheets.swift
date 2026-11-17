import SwiftUI

/// Feuilles de l'écran "Mon contrat".
enum ContratHeuresSheet: Int, Identifiable {
    case rule
    case classification
    case placement
    case alert

    var id: Int { return rawValue }
}

// MARK: - Quand ça ne tombe pas pile (106.4)

struct ContratRegleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var selected: HoursCarryRule
    let onSelect: (HoursCarryRule) -> Void

    init(selection: HoursCarryRule, onSelect: @escaping (HoursCarryRule) -> Void) {
        _selected = State(initialValue: selection)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Quand ça ne tombe pas pile") {
                Text("Dis-moi ce qui se passe vraiment pour toi. Si tu ne sais pas, laisse « À renseigner » : je ne présume rien.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                PLTListGroup {
                    ForEach(HoursCarryRule.allCases, id: \.rawValue) { (rule: HoursCarryRule) in
                        let isSelected: Bool = rule == selected
                        let traits: AccessibilityTraits = isSelected ? .isSelected : []
                        PLTRow(symbol: isSelected ? "checkmark.circle.fill" : "circle",
                               tone: isSelected ? .accent : .neutral,
                               title: rule.title,
                               subtitle: rule.detail,
                               showsSeparator: rule != HoursCarryRule.allCases.last,
                               action: {
                                   selected = rule
                                   onSelect(rule)
                               })
                            .accessibilityAddTraits(traits)
                    }
                }
                Text("C'est ton contrat et ton employeur qui décident de ce qui est reporté ou payé. Vérifie auprès d'eux : je ne fais que compter selon ce que tu m'indiques.")
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

// MARK: - Comment ces heures sont comptées (106.5)

struct ContratClassementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let overMinutes: Int
    let quotaMinutes: Int

    init(overMinutes: Int, quotaMinutes: Int) {
        self.overMinutes = overMinutes
        self.quotaMinutes = quotaMinutes
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Comment ces \(ContractHoursText.hours(overMinutes)) sont comptées") {
                PLTBanner(kind: .info,
                          title: "À vérifier dans ton contrat",
                          message: "Au-delà de \(ContractHoursText.hours(quotaMinutes)), il peut s'agir d'heures complémentaires ou d'autre chose. Le classement, la majoration et le plafond dépendent de ton contrat et de ta convention.")
                PLTListGroup {
                    PLTRow(symbol: "tag",
                           tone: .neutral,
                           title: "Classement",
                           subtitle: "À renseigner. Regarde ton contrat ou demande à ton employeur.")
                    PLTRow(symbol: "percent",
                           tone: .neutral,
                           title: "Majoration",
                           subtitle: "À renseigner. Ta convention peut la préciser.")
                    PLTRow(symbol: "gauge.with.dots.needle.33percent",
                           tone: .neutral,
                           title: "Plafond d'heures complémentaires",
                           subtitle: "À renseigner.",
                           showsSeparator: false)
                }
                Text("Les règles sourcées (convention, règles générales) ne sont pas encore dans l'app, donc je ne te donne aucun chiffre. Je t'informe, je ne donne pas de conseil juridique.")
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

// MARK: - Où placer les heures manquantes (106.7)

struct ContratRepartirSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let missingMinutes: Int
    let days: Int
    let quotaMinutes: Int
    let projectedMinutes: Int

    init(missingMinutes: Int, days: Int, quotaMinutes: Int, projectedMinutes: Int) {
        self.missingMinutes = missingMinutes
        self.days = days
        self.quotaMinutes = quotaMinutes
        self.projectedMinutes = projectedMinutes
    }

    var body: some View {
        let perDay: Int = ContractHoursBalance.evenSplitMinutes(missing: missingMinutes, days: days)
        return NavigationStack {
            PLTScreen(title: "Où placer les \(ContractHoursText.hours(missingMinutes))") {
                Text("Pour atteindre tes \(ContractHoursText.hours(quotaMinutes)), il te faut \(ContractHoursText.hours(missingMinutes)) de plus sur les \(days) jours qu'il te reste, aujourd'hui compris. Tu peux aussi ne rien faire.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                PLTListGroup {
                    PLTRow(symbol: "calendar",
                           title: "Répartir à égalité",
                           subtitle: "Environ \(ContractHoursText.hours(perDay)) par jour sur \(days) jours.")
                    PLTRow(symbol: "arrow.left.and.right",
                           title: "Rallonger un créneau déjà prévu",
                           subtitle: "Si ton planning a un jour plus léger, c'est le plus simple.")
                    PLTRow(symbol: "hand.raised",
                           tone: .neutral,
                           title: "Ne rien changer",
                           subtitle: "Tu finis à \(ContractHoursText.hours(projectedMinutes)). Ce que ça devient dépend de ce que tu as renseigné dans « Quand ça ne tombe pas pile ».",
                           showsSeparator: false)
                }
                Text("Je ne regarde pas encore ton planning, tes disponibilités ni ton repos : vérifie-les avant de choisir. Je ne propose jamais de contourner ton contrat.")
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

// MARK: - Alerte de quota (109)

struct ContratAlerteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let enabled: Binding<Bool>
    let threshold2h: Binding<Bool>
    let threshold1h: Binding<Bool>
    let thresholdReached: Binding<Bool>

    init(enabled: Binding<Bool>, threshold2h: Binding<Bool>, threshold1h: Binding<Bool>, thresholdReached: Binding<Bool>) {
        self.enabled = enabled
        self.threshold2h = threshold2h
        self.threshold1h = threshold1h
        self.thresholdReached = thresholdReached
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Alerte de quota") {
                Text("Optionnelle, éteinte au départ. Je te donne l'information pour que tu choisisses en connaissance de cause, sans te pousser à faire plus ou moins.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                PLTCard {
                    Toggle("Prévenir quand je m'approche de mon quota", isOn: enabled)
                        .font(.body)
                        .frame(minHeight: 44)
                }
                if enabled.wrappedValue {
                    PLTCard {
                        Toggle("À 2 h restantes", isOn: threshold2h)
                            .frame(minHeight: 44)
                        Toggle("À 1 h restante", isOn: threshold1h)
                            .frame(minHeight: 44)
                        Toggle("Quand le quota est atteint", isOn: thresholdReached)
                            .frame(minHeight: 44)
                    }
                }
                Text("Ici, l'alerte s'affiche en haut de l'écran Mon contrat. Les notifications ne sont pas encore envoyées, et je ne sais pas encore couper l'alerte pendant tes congés : ne te fie pas à elle pour ça.")
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
