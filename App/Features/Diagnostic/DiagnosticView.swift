import SwiftUI
import SwiftData
import UIKit

/// Filtre du journal de détection.
enum DiagnosticJournalFilter: String, CaseIterable, Identifiable {
    case all
    case arrivalsAndDepartures
    case errors

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .all: return "Tout"
        case .arrivalsAndDepartures: return "Arrivées et départs"
        case .errors: return "Erreurs"
        }
    }

    func accepts(_ family: DiagEventFamily) -> Bool {
        switch self {
        case .all: return true
        case .arrivalsAndDepartures: return family == .arrivalsAndDepartures
        case .errors: return family == .errors
        }
    }
}

/// Événements d'une même journée, du plus récent au plus ancien.
struct DiagnosticDayGroup: Identifiable {
    let day: Date
    var events: [DetectionEvent]
    var id: Date { return day }
}

/// Fiabilité et diagnostic (section 52). Poussé depuis Réglages.
/// Prototypes : design/prototype/src/screens/97_diagnostic.html et 95_fiabilite.html.
struct DiagnosticView: View {
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(GeofenceService.self) private var geofence

    @Query(sort: \DetectionEvent.date, order: .reverse) private var events: [DetectionEvent]
    @Query private var places: [Place]

    @State private var capabilities: CapabilityService = CapabilityService()
    @State private var filter: DiagnosticJournalFilter = .all
    @State private var showPurgeConfirm: Bool = false
    @State private var restartMessage: String? = nil
    @State private var purgeError: String? = nil

    private static let maxDisplayedEvents: Int = 300

    var body: some View {
        PLTScreen(title: "Diagnostic de la détection") {
            summarySection
            checksSection
            restartSection
            journalSection
        }
        .onAppear { capabilities.refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { capabilities.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            capabilities.refresh()
        }
        .confirmationDialog("Vider le journal ?", isPresented: $showPurgeConfirm, titleVisibility: .visible) {
            Button("Vider le journal", role: .destructive) { purgeJournal() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes lieux et tes sessions ne bougent pas. Seul l'historique de détection est effacé.")
        }
    }

    // MARK: Données

    private var diagnosticInput: DiagInput {
        return DiagInput(location: locationState,
                         preciseLocation: capabilities.hasPreciseLocation,
                         notificationsAllowed: capabilities.notifications == .allowed || capabilities.notifications == .provisional,
                         backgroundRefreshAvailable: capabilities.backgroundRefresh == .available,
                         lowPowerMode: capabilities.isLowPowerMode,
                         placeCount: places.count,
                         isMonitoring: geofence.isMonitoring,
                         monitoringError: geofence.lastError,
                         monitoredCount: geofence.monitoredPlaceUIDs.count,
                         lastEventDate: geofence.lastEventDate ?? events.first?.date,
                         now: Date())
    }

    private var locationState: DiagLocationState {
        switch capabilities.location {
        case .always: return .always
        case .whenInUse: return .whenInUse
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        }
    }

    // MARK: Résumé

    private var summarySection: some View {
        let summary: DiagSummary = DiagnosticRules.summary(diagnosticInput)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTBanner(kind: bannerKind(for: summary), title: summary.title, message: summary.message)
        }
    }

    private func bannerKind(for summary: DiagSummary) -> PLTBannerKind {
        switch summary.status {
        case .ok: return .info
        case .warning: return .warning
        case .blocking: return .error
        }
    }

    // MARK: Ce que j'ai vérifié

    private var checksSection: some View {
        let checks: [DiagCheck] = DiagnosticRules.checks(diagnosticInput)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que j'ai vérifié")
            PLTListGroup {
                ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                    checkRow(check, isLast: index == checks.count - 1)
                }
            }
            Text("Rien n'est changé sans ton tap. Tout reste sur ton tel.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func checkRow(_ check: DiagCheck, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PLTRow(symbol: symbol(for: check),
                   tone: tone(for: check.status),
                   title: check.title,
                   subtitle: check.detail,
                   value: check.status.title,
                   showsSeparator: false)
            .accessibilityLabel("\(check.title), \(check.status.title). \(check.detail)")
            if let fixTitle = check.fixTitle, check.fix != .none {
                Button(fixTitle) { performFix(check.fix) }
                    .buttonStyle(.pltSecondary)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.s)
            }
            if !isLast {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
    }

    private func tone(for status: DiagStatus) -> PLTTone {
        switch status {
        case .ok: return .accent
        case .warning: return .neutral
        case .blocking: return .danger
        }
    }

    private func symbol(for check: DiagCheck) -> String {
        switch check.id {
        case .location: return "location.fill"
        case .precise: return "scope"
        case .notifications: return "bell.fill"
        case .backgroundRefresh: return "arrow.triangle.2.circlepath"
        case .lowPower: return "battery.50percent"
        case .places: return "mappin.and.ellipse"
        case .monitoring: return "dot.radiowaves.left.and.right"
        case .monitoredCount: return "number"
        case .lastEvent: return "clock"
        }
    }

