import Foundation

/// Demande de changement qui touche d'autres modules : à confirmer avant d'appliquer.
struct ModuleChangeRequest: Identifiable, Equatable {
    /// Module que l'utilisateur vient de basculer.
    let moduleID: String
    /// Vrai pour une activation, faux pour une désactivation.
    let turnOn: Bool
    /// Les autres modules qui seront aussi activés (activation) ou coupés (désactivation), dans l'ordre du registre.
    let others: [ModuleDefinition]

    var id: String { return moduleID + (turnOn ? "#on" : "#off") }
}

/// Regroupement par thème, recherche et compteurs de l'écran Fonctionnalités. Pur : Foundation seulement.
enum ModuleCatalog {

    /// Un thème et les modules optionnels qu'il contient.
    struct Group: Identifiable, Equatable {
        let theme: String
        let modules: [ModuleDefinition]
        var id: String { return theme }
    }

    static let defaultTheme: String = "Autres"

    /// Ordre d'affichage des thèmes.
    static let themeOrder: [String] = [
        "Planning",
        "Emploi et paie",
        "Études",
        "Trajets",
        "Lieux et détection",
        "Confort",
        "Sécurité et données",
        "Autres"
    ]

    /// Thème de chaque module du registre. Un identifiant absent d'ici tombe dans "Autres".
    static let themeByID: [String: String] = [
        // Planning
        "planning_ocr": "Planning", "schedule_archive": "Planning", "pattern_detection": "Planning",
        "schedule_rotation": "Planning", "planning_diff": "Planning", "planning_text": "Planning",
        "premium_planner": "Planning", "plan_proposals": "Planning", "weekend_preview": "Planning",
        "month_forecast": "Planning", "load_forecast": "Planning", "availability_planner": "Planning",
        "blocked_periods": "Planning", "calendar_constraints": "Planning", "school_calendar": "Planning",
        "holiday_outlook": "Planning", "share_import": "Planning", "low_period_alert": "Planning",
        // Emploi et paie
        "employment": "Emploi et paie", "pay": "Emploi et paie", "contract_hours": "Emploi et paie",
        "multi_employer": "Emploi et paie", "leave": "Emploi et paie", "simulator": "Emploi et paie",
        "pay_date": "Emploi et paie", "tax_threshold": "Emploi et paie", "replacements": "Emploi et paie",
        "contract_journal": "Emploi et paie", "work_contacts": "Emploi et paie", "shift_swaps": "Emploi et paie",
        "team_swaps": "Emploi et paie", "payslip_check": "Emploi et paie", "interview_prep": "Emploi et paie",
        "experience_log": "Emploi et paie", "live_earnings": "Emploi et paie", "true_hourly_rate": "Emploi et paie",
        "notice_check": "Emploi et paie", "pay_reconciliation": "Emploi et paie", "contract_check": "Emploi et paie",
        "internship_log": "Emploi et paie", "pay_period": "Emploi et paie", "extra_time": "Emploi et paie",
        "age_rules": "Emploi et paie", "last_minute_offer": "Emploi et paie", "expenses": "Emploi et paie",
        "savings": "Emploi et paie", "breaks": "Emploi et paie", "short_night": "Emploi et paie",
        "rest_alert": "Emploi et paie", "proof_pack": "Emploi et paie", "send_hours_reminder": "Emploi et paie",
        "badge_reminder": "Emploi et paie", "multi_site": "Emploi et paie", "constraint_counters": "Emploi et paie",
        "missing_hours": "Emploi et paie", "vacation_mode": "Emploi et paie", "vacation_prep": "Emploi et paie",
        "return_recap": "Emploi et paie",
        // Études
        "exam_mode": "Études", "study_slots": "Études", "school_timetable": "Études",
        "class_work_tradeoff": "Études", "exam_budget": "Études",
        // Trajets
        "travel_departure": "Trajets", "travel_cost": "Trajets", "going_home": "Trajets",
        "travel_calibration": "Trajets", "delay_log": "Trajets", "departure_checklist": "Trajets",
        "end_of_day_countdown": "Trajets",
        // Lieux et détection
        "place_discovery": "Lieux et détection", "place_calibration": "Lieux et détection",
        "battery_recovery": "Lieux et détection", "detection_help": "Lieux et détection",
        "nfc": "Lieux et détection", "place_memos": "Lieux et détection", "end_prediction": "Lieux et détection",
        "clock_check": "Lieux et détection", "break_in": "Lieux et détection", "heatmap": "Lieux et détection",
        "day_replay": "Lieux et détection", "backup_signals": "Lieux et détection",
        // Confort
        "notes": "Confort", "search": "Confort", "weekly_review": "Confort", "recaps": "Confort",
        "live_activity_widgets": "Confort", "now_card": "Confort", "smart_notifications": "Confort",
        "focus": "Confort", "rough_day": "Confort", "morning_brief": "Confort", "voice_corrections": "Confort",
        "weekly_balance": "Confort", "share_summary": "Confort", "regularity": "Confort",
        "self_compare": "Confort", "ask_assistant": "Confort", "glossary": "Confort", "day_assistant": "Confort",
        // Sécurité et données
        "undo_safety": "Sécurité et données", "data_trust": "Sécurité et données",
        "biometric_lock": "Sécurité et données", "icloud": "Sécurité et données",
        "tamper_log": "Sécurité et données", "folder_backup": "Sécurité et données",
        "privacy_shield": "Sécurité et données", "reliability_center": "Sécurité et données"
    ]

