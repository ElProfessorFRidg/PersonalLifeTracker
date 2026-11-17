import SwiftUI
import SwiftData

/// Onglet Accueil (écran `accueil`) : carte Maintenant, session en cours, chiffres du jour, ruban et sessions du jour.
/// Garde le bouton Réglages de la barre d'outils.
struct AccueilView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]

    @State private var showStart: Bool = false
    @State private var showAdd: Bool = false
    @State private var showStopConfirm: Bool = false
    @State private var doubtSession: WorkSession?
    @State private var errorMessage: String?

    var body: some View {
        let hasRunning: Bool = sessions.contains { $0.endDate == nil }
        let interval: TimeInterval = hasRunning ? 1 : 30
        return PLTScreen(title: "Accueil") {
            TimelineView(.periodic(from: Date(), by: interval)) { timeline in
                content(now: timeline.date)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Ajouter")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ReglagesView()
                } label: {
                    Image(systemName: "gearshape")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Réglages")
            }
        }
        .sheet(isPresented: $showStart) {
            DemarrerSheet()
        }
        .sheet(isPresented: $showAdd) {
            SessionAjoutView()
        }
        .sheet(item: $doubtSession) { session in
            DouteView(session: session)
        }
        .confirmationDialog("Arrêter la session ?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button("Arrêter") { stopRunning() }
            Button("Annuler", role: .cancel) { }
        }
    }

    // MARK: Contenu

    private func input(for session: WorkSession) -> DaySessionInput {
        return DaySessionInput(id: session.uid, start: session.startDate, end: session.endDate,
                               activity: session.activity, chosenStart: session.chosenStart, chosenEnd: session.chosenEnd)
    }

    private func doubtSessionFor(_ decision: NowDecision) -> WorkSession? {
        switch decision {
        case .chooseDoubt(let id):
            return sessions.first(where: { $0.uid == id })
        case .confirmRunning, .firstDay, .calm:
            return nil
        }
    }

    private func content(now: Date) -> some View {
        let cal: Calendar = Calendar.current
        let base: CalculationBase = settings.calculationBase
        let running: WorkSession? = sessions.first(where: { $0.endDate == nil })
        let candidates: [NowCandidate] = sessions.map { s in
            NowCandidate(id: s.uid, start: s.startDate, end: s.endDate, hasUnresolvedDoubt: s.hasUnresolvedDoubt)
        }
        let decision: NowDecision = DaySummary.decideNow(candidates: candidates)
        let doubtTarget: WorkSession? = doubtSessionFor(decision)
        let today: [WorkSession] = sessions
            .filter { DaySummary.overlapsDay(start: $0.startDate, end: $0.endDate, day: now, now: now, calendar: cal) }
            .sorted { $0.startDate < $1.startDate }
        let inputs: [DaySessionInput] = sessions.map { input(for: $0) }
        let work: ActivityDayTotal = DaySummary.total(activity: .work, day: now, inputs: inputs, base: base, now: now, calendar: cal)
        let study: ActivityDayTotal = DaySummary.total(activity: .education, day: now, inputs: inputs, base: base, now: now, calendar: cal)

        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header(now: now, calendar: cal)

            if let message = errorMessage {
                PLTBanner(kind: .error, title: message)
            }

            RecoveryCardsSection(now: now, calendar: cal, running: running)

            AccueilNowCard(decision: decision,
                           running: running,
                           doubtSession: doubtTarget,
                           onStop: { showStopConfirm = true },
                           onChooseDoubt: { doubtSession = doubtTarget })

            if let live = running {
                AccueilRunningCard(session: live, now: now, onStop: { showStopConfirm = true })
            } else {
                Button {
                    errorMessage = nil
                    showStart = true
                } label: {
                    Label("Démarrer", systemImage: "play.fill")
                }
                .buttonStyle(.pltPrimary)
            }

            todaySection(work: work, study: study, base: base)
            daySection(today: today, now: now, calendar: cal, base: base)
        }
    }

    private func header(now: Date, calendar: Calendar) -> some View {
        let raw: String = Formatting.dayTitle(now, calendar: calendar)
        let title: String = raw.prefix(1).uppercased() + String(raw.dropFirst())
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Text("Salut !")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private func todaySection(work: ActivityDayTotal, study: ActivityDayTotal, base: CalculationBase) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Aujourd'hui")
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                StatTile(label: "Taf", value: DaySummary.tileValue(work),
                         note: DaySummary.tileNote(work, base: base), tone: .work)
                StatTile(label: "Cours", value: DaySummary.tileValue(study),
                         note: DaySummary.tileNote(study, base: base), tone: .study)
            }
        }
    }

    private func daySection(today: [WorkSession], now: Date, calendar: Calendar, base: CalculationBase) -> some View {
        let inputs: [DayTimelineInput] = today.map { $0.timelineInput }
        let segments: [DaySegment] = DayTimeline.segments(day: now, inputs: inputs, now: now, calendar: calendar)
        let range: HourRange = DayTimeline.visibleRange(segments: segments)
        let nowHour: Double? = DayTimeline.nowHour(day: now, now: now, calendar: calendar)
        let summary: String = DayTimeline.summary(segments: segments)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ta journée")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Theme.Spacing.s)
                NavigationLink {
                    SessionsView()
                } label: {
                    Text("Tout voir")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
            }
            if today.isEmpty {
                PLTCard {
                    Text("Rien de noté aujourd'hui.")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                    Text("Dès que tu démarres une session, elle apparaît ici avec ton ruban de la journée.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTCard {
                    HourRibbon(segments: segments, range: range, nowHour: nowHour, summary: summary)
                }
                PLTListGroup {
                    ForEach(Array(today.enumerated()), id: \.element.uid) { item in
                        NavigationLink {
                            SessionDetailView(session: item.element)
                        } label: {
                            PLTRow(symbol: item.element.activity.symbolName,
                                   tone: item.element.activity.tone,
                                   title: item.element.activity.title,
                                   subtitle: rowSubtitle(item.element),
                                   value: rowValue(item.element, now: now, base: base),
                                   showsChevron: true,
                                   showsSeparator: item.offset < today.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func rowSubtitle(_ session: WorkSession) -> String {
        let cal: Calendar = session.calendar
        let start: String = Formatting.clock(session.startDate, calendar: cal)
        var range: String = "depuis \(start)"
        if let end = session.endDate {
            range = "\(start) à \(Formatting.clock(end, calendar: cal))"
        }
        var text: String = range
        if let place = session.place {
            text = "\(place.name), \(range)"
        }
        if session.endDate != nil && session.hasUnresolvedDoubt {
            text += ". À confirmer"
        }
        return text
    }

    private func rowValue(_ session: WorkSession, now: Date, base: CalculationBase) -> String {
        if session.endDate == nil {
            return Formatting.duration(seconds: session.exactSeconds(now: now))
        }
        let end: Date = session.effectiveEnd(now: now)
        let retained = SessionDurations.retained(base: base, start: session.startDate, end: end,
                                                 chosenStart: session.chosenStart, chosenEnd: session.chosenEnd,
                                                 calendar: session.calendar)
        return Formatting.duration(seconds: retained.seconds)
    }

    // MARK: Actions

    private func stopRunning() {
        let service = SessionService(context: context)
        do {
            _ = try service.stopRunning(now: Date())
            errorMessage = nil
        } catch {
            errorMessage = "Impossible d'arrêter la session. Réessaie."
        }
    }
}
