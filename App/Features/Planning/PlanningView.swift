import SwiftUI
import SwiftData

/// Onglet Planning (section 91) : semaine datée, jour par jour, prévu contre fait.
struct PlanningView: View {
    @Environment(\.palette) private var palette
    @Environment(ModuleStore.self) private var modules
    @Query(sort: \PlannedShift.start) private var shifts: [PlannedShift]
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]
    @Query(sort: \LeaveEntry.startDay) private var leaves: [LeaveEntry]

    @State private var weekStart: Date = PlanningSupport.currentWeekStart()
    @State private var showAdd: Bool = false
    @State private var showCopy: Bool = false
    @State private var showLeave: Bool = false
    @State private var shiftToReview: PlannedShift?

    private var calendar: Calendar { return PlanningSupport.calendar }

    private var allSlots: [PlanSlot] {
        var result: [PlanSlot] = []
        for s in shifts { result.append(s.planSlot) }
        return result
    }

    private func weekShifts(_ start: Date) -> [PlannedShift] {
        let end: Date = PlanningRules.shiftWeek(start, by: 1, calendar: calendar)
        var result: [PlannedShift] = []
        for s in shifts where s.start >= start && s.start < end { result.append(s) }
        return result
    }

    private var isCurrentWeek: Bool {
        return weekStart == PlanningSupport.currentWeekStart()
    }

    private var defaultDay: Date {
        if isCurrentWeek { return calendar.startOfDay(for: Date()) }
        return weekStart
    }

    var body: some View {
        let now: Date = Date()
        let days: [Date] = PlanningRules.days(ofWeekStarting: weekStart, calendar: calendar)
        let current: [PlannedShift] = weekShifts(weekStart)
        let slots: [PlanSlot] = allSlots
        var real: [RealSlot] = []
        for s in sessions { real.append(s.planRealSlot) }
        let planned: Int = PlanningRules.plannedMinutes(weekStarting: weekStart, slots: slots, calendar: calendar)
        let done: Int = PlanningRules.doneMinutes(weekStarting: weekStart, real: real, now: now, calendar: calendar)
        let nextStart: Date = PlanningRules.shiftWeek(weekStart, by: 1, calendar: calendar)
        let nextEmpty: Bool = weekShifts(nextStart).isEmpty
        let missing = unloggedShifts(current, sessions: real, now: now)

        return PLTScreen(title: "Planning") {
            weekHeader(hasShifts: !current.isEmpty, hasImported: current.contains(where: { $0.sourceRaw == "photo" || $0.sourceRaw == "text" }))

            if isCurrentWeek && nextEmpty {
                PLTBanner(kind: .info,
                          title: "Pas de planning pour la semaine prochaine",
                          message: "Saisis-le à la main ou importe-le quand tu l'as reçu.",
                          actionTitle: "Voir la semaine prochaine") {
                    weekStart = nextStart
                }
            }

            if current.isEmpty {
                PLTEmptyState(symbol: "calendar",
                              title: "Pas de planning pour cette semaine",
                              message: "Chaque semaine est indépendante. Ajoute tes créneaux un par un, ou copie une autre semaine comme point de départ.",
                              actionTitle: "Ajouter un créneau") {
                    showAdd = true
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    StatTile(label: "Prévu", value: Formatting.duration(minutes: planned), note: "cette semaine", tone: .accent)
                    StatTile(label: "Fait", value: Formatting.duration(minutes: done),
                             note: PlanningSupport.differenceText(minutes: done - planned), tone: .work)
                }
            }

            if !missing.isEmpty {
                PLTSectionHeader(title: "Créneaux à vérifier")
                Text("Tu avais prévu de travailler. Si tu as fait le service, vérifie les horaires avant de l’ajouter.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                PLTListGroup {
                    ForEach(missing) { shift in
                        PLTRow(symbol: "clock.badge.questionmark", tone: .work,
                               title: PlanningSupport.dayShort(shift.start),
                               subtitle: PlanningSupport.range(start: shift.start, end: shift.end),
                               showsChevron: true, showsSeparator: shift.uid != missing.last?.uid) {
                            shiftToReview = shift
                        }
                    }
                }
            }

            PLTSectionHeader(title: "Jour par jour")
            PLTCard {
                ForEach(days, id: \.self) { day in
                    PlanningDayRow(day: day,
                                   planned: PlanningRules.slots(onDay: day, slots: slots, calendar: calendar),
                                   real: PlanningSupport.realSlots(sessions: sessions, day: day, now: now),
                                   isLeave: isLeave(day),
                                   isToday: calendar.isDate(day, inSameDayAs: now),
                                   now: now)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if modules.isActive("planning_ocr") {
                    NavigationLink {
                        PlanningImportView(week: weekStart)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Importer un planning")
                }
                if modules.isActive("weekly_review"), weekStart <= Date() {
                    NavigationLink {
                        WeeklyReviewView(week: weekStart)
                    } label: {
                        Image(systemName: "checklist")
                    }
                    .accessibilityLabel("Revoir la semaine")
                }
                Menu {
                    Button("Ajouter un créneau") { showAdd = true }
                    Button("Copier cette semaine vers une autre") { showCopy = true }
                    Button("Poser un congé") { showLeave = true }
                    Button("Aller à aujourd'hui") { weekStart = PlanningSupport.currentWeekStart() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Plus d'actions")
            }
        }
        .sheet(isPresented: $showAdd) {
            PlanningShiftEditView(shift: nil, defaultDay: defaultDay)
        }
        .sheet(isPresented: $showCopy) {
            PlanningCopyView(sourceWeekStart: weekStart)
        }
        .sheet(isPresented: $showLeave) {
            PlanningLeaveView(defaultDay: defaultDay)
        }
        .sheet(item: $shiftToReview) { shift in
            SessionAjoutView(plannedShift: shift)
        }
    }

    private func unloggedShifts(_ current: [PlannedShift], sessions: [RealSlot], now: Date) -> [PlannedShift] {
        if modules.isActive("vacation_mode") { return [] }
        let leaveDays = leaves.compactMap { leave -> DateInterval? in
            let start = calendar.startOfDay(for: leave.startDay)
            let endDay = calendar.startOfDay(for: leave.endDay)
            guard let end = calendar.date(byAdding: .day, value: 1, to: endDay), end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
        return current.filter {
            PlannedWorkReview.hasUnloggedWork($0.planSlot, sessions: sessions, leaveDays: leaveDays,
                                             now: now, calendar: calendar)
        }
    }

    private func isLeave(_ day: Date) -> Bool {
        for l in leaves {
            if PlanningRules.leaveCovers(day: day, startDay: l.startDay, endDay: l.endDay, calendar: calendar) { return true }
        }
        return false
    }

    private func weekHeader(hasShifts: Bool, hasImported: Bool) -> some View {
        let status: String = hasShifts ? (hasImported ? "Planning importé" : "Planning saisi") : "Pas de planning"
        return HStack(spacing: Theme.Spacing.s) {
            Button {
                weekStart = PlanningRules.shiftWeek(weekStart, by: -1, calendar: calendar)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Semaine précédente")
            Spacer()
            VStack(spacing: Theme.Spacing.xs) {
                Text(PlanningRules.weekTitle(weekStart: weekStart, calendar: calendar))
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button {
                weekStart = PlanningRules.shiftWeek(weekStart, by: 1, calendar: calendar)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Semaine suivante")
        }
        .foregroundStyle(palette.accent)
    }
}

/// Une ligne de jour : ce qui est prévu et ce qui a été fait, côte à côte.
private struct PlanningDayRow: View {
    @Environment(\.palette) private var palette
    let day: Date
    let planned: [PlanSlot]
    let real: [RealSlot]
    let isLeave: Bool
    let isToday: Bool
    let now: Date

    private var calendar: Calendar { return PlanningSupport.calendar }

    var body: some View {
        NavigationLink {
            PlanningJourView(day: day)
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Text(PlanningSupport.dayShort(day))
                    .font(.subheadline.weight(isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isToday ? palette.accent : palette.textPrimary)
                    .frame(width: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if isLeave {
                        PLTChip("Congé", kind: .neutral)
                    }
                    if planned.isEmpty && real.isEmpty && !isLeave {
                        Text("Rien de prévu")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    ForEach(planned) { s in
                        line(tone: s.activity.tone,
                             text: "\(s.activity.title) \(PlanningSupport.range(start: s.start, end: s.end))",
                             tag: "prévu")
                    }
                    ForEach(Array(real.enumerated()), id: \.offset) { item in
                        let r: RealSlot = item.element
                        let rangeText: String = r.end == nil
                            ? "depuis \(Formatting.clock(r.start, calendar: calendar))"
                            : PlanningSupport.range(start: r.start, end: r.end ?? now)
                        line(tone: r.activity.tone, text: "\(r.activity.title) \(rangeText)",
                             tag: r.end == nil ? "en cours" : "fait")
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvre le détail du jour")
    }

    private func line(tone: PLTTone, text: String, tag: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(tone.color(palette))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(palette.textPrimary)
            Text(tag)
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }
}
