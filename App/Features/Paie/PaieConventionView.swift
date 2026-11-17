import SwiftUI
import SwiftData

/// "Ta convention" (section 21) : recherche parmi les packs du bundle. Écran poussé depuis PaieView.
/// Les packs ne contiennent que des valeurs avec leur source ; ce qui manque est "à renseigner".
struct PaieConventionView: View {
    let employer: Employer

    @Environment(\.palette) private var palette
    @State private var query: String = ""

    private var loaded: ConventionLoadResult { return ConventionCatalog.bundled }

    private var currentPack: ConventionPack {
        return ConventionCatalog.pack(for: employer.conventionID, in: loaded.packs)
    }

    private var results: [ConventionPack] {
        return ConventionCatalog.search(query, in: loaded.packs)
    }

    var body: some View {
        PLTScreen(title: "Ta convention") {
            Text("Choisis la convention collective de \(employer.name). Elle apporte des règles (nuit, dimanche, heures au-delà du seuil). Tu peux changer chaque valeur après. Changer de convention ne détruit rien : le calcul est refait à partir de tes sessions.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            if loaded.packs.isEmpty {
                PLTBanner(kind: .error, title: "Aucun pack de convention lisible",
                          message: "Les fichiers de règles n'ont pas pu être chargés. Aucune majoration n'est appliquée.")
            }
            if !loaded.rejected.isEmpty || !loaded.unreadableFiles.isEmpty {
                PLTBanner(kind: .warning, title: "Certains packs ont été écartés",
                          message: rejectedMessage)
            }
            currentSection
            searchSection
            resultsSection
            unknownSection
        }
    }

    private var rejectedMessage: String {
        var parts: [String] = []
        for r in loaded.rejected {
            let first: String = r.errors.first?.message ?? "pack invalide"
            parts.append(r.packID + " : " + first)
        }
        for f in loaded.unreadableFiles { parts.append(f + " : fichier illisible") }
        return parts.joined(separator: " ")
    }

