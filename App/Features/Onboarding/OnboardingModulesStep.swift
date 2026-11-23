import SwiftUI

/// Étape 2 : préréglages et interrupteurs. Les dépendances sont gérées par ModuleStore.
struct OnboardingModulesStep: View {
    @Environment(\.palette) private var palette
    @Environment(ModuleStore.self) private var modules
    let onContinue: () -> Void

    @State private var dependencyNote: String = ""

    /// Libellés courts du prototype (le registre garde les titres complets).
    private static let shortTitles: [String: String] = [
        "employment": "Employeurs et contrats",
        "pay": "Salaire et paie",
        "contract_hours": "Heures du contrat",
        "leave": "Congés payés",
        "multi_employer": "Plusieurs employeurs",
        "school_calendar": "Calendrier scolaire",
        "exam_mode": "Mode examens",
        "study_slots": "Créneaux de révision",
        "planning_ocr": "Planning par photo",
        "missing_hours": "Heures manquantes",
        "now_card": "Carte Maintenant",
        "notes": "Notes de journée",
        "recaps": "Bilans du mois et de l'année",
        "weekly_review": "Revue de la semaine",
        "live_activity_widgets": "Écran verrouillé et widgets",
        "travel_departure": "Trajet et Pars maintenant"
    ]

    private static let symbols: [String: String] = [
        "employment": "briefcase",
        "pay": "eurosign",
        "contract_hours": "clock",
        "leave": "calendar",
        "multi_employer": "person.2",
        "school_calendar": "book",
        "exam_mode": "star",
        "study_slots": "list.bullet",
        "planning_ocr": "camera",
        "missing_hours": "magnifyingglass",
        "now_card": "bolt",
        "notes": "pencil",
        "recaps": "chart.bar",
        "weekly_review": "arrow.triangle.2.circlepath",
        "live_activity_widgets": "square.grid.2x2",
        "travel_departure": "arrow.triangle.turn.up.right.diamond"
    ]

    private static let planningIDs: [String] = ["planning_ocr", "missing_hours"]
    private static let dailyIDs: [String] = ["now_card", "notes", "recaps", "weekly_review",
                                             "live_activity_widgets", "travel_departure"]

    private var currentPreset: OnboardingPreset {
        return OnboardingFlow.detectPreset(enabled: modules.enabledIDs)
    }

    private var countText: String {
        let n: Int = OnboardingFlow.offeredEnabledCount(enabled: modules.enabledIDs)
        let total: Int = OnboardingFlow.offeredModuleIDs.count
        if n == 0 { return "Seulement le noyau, rien en plus" }
        return n == 1 ? "1 fonctionnalité en plus sur \(total)" : "\(n) fonctionnalités en plus sur \(total)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingTitle(title: "Qu'est-ce qui t'intéresse ?",
                            lead: "Je te propose le réglage qui va à la plupart des gens. Coche ou décoche, tu pourras tout changer dans Réglages, Fonctionnalités.")

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Un préréglage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                Picker("Préréglage", selection: presetBinding) {
                    Text("Essentiel").tag(OnboardingPreset.essentiel)
                    Text("Complet").tag(OnboardingPreset.complet)
                    Text("Je choisis").tag(OnboardingPreset.choix)
                }
                .pickerStyle(.segmented)
                Text(countText)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Toujours là")
                PLTListGroup {
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "lock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .frame(width: 36, height: 36)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Le noyau")
                                .font(.body)
                                .foregroundStyle(palette.textPrimary)
                            Text("Tes lieux, la détection des arrivées et départs, tes sessions, ta journée et tes stats. Pas désactivable.")
                                .font(.subheadline)
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer(minLength: Theme.Spacing.s)
                        Text("Obligatoire")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, Theme.Spacing.s + Theme.Spacing.xxs)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(palette.accentSoft, in: Capsule())
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
                Text("Rien lié à l'argent n'est obligatoire. Tu peux tout décocher en dessous.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            moduleGroup(title: "Ton taf", ids: OnboardingFlow.workModuleIDs)
            moduleGroup(title: "Tes cours", ids: OnboardingFlow.studyModuleIDs)
            moduleGroup(title: "Ton planning", ids: OnboardingModulesStep.planningIDs)
            moduleGroup(title: "Au quotidien", ids: OnboardingModulesStep.dailyIDs)

            if !dependencyNote.isEmpty {
                PLTBanner(kind: .info, title: dependencyNote)
            }

            VStack(spacing: Theme.Spacing.s) {
                Button("Continuer", action: onContinue)
                    .buttonStyle(.pltPrimary)
                Text("Les étapes suivantes s'adaptent à ton choix.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func moduleGroup(title: String, ids: [String]) -> some View {
        let defs: [ModuleDefinition] = ids.compactMap { ModuleRegistry.definition(for: $0) }
        if !defs.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: title)
                PLTListGroup {
                    ForEach(defs) { def in
                        moduleRow(def, isLast: def.id == defs.last?.id)
                    }
                }
            }
        }
    }

    private func moduleRow(_ def: ModuleDefinition, isLast: Bool) -> some View {
        let name: String = OnboardingModulesStep.shortTitles[def.id] ?? def.title
        let symbol: String = OnboardingModulesStep.symbols[def.id] ?? "square"
        return Toggle(isOn: moduleBinding(def.id)) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(palette.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.s) {
                        Text(name)
                            .font(.body)
                            .foregroundStyle(palette.textPrimary)
                        if !def.isAvailable {
                            PLTChip("Bientôt", kind: .neutral)
                        }
                    }
                    Text(def.summary)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
        .accessibilityHint(def.isAvailable ? "" : "Pas encore disponible, tu peux le pré-sélectionner.")
    }

    private func moduleBinding(_ id: String) -> Binding<Bool> {
        return Binding<Bool>(
            get: { return modules.isEnabled(id) },
            set: { newValue in
                let missing: Set<String> = newValue ? ModuleRules.missingRequirements(for: id, enabled: modules.enabledIDs) : []
                let dependents: Set<String> = newValue ? [] : ModuleRules.activeDependents(of: id, enabled: modules.enabledIDs)
                if !missing.isEmpty {
                    dependencyNote = "J'ai aussi coché ce dont ce module a besoin (" + names(missing) + ")."
                } else if !dependents.isEmpty {
                    dependencyNote = "Je coupe aussi ce qui en dépend (" + names(dependents) + ")."
                } else {
                    dependencyNote = ""
                }
                modules.setEnabled(id, newValue)
            }
        )
    }

    private func names(_ ids: Set<String>) -> String {
        let list: [String] = ids.sorted().map { OnboardingModulesStep.shortTitles[$0] ?? (ModuleRegistry.definition(for: $0)?.title ?? $0) }
        return list.joined(separator: ", ")
    }

    private var presetBinding: Binding<OnboardingPreset> {
        return Binding<OnboardingPreset>(
            get: { return currentPreset },
            set: { newValue in
                if newValue == .choix { return }
                dependencyNote = ""
                applyPreset(newValue)
            }
        )
    }

    /// Désactive d'abord ce qui sort du préréglage, puis active ce qui y entre (le store gère les dépendances).
    private func applyPreset(_ preset: OnboardingPreset) {
        let target: Set<String> = OnboardingFlow.presetIDs(preset)
        for def in ModuleRegistry.all where !def.isMandatory && !target.contains(def.id) {
            modules.setEnabled(def.id, false)
        }
        for def in ModuleRegistry.all where !def.isMandatory && target.contains(def.id) {
            modules.setEnabled(def.id, true)
        }
    }
}
