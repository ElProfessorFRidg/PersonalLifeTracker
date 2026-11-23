import SwiftUI

/// Section "Pauses" du détail d'une session : démarrer ou finir une pause, ajouter à la main, durée nette.
/// N'affiche rien si le module breaks n'est pas actif. Ne change pas le calcul des durées de session.
struct SessionPausesSection: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.palette) private var palette
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?

    let session: WorkSession

    private let store: BreakStore = BreakStore.shared
    private let settings: BreakSettingsStore = BreakSettingsStore.shared

    @State private var showAdd: Bool = false
    @State private var pendingDelete: BreakRecord? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if modules.isActive("breaks") {
                content
            }
        }
    }

    private var content: some View {
        let now: Date = Date()
        let cal: Calendar = session.calendar
        let records: [BreakRecord] = store.breaks(for: session.uid)
        let intervals: [BreakInterval] = records.map { (r: BreakRecord) -> BreakInterval in return r.interval }
        let retained: Int = retainedSeconds(now: now)
        let deducted: Int = BreaksRules.deductedSeconds(breaks: intervals, sessionStart: session.startDate,
                                                        sessionEnd: session.endDate, now: now, isPaid: settings.isPaid)
        let total: Int = BreaksRules.breakSeconds(breaks: intervals, sessionStart: session.startDate,
                                                  sessionEnd: session.endDate, now: now)
        let net: Int = BreaksRules.netSeconds(retainedSeconds: retained, deductedSeconds: deducted)
        let running: BreakRecord? = store.runningBreak(for: session.uid)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Pauses")
            if let message = errorMessage {
                PLTBanner(kind: .error, title: message)
            }
            PLTListGroup {
                ForEach(records) { (record: BreakRecord) in
                    PLTRow(symbol: "pause.circle",
                           title: rangeText(record, calendar: cal),
                           subtitle: record.isManual ? "Ajoutée à la main" : nil,
                           value: Formatting.duration(seconds: BreaksRules.breakSeconds(breaks: [record.interval],
                                                                                         sessionStart: session.startDate,
                                                                                         sessionEnd: session.endDate, now: now)),
                           showsSeparator: true,
                           action: { pendingDelete = record })
                }
                if let current = running {
                    PLTRow(symbol: "stop.circle",
                           tone: .accent,
                           title: "Finir la pause",
                           subtitle: "Commencée à \(Formatting.clock(current.start, calendar: cal))",
                           showsChevron: true,
                           showsSeparator: true,
                           action: { stopBreak() })
                } else if session.endDate == nil {
                    PLTRow(symbol: "pause.circle",
                           tone: .accent,
                           title: "Démarrer une pause",
                           showsChevron: true,
                           showsSeparator: true,
                           action: { startBreak() })
                }
                PLTRow(symbol: "plus",
                       tone: .accent,
                       title: "Ajouter à la main",
                       showsChevron: true,
                       showsSeparator: !records.isEmpty,
                       action: { showAdd = true })
                if !records.isEmpty {
                    PLTRow(title: "Net des pauses",
                           subtitle: settings.isPaid
                               ? "Pauses payées, rien n'est déduit (total \(Formatting.duration(seconds: total)))"
                               : "Pauses non payées, \(Formatting.duration(seconds: total)) déduites",
                           value: Formatting.duration(seconds: net),
                           showsSeparator: false)
                }
            }
            if settings.mode != .none {
                Text(BreaksRules.legalReminderText)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .sheet(isPresented: $showAdd) {
            BreakAddSheet(session: session) { (start: Date, end: Date) in
                addManual(start: start, end: end)
            }
        }
        .confirmationDialog("Supprimer cette pause ?", isPresented: Binding<Bool>(
            get: { return pendingDelete != nil },
            set: { (shown: Bool) in if !shown { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { deletePending() }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        }
        .onAppear { syncReminder() }
    }

    // MARK: Calculs d'affichage

    private func retainedSeconds(now: Date) -> Int {
        if let end = session.endDate {
            return SessionDurations.retained(base: appSettings.calculationBase, start: session.startDate, end: end,
                                             chosenStart: session.chosenStart, chosenEnd: session.chosenEnd,
                                             calendar: session.calendar).seconds
        }
        return session.exactSeconds(now: now)
    }

    private func rangeText(_ record: BreakRecord, calendar: Calendar) -> String {
        let start: String = Formatting.clock(record.start, calendar: calendar)
        if let end = record.end {
            return "\(start) à \(Formatting.clock(end, calendar: calendar))"
        }
        return "Depuis \(start)"
    }

    // MARK: Actions

    private func startBreak() {
        let center: UndoCenter? = undoCenter
        let breaks: BreakStore = store
        do {
            let created: BreakRecord = try breaks.start(sessionUID: session.uid)
            errorMessage = nil
            let createdID: UUID = created.id
            center?.register(message: "Pause démarrée") {
                _ = breaks.delete(id: createdID)
            }
        } catch {
            errorMessage = "Une pause est déjà en cours."
        }
        syncReminder()
    }

    private func stopBreak() {
        let center: UndoCenter? = undoCenter
        let breaks: BreakStore = store
        guard let before = breaks.runningBreak(for: session.uid) else { return }
        do {
            _ = try breaks.stop(sessionUID: session.uid)
            errorMessage = nil
            center?.register(message: "Pause terminée") {
                breaks.restore(before)
            }
        } catch {
            errorMessage = "Aucune pause en cours."
        }
        syncReminder()
    }

    private func addManual(start: Date, end: Date) {
        let center: UndoCenter? = undoCenter
        let breaks: BreakStore = store
        do {
            let created: BreakRecord = try breaks.addManual(sessionUID: session.uid, start: start, end: end)
            errorMessage = nil
            let createdID: UUID = created.id
            center?.register(message: "Pause ajoutée") {
                _ = breaks.delete(id: createdID)
            }
        } catch {
            errorMessage = "Cette pause n'est pas valide."
        }
        syncReminder()
    }

    private func deletePending() {
        guard let record = pendingDelete else { return }
        pendingDelete = nil
        let center: UndoCenter? = undoCenter
        let breaks: BreakStore = store
        if let removed = breaks.delete(id: record.id) {
            center?.register(message: "Pause supprimée") {
                breaks.restore(removed)
            }
        }
        syncReminder()
    }

    /// Planifie ou annule le rappel de cette session (une seule fois par session, jamais pendant une pause).
    private func syncReminder() {
        let identifier: String = JournalNotifier.breakIdentifierPrefix + session.uid.uuidString
        if settings.mode != .reminder || session.endDate != nil || settings.hasReminded(sessionUID: session.uid) {
            JournalNotifier.cancel(identifier: identifier)
            return
        }
        let intervals: [BreakInterval] = store.breaks(for: session.uid).map { (r: BreakRecord) -> BreakInterval in return r.interval }
        guard let date = BreaksRules.reminderDate(sessionStart: session.startDate, sessionEnd: session.endDate,
                                                  breaks: intervals, afterHours: settings.reminderHours) else {
            JournalNotifier.cancel(identifier: identifier)
            return
        }
        if date <= Date() {
            settings.markReminded(sessionUID: session.uid)
            JournalNotifier.cancel(identifier: identifier)
            return
        }
        JournalNotifier.schedule(identifier: identifier,
                                 title: "Une pause ?",
                                 body: BreaksRules.reminderMessage(hours: settings.reminderHours),
                                 at: date)
    }
}

/// Feuille d'ajout d'une pause à la main, dans les bornes de la session.
struct BreakAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let session: WorkSession
    let onSave: (Date, Date) -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var errorText: String? = nil

    init(session: WorkSession, onSave: @escaping (Date, Date) -> Void) {
        self.session = session
        self.onSave = onSave
        let limit: Date = session.endDate ?? Date()
        let defaultEnd: Date = max(session.startDate, limit)
        let defaultStart: Date = max(session.startDate, defaultEnd.addingTimeInterval(-15 * 60))
        _start = State(initialValue: defaultStart)
        _end = State(initialValue: defaultEnd)
    }

    var body: some View {
        let upper: Date = session.endDate ?? Date()
        return NavigationStack {
            PLTScreen(title: "Ajouter une pause") {
                if let text = errorText {
                    PLTBanner(kind: .error, title: text)
                }
                DatePicker("Début", selection: $start, in: session.startDate...max(session.startDate, upper),
                           displayedComponents: [.date, .hourAndMinute])
                    .frame(minHeight: 44)
                DatePicker("Fin", selection: $end, in: session.startDate...max(session.startDate, upper),
                           displayedComponents: [.date, .hourAndMinute])
                    .frame(minHeight: 44)
                Button("Enregistrer") { save() }
                    .buttonStyle(.pltPrimary)
            }
            .environment(\.timeZone, session.timeZone)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func save() {
        if !BreaksRules.isValidManualBreak(start: start, end: end, sessionStart: session.startDate,
                                           sessionEnd: session.endDate, now: Date()) {
            errorText = "La pause doit finir après son début et rester dans la session."
            return
        }
        onSave(start, end)
        dismiss()
    }
}
