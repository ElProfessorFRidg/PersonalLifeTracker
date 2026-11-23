import SwiftUI

/// Formats de dates courts pour les écrans du calendrier (français, fuseau du calendrier).
enum CalendrierFormat {
    static func shortDay(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}

/// Écran du calendrier scolaire (section 30), poussé depuis Réglages : jours fériés calculés, vacances par zone, pauses perso.
struct CalendrierScolaireView: View {
    @Environment(\.palette) private var palette

    @State private var zoneChoice: String = "none"
    @State private var userBreaks: [SchoolBreak] = []
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var editing: SchoolBreak? = nil
    @State private var loaded: Bool = false

    private var store: SchoolCalendarStore { return SchoolCalendarStore() }
    private var calendar: Calendar { return Calendar.current }

    private var zone: SchoolZone? {
        return SchoolZone(rawValue: zoneChoice)
    }

    private var allBreaks: [SchoolBreak] {
        var result: [SchoolBreak] = store.bundledData().breaks
        result.append(contentsOf: userBreaks)
        return result
    }

    var body: some View {
        let now: Date = Date()
        let data: SchoolCalendarData = store.bundledData()
        return PLTScreen(title: "Calendrier scolaire") {
            todayBanner(now: now)
            zoneSection
            nextBreakSection(now: now)
            breaksSection(data: data)
            holidaysSection
        }
        .onAppear { loadIfNeeded() }
        .sheet(item: $editing) { (draft: SchoolBreak) in
            SchoolBreakEditSheet(draft: draft,
                                 isExisting: userBreaks.contains(where: { $0.id == draft.id }),
                                 onSave: { (saved: SchoolBreak) in saveBreak(saved) },
                                 onDelete: { deleteBreak(draft.id) })
        }
    }

    // MARK: Données

    private func loadIfNeeded() {
        if loaded { return }
        loaded = true
        userBreaks = store.userBreaks()
        zoneChoice = store.zone?.rawValue ?? "none"
    }

    private func saveBreak(_ item: SchoolBreak) {
        var list: [SchoolBreak] = userBreaks
        if let index = list.firstIndex(where: { $0.id == item.id }) {
            list[index] = item
        } else {
            list.append(item)
        }
        userBreaks = list
        store.saveUserBreaks(list)
    }

    private func deleteBreak(_ id: String) {
        let list: [SchoolBreak] = userBreaks.filter { $0.id != id }
        userBreaks = list
        store.saveUserBreaks(list)
    }

    // MARK: Sections

