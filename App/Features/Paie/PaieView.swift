import SwiftUI
import SwiftData

/// Demande d'ouverture du formulaire de taux (feuille).
struct PaieRateFormRequest: Identifiable {
    let id: UUID = UUID()
    let contractUID: UUID
    let contractStart: Date
    /// Vrai pour "Je suis au SMIC" : valeur et date proposées par l'app, modifiables.
    let isSmic: Bool
}

/// Mise en forme des textes de la paie (vues seulement).
enum PaieFormat {
    static func formatter(_ pattern: String, calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = pattern
        return f
    }

    /// "Novembre 2026"
    static func monthTitle(_ date: Date, calendar: Calendar) -> String {
        let text: String = formatter("LLLL yyyy", calendar: calendar).string(from: date)
        return text.prefix(1).uppercased() + String(text.dropFirst())
    }

    /// "16 novembre 2026"
    static func longDate(_ date: Date, calendar: Calendar) -> String {
        return formatter("d MMMM yyyy", calendar: calendar).string(from: date)
    }

    /// 0,79 donne "0,79".
    static func ratioText(_ value: Double) -> String {
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Taux horaire : "12,02" avec la devise de l'utilisateur.
    static func rateText(_ rate: Decimal, settings: AppSettings) -> String {
        return settings.formatMoney(PayMath.double(rate))
    }

    static func plural(_ n: Int, _ one: String, _ many: String) -> String {
        return n == 1 ? "1 \(one)" : "\(n) \(many)"
    }
}

/// Écran Paie (sections 20 et 69, prototype 52_paie.html). Poussé depuis Emploi, sans argument.
/// Tous les montants sont des estimations d'après les sessions de taf et les taux saisis.
struct PaieView: View {
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Environment(ModuleStore.self) private var modules
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]
    @Query(sort: \Contract.startDate, order: .reverse) private var contracts: [Contract]
    @Query(sort: \PayRate.effectiveDate) private var payRates: [PayRate]

    @AppStorage(PayPreferences.Key.netRatio) private var netRatioStored: Double = PayPreferences.defaultNetRatio
    @AppStorage(PayPreferences.Key.hideAmounts) private var hideAmounts: Bool = false
    @AppStorage(PayPreferences.Key.smicOverride) private var smicOverride: Double = 0

    @State private var monthStart: Date = PaieView.firstOfMonth(Date())
    @State private var selectedContractUID: UUID? = nil
    @State private var formRequest: PaieRateFormRequest? = nil
    @State private var showCalc: Bool = false
    @State private var revealed: Bool = false
    @State private var jsonURL: URL? = nil
    @State private var csvURL: URL? = nil
    @State private var exportFailed: Bool = false

    private var calendar: Calendar { return Calendar.current }