    static func theme(for id: String) -> String {
        return themeByID[id] ?? defaultTheme
    }

    /// Minuscules et sans accents : "Éléphant" et "elephant" deviennent identiques.
    static func normalize(_ text: String) -> String {
        return text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Chaque mot de la recherche doit se trouver dans le titre ou le résumé. Recherche vide : tout passe.
    static func matches(_ module: ModuleDefinition, query: String) -> Bool {
        let words: [String] = normalize(query).split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map { String($0) }
        if words.isEmpty { return true }
        let haystack: String = normalize(module.title + " " + module.summary)
        for w in words where !haystack.contains(w) { return false }
        return true
    }

    /// Modules optionnels (le noyau est affiché à part).
    static func optionalModules(registry: [ModuleDefinition] = ModuleRegistry.all) -> [ModuleDefinition] {
        return registry.filter { !$0.isMandatory }
    }

    /// Groupes par thème, dans l'ordre de `themeOrder`, sans groupe vide. Chaque module optionnel
    /// apparaît dans exactement un groupe. L'ordre du registre est gardé dans un groupe.
    static func groups(registry: [ModuleDefinition] = ModuleRegistry.all, query: String = "") -> [Group] {
        let candidates: [ModuleDefinition] = optionalModules(registry: registry).filter { matches($0, query: query) }
        var byTheme: [String: [ModuleDefinition]] = [:]
        for m in candidates {
            byTheme[theme(for: m.id), default: []].append(m)
        }
        var result: [Group] = []
        for t in themeOrder {
            if let list = byTheme[t], !list.isEmpty { result.append(Group(theme: t, modules: list)) }
        }
        return result
    }

    /// (actifs, total) sur les modules optionnels. Actif = activé ET livré (même règle que ModuleStore.isActive).
    static func counts(enabled: Set<String>, registry: [ModuleDefinition] = ModuleRegistry.all) -> (active: Int, total: Int) {
        let optional: [ModuleDefinition] = optionalModules(registry: registry)
        var active: Int = 0
        for m in optional where m.isAvailable && enabled.contains(m.id) { active += 1 }
        return (active, optional.count)
    }

    /// Nombre de modules pas encore livrés.
    static func comingSoonCount(registry: [ModuleDefinition] = ModuleRegistry.all) -> Int {
        return optionalModules(registry: registry).filter { !$0.isAvailable }.count
    }

    /// Ce qui change en plus quand on bascule `id`. Nil si rien d'autre n'est touché (on applique direct).
    static func changeRequest(for id: String, turnOn: Bool, enabled: Set<String>,
                              registry: [ModuleDefinition] = ModuleRegistry.all) -> ModuleChangeRequest? {
        let ids: Set<String> = turnOn
            ? ModuleRules.missingRequirements(for: id, enabled: enabled, registry: registry)
            : ModuleRules.activeDependents(of: id, enabled: enabled, registry: registry)
        if ids.isEmpty { return nil }
        let others: [ModuleDefinition] = registry.filter { ids.contains($0.id) && !$0.isMandatory }
        if others.isEmpty { return nil }
        return ModuleChangeRequest(moduleID: id, turnOn: turnOn, others: others)
    }
}
