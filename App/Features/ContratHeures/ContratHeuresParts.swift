import SwiftUI

/// Jauge de la semaine : réalisé (plein), prévu restant (pointillé), repère du quota (trait).
/// Prototype : design/prototype/src/screens/51_contrat.html (.ct-meter).
struct ContratMeterView: View {
    @Environment(\.palette) private var palette

    let doneMinutes: Int
    let plannedRemainingMinutes: Int
    let quotaMinutes: Int

    init(doneMinutes: Int, plannedRemainingMinutes: Int, quotaMinutes: Int) {
        self.doneMinutes = doneMinutes
        self.plannedRemainingMinutes = plannedRemainingMinutes
        self.quotaMinutes = quotaMinutes
    }

    private var scale: Double {
        let top: Int = max(quotaMinutes, doneMinutes + plannedRemainingMinutes, 1)
        return Double(top) * 1.2
    }

    private func fraction(_ minutes: Int) -> CGFloat {
        let f: Double = Double(max(0, minutes)) / scale
        return CGFloat(min(1.0, f))
    }

    var body: some View {
        GeometryReader { (geo: GeometryProxy) in
            let width: CGFloat = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.fill)
                    .frame(width: width, height: 12)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(palette.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: max(12, width * fraction(doneMinutes + plannedRemainingMinutes)), height: 12)
                    .opacity(doneMinutes + plannedRemainingMinutes > 0 ? 1 : 0)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.work)
                    .frame(width: max(0, width * fraction(doneMinutes)), height: 12)
                Rectangle()
                    .fill(palette.textPrimary)
                    .frame(width: 2, height: 20)
                    .offset(x: max(0, width * fraction(quotaMinutes) - 1))
            }
            .frame(width: width, height: 20, alignment: .leading)
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ContractHoursText.hours(quotaMinutes)) au contrat, \(ContractHoursText.hours(doneMinutes)) faites, \(ContractHoursText.hours(plannedRemainingMinutes)) prévues.")
    }
}

/// Légende commune des barres.
struct ContratLegendView: View {
    @Environment(\.palette) private var palette
    let showsQuota: Bool
    let quotaText: String

    init(showsQuota: Bool, quotaText: String) {
        self.showsQuota = showsQuota
        self.quotaText = quotaText
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            legendItem(fill: true, text: "Fait")
            legendItem(fill: false, text: "Prévu")
            if showsQuota {
                HStack(spacing: Theme.Spacing.xs) {
                    Rectangle()
                        .fill(palette.textPrimary)
                        .frame(width: 2, height: 14)
                    Text(quotaText)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func legendItem(fill: Bool, text: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            if fill {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.work)
                    .frame(width: 14, height: 10)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(palette.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 14, height: 10)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }
}

/// Barres jour par jour, prévu contre réalisé (106.2).
struct ContratDayBarsView: View {
    @Environment(\.palette) private var palette
    let week: WeekBalance

    private let letters: [String] = ["L", "M", "M", "J", "V", "S", "D"]
    private let names: [String] = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
    private let barAreaHeight: CGFloat = 84

    init(week: WeekBalance) {
        self.week = week
    }

    private var maxMinutes: Int {
        var m: Int = 480
        for v in week.dayDone { m = max(m, v) }
        for v in week.dayPlanned { m = max(m, v) }
        return m
    }

    private func height(_ minutes: Int) -> CGFloat {
        if minutes <= 0 { return 0 }
        return max(4, barAreaHeight * CGFloat(minutes) / CGFloat(maxMinutes))
    }

    private var summary: String {
        var parts: [String] = []
        for i in 0..<7 {
            let done: Int = week.dayDone[i]
            let plan: Int = week.dayPlanned[i]
            if done == 0 && plan == 0 { continue }
            var text: String = names[i]
            if done > 0 { text += " \(ContractHoursText.hours(done)) faites" }
            if done > 0 && plan > 0 { text += "," }
            if plan > 0 { text += " \(ContractHoursText.hours(plan)) prévues" }
            parts.append(text)
        }
        if parts.isEmpty { return "Aucune heure faite ni prévue cette semaine." }
        return "Heures par jour, prévu contre fait : " + parts.joined(separator: " ; ") + "."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                ForEach(0..<7, id: \.self) { (i: Int) in
                    VStack(spacing: Theme.Spacing.xs) {
                        HStack(alignment: .bottom, spacing: 3) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(palette.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                .frame(width: 12, height: height(week.dayPlanned[i]))
                                .opacity(week.dayPlanned[i] > 0 ? 1 : 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.work)
                                .frame(width: 12, height: height(week.dayDone[i]))
                                .opacity(week.dayDone[i] > 0 ? 1 : 0)
                        }
                        .frame(height: barAreaHeight, alignment: .bottom)
                        Text(valueText(i))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(height: 14)
                        Text(letters[i])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            ContratLegendView(showsQuota: false, quotaText: "")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private func valueText(_ i: Int) -> String {
        let v: Int = week.dayDone[i] > 0 ? week.dayDone[i] : week.dayPlanned[i]
        if v <= 0 { return " " }
        return ContractHoursText.shortHours(v)
    }
}

/// Historique des semaines finies : barres au-dessus (accent) ou au niveau du contrat et en dessous (neutre), trait du contrat.
struct ContratHistoryView: View {
    @Environment(\.palette) private var palette
    let weeks: [WeekBalance]
    let quotaMinutes: Int

    private let plotHeight: CGFloat = 100
    private let labelHeight: CGFloat = 16

    init(weeks: [WeekBalance], quotaMinutes: Int) {
        self.weeks = weeks
        self.quotaMinutes = quotaMinutes
    }

    private var scaleMinutes: Int {
        var m: Int = max(quotaMinutes, 60)
        for w in weeks { m = max(m, w.doneMinutes) }
        return m
    }

    private func barHeight(_ minutes: Int) -> CGFloat {
        return max(4, plotHeight * CGFloat(minutes) / CGFloat(scaleMinutes))
    }

    private var summary: String {
        let list: [String] = weeks.map { (w: WeekBalance) -> String in
            return ContractHoursText.shortHours(w.doneMinutes)
        }
        let first: String = weeks.first.map { (w: WeekBalance) -> String in "\(w.isoWeek)" } ?? ""
        let last: String = weeks.last.map { (w: WeekBalance) -> String in "\(w.isoWeek)" } ?? ""
        return "Heures faites par semaine, de la semaine \(first) à la \(last) : \(list.joined(separator: ", ")). Le contrat est de \(ContractHoursText.hours(quotaMinutes))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                    ForEach(weeks, id: \.weekStart) { (w: WeekBalance) in
                        VStack(spacing: 2) {
                            Text(ContractHoursText.shortHours(w.doneMinutes))
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(height: labelHeight)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(w.doneMinutes > w.quotaMinutes ? palette.work : palette.textTertiary)
                                .frame(height: barHeight(w.doneMinutes))
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                    }
                }
                Rectangle()
                    .fill(palette.textPrimary.opacity(0.7))
                    .frame(height: 1.5)
                    .offset(y: -(plotHeight * CGFloat(quotaMinutes) / CGFloat(scaleMinutes)))
            }
            .frame(height: plotHeight + labelHeight, alignment: .bottom)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(weeks, id: \.weekStart) { (w: WeekBalance) in
                    Text("\(w.isoWeek)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            Text("Numéro de semaine. Trait : tes \(ContractHoursText.hours(quotaMinutes)) au contrat.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }
}