    static func firstOfMonth(_ date: Date) -> Date {
        let cal: Calendar = Calendar.current
        let comps: DateComponents = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    // MARK: Données

    private var selectedContract: Contract? {
        if let uid = selectedContractUID {
            for c in contracts where c.uid == uid { return c }
        }
        let today: Date = Date()
        for c in contracts {
            if let end = c.endDate {
                if end >= today { return c }
            } else {
                return c
            }
        }
        return contracts.first
    }

    private func entries(for contract: Contract) -> [PayRateEntry] {
        var list: [PayRateEntry] = []
        for r in payRates where r.contractUID == contract.uid {
            list.append(PayRateEntry(effectiveDate: r.effectiveDate, hourlyGross: PayMath.decimal(r.hourlyGross)))
        }
        if list.isEmpty, let rate = contract.hourlyGrossRate, rate > 0 {
            // Taux saisi sur le contrat, sans historique : il vaut depuis le début du contrat.
            list.append(PayRateEntry(effectiveDate: contract.startDate, hourlyGross: PayMath.decimal(rate)))
        }
        return list
    }

    private func inputs(for contract: Contract) -> [PaySessionInput] {
        var list: [PaySessionInput] = []
        for s in sessions where s.activity == .work {
            if !contract.placeUIDs.isEmpty {
                guard let placeUID = s.place?.uid, contract.placeUIDs.contains(placeUID) else { continue }
            }
            list.append(PaySessionInput(id: s.uid, start: s.startDate, end: s.endDate,
                                        chosenStart: s.chosenStart, chosenEnd: s.chosenEnd, isConfirmed: s.isConfirmed))
        }
        return list
    }

    private var netRatioDecimal: Decimal {
        return PayMath.decimal(PayPreferences.clampedRatio(netRatioStored))
    }

    private func computeResult(for contract: Contract) -> PayMonthResult {
        let comps: DateComponents = calendar.dateComponents([.year, .month], from: monthStart)
        return PayCalculator.month(year: comps.year ?? 0, month: comps.month ?? 1,
                                   sessions: inputs(for: contract), rates: entries(for: contract),
                                   base: settings.calculationBase, netRatio: netRatioDecimal,
                                   now: Date(), calendar: calendar)
    }

    private func computeDetail(for contract: Contract, context ctx: PaieRulesContext) -> PayDetailResult {
        let comps: DateComponents = calendar.dateComponents([.year, .month], from: monthStart)
        return PayCalculator.monthDetail(year: comps.year ?? 0, month: comps.month ?? 1,
                                         sessions: inputs(for: contract), rates: entries(for: contract),
                                         base: settings.calculationBase, netRatio: netRatioDecimal,
                                         rules: ctx.rules, premiums: ctx.premiums,
                                         now: Date(), calendar: calendar)
    }

    private var isCurrentMonth: Bool {
        return calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month)
    }

    private var showsAmountsToggle: Bool {
        guard modules.isActive("pay"), let c = selectedContract else { return false }
        return !entries(for: c).isEmpty
    }

    private var amountsAreMasked: Bool { return hideAmounts && !revealed }

    private func amount(_ cents: Int) -> String {
        if amountsAreMasked { return "••••" }
        return "≈\u{00A0}" + settings.formatMoney(PayMath.units(fromCents: cents))
    }

    private func amountLabel(_ cents: Int) -> String {
        if amountsAreMasked { return "Montant masqué. Touche deux fois pour l'afficher." }
        return "environ " + settings.formatMoney(PayMath.units(fromCents: cents))
    }

    // MARK: Corps

    var body: some View {
        PLTScreen(title: "Paie") {
            content
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if showsAmountsToggle {
                    Button {
                        hideAmounts.toggle()
                        revealed = false
                    } label: {
                        Image(systemName: hideAmounts ? "eye.slash.fill" : "eye.fill")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(hideAmounts ? "Afficher les montants" : "Masquer les montants")
                }
            }
        }
        .sheet(item: $formRequest) { (request: PaieRateFormRequest) in
            PaieTauxFormView(request: request)
        }
        .sheet(isPresented: $showCalc) {
            calcSheet
        }
    }

    @ViewBuilder
    private var content: some View {
        if !modules.isActive("pay") {
            disabledSection
        } else if let contract = selectedContract {
            if entries(for: contract).isEmpty {
                noRateSection(contract)
            } else {
                estimateSections(contract)
            }
        } else {
            noContractSection
        }
    }

    // MARK: Module désactivé

