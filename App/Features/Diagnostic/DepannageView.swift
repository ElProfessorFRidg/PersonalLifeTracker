import SwiftUI
import SwiftData
import UIKit

/// Cible de l'analyse : une session précise ou un jour sans session.
private enum DepannageTarget: Hashable {
    case session(UUID)
    case day
}

/// Assistant "Pourquoi j'ai raté ça ?" (section 132, module detection_help).
/// Étape 1 : ce qui s'est mal passé (et quelle session ou quel jour). Étape 2 : l'analyse.
/// Prototype : design/prototype/src/screens/97_diagnostic.html.
struct DepannageView: View {
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(GeofenceService.self) private var geofence

    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]
    @Query(sort: \DetectionEvent.date, order: .reverse) private var events: [DetectionEvent]
    @Query private var places: [Place]

    let session: WorkSession?

    @State private var capabilities: CapabilityService = CapabilityService()
    @State private var question: MissQuestion = .missedDeparture
    @State private var target: DepannageTarget = .day
    @State private var day: Date = Date()
    @State private var dayPlaceUID: UUID? = nil
    @State private var hasAnalyzed: Bool = false
    @State private var actionMessage: String? = nil

    /// Nombre de jours proposés dans le sélecteur de sessions.
    private static let recentDays: Int = 30
    private static let maxProposedSessions: Int = 40

    init(session: WorkSession?) {
        self.session = session
    }

    var body: some View {
        PLTScreen(title: "Pourquoi j'ai raté ça ?") {
            stepOneSection
            if hasAnalyzed {
                analysisSections
            }
        }
        .onAppear {
            capabilities.refresh()
            if let given = session {
                target = .session(given.uid)
                day = given.startDate
            } else if let first = recentSessions.first {
                target = .session(first.uid)
                day = first.startDate
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { capabilities.refresh() }
        }
        .onChange(of: question) { _, _ in hasAnalyzed = false }
        .onChange(of: target) { _, _ in hasAnalyzed = false }
        .onChange(of: day) { _, _ in hasAnalyzed = false }
        .onChange(of: dayPlaceUID) { _, _ in hasAnalyzed = false }
    }

    // MARK: Données

    private var recentSessions: [WorkSession] {
        let limit: Date = Date().addingTimeInterval(-Double(DepannageView.recentDays) * 86_400)
        var result: [WorkSession] = []
        for item in sessions {
            if item.startDate < limit { break }
            result.append(item)
            if result.count >= DepannageView.maxProposedSessions { break }
        }
        return result
    }

    private var activeSession: WorkSession? {
        if let given = session { return given }
        if case .session(let uid) = target {
            return sessions.first(where: { (s: WorkSession) -> Bool in s.uid == uid })
        }
        return nil
    }

    private var activePlace: Place? {
        if let s = activeSession { return s.place }
        if let uid = dayPlaceUID {
            return places.first(where: { (p: Place) -> Bool in p.uid == uid })
        }
        return nil
    }

    private var analysisCalendar: Calendar {
        if let s = activeSession { return s.calendar }
        return Calendar.current
    }

    private var currentCapabilities: MissCapabilities {
        var caps: MissCapabilities = MissCapabilities()
        switch capabilities.location {
        case .always: caps.location = .always
        case .whenInUse: caps.location = .whenInUse
        case .denied: caps.location = .denied
        case .restricted: caps.location = .restricted
        case .notDetermined: caps.location = .notDetermined
        }
        caps.preciseLocation = capabilities.hasPreciseLocation
        caps.backgroundRefreshOn = (capabilities.backgroundRefresh == .available)
        caps.lowPowerMode = capabilities.isLowPowerMode
        return caps
    }

    private var missInput: MissInput {
        let now: Date = Date()
        let calendar: Calendar = analysisCalendar
        var windowStart: Date = now
        var windowEnd: Date = now
        if let s = activeSession {
            let w: (start: Date, end: Date) = MissAnalysis.window(sessionStart: s.startDate, sessionEnd: s.endDate, now: now)
            windowStart = w.start
            windowEnd = w.end
        } else {
            let start: Date = calendar.startOfDay(for: day)
            windowStart = start
            windowEnd = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        }
        var mapped: [MissEvent] = []
        for item in events {
            mapped.append(MissEvent(kindRaw: item.kindRaw, date: item.date, placeName: item.placeName, accuracy: item.accuracyMeters))
        }
        let place: Place? = activePlace
        return MissInput(question: question,
                         windowStart: windowStart,
                         windowEnd: windowEnd,
                         events: mapped,
                         atTime: nil,
                         now: currentCapabilities,
                         placeRadius: place?.radius,
                         placeName: place?.name,
                         sessionStart: activeSession?.startDate,
                         sessionEnd: activeSession?.endDate,
                         sessionSourceRaw: activeSession?.sourceRaw,
                         calendar: calendar)
    }

    // MARK: Étape 1

    private var stepOneSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTSectionHeader(title: "Qu'est-ce qui s'est mal passé ?")
            PLTListGroup {
                ForEach(Array(MissQuestion.allCases.enumerated()), id: \.element) { (index: Int, item: MissQuestion) in
                    PLTRow(symbol: item == question ? "checkmark.circle.fill" : "circle",
                           tone: item == question ? .accent : .neutral,
                           title: item.title,
                           subtitle: item.hint,
                           showsSeparator: index < MissQuestion.allCases.count - 1,
                           action: { question = item })
                    .accessibilityLabel("\(item.title). \(item.hint)")
                    .accessibilityAddTraits(item == question ? [.isSelected] : [])
                }
            }
            if session == nil {
                targetPicker
            }
            Button("Analyser") {
                capabilities.refresh()
                actionMessage = nil
                hasAnalyzed = true
            }
            .buttonStyle(.pltPrimary)
            Text("Je relis le journal de détection de cette période. Tout reste sur ton tel et rien n'est changé sans ton tap.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Quelle session ou quel jour ?")
            let proposed: [WorkSession] = recentSessions
            Picker("Session ou jour", selection: $target) {
                ForEach(proposed, id: \.uid) { (item: WorkSession) in
                    Text(sessionLabel(item)).tag(DepannageTarget.session(item.uid))
                }
                Text("Un jour sans session").tag(DepannageTarget.day)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44, alignment: .leading)
            if target == .day {
                DatePicker("Jour", selection: $day, in: ...Date(), displayedComponents: [.date])
                    .frame(minHeight: 44)
                Picker("Lieu concerné", selection: $dayPlaceUID) {
                    Text("Je ne sais plus").tag(UUID?.none)
                    ForEach(places, id: \.uid) { (item: Place) in
                        Text(item.name).tag(UUID?.some(item.uid))
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44, alignment: .leading)
            }
        }
    }

    private func sessionLabel(_ item: WorkSession) -> String {
        let dayText: String = Formatting.dayTitle(item.startDate, calendar: item.calendar)
        let clock: String = Formatting.clock(item.startDate, calendar: item.calendar)
        let name: String = item.place?.name ?? item.activity.title
        return "\(dayText), \(clock), \(name)"
    }

    // MARK: Étape 2

    @ViewBuilder
    private var analysisSections: some View {
        let input: MissInput = missInput
        let result: MissResult = MissAnalysis.analyze(input)
        contextCard(input)
        verdictSection(result)
        if result.causes.count > 1 && result.verdict == .causes {
            otherCausesSection(result)
        }
        checksSection(result)
        actionsSection(result)
    }

    private func contextCard(_ input: MissInput) -> some View {
        let calendar: Calendar = input.calendar
        var line: String = ""
        if let start = input.sessionStart {
            line = "Début à \(Formatting.clock(start, calendar: calendar))"
            if let end = input.sessionEnd {
                line += ", fin à \(Formatting.clock(end, calendar: calendar))."
            } else {
                line += ", session encore en cours."
            }
        } else {
            line = "Pas de session : j'analyse toute la journée."
        }
        let dayDate: Date = input.sessionStart ?? input.windowStart
        var title: String = Formatting.dayTitle(dayDate, calendar: calendar)
        if let name = input.placeName, !name.isEmpty {
            title += ", " + name
        }
        return PLTCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    if let s = activeSession {
                        PLTChip(s.activity.title, kind: s.activity.chipKind)
                    }
                    PLTChip(question.title, kind: .doubt)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text(line)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func verdictSection(_ result: MissResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que je pense")
            PLTBanner(kind: bannerKind(for: result), title: result.bannerTitle, message: result.bannerText)
            if !result.usesHistoricalCapabilities && result.verdict != .manualSession {
                Text("Je n'ai pas gardé l'historique de tes réglages. Ceux que je cite sont ceux d'aujourd'hui, donc ce sont des pistes et pas des certitudes.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func bannerKind(for result: MissResult) -> PLTBannerKind {
        switch result.verdict {
        case .causes:
            if let top = result.topCause, top.confidence == .high { return .error }
            return .warning
        case .nothingFound, .unknown, .manualSession:
            return .info
        }
    }

    private func otherCausesSection(_ result: MissResult) -> some View {
        let others: [MissCause] = Array(result.causes.dropFirst())
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Autres pistes")
            PLTListGroup {
                ForEach(Array(others.enumerated()), id: \.element.id) { (index: Int, cause: MissCause) in
                    VStack(alignment: .leading, spacing: 0) {
                        PLTRow(symbol: "questionmark.circle.fill",
                               tone: .neutral,
                               title: cause.title,
                               subtitle: cause.explanation,
                               value: nil,
                               showsSeparator: false)
                        Text(cause.confidence.title)
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                            .padding(.horizontal, Theme.Spacing.m)
                            .padding(.bottom, Theme.Spacing.s)
                        fixButton(cause.fix)
                        if index < others.count - 1 {
                            Rectangle()
                                .fill(palette.separator)
                                .frame(height: 0.5)
                                .padding(.leading, Theme.Spacing.m)
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }

    private func checksSection(_ result: MissResult) -> some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que j'ai vérifié")
            PLTListGroup {
                ForEach(Array(result.checks.enumerated()), id: \.element.id) { (index: Int, check: MissCheck) in
                    VStack(alignment: .leading, spacing: 0) {
                        PLTRow(symbol: symbol(for: check.id),
                               tone: tone(for: check.status),
                               title: check.title,
                               subtitle: check.detail,
                               value: check.status.title,
                               showsSeparator: false)
                        .accessibilityLabel("\(check.title), \(check.status.title). \(check.detail)")
                        fixButton(check.fix)
                        if index < result.checks.count - 1 {
                            Rectangle()
                                .fill(palette.separator)
                                .frame(height: 0.5)
                                .padding(.leading, Theme.Spacing.m)
                        }
                    }
                }
            }
            if let message = actionMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Text("Chaque point vient de l'état de ton tel et du journal de détection. Rien n'est changé sans ton tap.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func tone(for status: MissCheckStatus) -> PLTTone {
        switch status {
        case .ok: return .accent
        case .warning: return .neutral
        case .blocking: return .danger
        case .unknown: return .neutral
        }
    }

    private func symbol(for id: MissCheckID) -> String {
        switch id {
        case .location: return "location.fill"
        case .precise: return "scope"
        case .backgroundRefresh: return "arrow.triangle.2.circlepath"
        case .lowPower: return "battery.50percent"
        case .radius: return "mappin.and.ellipse"
        case .accuracy: return "dot.radiowaves.left.and.right"
        case .journal: return "list.bullet.rectangle"
        }
    }

    // MARK: Correctifs

    /// Bouton de correctif. "Corriger la session" est géré plus bas par un lien, pas ici.
    @ViewBuilder
    private func fixButton(_ fix: MissFix?) -> some View {
        if let fix = fix, fix.kind != .none, fix.kind != .correctSession {
            Button(fix.title) { perform(fix) }
                .buttonStyle(.pltSecondary)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.s)
        }
    }

    private func perform(_ fix: MissFix) {
        switch fix.kind {
        case .none, .correctSession:
            break
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .widenRadius(let delta):
            widenRadius(by: delta)
        case .restartMonitoring:
            geofence.refreshMonitoredPlaces()
            capabilities.refresh()
            actionMessage = "Suivi relancé. Je surveille tes lieux depuis maintenant."
        }
    }

    private func widenRadius(by delta: Double) {
        guard let place = activePlace else {
            actionMessage = "Je ne sais pas de quel lieu il s'agit. Ouvre le lieu pour changer son rayon."
            return
        }
        let newRadius: Double = PlaceRules.clampRadius(place.radius + delta)
        place.radius = newRadius
        do {
            try context.save()
            geofence.refreshMonitoredPlaces()
            actionMessage = "Le rayon de \(place.name) est maintenant de \(Int(newRadius.rounded())) m."
        } catch {
            actionMessage = "Je n'ai pas réussi à changer le rayon. Rien n'a été modifié."
        }
    }

    // MARK: Actions

    private func actionsSection(_ result: MissResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if result.verdict != .manualSession {
                Button("Relancer le suivi") {
                    perform(MissFix(kind: .restartMonitoring, title: "Relancer le suivi"))
                }
                .buttonStyle(.pltPrimary)
            }
            if let s = activeSession {
                NavigationLink {
                    SessionDetailView(session: s)
                } label: {
                    Text("Corriger la session")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Corriger la session")
                .accessibilityHint("Ouvre le détail de la session pour changer l'heure à la main")
            }
        }
    }
}

/// Entrée du module dans l'écran de diagnostic : pousse `DepannageView(session: nil)`.
struct DepannageEntryRow: View {
    var body: some View {
        PLTListGroup {
            NavigationLink {
                DepannageView(session: nil)
            } label: {
                PLTRow(symbol: "questionmark.bubble.fill",
                       title: "Pourquoi j'ai raté ça ?",
                       subtitle: "Je cherche pourquoi une arrivée ou un départ n'est pas passé",
                       showsChevron: true,
                       showsSeparator: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pourquoi j'ai raté ça ?")
            .accessibilityHint("Ouvre l'assistant de dépannage")
        }
    }
}