    @ViewBuilder
    private func todayBanner(now: Date) -> some View {
        if let name = SchoolCalendarRules.holiday(on: now, calendar: calendar)?.name {
            PLTBanner(kind: .info, title: "Aujourd'hui : \(name)", message: "C'est un jour férié.")
        } else if let current = SchoolCalendarRules.breakCovering(now, in: allBreaks, zone: zone, calendar: calendar) {
            PLTBanner(kind: .info, title: "Aujourd'hui : \(current.name)", message: "Pas de cours attendus pendant cette période.")
        }
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ta zone")
            Picker("Zone scolaire", selection: $zoneChoice) {
                Text("Aucune").tag("none")
                ForEach(SchoolZone.allCases, id: \.rawValue) { (z: SchoolZone) in
                    Text(z.rawValue).tag(z.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            .onChange(of: zoneChoice) { (_: String, newValue: String) in
                let current: SchoolCalendarStore = store
                current.zone = SchoolZone(rawValue: newValue)
            }
            .accessibilityLabel("Zone scolaire")
            Text("Sans zone, seules les vacances communes à toutes les zones (Toussaint, Noël, été) et tes propres pauses comptent.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder
    private func nextBreakSection(now: Date) -> some View {
        if let next = SchoolCalendarRules.nextBreak(from: now, in: allBreaks, zone: zone, calendar: calendar),
           let start = SchoolCalendarRules.parseDay(next.startDay, calendar: calendar),
           let end = SchoolCalendarRules.parseDay(next.endDay, calendar: calendar) {
            let days: Int = SchoolCalendarRules.daysBetween(now, start, calendar: calendar)
            let range: String = SchoolCalendarRules.rangeText(start: start, end: end, calendar: calendar)
            let lead: String = days == 1 ? "Demain" : "Dans \(days) jours"
            let subtitle: String = days <= 0 ? "En cours, jusqu'au \(CalendrierFormat.shortDay(end, calendar: calendar))" : "\(lead), \(range)"
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: "Prochaines vacances")
                PLTListGroup {
                    PLTRow(symbol: "sun.max", tone: .accent, title: next.name, subtitle: subtitle, showsSeparator: false)
                }
            }
        }
    }

    private func breaksSection(data: SchoolCalendarData) -> some View {
        let list: [SchoolBreak] = SchoolCalendarRules.breaks(inYear: year, in: allBreaks, zone: zone, calendar: calendar)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            yearHeader(title: "Vacances \(year)")
            if list.isEmpty {
                PLTBanner(kind: .info,
                          title: "Pas de vacances enregistrées pour \(year)",
                          message: "Ajoute-les toi-même avec le bouton ci-dessous.")
            } else {
                PLTListGroup {
                    ForEach(Array(list.enumerated()), id: \.element.id) { (index: Int, item: SchoolBreak) in
                        breakRow(item, showsSeparator: index < list.count - 1)
                    }
                }
            }
            Button {
                editing = newDraft()
            } label: {
                Label("Ajouter une pause", systemImage: "plus")
            }
            .buttonStyle(.pltSecondary)
            Text("\(data.verificationNote)")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            Text("Source : \(data.source)")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder
    private func breakRow(_ item: SchoolBreak, showsSeparator: Bool) -> some View {
        let start: Date = SchoolCalendarRules.parseDay(item.startDay, calendar: calendar) ?? Date()
        let end: Date = SchoolCalendarRules.parseDay(item.endDay, calendar: calendar) ?? Date()
        let range: String = SchoolCalendarRules.rangeText(start: start, end: end, calendar: calendar)
        let zoneText: String = item.zone == "all" ? "toutes zones" : "zone \(item.zone)"
        let status: String = item.isCustom ? "ajouté par toi" : "à vérifier"
        if item.isCustom {
            PLTRow(symbol: "pencil", tone: .accent, title: item.name,
                   subtitle: "\(range), \(zoneText), \(status)",
                   showsChevron: true, showsSeparator: showsSeparator,
                   action: { editing = item })
        } else {
            PLTRow(symbol: "sun.max", tone: .accent, title: item.name,
                   subtitle: "\(range), \(zoneText), \(status)",
                   showsSeparator: showsSeparator)
        }
    }

    private var holidaysSection: some View {
        let list: [PublicHoliday] = SchoolCalendarRules.publicHolidays(year: year, calendar: calendar)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            yearHeader(title: "Jours fériés \(year)")
            PLTListGroup {
                ForEach(Array(list.enumerated()), id: \.element.id) { (index: Int, h: PublicHoliday) in
                    PLTRow(symbol: "flag", tone: .neutral, title: h.name,
                           value: CalendrierFormat.shortDay(h.day, calendar: calendar),
                           showsSeparator: index < list.count - 1)
                }
            }
            Text("Calculés par l'app, pas besoin de mise à jour. Le lundi de Pentecôte peut être travaillé selon ton contrat (journée de solidarité).")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func yearHeader(title: String) -> some View {
        HStack {
            PLTSectionHeader(title: title)
            Spacer(minLength: Theme.Spacing.s)
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Année précédente")
            Button {
                year += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Année suivante")
        }
    }

    private func newDraft() -> SchoolBreak {
        let today: Date = calendar.startOfDay(for: Date())
        let text: String = SchoolCalendarRules.dayText(today, calendar: calendar)
        return SchoolBreak(id: "custom-\(UUID().uuidString)", name: "", zone: "all",
                           startDay: text, endDay: text, note: "", isCustom: true)
    }
}

/// Feuille d'ajout ou de modification d'une pause de l'utilisateur.
struct SchoolBreakEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private let draft: SchoolBreak
    private let isExisting: Bool
    private let onSave: (SchoolBreak) -> Void
    private let onDelete: () -> Void

    @State private var name: String
    @State private var start: Date
    @State private var end: Date
    @State private var zoneValue: String
    @State private var confirmDelete: Bool = false

    init(draft: SchoolBreak, isExisting: Bool, onSave: @escaping (SchoolBreak) -> Void, onDelete: @escaping () -> Void) {
        self.draft = draft
        self.isExisting = isExisting
        self.onSave = onSave
        self.onDelete = onDelete
        let cal: Calendar = Calendar.current
        _name = State(initialValue: draft.name)
        _start = State(initialValue: SchoolCalendarRules.parseDay(draft.startDay, calendar: cal) ?? Date())
        _end = State(initialValue: SchoolCalendarRules.parseDay(draft.endDay, calendar: cal) ?? Date())
        _zoneValue = State(initialValue: draft.zone)
    }

    private var validation: SchoolCalendarRules.BreakValidation {
        return SchoolCalendarRules.validate(name: name, start: start, end: end, calendar: Calendar.current)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pause") {
                    TextField("Nom (par exemple stage, voyage)", text: $name)
                        .frame(minHeight: 44)
                    DatePicker("Premier jour", selection: $start, displayedComponents: [.date])
                    DatePicker("Dernier jour", selection: $end, displayedComponents: [.date])
                    Picker("Zone", selection: $zoneValue) {
                        Text("Toutes").tag("all")
                        ForEach(SchoolZone.allCases, id: \.rawValue) { (z: SchoolZone) in
                            Text(z.title).tag(z.rawValue)
                        }
                    }
                }
                if validation == .emptyName {
                    Section { PLTBanner(kind: .warning, title: "Donne un nom à ta pause") }
                } else if validation == .endBeforeStart {
                    Section { PLTBanner(kind: .error, title: "Le dernier jour doit être après le premier") }
                }
                if isExisting {
                    Section {
                        Button("Supprimer cette pause", role: .destructive) { confirmDelete = true }
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle(isExisting ? "Modifier la pause" : "Nouvelle pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(validation != .valid)
                }
            }
            .confirmationDialog("Supprimer cette pause ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Annuler", role: .cancel) { }
            }
        }
    }

    private func save() {
        let cal: Calendar = Calendar.current
        var item: SchoolBreak = draft
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.zone = zoneValue
        item.startDay = SchoolCalendarRules.dayText(start, calendar: cal)
        item.endDay = SchoolCalendarRules.dayText(end, calendar: cal)
        item.isCustom = true
        onSave(item)
        dismiss()
    }
}
