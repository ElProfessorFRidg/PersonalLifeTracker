import SwiftUI
import SwiftData

/// Mon contrat : équilibrage des heures (module contract_hours, sections 106 et 109).
/// Poussé depuis Emploi, sans argument. Prototype : design/prototype/src/screens/51_contrat.html.
/// L'écran informe, il ne dit jamais un droit : classement des heures et repos compensateur sont à vérifier.
struct ContratHeuresView: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Query(sort: \Employer.createdAt) private var employers: [Employer]

    @State private var selectedUID: UUID? = nil

    private var calendar: Calendar { return Calendar.current }

    var body: some View {
        PLTScreen(title: "Mon contrat") {
            if modules.isActive("contract_hours") && modules.isActive("employment") {
                activeContent
            } else {
                disabledContent
            }
        }
    }

    // MARK: Module désactivé

    @ViewBuilder
    private var disabledContent: some View {
        PLTCard {
            PLTEmptyState(symbol: "clock",
                          title: "Les heures du contrat, c'est optionnel.",
                          message: "Tant que ce module est éteint, tes heures sont suivies comme d'habitude, sans les comparer à ton contrat. Rien ne manque.",
                          actionTitle: "Activer les heures du contrat",
                          action: { modules.setEnabled("contract_hours", true) })
        }
    }

    // MARK: Module activé

    private func relevantContract(of employer: Employer) -> Contract? {
        let list: [Contract] = employer.contracts.sorted { (a: Contract, b: Contract) -> Bool in
            return a.startDate > b.startDate
        }
        let spans: [ContractSpan] = list.map { (c: Contract) -> ContractSpan in
            return ContractSpan(id: c.uid, start: c.startDate, end: c.endDate)
        }
        if let index = ContractRules.activeIndex(in: spans, at: Date(), calendar: calendar) {
            return list[index]
        }
        return list.first
    }

    private var candidates: [Employer] {
        return employers.filter { (e: Employer) -> Bool in
            return relevantContract(of: e) != nil
        }
    }

    private var resolved: Employer? {
        let list: [Employer] = candidates
        if let uid = selectedUID, let match = list.first(where: { (e: Employer) -> Bool in e.uid == uid }) {
            return match
        }
        return list.first
    }

    @ViewBuilder
    private var activeContent: some View {
        if let employer = resolved, let contract = relevantContract(of: employer) {
            if candidates.count > 1 {
                employerPicker
            }
            ContractHoursBody(employer: employer, contract: contract)
                .id(employer.uid)
        } else {
            noContractContent
        }
    }

    private var employerPicker: some View {
        let list: [Employer] = candidates
        let binding: Binding<UUID?> = Binding<UUID?>(
            get: { return resolved?.uid },
            set: { (v: UUID?) in selectedUID = v }
        )
        return PLTCard {
            Picker("Employeur", selection: binding) {
                ForEach(list) { (e: Employer) in
                    Text(e.name).tag(Optional<UUID>(e.uid))
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var noContractContent: some View {
        PLTCard {
            PLTEmptyState(symbol: "doc.text",
                          title: "Pas encore de contrat.",
                          message: "Ajoute ton employeur et ton contrat avec ses heures par semaine, et je compare ce que tu fais à ce qui est prévu. C'est facultatif.")
        }
        NavigationLink {
            EmploiView()
        } label: {
            Text("Aller dans Emploi")
        }
        .buttonStyle(.pltSecondary)
    }
}

// MARK: - Contenu pour un contrat

private struct ContractHoursBody: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]

    let employer: Employer
    let contract: Contract

    @State private var now: Date = Date()
    @State private var sheet: ContratHeuresSheet? = nil
    @State private var rule: HoursCarryRule = .unknown
    @State private var alertOn: Bool = false
    @State private var thresholdsOn: Set<Int> = []

    init(employer: Employer, contract: Contract) {
        self.employer = employer
        self.contract = contract
    }

    private var calendar: Calendar { return Calendar.current }

    private var weeklyMinutes: Int {
        return Int((contract.weeklyHours * 60.0).rounded())
    }

    // MARK: Calcul

    private func input(_ s: WorkSession) -> HoursSessionInput {
        let end: Date? = s.endDate
        var minutes: Int? = nil
        if end == nil {
            // Session en cours : comptée à l'exact jusqu'à maintenant (comme la carte du jour).
            minutes = s.exactSeconds(now: now) / 60
        } else {
            switch settings.calculationBase {
            case .fullHours:
                minutes = s.normalizedMinutes(now: now)
            case .exact:
                minutes = s.exactSeconds(now: now) / 60
            }
        }
        return HoursSessionInput(start: s.startDate, end: end, minutes: minutes, isConfirmed: s.isConfirmed)
    }

    private var report: ContractHoursReport {
        let inputs: [HoursSessionInput] = sessions
            .filter { (s: WorkSession) -> Bool in s.activity == .work }
            .map { (s: WorkSession) -> HoursSessionInput in input(s) }
        let c: HoursContractInput = HoursContractInput(weeklyMinutes: weeklyMinutes, start: contract.startDate, end: contract.endDate)
        let noShifts: [HoursPlannedShift] = []
        return ContractHoursBalance.report(contract: c, sessions: inputs, planned: noShifts,
                                           today: now, rule: rule, calendar: calendar)
    }

    private var activeThresholds: [Int] {
        if !alertOn { return [] }
        return Array(thresholdsOn).sorted()
    }

    private func reload() {
        rule = ContratHeuresSettings.rule(for: employer.uid)
        alertOn = ContratHeuresSettings.alertEnabled(for: employer.uid)
        var set: Set<Int> = []
        for m in ContratHeuresSettings.thresholdChoices {
            if ContratHeuresSettings.isThresholdOn(m, for: employer.uid) {
                set.insert(m)
            }
        }
        thresholdsOn = set
    }

    // MARK: Corps

    var body: some View {
        let rep: ContractHoursReport = report
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if weeklyMinutes <= 0 {
                noQuotaCard
            } else if rep.state == .notStarted {
                notStartedCard
            } else {
                mainContent(rep)
            }
        }
        .sheet(item: $sheet) { (s: ContratHeuresSheet) in
            sheetView(s, rep)
        }
        .onAppear {
            now = Date()
            reload()
        }
    }

    @ViewBuilder
    private func mainContent(_ rep: ContractHoursReport) -> some View {
        alertBanner(rep)
        if let w = rep.current {
            weekSection(w)
            daysSection(w)
        } else if rep.state == .ended {
            endedCard
        }
        optionsSection(rep)
        countersSection(rep)
        historySection(rep)
        footer
    }

    // MARK: États sans calcul

    private var noQuotaCard: some View {
        PLTCard {
            PLTEmptyState(symbol: "clock",
                          title: "Pas d'heures par semaine sur ce contrat.",
                          message: "Sans quota renseigné, je n'ai rien à comparer. Ajoute les heures par semaine dans Emploi, ou laisse comme ça si tes heures sont variables.")
        }
    }

    private var notStartedCard: some View {
        PLTCard {
            PLTEmptyState(symbol: "calendar",
                          title: "Ton contrat n'a pas encore commencé.",
                          message: "Il commence le \(EmploiFormat.date(contract.startDate)). Je commence à compter ce jour-là.")
        }
    }

    private var endedCard: some View {
        PLTCard {
            Text("Ton contrat est terminé")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text("Il s'est arrêté le \(EmploiFormat.date(contract.endDate ?? now)). Son historique reste là, il n'y a plus de semaine en cours.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Alerte (109)

    @ViewBuilder
    private func alertBanner(_ rep: ContractHoursReport) -> some View {
        if let w = rep.current {
            let level: QuotaAlertLevel = ContractHoursBalance.quotaAlert(doneMinutes: w.doneMinutes,
                                                                         limitMinutes: w.quotaMinutes,
                                                                         thresholdsMinutes: activeThresholds,
                                                                         suppressed: false)
            if level != .off {
                PLTBanner(kind: .info,
                          title: ContractHoursText.alertTitle(level),
                          message: "Je te le dis pour que tu choisisses en connaissance de cause. Rien d'autre à faire.",
                          actionTitle: "Régler cette alerte",
                          action: { sheet = .alert })
            }
        }
    }

    // MARK: Ta semaine (106.2)

    private func chipKind(_ status: WeekStatus) -> PLTChipKind {
        switch status {
        case .inContract: return .work
        case .inProgress: return .neutral
        case .under: return .doubt
        case .over: return .doubt
        case .toConfirm: return .doubt
        }
    }

    private func rangeText(_ w: WeekBalance) -> String {
        let last: Date = ContractHoursBalance.addDays(6, to: w.weekStart, calendar: calendar)
        return "\(EmploiFormat.shortDate(w.weekStart)) au \(EmploiFormat.shortDate(last))"
    }

    private func weekNote(_ w: WeekBalance) -> String {
        var parts: [String] = []
        switch settings.calculationBase {
        case .fullHours:
            parts.append("Calculé sur les heures pleines, ta base actuelle.")
        case .exact:
            parts.append("Calculé sur les heures exactes, ta base actuelle.")
        }
        parts.append("Sessions en cours incluses.")
        if w.pendingCount > 0 {
            let plural: String = w.pendingCount > 1 ? "s" : ""
            parts.append("\(w.pendingCount) session\(plural) à confirmer, pas encore dans le total.")
        }
        if w.plannedRemainingMinutes == 0 {
            parts.append("Je ne lis pas encore ton planning : la projection, c'est ce que tu as fait.")
        }
        if w.isPartial {
            parts.append("Semaine de début ou de fin de contrat : ton quota est proratisé au nombre de jours couverts (\(ContractHoursText.hours(w.quotaMinutes))). À vérifier avec ton contrat.")
        }
        return parts.joined(separator: " ")
    }

    private func weekSection(_ w: WeekBalance) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                PLTSectionHeader(title: "Ta semaine")
                Spacer(minLength: Theme.Spacing.s)
                Text(rangeText(w))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
            PLTCard {
                HStack(spacing: Theme.Spacing.s) {
                    PLTChip(ContractHoursText.statusTitle(w.status), kind: chipKind(w.status))
                    if w.isPartial {
                        PLTChip("Semaine partielle")
                    }
                }
                Text(ContractHoursText.headline(w))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                ContratMeterView(doneMinutes: w.doneMinutes,
                                 plannedRemainingMinutes: w.plannedRemainingMinutes,
                                 quotaMinutes: w.quotaMinutes)
                ContratLegendView(showsQuota: true, quotaText: "Contrat \(ContractHoursText.hours(w.quotaMinutes))")
                LazyVGrid(columns: statColumns, spacing: Theme.Spacing.s) {
                    StatTile(label: "Au contrat", value: ContractHoursText.hours(w.quotaMinutes))
                    StatTile(label: "Fait", value: ContractHoursText.hours(w.doneMinutes), tone: .work)
                    StatTile(label: "Encore prévu", value: ContractHoursText.hours(w.plannedRemainingMinutes))
                    StatTile(label: "Projection", value: ContractHoursText.hours(w.projectedMinutes))
                }
                Text(weekNote(w))
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var statColumns: [GridItem] {
        return [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)]
    }

    private func daysSection(_ w: WeekBalance) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Jour par jour")
            PLTCard {
                ContratDayBarsView(week: w)
            }
        }
    }

    // MARK: Ce que je propose (106.3, 106.4, 106.7)

    private func ruleShortTitle(_ r: HoursCarryRule) -> String {
        switch r {
        case .unknown: return "À renseigner"
        case .carried: return "Reporté"
        case .smoothedMonth: return "Lissé"
        case .paid: return "Payé en plus"
        case .notCarried: return "Non reporté"
        }
    }

    @ViewBuilder
    private func suggestionRow(_ s: HoursSuggestion, _ w: WeekBalance) -> some View {
        switch s {
        case .nothingToChange:
            PLTRow(symbol: "checkmark.circle",
                   title: "Rien à changer",
                   subtitle: w.plannedRemainingMinutes == 0
                       ? "Tu as atteint ton contrat. Je recalcule à chaque changement."
                       : "Si ton planning tient, tu atteins ton contrat sans dépasser. Je recalcule à chaque changement.")
        case .explainOver(let minutes):
            PLTRow(symbol: "info.circle",
                   title: "Comment ces \(ContractHoursText.hours(minutes)) sont comptées",
                   subtitle: "Heures complémentaires ou autre, selon ton contrat. À vérifier.",
                   showsChevron: true,
                   action: { sheet = .classification })
        case .placeMissing(let minutes, _):
            PLTRow(symbol: "calendar",
                   title: w.status == .inProgress
                       ? "Répartir les \(ContractHoursText.hours(minutes)) qui restent"
                       : "Où placer les \(ContractHoursText.hours(minutes)) manquantes",
                   subtitle: "Les jours qu'il te reste",
                   showsChevron: true,
                   action: { sheet = .placement })
        }
    }

    private func optionsSection(_ rep: ContractHoursReport) -> some View {
        let suggestions: [HoursSuggestion] = rep.current.map { (w: WeekBalance) -> [HoursSuggestion] in
            return ContractHoursBalance.suggestions(for: w)
        } ?? []
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que je te propose")
            PLTListGroup {
                if let w = rep.current, let first = suggestions.first {
                    suggestionRow(first, w)
                }
                PLTRow(symbol: "slider.horizontal.3",
                       tone: .neutral,
                       title: "Quand ça ne tombe pas pile",
                       subtitle: "Reporté, lissé ou payé en plus",
                       value: ruleShortTitle(rule),
                       showsChevron: true,
                       action: { sheet = .rule })
                PLTRow(symbol: "bell",
                       tone: .neutral,
                       title: "Alerte de quota",
                       subtitle: "Un message quand tu approches de tes heures",
                       value: alertOn ? "Allumée" : "Éteinte",
                       showsChevron: true,
                       showsSeparator: false,
                       action: { sheet = .alert })
            }
            Text("Je t'informe et je te propose des options. C'est toi qui décides, et je ne te propose jamais de contourner ton contrat.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Compteurs (106.4)

    private func countersSection(_ rep: ContractHoursReport) -> some View {
        let c: HoursCounters = rep.counters
        let unknown: Bool = rule == .unknown
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Tes compteurs")
            PLTListGroup {
                PLTRow(symbol: "plus.circle",
                       tone: .neutral,
                       title: "Heures d'avance",
                       subtitle: unknown
                           ? "Je ne sais pas encore ce qui est reporté : à renseigner, sinon je ne reporte rien."
                           : "Heures faites au-delà du contrat et gardées d'avance",
                       value: ContractHoursText.hours(c.advanceMinutes))
                PLTRow(symbol: "minus.circle",
                       tone: .neutral,
                       title: "Heures à rattraper",
                       subtitle: unknown
                           ? "Même chose : à renseigner."
                           : "Heures en moins par rapport au contrat",
                       value: ContractHoursText.hours(c.catchUpMinutes))
                if rule == .paid {
                    PLTRow(symbol: "eurosign.circle",
                           tone: .neutral,
                           title: "Heures en plus ce mois-ci",
                           subtitle: "Celles que tu m'as dit voir payées en plus. Ta fiche de paie fait foi.",
                           value: ContractHoursText.hours(c.paidExtraMinutes))
                }
                PLTRow(symbol: "bed.double",
                       tone: .neutral,
                       title: "Repos compensateur",
                       subtitle: "Ta convention n'est pas encore lue par l'app. À renseigner si ça te concerne, et à vérifier avec ton employeur.",
                       value: "À renseigner",
                       showsSeparator: false)
            }
            if c.weeksSkippedPending > 0 {
                let plural: String = c.weeksSkippedPending > 1 ? "s" : ""
                Text("\(c.weeksSkippedPending) semaine\(plural) laissée\(plural) de côté : des sessions y sont à confirmer.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: Historique (106.6)

    private func deltaText(_ w: WeekBalance) -> String {
        if w.status == .toConfirm { return "À confirmer" }
        let d: Int = w.doneMinutes - w.quotaMinutes
        if d == 0 { return "Pile" }
        if d > 0 { return "+\(ContractHoursText.hours(d))" }
        return "-\(ContractHoursText.hours(-d))"
    }

    private func historySection(_ rep: ContractHoursReport) -> some View {
        let finished: [WeekBalance] = Array(rep.weeks.filter { (w: WeekBalance) -> Bool in w.isComplete }.suffix(8))
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Tes dernières semaines")
            if finished.isEmpty {
                PLTCard {
                    Text("Pas encore de semaine terminée. L'historique apparaît dès la première.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTCard {
                    ContratHistoryView(weeks: finished, quotaMinutes: weeklyMinutes)
                    if let d = rep.distribution {
                        LazyVGrid(columns: statColumns, spacing: Theme.Spacing.s) {
                            StatTile(label: "Moyenne", value: ContractHoursText.hours(d.averageMinutes))
                            StatTile(label: "Min et max",
                                     value: "\(ContractHoursText.shortHours(d.minMinutes)) à \(ContractHoursText.hours(d.maxMinutes))")
                        }
                        Text(ContractHoursText.distributionSentence(d, quotaMinutes: weeklyMinutes))
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    if finished.contains(where: { (w: WeekBalance) -> Bool in w.isPartial }) {
                        Text("Les semaines de début ou de fin de contrat ne sont pas dans la moyenne.")
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                PLTListGroup {
                    ForEach(Array(finished.reversed()), id: \.weekStart) { (w: WeekBalance) in
                        PLTRow(title: "Semaine \(w.isoWeek), \(rangeText(w))",
                               subtitle: "\(ContractHoursText.hours(w.doneMinutes)) faites sur \(ContractHoursText.hours(w.quotaMinutes))",
                               value: deltaText(w),
                               showsSeparator: w.weekStart != finished.first?.weekStart)
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text("Les heures complémentaires, les heures supplémentaires et le repos compensateur dépendent de ton contrat et de ta convention : je ne les tranche pas, vérifie avec ton contrat ou ton employeur. Je compte toutes tes sessions de travail, sans distinguer l'employeur.")
            .font(.footnote)
            .foregroundStyle(palette.textSecondary)
    }

    // MARK: Feuilles

    private func thresholdBinding(_ minutes: Int) -> Binding<Bool> {
        return Binding<Bool>(
            get: { return thresholdsOn.contains(minutes) },
            set: { (on: Bool) in
                if on {
                    thresholdsOn.insert(minutes)
                } else {
                    thresholdsOn.remove(minutes)
                }
                ContratHeuresSettings.setThreshold(minutes, on: on, for: employer.uid)
            }
        )
    }

    private var alertBinding: Binding<Bool> {
        return Binding<Bool>(
            get: { return alertOn },
            set: { (on: Bool) in
                alertOn = on
                ContratHeuresSettings.setAlertEnabled(on, for: employer.uid)
            }
        )
    }

    @ViewBuilder
    private func sheetView(_ s: ContratHeuresSheet, _ rep: ContractHoursReport) -> some View {
        switch s {
        case .rule:
            ContratRegleSheet(selection: rule, onSelect: { (r: HoursCarryRule) in
                rule = r
                ContratHeuresSettings.setRule(r, for: employer.uid)
            })
        case .classification:
            ContratClassementSheet(overMinutes: max(0, rep.current?.deltaMinutes ?? 0), quotaMinutes: weeklyMinutes)
        case .placement:
            ContratRepartirSheet(missingMinutes: max(0, -(rep.current?.deltaMinutes ?? 0)),
                                 days: rep.current?.remainingDays ?? 0,
                                 quotaMinutes: weeklyMinutes,
                                 projectedMinutes: rep.current?.projectedMinutes ?? 0)
        case .alert:
            ContratAlerteSheet(enabled: alertBinding,
                               threshold2h: thresholdBinding(120),
                               threshold1h: thresholdBinding(60),
                               thresholdReached: thresholdBinding(0))
        }
    }
}
