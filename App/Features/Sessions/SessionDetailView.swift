import SwiftUI
import SwiftData

/// Borne d'une session en cours de correction.
private enum EditedBound: Int, Identifiable {
    case start
    case end

    var id: Int { return rawValue }
}

/// Écran `session` : détail et correction. Poussé dans une NavigationStack existante.
struct SessionDetailView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query private var allSessions: [WorkSession]

    let session: WorkSession

    @State private var editedBound: EditedBound? = nil
    @State private var showDoute: Bool = false
    @State private var showDeleteDialog: Bool = false
    @State private var isDeleted: Bool = false

    var body: some View {
        if isDeleted {
            PLTScreen(title: "Session") {
                EmptyView()
            }
        } else {
            content
        }
    }

    private var content: some View {
        let now = Date()
        return PLTScreen(title: "Session") {
            headerCard(now: now)
            if session.hasUnresolvedDoubt {
                doubtBanner
            }
            hoursSection(now: now)
            countingSection(now: now)
            editSection
            noteSection
            confirmSection
            deleteSection
        }
        .sheet(item: $editedBound) { (bound: EditedBound) in
            boundSheet(bound)
        }
        .sheet(isPresented: $showDoute) {
            DouteView(session: session)
        }
        .confirmationDialog("Supprimer cette session ?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { deleteSession() }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text(undoCenter?.isEnabled == true
                 ? "Elle disparaît de ton historique et de tes totaux. Tu pourras annuler juste après."
                 : "Elle disparaît de ton historique et de tes totaux. Tu ne pourras pas la récupérer.")
        }
    }

    // MARK: Entête

    private func headerCard(now: Date) -> some View {
        let cal = session.calendar
        let seconds: Int
        if let end = session.endDate {
            seconds = SessionDurations.retained(base: settings.calculationBase, start: session.startDate, end: end,
                                                chosenStart: session.chosenStart, chosenEnd: session.chosenEnd,
                                                calendar: cal).seconds
        } else {
            seconds = session.exactSeconds(now: now)
        }
        let exact = session.exactSeconds(now: now)
        return PLTCard {
            HStack(spacing: Theme.Spacing.s) {
                PLTChip(session.activity.title, kind: session.activity.chipKind)
                if SessionRules.needsConfirmation(session.listItem) {
                    PLTChip("À confirmer", kind: .doubt)
                }
            }
            Text(SessionDisplay.title(session))
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Text(SessionRules.dayLabel(day: cal.startOfDay(for: session.startDate), now: now, calendar: cal))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Text(Formatting.duration(seconds: seconds))
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.textPrimary)
            Text(session.isOngoing
                 ? "En cours, exact \(Formatting.duration(seconds: exact))."
                 : "\(settings.calculationBase.title), exact \(Formatting.duration(seconds: exact)).")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var doubtBanner: some View {
        PLTBanner(kind: .warning,
                  title: "Une heure est à choisir",
                  message: "Tant que tu choisis pas, je compte cette session comme « à choisir » dans tes totaux en heures pleines.",
                  actionTitle: "Choisir l'heure pleine",
                  action: { showDoute = true })
    }

    // MARK: Les heures

    private func hoursSection(now: Date) -> some View {
        let cal = session.calendar
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Les heures")
            PLTListGroup {
                PLTRow(title: "Arrivée",
                       subtitle: "Exact \(SessionRules.clockWithSeconds(session.startDate, calendar: cal)). Source : \(session.source.title).",
                       value: retainedText(exact: session.startDate, chosen: session.chosenStart),
                       showsSeparator: true)
                if let end = session.endDate {
                    PLTRow(title: "Départ",
                           subtitle: "Exact \(SessionRules.clockWithSeconds(end, calendar: cal)). Source : \(session.source.title).",
                           value: retainedText(exact: end, chosen: session.chosenEnd),
                           showsSeparator: false)
                } else {
                    PLTRow(title: "Départ",
                           subtitle: "La session est toujours en cours.",
                           value: "En cours",
                           showsSeparator: false)
                }
            }
            Text("La colonne de droite, c'est l'heure pleine retenue. L'heure exacte reste toujours gardée, je ne l'écrase jamais.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func retainedText(exact: Date, chosen: Date?) -> String {
        let cal = session.calendar
        if let hour = SessionDurations.resolvedBound(exact: exact, chosen: chosen, calendar: cal) {
            return Formatting.clock(hour, calendar: cal)
        }
        return "À choisir"
    }

    // MARK: Trois façons de compter

    private func countingSection(now: Date) -> some View {
        let cal = session.calendar
        let end = session.effectiveEnd(now: now)
        let normalized = SessionDurations.normalizedSeconds(start: session.startDate, end: end,
                                                            chosenStart: session.chosenStart, chosenEnd: session.chosenEnd,
                                                            calendar: cal)
        let exact = session.exactSeconds(now: now)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Trois façons de compter")
            PLTListGroup {
                PLTRow(title: "Heures pleines",
                       subtitle: "Utilisées pour tes stats et ton contrat",
                       value: normalized.map { Formatting.duration(seconds: $0) } ?? "À choisir")
                PLTRow(title: "Exact",
                       subtitle: "À la seconde près : \(SessionRules.durationWithSeconds(exact))",
                       value: Formatting.duration(seconds: exact))
                PLTRow(title: "Planning",
                       subtitle: "Pas de créneau prévu pour cette session",
                       value: "Aucun",
                       showsSeparator: false)
            }
            Text("Base retenue pour l'affichage : \(settings.calculationBase.title). Tu peux la changer dans les réglages.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Correction

    private var editSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Corriger")
            PLTListGroup {
                PLTRow(symbol: "clock",
                       tone: .accent,
                       title: "Changer l'arrivée",
                       subtitle: "Tu gardes l'heure détectée à côté",
                       showsChevron: true,
                       action: { editedBound = .start })
                if !session.isOngoing {
                    PLTRow(symbol: "clock",
                           tone: .accent,
                           title: "Changer le départ",
                           subtitle: "Tu gardes l'heure détectée à côté",
                           showsChevron: true,
                           action: { editedBound = .end })
                }
                if session.hasUnresolvedDoubt {
                    PLTRow(symbol: "questionmark.circle",
                           tone: .accent,
                           title: "Choisir l'heure pleine",
                           subtitle: "Zone de doute à régler",
                           showsChevron: true,
                           action: { showDoute = true })
                }
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 36, height: 36)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Changer le type")
                            .font(.body)
                            .foregroundStyle(palette.textPrimary)
                        Text("Taf, cours ou courses")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Type", selection: activityBinding) {
                        ForEach(ActivityType.allCases) { (type: ActivityType) in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private var activityBinding: Binding<ActivityType> {
        return Binding<ActivityType>(
            get: { return session.activity },
            set: { (newValue: ActivityType) in
                session.activity = newValue
                persist()
                // Section 11 : toute correction crée une règle locale limitée à son contexte (voir HabitLearning).
                HabitLearning.recordFeedback(for: session, store: HabitStore.shared)
            }
        )
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Note")
            TextField("Une précision sur cette session", text: noteBinding, axis: .vertical)
                .lineLimit(1...5)
                .font(.body)
                .padding(Theme.Spacing.m)
                .frame(minHeight: 44, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Note de la session")
        }
    }

    private var noteBinding: Binding<String> {
        return Binding<String>(
            get: { return session.note },
            set: { (newValue: String) in
                session.note = newValue
                persist()
            }
        )
    }

    @ViewBuilder
    private var confirmSection: some View {
        if !session.isConfirmed {
            Button("C'est bon, je confirme") {
                session.isConfirmed = true
                persist()
                // Section 11 : une confirmation compte comme une réponse concordante pour son contexte.
                HabitLearning.recordFeedback(for: session, store: HabitStore.shared)
            }
            .buttonStyle(.pltPrimary)
        }
    }

    private var deleteSection: some View {
        PLTListGroup {
            PLTRow(symbol: "trash",
                   tone: .danger,
                   title: "Supprimer cette session",
                   subtitle: undoCenter?.isEnabled == true ? "Tu peux annuler juste après" : nil,
                   showsSeparator: false,
                   action: { showDeleteDialog = true })
        }
    }

    // MARK: Feuille de correction d'une borne

    private func boundSheet(_ bound: EditedBound) -> some View {
        let initial: Date = (bound == .start) ? session.startDate : (session.endDate ?? Date())
        let title: String = (bound == .start) ? "Heure d'arrivée" : "Heure de départ"
        return BoundEditSheet(title: title,
                              initial: initial,
                              timeZone: session.timeZone,
                              validate: { (date: Date) -> [SessionValidationError] in
                                  return validateBound(bound, date)
                              },
                              onSave: { (date: Date) in
                                  applyBound(bound, date)
                              })
    }

    private func otherIntervals(now: Date) -> [SessionInterval] {
        var result: [SessionInterval] = []
        for other in allSessions {
            if other.uid == session.uid { continue }
            let end: Date = other.endDate ?? now
            if end > other.startDate {
                result.append(SessionInterval(start: other.startDate, end: end))
            }
        }
        return result
    }

    private func validateBound(_ bound: EditedBound, _ date: Date) -> [SessionValidationError] {
        let now = Date()
        let newStart: Date = (bound == .start) ? date : session.startDate
        let newEnd: Date = (bound == .end) ? date : (session.endDate ?? now)
        return SessionRules.validate(start: newStart, end: newEnd, now: now, others: otherIntervals(now: now))
    }

    /// Corrige une borne exacte. Le choix de la zone de doute de cette borne est effacé s'il change (il ne vaut plus rien).
    /// Aucun arrondi n'est jamais écrit dans startDate ou endDate.
    private func applyBound(_ bound: EditedBound, _ date: Date) {
        switch bound {
        case .start:
            if date != session.startDate {
                session.startDate = date
                session.chosenStart = nil
            }
        case .end:
            if date != session.endDate {
                session.endDate = date
                session.chosenEnd = nil
            }
        }
        persist()
    }

    private func persist() {
        try? context.save()
    }

    private func deleteSession() {
        let copy: ExportedSession = UndoSnapshots.exportedSession(session)
        let ctx: ModelContext = context
        isDeleted = true
        context.delete(session)
        try? context.save()
        undoCenter?.register(message: "Session supprimée") {
            try? UndoSnapshots.restoreSession(copy, context: ctx)
        }
        dismiss()
    }
}

/// Feuille avec un sélecteur de date et d'heure et les erreurs de validation en ligne.
private struct BoundEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let title: String
    let timeZone: TimeZone
    let validate: (Date) -> [SessionValidationError]
    let onSave: (Date) -> Void
    @State private var value: Date

    init(title: String,
         initial: Date,
         timeZone: TimeZone,
         validate: @escaping (Date) -> [SessionValidationError],
         onSave: @escaping (Date) -> Void) {
        self.title = title
        self.timeZone = timeZone
        self.validate = validate
        self.onSave = onSave
        _value = State(initialValue: initial)
    }

    var body: some View {
        let errors = validate(value)
        return NavigationStack {
            PLTScreen(title: title) {
                if !errors.isEmpty {
                    PLTBanner(kind: .error,
                              title: "Je peux pas enregistrer ça",
                              message: errors.map { (e: SessionValidationError) -> String in e.message }.joined(separator: " "))
                }
                DatePicker(title, selection: $value, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .environment(\.timeZone, timeZone)
                    .accessibilityLabel(title)
                Text("L'heure exacte que tu entres est gardée telle quelle. Les heures pleines se recalculent ensuite.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                Button("Enregistrer") {
                    onSave(value)
                    dismiss()
                }
                .buttonStyle(.pltPrimary)
                .disabled(!errors.isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}
