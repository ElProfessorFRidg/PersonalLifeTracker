import SwiftUI
import SwiftData

/// Onglet Statistiques (prototype 60_stats.html) : totaux de taf et de cours sur une semaine ou un mois,
/// graphique jour par jour à l'échelle, base heures pleines ou exacte. Les calculs sont dans StatsAggregator.
struct StatsView: View {
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Environment(ModuleStore.self) private var modules
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]

    @State private var period: StatsPeriod = .week
    /// 0 = la période en cours, -1 = la précédente, etc.
    @State private var offset: Int = 0

    private var calendar: Calendar { return Calendar.current }

    private var inputs: [DaySessionInput] {
        var list: [DaySessionInput] = []
        for s in sessions where s.isConfirmed {
            list.append(DaySessionInput(id: s.uid, start: s.startDate, end: s.endDate, activity: s.activity,
                                        chosenStart: s.chosenStart, chosenEnd: s.chosenEnd))
        }
        return list
    }

    private var reference: Date {
        return StatsAggregator.shifted(reference: Date(), period: period, by: offset, calendar: calendar)
    }

    private var result: StatsResult {
        return StatsAggregator.aggregate(period: period, reference: reference, inputs: inputs,
                                         base: settings.calculationBase, now: Date(), calendar: calendar)
    }

    private var previousResult: StatsResult {
        let before: Date = StatsAggregator.shifted(reference: reference, period: period, by: -1, calendar: calendar)
        return StatsAggregator.aggregate(period: period, reference: before, inputs: inputs,
                                         base: settings.calculationBase, now: Date(), calendar: calendar)
    }

    private var baseBinding: Binding<CalculationBase> {
        return Binding<CalculationBase>(get: { settings.calculationBase }, set: { settings.calculationBase = $0 })
    }

    private var periodBinding: Binding<StatsPeriod> {
        return Binding<StatsPeriod>(get: { period }, set: { newValue in
            period = newValue
            offset = 0
        })
    }

    private var unconfirmedCount: Int {
        let r: StatsResult = result
        var n: Int = 0
        for s in sessions where !s.isConfirmed {
            let end: Date = s.endDate ?? Date()
            if s.startDate < r.end && end > r.start { n += 1 }
        }
        return n
    }

    var body: some View {
        let current: StatsResult = result
        return PLTScreen(title: "Statistiques", hidesNavigationBar: true) {
            PLTRootHeader(eyebrow: periodTitle, title: "Statistiques") {
                NavigationLink {
                    ReglagesView()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(palette.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réglages")
            }
            controls
            if current.isEmpty {
                emptySection
            } else {
                totalsSection(current)
                chartSection(current)
                averagesSection(current)
                evolutionSection(current)
            }
            footerSection
        }
    }

    // MARK: Contrôles

    private var controls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Picker("Période", selection: periodBinding) {
                ForEach(StatsPeriod.allCases) { p in
                    Text(p.title).tag(p)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    offset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(period == .week ? "Semaine précédente" : "Mois précédent")
                Spacer(minLength: Theme.Spacing.s)
                Text(periodTitle)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Theme.Spacing.s)
                Button {
                    offset += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .disabled(offset >= 0)
                .accessibilityLabel(period == .week ? "Semaine suivante" : "Mois suivant")
            }

            Text("Base de calcul")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
            Picker("Base de calcul", selection: baseBinding) {
                ForEach(CalculationBase.allCases) { b in
                    Text(b.title).tag(b)
                }
            }
            .pickerStyle(.segmented)
            Text(settings.calculationBase == .fullHours
                 ? "Heures pleines : 17:56 compte comme 18:00. Ton heure exacte reste toujours gardée."
                 : "Heure exacte : 17:56 compte comme 17:56, à la minute près.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var periodTitle: String {
        let r: (start: Date, end: Date) = StatsAggregator.range(period: period, reference: reference, calendar: calendar)
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        switch period {
        case .month:
            f.dateFormat = "LLLL yyyy"
            let text: String = f.string(from: r.start)
            return text.prefix(1).uppercased() + String(text.dropFirst())
        case .week:
            let last: Date = calendar.date(byAdding: .day, value: -1, to: r.end) ?? r.end
            let sameMonth: Bool = calendar.component(.month, from: r.start) == calendar.component(.month, from: last)
            if sameMonth {
                f.dateFormat = "d"
                let a: String = f.string(from: r.start)
                f.dateFormat = "d MMMM"
                return "Du \(a) au \(f.string(from: last))"
            }
            f.dateFormat = "d MMM"
            return "Du \(f.string(from: r.start)) au \(f.string(from: last))"
        }
    }

    // MARK: Vide

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTCard {
                PLTEmptyState(symbol: "chart.bar",
                              title: "Rien à compter sur cette période.",
                              message: "Dès une session de taf ou de cours, tes heures apparaissent ici. Pas besoin de remplir quoi que ce soit.")
            }
            Text("Je ne dessine aucun graphique sans vraies données. Pas de faux zéros.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Totaux

    private func note(exact: Int, retained: Int) -> String {
        if settings.calculationBase == .fullHours {
            return "Heures pleines, exact \(Formatting.duration(seconds: exact))"
        }
        return "Heure exacte"
    }

    private func totalsSection(_ r: StatsResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Totaux")
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                StatTile(label: "Taf", value: Formatting.duration(seconds: r.workSeconds),
                         note: note(exact: r.workExactSeconds, retained: r.workSeconds), tone: .work)
                StatTile(label: "Cours", value: Formatting.duration(seconds: r.studySeconds),
                         note: note(exact: r.studyExactSeconds, retained: r.studySeconds), tone: .study)
            }
            if r.hasLive || offset == 0 {
                PLTBanner(kind: .info,
                          title: offset == 0 ? "Cette période n'est pas finie" : "Une session tourne",
                          message: "Le total bouge jusqu'à la fin de tes sessions en cours.")
            }
            if r.hasProvisional {
                PLTBanner(kind: .warning,
                          title: "Une heure est à confirmer",
                          message: "Une session a un début ou une fin dans la zone de doute. Son heure exacte est comptée en attendant ton choix.")
            }
        }
    }

    // MARK: Graphique

    private func chartSection(_ r: StatsResult) -> some View {
        let axis: Int = StatsAggregator.axisHours(maxDaySeconds: r.maxDaySeconds)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Jour par jour")
            PLTCard {
                StatsBarChart(days: r.days, axisHours: axis, isMonth: period == .month, calendar: calendar, now: Date())
                HStack(spacing: Theme.Spacing.m) {
                    legendItem(color: palette.work, text: "Taf")
                    legendItem(color: palette.study, text: "Cours")
                }
                .accessibilityHidden(true)
                Text("Chaque barre est à l'échelle, de 0 à \(axis) h. Une barre vide dans un contour est une session en cours.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Moyennes et évolution

    private func averagesSection(_ r: StatsResult) -> some View {
        let workAvg: Int = StatsAggregator.averagePerActiveDay(totalSeconds: r.workSeconds, activeDays: r.workDayCount)
        let studyAvg: Int = StatsAggregator.averagePerActiveDay(totalSeconds: r.studySeconds, activeDays: r.studyDayCount)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Moyennes")
            PLTListGroup {
                PLTRow(symbol: ActivityType.work.symbolName, tone: .work,
                       title: "Taf, moyenne par jour",
                       subtitle: "\(r.workDayCount) jours avec une session",
                       value: r.workDayCount == 0 ? "0 h" : Formatting.duration(seconds: workAvg))
                PLTRow(symbol: ActivityType.education.symbolName, tone: .study,
                       title: "Cours, moyenne par jour",
                       subtitle: "\(r.studyDayCount) jours avec une session",
                       value: r.studyDayCount == 0 ? "0 h" : Formatting.duration(seconds: studyAvg),
                       showsSeparator: false)
            }
            Text("Les jours sans session ne tirent pas la moyenne vers le bas.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func evolutionSection(_ r: StatsResult) -> some View {
        let prev: StatsResult = previousResult
        let what: String = period == .week ? "la semaine d'avant" : "le mois d'avant"
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Évolution")
            PLTListGroup {
                PLTRow(symbol: ActivityType.work.symbolName, tone: .work,
                       title: "Taf",
                       subtitle: "Par rapport à \(what)",
                       value: StatsAggregator.signedDuration(seconds: r.workSeconds - prev.workSeconds))
                PLTRow(symbol: ActivityType.education.symbolName, tone: .study,
                       title: "Cours",
                       subtitle: "Par rapport à \(what)",
                       value: StatsAggregator.signedDuration(seconds: r.studySeconds - prev.studySeconds),
                       showsSeparator: false)
            }
        }
    }

    /// Texte partageable de la période affichée (module share_summary).
    private var shareText: String {
        return HoursSummaryText.build(period: period, reference: reference, inputs: inputs,
                                      base: settings.calculationBase, now: Date(), calendar: calendar)
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if modules.isActive("share_summary") {
                ShareLink(item: shareText) {
                    Label("Partager mes heures", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel("Partager mes heures")
            }
            if unconfirmedCount > 0 {
                PLTBanner(kind: .info,
                          title: unconfirmedCount == 1 ? "1 session à confirmer n'est pas comptée" : "\(unconfirmedCount) sessions à confirmer ne sont pas comptées",
                          message: "Elles entrent dans les totaux dès que tu les confirmes.")
            }
            Text("Les courses, les trajets et le reste ne sont pas comptés dans ces totaux.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }
}

/// Barres empilées taf (bas) et cours (haut), à l'échelle de l'axe. Dessiné avec des formes SwiftUI.
struct StatsBarChart: View {
    @Environment(\.palette) private var palette

    let days: [StatsDay]
    let axisHours: Int
    let isMonth: Bool
    let calendar: Calendar
    let now: Date

    private let plotHeight: CGFloat = 150
    private let axisWidth: CGFloat = 34

    private var gap: CGFloat { return isMonth ? 2 : 6 }

    private var tickHours: [Int] {
        let step: Int = axisHours <= 10 ? 2 : 4
        var list: [Int] = []
        var h: Int = 0
        while h <= axisHours {
            list.append(h)
            h += step
        }
        return list
    }

    private static let weekdayNames: [String] = ["lun", "mar", "mer", "jeu", "ven", "sam", "dim"]

    private func weekdayName(_ day: Date) -> String {
        let weekday: Int = calendar.component(.weekday, from: day)
        return StatsBarChart.weekdayNames[(weekday + 5) % 7]
    }

    private func dayNumber(_ day: Date) -> Int {
        return calendar.component(.day, from: day)
    }

    private func isToday(_ day: Date) -> Bool {
        return calendar.isDate(day, inSameDayAs: now)
    }

    private func compactValue(_ seconds: Int) -> String {
        if seconds <= 0 { return "0" }
        return Formatting.duration(seconds: seconds).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            axisColumn
            VStack(spacing: Theme.Spacing.xs) {
                plot
                labels
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heures par jour. " + StatsAggregator.accessibilitySummary(days: days, calendar: calendar))
    }

    private var axisColumn: some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(tickHours, id: \.self) { h in
                Text("\(h) h")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
                    .offset(y: tickOffset(h) + 6)
            }
        }
        .frame(width: axisWidth, height: plotHeight, alignment: .bottomTrailing)
    }

    /// Décalage vertical (négatif vers le haut) d'une graduation depuis le bas du graphique.
    private func tickOffset(_ hour: Int) -> CGFloat {
        let fraction: Double = axisHours > 0 ? Double(hour) / Double(axisHours) : 0
        return -CGFloat(fraction) * plotHeight
    }

    private var plot: some View {
        ZStack(alignment: .bottom) {
            ForEach(tickHours, id: \.self) { h in
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 1)
                    .offset(y: tickOffset(h))
            }
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<days.count, id: \.self) { i in
                    column(days[i])
                }
            }
        }
        .frame(height: plotHeight)
    }

    private func barHeight(_ seconds: Int) -> CGFloat {
        if seconds <= 0 { return 0 }
        let h: CGFloat = CGFloat(StatsAggregator.barFraction(seconds: seconds, axisHours: axisHours)) * plotHeight
        return max(3, h)
    }

    private func column(_ day: StatsDay) -> some View {
        VStack(spacing: 1) {
            Spacer(minLength: 0)
            bar(height: barHeight(day.studySeconds), color: palette.study, soft: palette.studySoft, live: day.studyHasLive)
            bar(height: barHeight(day.workSeconds), color: palette.work, soft: palette.workSoft, live: day.workHasLive)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func bar(height: CGFloat, color: Color, soft: Color, live: Bool) -> some View {
        if height > 0 {
            if live {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(soft)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(color, lineWidth: 1.5))
                    .frame(maxWidth: 18)
                    .frame(height: height)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(maxWidth: 18)
                    .frame(height: height)
            }
        }
    }

    private var labels: some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(0..<days.count, id: \.self) { i in
                labelColumn(days[i], index: i)
            }
        }
    }

    private func labelColumn(_ day: StatsDay, index: Int) -> some View {
        let number: Int = dayNumber(day.day)
        let showNumber: Bool = !isMonth || number % 2 == 1 || isToday(day.day)
        return VStack(spacing: 2) {
            if !isMonth {
                Text(weekdayName(day.day))
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
            }
            Text(showNumber ? "\(number)" : " ")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(isToday(day.day) ? palette.accent : palette.textPrimary)
            if !isMonth {
                Text(compactValue(day.workSeconds))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(day.workSeconds > 0 ? palette.work : palette.textTertiary)
                Text(compactValue(day.studySeconds))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(day.studySeconds > 0 ? palette.study : palette.textTertiary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
    }
}