    private func performFix(_ fix: DiagFix) {
        switch fix {
        case .none:
            break
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .restartMonitoring:
            restartMonitoring()
        }
    }

    // MARK: Relancer

    private var restartSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button("Relancer la surveillance") { restartMonitoring() }
                .buttonStyle(.pltPrimary)
            if let message = restartMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Text("Je relis tes lieux et je remets la surveillance en route.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func restartMonitoring() {
        geofence.refreshMonitoredPlaces()
        capabilities.refresh()
        restartMessage = "Surveillance relancée à \(DiagnosticFormat.time(Date()))."
    }

    // MARK: Journal

    private var filteredEvents: [DetectionEvent] {
        var result: [DetectionEvent] = []
        for event in events {
            if filter.accepts(DiagnosticRules.family(forKind: event.kindRaw)) {
                result.append(event)
                if result.count >= DiagnosticView.maxDisplayedEvents { break }
            }
        }
        return result
    }

    private func groups(of list: [DetectionEvent]) -> [DiagnosticDayGroup] {
        let calendar: Calendar = Calendar.current
        var result: [DiagnosticDayGroup] = []
        for event in list {
            let day: Date = calendar.startOfDay(for: event.date)
            if let last = result.last, last.day == day {
                result[result.count - 1].events.append(event)
            } else {
                result.append(DiagnosticDayGroup(day: day, events: [event]))
            }
        }
        return result
    }

    private var journalSection: some View {
        let shown: [DetectionEvent] = filteredEvents
        let dayGroups: [DiagnosticDayGroup] = groups(of: shown)
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PLTSectionHeader(title: "Journal de détection")
            Picker("Filtre du journal", selection: $filter) {
                ForEach(DiagnosticJournalFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            if let message = purgeError {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: message)
            }
            if shown.isEmpty {
                PLTEmptyState(symbol: "list.bullet.rectangle",
                              title: events.isEmpty ? "Le journal est vide" : "Rien dans ce filtre",
                              message: events.isEmpty
                                ? "Dès que je vois une entrée ou une sortie de zone, elle apparaît ici."
                                : "Change de filtre pour voir les autres événements.")
            } else {
                ForEach(dayGroups) { group in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(Formatting.dayTitle(group.day, calendar: Calendar.current))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)
                            .accessibilityAddTraits(.isHeader)
                        PLTListGroup {
                            ForEach(Array(group.events.enumerated()), id: \.element.uid) { index, event in
                                eventRow(event, isLast: index == group.events.count - 1)
                            }
                        }
                    }
                }
            }
            if !events.isEmpty {
                Button("Vider le journal") { showPurgeConfirm = true }
                    .buttonStyle(.pltDestructive)
            }
        }
    }

    private func eventRow(_ event: DetectionEvent, isLast: Bool) -> some View {
        let family: DiagEventFamily = DiagnosticRules.family(forKind: event.kindRaw)
        var parts: [String] = []
        let detail: String = event.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty { parts.append(detail) }
        if let accuracy = DiagnosticRules.accuracyText(event.accuracyMeters) {
            parts.append("Précision \(accuracy)")
        }
        let subtitle: String? = parts.isEmpty ? nil : parts.joined(separator: " · ")
        return PLTRow(symbol: eventSymbol(family),
                      tone: eventTone(family),
                      title: DiagnosticRules.sentence(forKind: event.kindRaw, placeName: event.placeName),
                      subtitle: subtitle,
                      value: DiagnosticFormat.timeWithSeconds(event.date),
                      showsSeparator: !isLast)
    }

    private func eventSymbol(_ family: DiagEventFamily) -> String {
        switch family {
        case .arrivalsAndDepartures: return "mappin.circle.fill"
        case .errors: return "exclamationmark.triangle.fill"
        case .other: return "circle.fill"
        }
    }

    private func eventTone(_ family: DiagEventFamily) -> PLTTone {
        switch family {
        case .arrivalsAndDepartures: return .accent
        case .errors: return .danger
        case .other: return .neutral
        }
    }

    private func purgeJournal() {
        do {
            try context.delete(model: DetectionEvent.self)
            try context.save()
            purgeError = nil
        } catch {
            purgeError = "Je n'ai pas réussi à vider le journal. Rien n'a été effacé."
        }
    }
}

/// Formats d'heure du diagnostic (24 h, secondes, calendrier courant).
enum DiagnosticFormat {
    private static let secondsFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func timeWithSeconds(_ date: Date) -> String {
        return secondsFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        return secondsFormatter.string(from: date)
    }
}