    private var disabledSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTCard {
                PLTEmptyState(symbol: "eurosign.circle",
                              title: "La paie, c'est optionnel.",
                              message: "Tant que ce module est éteint, l'app n'affiche aucun montant. Elle ne compte que tes heures.",
                              actionTitle: "Activer la paie",
                              action: { modules.setEnabled("pay", true) })
            }
            PLTListGroup {
                PLTRow(symbol: "eurosign.circle", title: "Brut et net estimés",
                       subtitle: "Toujours marqués comme des estimations")
                PLTRow(symbol: "doc.text", title: "Relevé d'heures",
                       subtitle: "À envoyer à ton employeur, en CSV ou en JSON")
                PLTRow(symbol: "briefcase", title: "Besoin d'Emploi",
                       subtitle: "La paie s'appuie sur ton contrat",
                       showsSeparator: false)
            }
            Text("Pour l'allumer plus tard : Réglages, puis Fonctionnalités, puis Paie.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Pas de contrat, pas de taux

    private var noContractSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTCard {
                PLTEmptyState(symbol: "briefcase",
                              title: "Il te faut d'abord un contrat.",
                              message: "Ajoute ton employeur et ton contrat dans Emploi, puis reviens ici : j'estime ton mois d'après tes heures.")
            }
            Text("Tes heures sont comptées quand même. Tout reste sur ton tel.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func noRateSection(_ contract: Contract) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTCard {
                PLTEmptyState(symbol: "eurosign.circle",
                              title: "Pas encore d'estimation.",
                              message: "Dis-moi ton taux horaire et j'estime ton mois d'après tes heures. Sans taux, je n'affiche aucun montant.",
                              actionTitle: "Saisir mon taux",
                              action: { openForm(contract, isSmic: false) })
                Button("Je suis au SMIC") { openForm(contract, isSmic: true) }
                    .buttonStyle(.pltSecondary)
            }
            Text("Le SMIC change : je te montre la valeur que j'ai et sa date, tu peux la corriger avant de la garder. Tout reste sur ton tel.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func openForm(_ contract: Contract, isSmic: Bool) {
        formRequest = PaieRateFormRequest(contractUID: contract.uid, contractStart: contract.startDate, isSmic: isSmic)
    }

    // MARK: Estimation

    private func estimateSections(_ contract: Contract) -> some View {
        let r: PayMonthResult = computeResult(for: contract)
        let ctx: PaieRulesContext = PaieRulesContext.load(employer: contract.employer)
        let d: PayDetailResult = computeDetail(for: contract, context: ctx)
        let key: String = "\(r.year)-\(r.month)-\(r.grossCents)-\(r.netCents)-\(r.retainedSeconds)-\(r.exactSeconds)-\(r.sessionCount)-\(r.doubtSessionCount)-\(settings.currencyCode)-\(settings.calculationBase.rawValue)"
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            PLTBanner(kind: .warning,
                      title: "Ce sont des estimations",
                      message: "Je calcule d'après tes heures et les taux que tu as saisis. Ta fiche de paie fait foi, pas moi.")
            if contracts.count > 1 {
                contractPicker
            }
            monthNavigator
            if r.hasAnySession {
                monthSection(r, d)
                flagsSection(r)
                minimumRateSection(r, ctx)
                breakdownSection(r, d, ctx)
            } else {
                emptyMonthSection(r)
            }
            plannedSection(contract, r)
            conventionSection(contract, ctx)
            ratesSection(contract)
            if r.hasAnySession {
                exportSection(r)
            }
            sourcesSection
        }
        .task(id: key) {
            prepareExports(r)
        }
    }

