import SwiftUI

/// Écran Fonctionnalités (section 3), poussé depuis Réglages.
/// Prototype : design/prototype/src/screens/70_fonctionnalites.html.
struct FonctionnalitesView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette

    @State private var query: String = ""
    @State private var pending: ModuleChangeRequest? = nil

    private struct CoreItem: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let subtitle: String
    }

    private let coreItems: [CoreItem] = [
        CoreItem(id: "lieux", symbol: "mappin.and.ellipse", title: "Lieux et sessions",
                 subtitle: "Ton taf, ta fac, tes courses, avec leurs heures"),
        CoreItem(id: "detection", symbol: "location.fill", title: "Détection arrivée et départ",
                 subtitle: "Dans la limite des autorisations que tu donnes"),
        CoreItem(id: "manuel", symbol: "hand.tap.fill", title: "Saisie manuelle",
                 subtitle: "Démarrer, arrêter ou ajouter une session à la main"),
        CoreItem(id: "stats", symbol: "chart.bar.fill", title: "Statistiques d'heures",
                 subtitle: "Totaux, moyennes, graphique par jour"),
        CoreItem(id: "reglages", symbol: "gearshape.fill", title: "Réglages, export et import",
                 subtitle: "Tes données en JSON, quand tu veux")
    ]

    var body: some View {
        let counts = ModuleCatalog.counts(enabled: modules.enabledIDs)
        let groups: [ModuleCatalog.Group] = ModuleCatalog.groups(query: query)
        return PLTScreen(title: "Fonctionnalités") {
            searchField
            counterLine(active: counts.active, total: counts.total)
            if counts.active == 0 {
                PLTBanner(kind: .info,
                          title: "Tout est désactivé, et ça marche",
                          message: "Il te reste l'essentiel : tes lieux, tes sessions et tes heures. Tu peux rallumer ce que tu veux quand tu veux, tes données sont gardées.")
            }
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                coreSection
            }
            if groups.isEmpty {
                PLTEmptyState(symbol: "magnifyingglass",
                              title: "Aucune fonctionnalité ne s'appelle comme ça.",
                              message: "Essaie un mot plus court, comme « paie », « congés » ou « notes ».",
                              actionTitle: "Effacer la recherche",
                              action: { query = "" })
            } else {
                ForEach(groups) { group in
                    groupSection(group)
                }
            }
        }
        .sheet(item: $pending) { request in
            ModuleChangeSheet(request: request) {
                modules.setEnabled(request.moduleID, request.turnOn)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: recherche et compteur

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
            TextField("Chercher : paie, congés, notes...", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Chercher une fonctionnalité")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.textTertiary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .frame(minHeight: 44)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private func counterLine(active: Int, total: Int) -> some View {
        let soon: Int = ModuleCatalog.comingSoonCount()
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("\(active) actives sur \(total)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(palette.textPrimary)
            Text("\(soon) arrivent bientôt, elles ne sont pas encore utilisables.")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: noyau

    private var coreSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Toujours là")
            PLTListGroup {
                ForEach(coreItems) { item in
                    PLTRow(symbol: item.symbol,
                           tone: .neutral,
                           title: item.title,
                           subtitle: item.subtitle,
                           value: "Toujours",
                           showsSeparator: item.id != coreItems.last?.id)
                        .accessibilityValue("Toujours actif, verrouillé")
                }
            }
            Text("Ça, tu ne peux pas le couper : sans ça l'app ne note rien. Tout le reste est à toi. Rien sur la paie ou l'argent n'est obligatoire.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: modules par thème

    private func groupSection(_ group: ModuleCatalog.Group) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: group.theme)
            PLTListGroup {
                ForEach(group.modules) { module in
                    ModuleRow(module: module,
                              isOn: toggleBinding(for: module),
                              showsSeparator: module.id != group.modules.last?.id)
                }
            }
        }
    }

    private func toggleBinding(for module: ModuleDefinition) -> Binding<Bool> {
        return Binding<Bool>(
            get: { module.isAvailable && modules.isEnabled(module.id) },
            set: { newValue in
                requestChange(module.id, on: newValue)
            }
        )
    }

    private func requestChange(_ id: String, on: Bool) {
        if let request = ModuleCatalog.changeRequest(for: id, turnOn: on, enabled: modules.enabledIDs) {
            pending = request
        } else {
            modules.setEnabled(id, on)
        }
    }
}

/// Une ligne de module : texte qui ouvre le détail, interrupteur à droite.
struct ModuleRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.pltDensity) private var density

    let module: ModuleDefinition
    let isOn: Binding<Bool>
    let showsSeparator: Bool

    var body: some View {
        let vertical: CGFloat = density == .compact ? Theme.Spacing.xs : Theme.Spacing.s
        return HStack(spacing: Theme.Spacing.s) {
            NavigationLink {
                ModuleDetailView(moduleID: module.id)
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.s) {
                        Text(module.title)
                            .font(.body)
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.leading)
                        if !module.isAvailable {
                            PLTChip("Bientôt")
                        }
                    }
                    Text(module.summary)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .disabled(!module.isAvailable)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(module.title)
                .accessibilityHint(module.isAvailable ? "Active ou coupe cette fonctionnalité" : "Pas encore disponible")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, vertical)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
    }
}

/// Feuille de confirmation quand un changement touche d'autres modules.
struct ModuleChangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let request: ModuleChangeRequest
    let onConfirm: () -> Void

    private var moduleTitle: String {
        return ModuleRegistry.definition(for: request.moduleID)?.title ?? request.moduleID
    }

    private var heading: String {
        return request.turnOn ? "Ça va en allumer d'autres" : "Ça va en couper d'autres"
    }

    private var explanation: String {
        if request.turnOn {
            return "« \(moduleTitle) » a besoin de ces fonctionnalités pour marcher. Je les active avec."
        }
        return "Ces fonctionnalités ont besoin de « \(moduleTitle) ». Si tu la coupes, elles s'éteignent aussi. Tes données restent gardées."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text(explanation)
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    PLTListGroup {
                        ForEach(request.others) { other in
                            PLTRow(symbol: request.turnOn ? "plus.circle.fill" : "minus.circle.fill",
                                   tone: request.turnOn ? .accent : .danger,
                                   title: other.title,
                                   showsSeparator: other.id != request.others.last?.id)
                        }
                    }
                    if request.turnOn {
                        Button("Tout activer") {
                            onConfirm()
                            dismiss()
                        }
                        .buttonStyle(.pltPrimary)
                    } else {
                        Button("Tout couper") {
                            onConfirm()
                            dismiss()
                        }
                        .buttonStyle(.pltDestructive)
                    }
                    Button("Annuler") { dismiss() }
                        .buttonStyle(.pltSecondary)
                }
                .padding(Theme.Spacing.m)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
