import SwiftUI
import SwiftData

/// Écran `session-ajout` : saisie d'une session passée. Présenté en feuille : il porte sa propre NavigationStack.
struct SessionAjoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var allSessions: [WorkSession]

    @State private var selectedPlaceID: UUID? = nil
    @State private var activity: ActivityType = .work
    @State private var day: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var endsNextDay: Bool
    @State private var saveFailed: Bool = false

    private let source: SessionSource
    private let suggestedInterval: DateInterval?

    init(plannedShift: PlannedShift? = nil, suggestedInterval: DateInterval? = nil) {
        source = plannedShift == nil ? .manual : .planning
        self.suggestedInterval = suggestedInterval
        let calendar = Calendar.current
        let now = Date()
        let defaultEnd = suggestedInterval?.end ?? plannedShift?.end ?? calendar.dateInterval(of: .minute, for: now)?.start ?? now
        let defaultStart = suggestedInterval?.start ?? plannedShift?.start ?? defaultEnd.addingTimeInterval(-3600)
        _selectedPlaceID = State(initialValue: plannedShift?.placeUID)
        _activity = State(initialValue: plannedShift?.activity ?? .work)
        _day = State(initialValue: calendar.startOfDay(for: defaultStart))
        _startTime = State(initialValue: defaultStart)
        _endTime = State(initialValue: defaultEnd)
        _endsNextDay = State(initialValue: !calendar.isDate(defaultStart, inSameDayAs: defaultEnd))
    }

    // MARK: Valeurs calculées

    private var calendar: Calendar { return Calendar.current }

    private var startDate: Date {
        if let suggestedInterval, startTime == suggestedInterval.start,
           calendar.isDate(day, inSameDayAs: suggestedInterval.start) {
            return suggestedInterval.start
        }
        return SessionRules.combine(day: day, time: startTime, calendar: calendar)
    }

    private var endDate: Date {
        if let suggestedInterval, endTime == suggestedInterval.end,
           calendar.isDate(day, inSameDayAs: suggestedInterval.start),
           endsNextDay == !calendar.isDate(suggestedInterval.start, inSameDayAs: suggestedInterval.end) {
            return suggestedInterval.end
        }
        return SessionRules.combine(day: day, time: endTime, dayOffset: endsNextDay ? 1 : 0, calendar: calendar)
    }

    private var errors: [SessionValidationError] {
        let now = Date()
        var others: [SessionInterval] = []
        for s in allSessions {
            let end: Date = s.endDate ?? now
            if end > s.startDate {
                others.append(SessionInterval(start: s.startDate, end: end))
            }
        }
        return SessionRules.validate(start: startDate, end: endDate, now: now, others: others)
    }

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return places.first(where: { (p: Place) -> Bool in p.uid == id })
    }

    // MARK: Vue

    var body: some View {
        let currentErrors = errors
        return NavigationStack {
            PLTScreen(title: "Session passée") {
                if !currentErrors.isEmpty {
                    PLTBanner(kind: .error,
                              title: "Je peux pas enregistrer ça",
                              message: currentErrors.map { (e: SessionValidationError) -> String in e.message }.joined(separator: " "))
                }
                if saveFailed {
                    PLTBanner(kind: .error,
                              title: "Oups, ça a pas marché.",
                              message: "La session n'a pas été enregistrée. Réessaie ?")
                }
                placeSection
                activitySection
                whenSection
                Button("Enregistrer la session") { save() }
                    .buttonStyle(.pltPrimary)
                    .disabled(!currentErrors.isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "C'était où et quoi ?")
            PLTListGroup {
                PLTRow(symbol: "mappin.slash",
                       tone: .neutral,
                       title: "Aucun lieu",
                       value: selectedPlaceID == nil ? "Choisi" : nil,
                       showsSeparator: !places.isEmpty,
                       action: { selectedPlaceID = nil })
                ForEach(places) { (place: Place) in
                    PLTRow(symbol: place.type.symbolName,
                           tone: place.type.tone,
                           title: place.name,
                           subtitle: place.type.title,
                           value: selectedPlaceID == place.uid ? "Choisi" : nil,
                           action: {
                               selectedPlaceID = place.uid
                               activity = place.type.defaultActivity
                           })
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Type")
            PLTCard {
                HStack {
                    Text("Type")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Type", selection: $activity) {
                        ForEach(ActivityType.allCases) { (type: ActivityType) in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                }
            }
            Text("Préchoisi selon le lieu. Les courses sont notées mais pas comptées dans tes heures.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Quand ?")
            PLTCard {
                DatePicker("Date", selection: $day, in: ...Date(), displayedComponents: [.date])
                    .frame(minHeight: 44)
                DatePicker("Début", selection: $startTime, displayedComponents: [.hourAndMinute])
                    .frame(minHeight: 44)
                DatePicker("Fin", selection: $endTime, displayedComponents: [.hourAndMinute])
                    .frame(minHeight: 44)
                Toggle("Ça finit le lendemain", isOn: $endsNextDay)
                    .frame(minHeight: 44)
            }
            Text("Tu peux entrer l'heure exacte. J'applique les heures pleines après, avec toi si c'est dans la zone de doute.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Enregistrement

    private func save() {
        if !errors.isEmpty { return }
        let session = WorkSession(activity: activity,
                                  start: startDate,
                                  end: endDate,
                                  place: selectedPlace,
                                  source: source,
                                  isConfirmed: source == .manual,
                                  note: "")
        context.insert(session)
        do {
            try context.save()
            dismiss()
        } catch {
            context.delete(session)
            saveFailed = true
        }
    }
}
