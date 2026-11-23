import SwiftUI

/// Détail d'une fonctionnalité (prototype 71_module.html) : ce qu'elle fait, son étape, ce qu'il lui faut,
/// ce qui en dépend, et ce qui se passe quand elle est coupée.
struct ModuleDetailView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette

    let moduleID: String

    @State private var pending: ModuleChangeRequest? = nil

    private var definition: ModuleDefinition? {
        return ModuleRegistry.definition(for: moduleID)
    }

    var body: some View {
        if let module = definition {
            content(for: module)
        } else {
            PLTScreen(title: "Fonctionnalité") {
                PLTEmptyState(symbol: "questionmark.circle",
                              title: "Je ne connais pas cette fonctionnalité.",
                              message: "Reviens à la liste et choisis-en une autre.")
            }
        }
    }

    private func titles(of ids: Set<String>) -> [ModuleDefinition] {
        return ModuleRegistry.all.filter { ids.contains($0.id) }
    }

    private func content(for module: ModuleDefinition) -> some View {
        let requirements: [ModuleDefinition] = titles(of: ModuleRules.requirements(of: module.id))
        let dependents: [ModuleDefinition] = titles(of: ModuleRules.dependents(of: module.id))
        let missing: [ModuleDefinition] = titles(of: ModuleRules.missingRequirements(for: module.id, enabled: modules.enabledIDs))
        let isOn: Bool = module.isAvailable && modules.isEnabled(module.id)
        return PLTScreen(title: module.isMandatory ? module.title : "Fonctionnalité") {
            PLTCard {
                HStack {
                    PLTChip(ModuleCatalog.theme(for: module.id), kind: .neutral)
                    Spacer(minLength: Theme.Spacing.s)
                    Text(statusText(module: module, isOn: isOn))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isOn ? palette.success : palette.textSecondary)
                }
                Text(module.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(module.summary)
                    .font(.body)
                    .foregroundStyle(palette.textSecondary)
                if module.isMandatory {
                    Text("Toujours actif, tu ne peux pas le couper.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                } else {
                    Toggle(isOn: switchBinding(for: module)) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Activer cette fonction")
                                .font(.body)
                                .foregroundStyle(palette.textPrimary)
                            Text(module.isAvailable ? "Tu peux la couper quand tu veux." : "Pas encore disponible, elle arrive bientôt.")
                                .font(.subheadline)
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .disabled(!module.isAvailable)
                    .frame(minHeight: 44)
                }
            }
            if !missing.isEmpty && !module.isMandatory {
                PLTBanner(kind: .warning,
                          title: "Il lui faut : " + missing.map { $0.title }.joined(separator: ", "),
                          message: "Sans ça, cette fonction ne sait pas sur quoi se baser. Si tu l'actives, je les active avec.")
            }
            infoSection(module: module)
            relationSection(title: "Ce qu'il lui faut",
                            empty: "Rien. Elle marche toute seule.",
                            items: requirements)
            relationSection(title: "Ce qui en dépend",
                            empty: "Aucune autre fonction ne dépend d'elle.",
                            items: dependents)
            offSection(module: module, dependents: dependents)
        }
        .sheet(item: $pending) { request in
            ModuleChangeSheet(request: request) {
                modules.setEnabled(request.moduleID, request.turnOn)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func statusText(module: ModuleDefinition, isOn: Bool) -> String {
        if module.isMandatory { return "Toujours actif" }
        if !module.isAvailable { return "Bientôt" }
        return isOn ? "Activée" : "Coupée"
    }

    private func switchBinding(for module: ModuleDefinition) -> Binding<Bool> {
        return Binding<Bool>(
            get: { module.isAvailable && modules.isEnabled(module.id) },
            set: { newValue in
                if let request = ModuleCatalog.changeRequest(for: module.id, turnOn: newValue, enabled: modules.enabledIDs) {
                    pending = request
                } else {
                    modules.setEnabled(module.id, newValue)
                }
            }
        )
    }

    private func infoSection(module: ModuleDefinition) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que ça fait")
            PLTListGroup {
                PLTRow(symbol: "text.alignleft", tone: .neutral, title: module.summary)
                PLTRow(symbol: "flag.checkered", tone: .neutral,
                       title: "Étape de livraison",
                       value: "\(module.step)",
                       showsSeparator: false)
            }
            Text(module.id == "place_discovery"
                 ? "L’historique reste sur ton iPhone. Plans reçoit la position des arrêts recherchés pour retrouver leur adresse."
                 : "Les données de ce module sont stockées sur ton iPhone.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func relationSection(title: String, empty: String, items: [ModuleDefinition]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: title)
            if items.isEmpty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            } else {
                PLTListGroup {
                    ForEach(items) { item in
                        PLTRow(symbol: "square.grid.2x2",
                               tone: .neutral,
                               title: item.title,
                               value: modules.isEnabled(item.id) ? "Activée" : "Coupée",
                               showsSeparator: item.id != items.last?.id)
                    }
                }
            }
        }
    }

    private func offSection(module: ModuleDefinition, dependents: [ModuleDefinition]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Si tu la désactives")
            PLTCard {
                bullet("Rien n'est supprimé. Tes données restent là, et tout revient si tu rallumes.")
                bullet("Les écrans, boutons et notifications de cette fonction disparaissent.")
                bullet("Plus aucun calcul en arrière-plan, plus aucune demande d'autorisation.")
                if !dependents.isEmpty {
                    bullet("Les fonctions qui en dépendent se coupent aussi : " + dependents.map { $0.title }.joined(separator: ", ") + ".")
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text("•")
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
        }
        .foregroundStyle(palette.textPrimary)
    }
}