    private var currentSection: some View {
        let pack: ConventionPack = currentPack
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Convention actuelle")
            PLTListGroup {
                NavigationLink {
                    PaieConventionRulesView(employer: employer, pack: pack)
                } label: {
                    PLTRow(symbol: "doc.text.magnifyingglass", tone: .accent,
                           title: pack.name,
                           subtitle: pack.isUnverified ? "Valeurs à vérifier. " + PaieRuleText.verifyHint : "Vérifiée le " + (pack.verifiedOn ?? ""),
                           showsChevron: true,
                           showsSeparator: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchSection: some View {
        PLTCard {
            Text("Chercher")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            TextField("Nom, secteur ou numéro IDCC", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .frame(minHeight: 44)
                .accessibilityLabel("Chercher une convention")
            Text("Par exemple supermarché, garage, resto, ménage, ou 2216. Les accents et les petites fautes ne gênent pas.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var resultsSection: some View {
        let list: [ConventionPack] = results
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: query.isEmpty ? "Toutes les conventions" : "Résultats")
            if list.isEmpty {
                PLTCard {
                    Text("Aucune convention ne correspond. Essaie un autre mot, ou choisis le pack général ou personnalisé plus bas.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(0..<list.count, id: \.self) { i in
                        resultRow(list[i], showsSeparator: i < list.count - 1)
                    }
                }
            }
        }
    }

    private func resultRow(_ pack: ConventionPack, showsSeparator: Bool) -> some View {
        let isCurrent: Bool = pack.id == currentPack.id
        var subtitle: String = pack.summary
        if let idcc = pack.idcc { subtitle = "IDCC " + idcc + ". " + subtitle }
        return NavigationLink {
            PaieConventionRulesView(employer: employer, pack: pack)
        } label: {
            PLTRow(symbol: "building.2", tone: isCurrent ? .accent : .neutral,
                   title: pack.name,
                   subtitle: subtitle,
                   value: isCurrent ? "Choisie" : nil,
                   showsChevron: true,
                   showsSeparator: showsSeparator)
        }
        .buttonStyle(.plain)
    }

    private var unknownSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Je ne sais pas")
            PLTCard {
                Text("C'est écrit en haut de ta fiche de paie ou dans ton contrat, avec un numéro à 4 chiffres (l'IDCC). Tape-le dans la recherche. Je ne lis pas encore la fiche de paie pour le trouver.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textPrimary)
            }
            PLTListGroup {
                packLink(id: ConventionCatalog.genericID, title: "Je ne trouve pas ma convention",
                         subtitle: "Règles générales du Code du travail, valeurs à vérifier", symbol: "book.closed", last: false)
                packLink(id: ConventionCatalog.customID, title: "Saisir mes propres règles",
                         subtitle: "Pack personnalisé : tu règles tout toi-même", symbol: "slider.horizontal.3", last: true)
            }
        }
    }

    @ViewBuilder
    private func packLink(id: String, title: String, subtitle: String, symbol: String, last: Bool) -> some View {
        if let pack = loaded.packs.first(where: { (p: ConventionPack) -> Bool in p.id == id }) {
            NavigationLink {
                PaieConventionRulesView(employer: employer, pack: pack)
            } label: {
                PLTRow(symbol: symbol, tone: .neutral, title: title, subtitle: subtitle, showsChevron: true, showsSeparator: !last)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Règles d'un pack, choix, et surcharge de chaque valeur.
struct PaieConventionRulesView: View {
    let employer: Employer
    let pack: ConventionPack

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @State private var overrides: ConventionRules
    @State private var showEditor: Bool = false
    @State private var showResetDialog: Bool = false
    @State private var errorMessage: String? = nil

    init(employer: Employer, pack: ConventionPack) {
        self.employer = employer
        self.pack = pack
        _overrides = State(initialValue: ConventionOverrides.load(packID: pack.id, defaults: UserDefaults.standard))
    }

    private var effective: ConventionRules {
        return ConventionOverrides.effectiveRules(pack: pack, overrides: overrides)
    }

    private var isChosen: Bool {
        return ConventionCatalog.pack(for: employer.conventionID, in: ConventionCatalog.bundled.packs).id == pack.id
    }

    var body: some View {
        PLTScreen(title: "Règles") {
            headerSection
            chooseSection
            if let message = errorMessage {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: message)
            }
            rulesSection
            toFillSection
            editSection
        }
        .sheet(isPresented: $showEditor) {
            PaieRuleOverrideView(pack: pack, overrides: overrides, onSave: { (rules: ConventionRules) in
                saveOverrides(rules)
            })
        }
        .confirmationDialog("Revenir aux valeurs du pack ?", isPresented: $showResetDialog, titleVisibility: .visible) {
            Button("Effacer mes valeurs", role: .destructive) {
                ConventionOverrides.clear(packID: pack.id, defaults: UserDefaults.standard)
                overrides = ConventionRules()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes valeurs pour ce pack sont effacées. Tes sessions ne changent pas.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTCard {
                Text(pack.name)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                if let idcc = pack.idcc {
                    Text("IDCC " + idcc)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                }
                if !pack.summary.isEmpty {
                    Text(pack.summary)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                Text(validityText)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            if pack.isUnverified {
                PLTBanner(kind: .warning, title: "Valeurs à vérifier",
                          message: pack.sourceNote.isEmpty ? PaieRuleText.verifyHint : pack.sourceNote)
            } else if !pack.sourceNote.isEmpty {
                PLTBanner(kind: .info, title: "Sources", message: pack.sourceNote)
            }
        }
    }

    private var validityText: String {
        var parts: [String] = []
        if let v = pack.validFrom { parts.append("Valable depuis le " + v) } else { parts.append("Date de validité inconnue") }
        if let c = pack.verifiedOn { parts.append("vérifié le " + c) } else { parts.append("jamais vérifié par l'app") }
        return parts.joined(separator: ", ") + "."
    }

    private var chooseSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if isChosen {
                PLTChip("Convention choisie", kind: .work)
            } else {
                Button("Utiliser cette convention") { choose() }
                    .buttonStyle(.pltPrimary)
            }
        }
    }

    private func choose() {
        employer.conventionID = pack.id
        do {
            try context.save()
            errorMessage = nil
        } catch {
            errorMessage = "Je n'ai pas réussi à enregistrer ton choix. Réessaie ?"
        }
    }

    private var rulesSection: some View {
        let eff: ConventionRules = effective
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que j'en tire")
            PLTListGroup {
                if let n = eff.night {
                    PLTRow(symbol: "moon", tone: .accent, title: "Nuit " + PaieRuleText.nightWindow(n),
                           subtitle: ruleNote(n.source, n.sourceDate, overridden: overrides.night != nil),
                           value: "+" + PaieRuleText.percent(n.percent))
                } else {
                    missingRow(symbol: "moon", title: "Majoration de nuit")
                }
                if let s = eff.sunday {
                    PLTRow(symbol: "sun.max", tone: .accent, title: "Dimanche",
                           subtitle: ruleNote(s.source, s.sourceDate, overridden: overrides.sunday != nil),
                           value: "+" + PaieRuleText.percent(s.percent))
                } else {
                    missingRow(symbol: "sun.max", title: "Majoration du dimanche")
                }
                if let h = eff.publicHoliday {
                    PLTRow(symbol: "calendar", tone: .accent, title: "Jours fériés, " + PaieRuleText.holidayScope(h),
                           subtitle: ruleNote(h.source, h.sourceDate, overridden: overrides.publicHoliday != nil),
                           value: "+" + PaieRuleText.percent(h.percent))
                } else {
                    missingRow(symbol: "calendar", title: "Majoration des jours fériés")
                }
                if let o = eff.overtime {
                    PLTRow(symbol: "clock.badge.exclamationmark", tone: .accent, title: "Heures au-delà du seuil",
                           subtitle: PaieRuleText.overtimeSummary(o) + ". " + ruleNote(o.source, o.sourceDate, overridden: overrides.overtime != nil))
                } else {
                    missingRow(symbol: "clock.badge.exclamationmark", title: "Heures au-delà du seuil hebdomadaire")
                }
                if let m = eff.minimumRate {
                    PLTRow(symbol: "eurosign.circle", tone: .accent, title: m.label,
                           subtitle: ruleNote(m.source, m.sourceDate, overridden: overrides.minimumRate != nil),
                           value: PayExport.centsText(m.hourlyCents) + "\u{00A0}€/h",
                           showsSeparator: false)
                } else {
                    missingRow(symbol: "eurosign.circle", title: "Taux horaire minimal", last: true)
                }
            }
            Text("Cumul quand une heure relève de plusieurs règles : " + eff.cumulationMode.title.lowercased() + ". Tout est une estimation. " + PaieRuleText.verifyHint)
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func ruleNote(_ source: String, _ date: String?, overridden: Bool) -> String {
        var text: String = PaieRuleText.sourceWithDate(source, date: date)
        if overridden { text += " Modifié par toi." }
        return text
    }

    private func missingRow(symbol: String, title: String, last: Bool = false) -> some View {
        return PLTRow(symbol: symbol, tone: .neutral, title: title,
                      subtitle: "À renseigner. " + PaieRuleText.verifyHint,
                      value: "Rien",
                      showsSeparator: !last)
    }

    @ViewBuilder
    private var toFillSection: some View {
        if !pack.toFill.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "À renseigner")
                PLTCard {
                    ForEach(0..<pack.toFill.count, id: \.self) { i in
                        Text(pack.toFill[i])
                            .font(.subheadline)
                            .foregroundStyle(palette.textPrimary)
                    }
                    Text("Tant que ce n'est pas renseigné, je n'applique rien. Beaucoup de règles dépendent aussi de ton entreprise : regarde ton contrat.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    private var editSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button("Modifier une valeur") { showEditor = true }
                .buttonStyle(.pltSecondary)
            if overrides != ConventionRules() {
                Button("Revenir aux valeurs du pack") { showResetDialog = true }
                    .buttonStyle(.pltSecondary)
            }
            Text("Tes valeurs passent avant celles du pack. Elles restent sur ton tel.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func saveOverrides(_ rules: ConventionRules) {
        let errors: [PackValidationError] = ConventionOverrides.save(rules, packID: pack.id, defaults: UserDefaults.standard)
        if let first = errors.first {
            errorMessage = first.message
        } else {
            overrides = rules
            errorMessage = nil
        }
    }
}

/// Feuille de modification des valeurs d'un pack. Ne garde comme surcharge que ce qui diffère du pack.
struct PaieRuleOverrideView: View {
    let pack: ConventionPack
    let onSave: (ConventionRules) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var nightOn: Bool
    @State private var nightStart: Date
    @State private var nightEnd: Date
    @State private var nightPercent: String
    @State private var sundayOn: Bool
    @State private var sundayPercent: String
    @State private var holidayOn: Bool
    @State private var holidayAll: Bool
    @State private var holidayPercent: String
    @State private var overtimeOn: Bool
    @State private var thresholdHours: String
    @State private var band1Hours: String
    @State private var band1Percent: String
    @State private var band2Percent: String
    @State private var minimumOn: Bool
    @State private var minimumText: String
    @State private var cumulateSum: Bool
    @State private var errorMessage: String? = nil

    private static func plain(_ value: Double) -> String {
        return PaieRuleText.percent(value).replacingOccurrences(of: "\u{00A0}%", with: "")
    }

    private static func dateFor(minute: Int) -> Date {
        let cal: Calendar = Calendar.current
        return cal.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: cal.startOfDay(for: Date())) ?? Date()
    }

    private static func minute(of date: Date) -> Int {
        let cal: Calendar = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    init(pack: ConventionPack, overrides: ConventionRules, onSave: @escaping (ConventionRules) -> Void) {
        self.pack = pack
        self.onSave = onSave
        let eff: ConventionRules = overrides.merged(over: pack.rules)
        _nightOn = State(initialValue: eff.night != nil)
        _nightStart = State(initialValue: PaieRuleOverrideView.dateFor(minute: eff.night?.startMinute ?? 21 * 60))
        _nightEnd = State(initialValue: PaieRuleOverrideView.dateFor(minute: eff.night?.endMinute ?? 6 * 60))
        _nightPercent = State(initialValue: eff.night.map { (n: PackNightRule) -> String in PaieRuleOverrideView.plain(n.percent) } ?? "")
        _sundayOn = State(initialValue: eff.sunday != nil)
        _sundayPercent = State(initialValue: eff.sunday.map { (s: PackPercentRule) -> String in PaieRuleOverrideView.plain(s.percent) } ?? "")
        _holidayOn = State(initialValue: eff.publicHoliday != nil)
        _holidayAll = State(initialValue: (eff.publicHoliday?.scope ?? PackHolidayRule.scopeAll) == PackHolidayRule.scopeAll)
        _holidayPercent = State(initialValue: eff.publicHoliday.map { (h: PackHolidayRule) -> String in PaieRuleOverrideView.plain(h.percent) } ?? "")
        _overtimeOn = State(initialValue: eff.overtime != nil)
        var threshold: String = ""
        var b1h: String = ""
        var b1p: String = ""
        var b2p: String = ""
        if let o = eff.overtime {
            threshold = PaieRuleOverrideView.plain(Double(o.weeklyThresholdMinutes) / 60)
            if o.bands.count >= 2, let limit = o.bands[0].overMinutes {
                b1h = PaieRuleOverrideView.plain(Double(limit) / 60)
                b1p = PaieRuleOverrideView.plain(o.bands[0].percent)
                b2p = PaieRuleOverrideView.plain(o.bands[o.bands.count - 1].percent)
            } else if let last = o.bands.last {
                b2p = PaieRuleOverrideView.plain(last.percent)
            }
        }
        _thresholdHours = State(initialValue: threshold)
        _band1Hours = State(initialValue: b1h)
        _band1Percent = State(initialValue: b1p)
        _band2Percent = State(initialValue: b2p)
        _minimumOn = State(initialValue: eff.minimumRate != nil)
        _minimumText = State(initialValue: eff.minimumRate.map { (m: PackMinimumRate) -> String in PayExport.centsText(m.hourlyCents) } ?? "")
        _cumulateSum = State(initialValue: eff.cumulationMode == .sum)
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Modifier une valeur") {
                Text("Remplis seulement ce que ton contrat ou ta fiche de paie dit. Une règle laissée éteinte n'est pas appliquée. Une valeur qui change celle du pack est marquée \"saisie par toi\".")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                nightCard
                sundayCard
                holidayCard
                overtimeCard
                minimumCard
                cumulCard
                if let message = errorMessage {
                    PLTBanner(kind: .error, title: "Pas enregistré", message: message)
                }
                Button("Enregistrer") { save() }
                    .buttonStyle(.pltPrimary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func percentField(_ title: String, text: Binding<String>) -> some View {
        return HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: Theme.Spacing.s)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 90, height: 44)
                .accessibilityLabel(title)
        }
    }

    private var nightCard: some View {
        PLTCard {
            Toggle("Majoration de nuit", isOn: $nightOn).frame(minHeight: 44)
            if nightOn {
                DatePicker("Début de la nuit", selection: $nightStart, displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44)
                DatePicker("Fin de la nuit", selection: $nightEnd, displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44)
                percentField("Majoration en %", text: $nightPercent)
            }
        }
    }

    private var sundayCard: some View {
        PLTCard {
            Toggle("Majoration du dimanche", isOn: $sundayOn).frame(minHeight: 44)
            if sundayOn { percentField("Majoration en %", text: $sundayPercent) }
        }
    }

    private var holidayCard: some View {
        PLTCard {
            Toggle("Majoration des jours fériés", isOn: $holidayOn).frame(minHeight: 44)
            if holidayOn {
                Toggle("Tous les jours fériés (sinon le 1er mai seulement)", isOn: $holidayAll).frame(minHeight: 44)
                percentField("Majoration en %", text: $holidayPercent)
            }
        }
    }

    private var overtimeCard: some View {
        PLTCard {
            Toggle("Heures au-delà d'un seuil par semaine", isOn: $overtimeOn).frame(minHeight: 44)
            if overtimeOn {
                hoursField("Seuil, en heures par semaine", text: $thresholdHours)
                hoursField("Première tranche, en heures (vide = pas de tranche)", text: $band1Hours)
                percentField("Première tranche en %", text: $band1Percent)
                percentField("Ensuite en %", text: $band2Percent)
                Text("Les semaines vont du lundi au dimanche. Pour un temps partiel, mets ton nombre d'heures au contrat comme seuil.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func hoursField(_ title: String, text: Binding<String>) -> some View {
        return HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: Theme.Spacing.s)
            TextField("35", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 70, height: 44)
                .accessibilityLabel(title)
        }
    }

    private var minimumCard: some View {
        PLTCard {
            Toggle("Taux horaire minimal", isOn: $minimumOn).frame(minHeight: 44)
            if minimumOn {
                HStack {
                    Text("Brut par heure, en euros")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    TextField("0,00", text: $minimumText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                        .frame(width: 90, height: 44)
                        .accessibilityLabel("Taux horaire minimal")
                }
                if pack.rules.minimumRate != nil {
                    Text("Le minimum du pack ne peut pas être retiré, seulement changé.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    private var cumulCard: some View {
        PLTCard {
            Toggle("Additionner les majorations", isOn: $cumulateSum).frame(minHeight: 44)
            Text("Éteint : quand une heure relève de plusieurs règles (dimanche de nuit par exemple), je prends la plus haute. Allumé : j'additionne.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Enregistrement

    private func save() {
        var result = ConventionRules()
        let user: String = PaieRuleText.userSource

        // Nuit
        if nightOn {
            guard let pct = PayRules.parsePercent(nightPercent) else { return fail("La majoration de nuit doit être un nombre entre 0 et 300.") }
            let s: Int = PaieRuleOverrideView.minute(of: nightStart)
            let e: Int = PaieRuleOverrideView.minute(of: nightEnd)
            if s == e { return fail("Le début et la fin de la nuit doivent être différents.") }
            let candidate = PackNightRule(startMinute: s, endMinute: e, percent: pct,
                                          source: pack.rules.night?.source ?? user, sourceDate: pack.rules.night?.sourceDate)
            if pack.rules.night != candidate {
                result.night = PackNightRule(startMinute: s, endMinute: e, percent: pct, source: user)
            }
        } else if let p = pack.rules.night {
            result.night = PackNightRule(startMinute: p.startMinute, endMinute: p.endMinute, percent: 0, source: user)
        }

        // Dimanche
        if sundayOn {
            guard let pct = PayRules.parsePercent(sundayPercent) else { return fail("La majoration du dimanche doit être un nombre entre 0 et 300.") }
            let candidate = PackPercentRule(percent: pct, source: pack.rules.sunday?.source ?? user, sourceDate: pack.rules.sunday?.sourceDate)
            if pack.rules.sunday != candidate { result.sunday = PackPercentRule(percent: pct, source: user) }
        } else if pack.rules.sunday != nil {
            result.sunday = PackPercentRule(percent: 0, source: user)
        }

        // Jours fériés
        let scope: String = holidayAll ? PackHolidayRule.scopeAll : PackHolidayRule.scopeMayFirstOnly
        if holidayOn {
            guard let pct = PayRules.parsePercent(holidayPercent) else { return fail("La majoration des jours fériés doit être un nombre entre 0 et 300.") }
            let candidate = PackHolidayRule(scope: scope, percent: pct, source: pack.rules.publicHoliday?.source ?? user,
                                            sourceDate: pack.rules.publicHoliday?.sourceDate)
            if pack.rules.publicHoliday != candidate { result.publicHoliday = PackHolidayRule(scope: scope, percent: pct, source: user) }
        } else if let p = pack.rules.publicHoliday {
            result.publicHoliday = PackHolidayRule(scope: p.scope, percent: 0, source: user)
        }

        // Heures au-delà du seuil
        if overtimeOn {
            guard let threshold = PayRules.parseHoursToMinutes(thresholdHours) else { return fail("Le seuil doit être un nombre d'heures, par exemple 35.") }
            guard let p2 = PayRules.parsePercent(band2Percent) else { return fail("Le pourcentage \"ensuite\" doit être un nombre entre 0 et 300.") }
            var bands: [PackOvertimeBand] = []
            if !band1Hours.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let limit = PayRules.parseHoursToMinutes(band1Hours) else { return fail("La première tranche doit être un nombre d'heures.") }
                guard let p1 = PayRules.parsePercent(band1Percent) else { return fail("Le pourcentage de la première tranche doit être un nombre entre 0 et 300.") }
                bands.append(PackOvertimeBand(overMinutes: limit, percent: p1))
            }
            bands.append(PackOvertimeBand(overMinutes: nil, percent: p2))
            let candidate = PackOvertimeRule(weeklyThresholdMinutes: threshold, bands: bands,
                                             source: pack.rules.overtime?.source ?? user, sourceDate: pack.rules.overtime?.sourceDate)
            if pack.rules.overtime != candidate {
                result.overtime = PackOvertimeRule(weeklyThresholdMinutes: threshold, bands: bands, source: user)
            }
        } else if let p = pack.rules.overtime {
            result.overtime = PackOvertimeRule(weeklyThresholdMinutes: p.weeklyThresholdMinutes,
                                               bands: [PackOvertimeBand(overMinutes: nil, percent: 0)], source: user)
        }

        // Taux minimal
        if minimumOn {
            guard let cents = PayRules.parseMoneyCents(minimumText) else { return fail("Le taux minimal doit être un montant, par exemple 12,02.") }
            let label: String = pack.rules.minimumRate?.label ?? "Taux horaire minimal"
            let candidate = PackMinimumRate(hourlyCents: cents, label: label,
                                            source: pack.rules.minimumRate?.source ?? user, sourceDate: pack.rules.minimumRate?.sourceDate)
            if pack.rules.minimumRate != candidate { result.minimumRate = PackMinimumRate(hourlyCents: cents, label: label, source: user) }
        }

        // Cumul
        let wanted: RuleCumulation = cumulateSum ? .sum : .highest
        if wanted != pack.rules.cumulationMode { result.cumulation = wanted.rawValue }

        let errors: [PackValidationError] = ConventionPackValidator.validate(rules: result)
        if let first = errors.first {
            fail(first.message)
            return
        }
        onSave(result)
        dismiss()
    }

    private func fail(_ message: String) {
        errorMessage = message
    }
}
