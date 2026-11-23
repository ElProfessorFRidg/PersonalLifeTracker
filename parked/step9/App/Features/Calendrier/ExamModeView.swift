import SwiftUI

/// Écran du mode examens (section 31), poussé depuis Réglages : définir la période et les épreuves.
/// Rien de destructif : le mode ne fait que se taire pendant la période.
struct ExamModeView: View {
    @Environment(\.palette) private var palette

    @State private var period: ExamPeriod? = nil
    @State private var loaded: Bool = false
    @State private var showEdit: Bool = false

    private var calendar: Calendar { return Calendar.current }

    var body: some View {
        let now: Date = Date()
        return PLTScreen(title: "Mode examens") {
            content(now: now)
        }
        .onAppear {
            if !loaded {
                loaded = true
                period = ExamModeStore().period()
            }
        }
        .sheet(isPresented: $showEdit) {
            ExamPeriodSheet(initial: period) { (saved: ExamPeriod?) in
                period = saved
                ExamModeStore().save(saved)
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let period = period {
            periodCard(period, now: now)
            examsSection(period, now: now)
            effectsSection
        } else {
            PLTEmptyState(symbol: "graduationcap",
                          title: "Pas de période d'examens",
                          message: "Définis tes dates de révisions ou d'épreuves. Pendant la période, les rappels se calment et tes objectifs d'heures sont mis en pause.",
                          actionTitle: "Définir ma période",
                          action: { showEdit = true })
            effectsSection
        }
    }

    private func periodCard(_ period: ExamPeriod, now: Date) -> some View {
        let phase: ExamPhase = ExamModeRules.phase(of: period, now: now, calendar: calendar)
        let status: String
        let kind: PLTChipKind
        switch phase {
        case .active:
            status = "En cours"
            kind = .study
        case .upcoming(let days):
            status = days == 1 ? "Demain" : "Dans \(days) jours"
            kind = .neutral
        case .over:
            status = "Terminée"
            kind = .neutral
        }
        let name: String = period.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let range: String = SchoolCalendarRules.rangeText(start: period.startDay, end: period.endDay, calendar: calendar)
        let rangeTitle: String = "D" + String(range.dropFirst())
        return PLTCard {
            HStack {
                Text(name.isEmpty ? "Période d'examens" : name)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                PLTChip(status, kind: kind)
            }
            Text(rangeTitle)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Button {
                showEdit = true
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            .buttonStyle(.pltSecondary)
        }
    }

    private func examsSection(_ period: ExamPeriod, now: Date) -> some View {
        let sorted: [ExamEntry] = period.exams.sorted { (a: ExamEntry, b: ExamEntry) -> Bool in return a.start < b.start }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Épreuves")
            if sorted.isEmpty {
                Text("Aucune épreuve notée. Tu peux en ajouter en modifiant la période.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            } else {
                PLTListGroup {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { (index: Int, exam: ExamEntry) in
                        PLTRow(symbol: "doc.text", tone: .study,
                               title: exam.title.isEmpty ? "Épreuve" : exam.title,
                               subtitle: ExamModeRules.examText(exam, now: now, calendar: calendar),
                               value: Formatting.clock(exam.start, calendar: calendar),
                               showsSeparator: index < sorted.count - 1)
                    }
                }
            }
        }
    }

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que ça change")
            PLTListGroup {
                PLTRow(symbol: "bell.slash", tone: .neutral, title: "Rappels réduits",
                       subtitle: "Les rappels et suggestions de travail se taisent pendant la période.")
                PLTRow(symbol: "pause.circle", tone: .neutral, title: "Objectifs d'heures en pause",
                       subtitle: "Aucun objectif de travail pendant la période.")
                PLTRow(symbol: "chart.bar", tone: .neutral, title: "Statistiques annotées",
                       subtitle: "La période est notée pour expliquer une baisse d'heures.")
                PLTRow(symbol: "hand.raised", tone: .neutral, title: "Pas aujourd'hui",
                       subtitle: "Sur l'Accueil, tu peux cacher la carte pour la journée, sans conséquence.",
                       showsSeparator: false)
            }
        }
    }
}

/// Feuille de saisie de la période et des épreuves. Enregistre ou retire la période (rien d'autre n'est touché).
struct ExamPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private let onSave: (ExamPeriod?) -> Void
    private let hasInitial: Bool

    @State private var title: String
    @State private var startDay: Date
    @State private var endDay: Date
    @State private var exams: [ExamEntry]
    @State private var newTitle: String = ""
    @State private var newStart: Date
    @State private var confirmRemove: Bool = false

