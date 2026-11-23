import SwiftUI
import SwiftData

/// Relevé d'heures d'un mois (section 20.2) : une ligne par jour avec les catégories, les totaux, partageable en texte ou en CSV.
/// C'est une estimation d'après tes sessions. Écran poussé depuis PaieView.
struct PaieReleveView: View {
    let contract: Contract

    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]

    @State private var monthStart: Date = PaieView.firstOfMonth(Date())
    @State private var csvURL: URL? = nil
    @State private var exportFailed: Bool = false

    private var calendar: Calendar { return Calendar.current }

    private var isCurrentMonth: Bool {
        return calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month)
    }

    private func buildStatement() -> HoursStatement {
        let ctx: PaieRulesContext = PaieRulesContext.load(employer: contract.employer)
        let comps: DateComponents = calendar.dateComponents([.year, .month], from: monthStart)
        return HoursStatementBuilder.build(year: comps.year ?? 0, month: comps.month ?? 1,
                                           sessions: PaieData.inputs(sessions: sessions, contract: contract),
                                           base: settings.calculationBase,
                                           rules: ctx.rules,
                                           employerName: contract.employer?.name ?? "",
                                           packName: ctx.pack.name,
                                           now: Date(), calendar: calendar)
    }

    var body: some View {
        let st: HoursStatement = buildStatement()
        let text: String = HoursStatementBuilder.text(st, calendar: calendar)
        let key: String = "\(st.year)-\(st.month)-\(st.totalSeconds)-\(st.days.count)-\(st.sessionCount)-\(settings.calculationBase.rawValue)"
        return PLTScreen(title: "Relevé d'heures") {
            PLTBanner(kind: .warning, title: "Estimation",
                      message: "Relevé d'après tes sessions et les règles choisies. Ta fiche de paie fait foi. " + PaieRuleText.verifyHint)
            monthNavigator
            if st.days.isEmpty {
                PLTCard {
                    PLTEmptyState(symbol: "clock",
                                  title: "Aucune session de taf ce mois-ci.",
                                  message: "Rien à relever pour \(PaieFormat.monthTitle(monthStart, calendar: calendar)).")
                }
            } else {
                flags(st)
                daysSection(st)
                totalsSection(st)
                shareSection(text)
            }
        }
        .task(id: key) {
            prepareCSV(st)
        }
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
        if let d = calendar.date(byAdding: .month, value: delta, to: monthStart) { monthStart = d }
    }

    @ViewBuilder
    private func flags(_ st: HoursStatement) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if st.doubtSessionCount > 0 {
                PLTBanner(kind: .warning,
                          title: PaieFormat.plural(st.doubtSessionCount, "session est dans la zone de doute", "sessions sont dans la zone de doute"),
                          message: "Son heure exacte est comptée en attendant ton choix.")
            }
            if st.liveSessionCount > 0 {
                PLTBanner(kind: .info, title: "Une session tourne", message: "Elle est comptée jusqu'à maintenant.")
            }
            if st.unconfirmedSessionCount > 0 {
                PLTBanner(kind: .info,
                          title: PaieFormat.plural(st.unconfirmedSessionCount, "session à confirmer n'est pas comptée", "sessions à confirmer ne sont pas comptées"),
                          message: "Confirme-les dans Sessions pour les compter.")
            }
        }
    }

    private func daysSection(_ st: HoursStatement) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Jour par jour")
            PLTListGroup {
                ForEach(0..<st.days.count, id: \.self) { i in
                    dayRow(st.days[i], showsSeparator: i < st.days.count - 1)
                }
            }
        }
    }

    private func dayRow(_ d: StatementDay, showsSeparator: Bool) -> some View {
        var lines: [String] = []
        for s in d.sessions {
            var text: String = Formatting.clock(s.exactStart, calendar: calendar) + " à "
            if let e = s.exactEnd { text += Formatting.clock(e, calendar: calendar) } else { text += "en cours" }
            if s.hasDoubt { text += ", borne à confirmer" }
            lines.append(text)
        }
        if lines.isEmpty { lines.append("Suite de la veille") }
        var cats: [String] = []
        for c in PayCategory.allCases where d.seconds(c) > 0 {
            cats.append(c.title + " " + Formatting.duration(seconds: d.seconds(c)))
        }
        if d.overtimeSeconds > 0 { cats.append("Au-delà du seuil " + Formatting.duration(seconds: d.overtimeSeconds)) }
        let subtitle: String = lines.joined(separator: " ; ") + ". " + cats.joined(separator: ", ")
        return PLTRow(title: Formatting.dayTitle(d.day, calendar: calendar),
                      subtitle: subtitle,
                      value: Formatting.duration(seconds: d.totalSeconds),
                      showsSeparator: showsSeparator)
    }

    private func totalsSection(_ st: HoursStatement) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Totaux du mois")
            PLTListGroup {
                PLTRow(symbol: "clock", tone: .work, title: "Total", subtitle: "Base : " + st.base.title,
                       value: Formatting.duration(seconds: st.totalSeconds))
                ForEach(0..<PayCategory.allCases.count, id: \.self) { i in
                    let c: PayCategory = PayCategory.allCases[i]
                    PLTRow(title: c.title, value: Formatting.duration(seconds: st.total(c)))
                }
                PLTRow(title: "Dont au-delà du seuil hebdomadaire",
                       subtitle: "Seuil de la convention ou le tien, semaines du lundi au dimanche",
                       value: Formatting.duration(seconds: st.overtimeSeconds),
                       showsSeparator: false)
            }
            Text("Règles : " + st.packName + ". Les heures de nuit, du dimanche et fériés ne sont séparées que si la règle est renseignée.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func shareSection(_ text: String) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Partager")
            if exportFailed {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: "Je n'ai pas réussi à préparer le fichier CSV.")
            }
            PLTListGroup {
                ShareLink(item: text) {
                    PLTRow(symbol: "text.alignleft", tone: .accent, title: "Partager en texte",
                           subtitle: "Pour un message ou un mail")
                }
                .buttonStyle(.plain)
                if let url = csvURL {
                    ShareLink(item: url) {
                        PLTRow(symbol: "tablecells", tone: .accent, title: "Partager en CSV",
                               subtitle: "Un jour par ligne, ouvrable dans un tableur", showsSeparator: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    PLTRow(symbol: "tablecells", tone: .neutral, title: "Partager en CSV",
                           subtitle: "Le fichier n'est pas prêt", showsSeparator: false)
                }
            }
            Text("Le fichier dit que c'est une estimation. Rien n'est envoyé nulle part. Le PDF n'est pas encore là.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func prepareCSV(_ st: HoursStatement) {
        if st.days.isEmpty {
            csvURL = nil
            return
        }
        let csv: String = "\u{FEFF}" + HoursStatementBuilder.csv(st, calendar: calendar)
        let month: String = PayExport.monthKey(year: st.year, month: st.month)
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalLifeTracker-releve-\(month).csv")
        do {
            try Data(csv.utf8).write(to: url, options: [.atomic])
            csvURL = url
            exportFailed = false
        } catch {
            csvURL = nil
            exportFailed = true
        }
    }
}