    private var contractPicker: some View {
        let binding = Binding<UUID>(get: { selectedContract?.uid ?? UUID() },
                                    set: { selectedContractUID = $0 })
        return HStack {
            Text("Contrat")
                .font(.body)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: Theme.Spacing.s)
            Picker("Contrat", selection: binding) {
                ForEach(contracts) { (c: Contract) in
                    Text((c.employer?.name ?? "Sans employeur") + ", " + c.kind.title).tag(c.uid)
                }
            }
            .pickerStyle(.menu)
        }
        .frame(minHeight: 44)
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mois précédent")
            Spacer(minLength: Theme.Spacing.s)
            Text(PaieFormat.monthTitle(monthStart, calendar: calendar))
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Spacing.s)
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel("Mois suivant")
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthStart) {
            monthStart = d
            revealed = false
        }
    }

    private func emptyMonthSection(_ r: PayMonthResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTCard {
                PLTEmptyState(symbol: "clock",
                              title: "Aucune session de taf ce mois-ci.",
                              message: "Rien à estimer pour \(PaieFormat.monthTitle(monthStart, calendar: calendar)). Je n'affiche pas de faux zéro.")
            }
            if r.unconfirmedSessionCount > 0 {
                PLTBanner(kind: .info,
                          title: PaieFormat.plural(r.unconfirmedSessionCount, "session à confirmer n'est pas comptée", "sessions à confirmer ne sont pas comptées"),
                          message: "Confirme-les dans Sessions pour les compter.")
            }
        }
    }

    private func monthSection(_ r: PayMonthResult, _ d: PayDetailResult) -> some View {
        let title: String = isCurrentMonth
            ? "\(PaieFormat.monthTitle(monthStart, calendar: calendar)), au \(calendar.component(.day, from: Date()))"
            : PaieFormat.monthTitle(monthStart, calendar: calendar)
        let hours: String = Formatting.duration(seconds: r.retainedSeconds)
        let hoursNote: String = isCurrentMonth ? "Environ, sur \(hours) faites" : "Environ, sur \(hours)"
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Theme.Spacing.s)
                PLTChip("Estimation", kind: .doubt)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                PaieEstimateTile(label: "Brut estimé", value: amount(d.grossCents),
                         note: hoursNote, tone: .work)
                    .accessibilityLabel("Brut estimé, " + amountLabel(d.grossCents))
                    .onTapGesture { if hideAmounts { revealed.toggle() } }
                PaieEstimateTile(label: "Net estimé", value: amount(d.netCents),
                         note: "Environ, ratio \(PaieFormat.ratioText(PayPreferences.clampedRatio(netRatioStored)))", tone: .accent)
                    .accessibilityLabel("Net estimé, " + amountLabel(d.netCents))
                    .onTapGesture { if hideAmounts { revealed.toggle() } }
            }
            if hideAmounts {
                Text(revealed ? "Touche un montant pour le masquer." : "Touche un montant pour l'afficher.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func flagsSection(_ r: PayMonthResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if r.doubtSessionCount > 0 {
                PLTBanner(kind: .warning,
                          title: PaieFormat.plural(r.doubtSessionCount, "session est dans la zone de doute", "sessions sont dans la zone de doute"),
                          message: "Son heure exacte est comptée en attendant ton choix. Le montant peut changer quand tu auras choisi.")
            }
            if r.liveSessionCount > 0 {
                PLTBanner(kind: .info,
                          title: "Une session tourne",
                          message: "Elle compte son heure exacte jusqu'à maintenant. Le montant bouge jusqu'à ton départ.")
            }
            if r.unconfirmedSessionCount > 0 {
                PLTBanner(kind: .info,
                          title: PaieFormat.plural(r.unconfirmedSessionCount, "session à confirmer n'est pas comptée", "sessions à confirmer ne sont pas comptées"),
                          message: "Confirme-les dans Sessions pour les compter.")
            }
            if r.unratedSeconds > 0 {
                PLTBanner(kind: .warning,
                          title: "\(Formatting.duration(seconds: r.unratedSeconds)) sans taux",
                          message: "Ces heures sont avant ton premier taux. Je les compte en heures, pas en euros. Ajoute un taux plus ancien si tu veux les inclure.")
            }
        }
    }

    private func breakdownSection(_ r: PayMonthResult, _ d: PayDetailResult, _ ctx: PaieRulesContext) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Comment je l'estime", actionTitle: "Détail du calcul", action: { showCalc = true })
            PLTListGroup {
                PLTRow(title: "Heures de taf",
                       subtitle: r.base == .fullHours ? "Heures pleines. Une session à confirmer n'est pas comptée." : "Heure exacte, à la minute près.",
                       value: Formatting.duration(seconds: r.retainedSeconds))
                ForEach(0..<r.rateLines.count, id: \.self) { i in
                    let line: PayRateLine = r.rateLines[i]
                    PLTRow(title: "Taux horaire brut \(PaieFormat.rateText(line.hourlyGross, settings: settings))",
                           subtitle: "\(Formatting.duration(seconds: line.seconds)) à ce taux",
                           value: amount(line.grossCents))
                }
                ForEach(0..<d.rules.lines.count, id: \.self) { i in
                    let line: PayRuleLine = d.rules.lines[i]
                    PLTRow(title: PaieRuleText.lineTitle(line, rules: ctx.rules),
                           subtitle: "\(Formatting.duration(seconds: line.seconds)) sur \(PaieFormat.rateText(line.hourlyGross, settings: settings)) de l'heure. Source : \(PaieRuleText.source(for: line, rules: ctx.rules))",
                           value: amount(line.majorationCents))
                }
                ForEach(0..<d.premiums.lines.count, id: \.self) { i in
                    let line: PremiumLine = d.premiums.lines[i]
                    PLTRow(title: line.name,
                           subtitle: "\(line.kind.title), \(line.quantityText). Saisie par toi, \(line.basis.title.lowercased()).",
                           value: amount(line.cents))
                }
                PLTRow(title: "Total brut estimé", value: amount(d.grossCents))
                PLTRow(title: "Net estimé",
                       subtitle: "Brut multiplié par le ratio \(PaieFormat.ratioText(PayPreferences.clampedRatio(netRatioStored))), plus les primes nettes. Indicatif",
                       value: amount(d.netCents),
                       showsSeparator: false)
            }
            ForEach(0..<d.premiums.notCounted.count, id: \.self) { i in
                Text("Prime non comptée, \(d.premiums.notCounted[i].name) : \(d.premiums.notCounted[i].reason)")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            if ctx.premiumsLoadFailed {
                PLTBanner(kind: .warning, title: "Primes illisibles",
                          message: "Je n'ai pas pu relire tes primes : elles ne sont pas comptées ici.")
            }
            Text(rulesFootnote(ctx, d))
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func rulesFootnote(_ ctx: PaieRulesContext, _ d: PayDetailResult) -> String {
        var text: String = "Estimation : heures x taux, plus les majorations de \"\(ctx.pack.name)\" et les primes que tu as saisies."
        var missing: [String] = []
        if ctx.rules.night == nil { missing.append("nuit") }
        if ctx.rules.sunday == nil { missing.append("dimanche") }
        if ctx.rules.publicHoliday == nil { missing.append("jours fériés") }
        if ctx.rules.overtime == nil { missing.append("heures au-delà du seuil") }
        if !missing.isEmpty {
            text += " Pas de règle renseignée pour : " + missing.joined(separator: ", ") + " (à renseigner)."
        }
        if ctx.pack.isUnverified { text += " Les valeurs du pack ne sont pas vérifiées." }
        text += " " + PaieRuleText.verifyHint
        return text
    }

    @ViewBuilder
    private func minimumRateSection(_ r: PayMonthResult, _ ctx: PaieRulesContext) -> some View {
        if let m = ctx.rules.minimumRate {
            let below: Bool = r.rateLines.contains(where: { (l: PayRateLine) -> Bool in
                PayRules.isBelowMinimum(hourlyGross: l.hourlyGross, rules: ctx.rules)
            })
            if below {
                PLTBanner(kind: .warning,
                          title: "Ton taux est sous le minimum de la convention",
                          message: "\(m.label) : \(PayExport.centsText(m.hourlyCents)) € brut par heure. Source : \(m.source) \(PaieRuleText.verifyHint)")
            }
        }
    }

    // MARK: Convention, primes, relevé

    private func conventionSection(_ contract: Contract, _ ctx: PaieRulesContext) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Convention, primes et relevé")
            PLTListGroup {
                if let employer = contract.employer {
                    NavigationLink {
                        PaieConventionView(employer: employer)
                    } label: {
                        PLTRow(symbol: "doc.text.magnifyingglass", tone: .accent,
                               title: "Ta convention",
                               subtitle: ctx.pack.name + (ctx.pack.isUnverified ? ". Valeurs à vérifier." : ""),
                               showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        PaiePrimesView(employer: employer)
                    } label: {
                        PLTRow(symbol: "gift", tone: .accent,
                               title: "Primes et indemnités",
                               subtitle: ctx.premiums.isEmpty ? "Aucune saisie" : PaieFormat.plural(ctx.premiums.count, "prime saisie par toi", "primes saisies par toi"),
                               showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    PLTRow(symbol: "briefcase", tone: .neutral,
                           title: "Ajoute un employeur à ton contrat",
                           subtitle: "La convention et les primes sont rattachées à l'employeur, dans Emploi.")
                }
                NavigationLink {
                    PaieReleveView(contract: contract)
                } label: {
                    PLTRow(symbol: "doc.text", tone: .accent,
                           title: "Relevé d'heures",
                           subtitle: "Jour par jour, avec nuit, dimanche et jours fériés. À partager en texte ou en CSV.",
                           showsChevron: true,
                           showsSeparator: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Prévu contre réel

    /// Créneaux prévus : vide tant que le planning n'existe pas (étape 7).
    private var plannedSlots: [PlannedSlot] { return [] }

    @ViewBuilder
    private func plannedSection(_ contract: Contract, _ r: PayMonthResult) -> some View {
        let planned: [PlannedSlot] = plannedSlots
        if !planned.isEmpty {
            let comps: DateComponents = calendar.dateComponents([.year, .month], from: monthStart)
            let rows: [PlannedDayComparison] = PayCalculator.plannedVersusReal(
                year: comps.year ?? 0, month: comps.month ?? 1, planned: planned,
                sessions: inputs(for: contract), base: settings.calculationBase, now: Date(), calendar: calendar)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Prévu contre réel")
                PLTListGroup {
                    ForEach(0..<rows.count, id: \.self) { i in
                        PLTRow(title: Formatting.dayTitle(rows[i].day, calendar: calendar),
                               subtitle: "Prévu \(Formatting.duration(seconds: rows[i].plannedSeconds)), réel \(Formatting.duration(seconds: rows[i].realSeconds))",
                               value: StatsAggregator.signedDuration(seconds: rows[i].differenceSeconds),
                               showsSeparator: i < rows.count - 1)
                    }
                }
            }
        }
    }

    // MARK: Taux

    private func ratesSection(_ contract: Contract) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Taux horaires")
            PLTListGroup {
                NavigationLink {
                    PaieTauxView(contractUID: contract.uid, contractStart: contract.startDate)
                } label: {
                    PLTRow(symbol: "chart.line.uptrend.xyaxis", tone: .accent,
                           title: "Historique des taux",
                           subtitle: "Chaque taux vaut à partir de sa date. Les mois passés ne changent pas.",
                           showsChevron: true,
                           showsSeparator: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Export

    private func exportSection(_ r: PayMonthResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Relevé du mois")
            if exportFailed {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: "Je n'ai pas réussi à préparer le fichier.")
            }
            PLTListGroup {
                if let url = csvURL {
                    ShareLink(item: url) {
                        PLTRow(symbol: "tablecells", tone: .accent,
                               title: "Exporter en CSV",
                               subtitle: "Un jour par ligne, ouvrable dans un tableur")
                    }
                    .buttonStyle(.plain)
                } else {
                    PLTRow(symbol: "tablecells", tone: .neutral, title: "Exporter en CSV", subtitle: "Le fichier n'est pas prêt")
                }
                if let url = jsonURL {
                    ShareLink(item: url) {
                        PLTRow(symbol: "curlybraces", tone: .accent,
                               title: "Exporter en JSON",
                               subtitle: "Toutes les valeurs du mois, lisibles par un autre outil",
                               showsSeparator: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    PLTRow(symbol: "curlybraces", tone: .neutral, title: "Exporter en JSON",
                           subtitle: "Le fichier n'est pas prêt", showsSeparator: false)
                }
            }
            Text("Le fichier dit que c'est une estimation. Ces deux exports ne contiennent pas les majorations ni les primes : pour ça, utilise le relevé d'heures. Le PDF n'est pas encore là. Rien n'est envoyé nulle part.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func prepareExports(_ r: PayMonthResult) {
        if !r.hasAnySession {
            jsonURL = nil
            csvURL = nil
            return
        }
        let doc: PayExportDocument = PayExport.makeDocument(result: r, currencyCode: settings.currencyCode,
                                                            exportedAt: Date(), calendar: calendar)
        do {
            jsonURL = try PayExport.writeJSONFile(doc)
            csvURL = try PayExport.writeCSVFile(doc)
            exportFailed = false
        } catch {
            jsonURL = nil
            csvURL = nil
            exportFailed = true
        }
    }

    // MARK: Sources

    private var smicValue: (hourlyGross: Decimal, isOverride: Bool) {
        return SmicReference.resolved(overrideValue: smicOverride > 0 ? smicOverride : nil)
    }

    private var sourcesSection: some View {
        let smic = smicValue
        let date: String = PaieFormat.longDate(SmicReference.effectiveDate(calendar: calendar), calendar: calendar)
        let staleHint: String = SmicReference.isOlderThanSixMonths(now: Date(), calendar: calendar)
            ? " Cette valeur date de plus de 6 mois : vérifie-la."
            : ""
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTListGroup {
                PLTRow(symbol: "checkmark.shield", tone: .neutral,
                       title: "Règles et taux utilisés",
                       subtitle: "SMIC de référence : \(PaieFormat.rateText(smic.hourlyGross, settings: settings)) brut par heure, valeur au \(date)\(smic.isOverride ? ", modifiée par toi" : ""). Pas vérifiée par l'app, à vérifier sur \(SmicReference.sourceName).\(staleHint)",
                       showsSeparator: false)
            }
        }
    }

    // MARK: Feuille "Comment c'est calculé"

    private var calcSheet: some View {
        let result: PayMonthResult? = selectedContract.map { computeResult(for: $0) }
        return NavigationStack {
            PLTScreen(title: "Comment c'est calculé") {
                Text("Les deux bases restent enregistrées en parallèle. Changer de base ne modifie jamais tes sessions. Le choix se fait dans Réglages.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                if let r = result {
                    PLTListGroup {
                        PLTRow(title: "Heures pleines",
                               subtitle: r.base == .fullHours ? "Base utilisée ici" : nil,
                               value: Formatting.duration(seconds: r.fullHoursSeconds))
                        PLTRow(title: "Exact",
                               subtitle: r.base == .exact ? "Base utilisée ici, à la minute près" : "À la minute près",
                               value: Formatting.duration(seconds: r.exactSeconds),
                               showsSeparator: false)
                    }
                }
                PLTCard {
                    Stepper(value: $netRatioStored, in: PayPreferences.minNetRatio...PayPreferences.maxNetRatio, step: 0.01) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Ratio net sur brut")
                                .font(.body)
                                .foregroundStyle(palette.textPrimary)
                            Text("Indicatif pour un salarié non cadre. Change-le d'après ta fiche de paie.")
                                .font(.footnote)
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    Text(PaieFormat.ratioText(PayPreferences.clampedRatio(netRatioStored)))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityLabel("Ratio \(PaieFormat.ratioText(PayPreferences.clampedRatio(netRatioStored)))")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showCalc = false }
                }
            }
        }
    }
}


/// Tuile "Brut estimé / Net estimé" du prototype : libellé en gras, gros montant, note.
private struct PaieEstimateTile: View {
    @Environment(\.palette) private var palette
    let label: String
    let value: String
    let note: String
    let tone: PLTTone

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
            Text(value)
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(note)
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