    init(initial: ExamPeriod?, onSave: @escaping (ExamPeriod?) -> Void) {
        self.onSave = onSave
        self.hasInitial = initial != nil
        let cal: Calendar = Calendar.current
        let today: Date = cal.startOfDay(for: Date())
        let weekLater: Date = cal.date(byAdding: .day, value: 7, to: today) ?? today
        _title = State(initialValue: initial?.title ?? "")
        _startDay = State(initialValue: initial?.startDay ?? today)
        _endDay = State(initialValue: initial?.endDay ?? weekLater)
        _exams = State(initialValue: initial?.exams ?? [])
        _newStart = State(initialValue: initial?.startDay ?? today)
    }

    private var isValid: Bool {
        return ExamModeRules.validate(startDay: startDay, endDay: endDay, calendar: Calendar.current)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Période") {
                    TextField("Nom (révisions, bac blanc, bac)", text: $title)
                        .frame(minHeight: 44)
                    DatePicker("Premier jour", selection: $startDay, displayedComponents: [.date])
                    DatePicker("Dernier jour", selection: $endDay, displayedComponents: [.date])
                }
                if !isValid {
                    Section { PLTBanner(kind: .error, title: "Le dernier jour doit être après le premier") }
                }
                Section("Épreuves (facultatif)") {
                    ForEach(exams) { (exam: ExamEntry) in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exam.title.isEmpty ? "Épreuve" : exam.title)
                                Text(describe(exam))
                                    .font(.footnote)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer(minLength: Theme.Spacing.s)
                            Button {
                                exams.removeAll(where: { $0.id == exam.id })
                            } label: {
                                Image(systemName: "trash")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Retirer l'épreuve \(exam.title)")
                        }
                    }
                    TextField("Nom de l'épreuve", text: $newTitle)
                        .frame(minHeight: 44)
                    DatePicker("Date et heure", selection: $newStart, displayedComponents: [.date, .hourAndMinute])
                    Button("Ajouter l'épreuve") { addExam() }
                        .frame(minHeight: 44)
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if hasInitial {
                    Section {
                        Button("Retirer la période", role: .destructive) { confirmRemove = true }
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Période d'examens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Retirer la période ?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Retirer", role: .destructive) {
                    onSave(nil)
                    dismiss()
                }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Tes sessions et tes heures ne bougent pas.")
            }
        }
    }

    private func describe(_ exam: ExamEntry) -> String {
        let cal: Calendar = Calendar.current
        return "\(CalendrierFormat.shortDay(exam.start, calendar: cal)) à \(Formatting.clock(exam.start, calendar: cal))"
    }

    private func addExam() {
        let name: String = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return }
        exams.append(ExamEntry(title: name, start: newStart))
        newTitle = ""
    }

    private func save() {
        let cal: Calendar = Calendar.current
        let period = ExamPeriod(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                startDay: cal.startOfDay(for: startDay),
                                endDay: cal.startOfDay(for: endDay),
                                exams: exams)
        onSave(period)
        dismiss()
    }
}

/// Carte de l'Accueil : compte à rebours pendant et juste avant la période. Visible seulement si le module est actif.
/// "Pas aujourd'hui" la cache pour la journée, sans autre effet.
struct ExamCountdownCard: View {
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette

    private let now: Date
    @State private var skipToken: Int = 0

    init(now: Date = Date()) {
        self.now = now
    }

    var body: some View {
        Group {
            if modules.isActive("exam_mode") {
                inner
            }
        }
    }

    @ViewBuilder
    private var inner: some View {
        let calendar: Calendar = Calendar.current
        let store: ExamModeStore = ExamModeStore()
        let skipped: Bool = skipToken >= 0 && ExamModeRules.isSkipped(skippedDay: store.skippedDay, now: now, calendar: calendar)
        if !skipped, let period = store.period(),
           let periodText = ExamModeRules.periodText(period, now: now, calendar: calendar) {
            let next: ExamEntry? = ExamModeRules.nextExam(in: period, now: now)
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    ExamModeView()
                } label: {
                    PLTRow(symbol: "graduationcap", tone: .study,
                           title: periodText,
                           subtitle: next.map { ExamModeRules.examText($0, now: now, calendar: calendar) },
                           showsChevron: true, showsSeparator: false)
                }
                .buttonStyle(.plain)
                Button {
                    store.skipToday(now: now, calendar: calendar)
                    skipToken += 1
                } label: {
                    Text("Pas aujourd'hui")
                }
                .buttonStyle(.pltSecondary)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
    }
}
