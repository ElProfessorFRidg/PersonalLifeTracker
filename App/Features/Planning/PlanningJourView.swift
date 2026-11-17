import SwiftUI
import SwiftData

/// Détail d'un jour : ruban prévu contre réel, créneaux modifiables, congé éventuel.
struct PlanningJourView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannedShift.start) private var shifts: [PlannedShift]
    @Query(sort: \WorkSession.startDate) private var sessions: [WorkSession]
    @Query(sort: \LeaveEntry.startDay) private var leaves: [LeaveEntry]

    @State private var day: Date
    @State private var editing: PlannedShift?
    @State private var showAdd: Bool = false

    init(day: Date) {
        _day = State(initialValue: PlanningSupport.calendar.startOfDay(for: day))
    }

    private var calendar: Calendar { return PlanningSupport.calendar }

    private func shiftDay(_ delta: Int) {
        day = calendar.date(byAdding: .day, value: delta, to: day) ?? day
    }

    var body: some View {
        let now: Date = Date()
        var plannedInputs: [DayTimelineInput] = []
        var dayShifts: [PlannedShift] = []
        for s in shifts {
            let slot: PlanSlot = s.planSlot
            if !PlanningRules.slots(onDay: day, slots: [slot], calendar: calendar).isEmpty {
                dayShifts.append(s)
                plannedInputs.append(DayTimelineInput(start: s.start, end: s.end, activity: s.activity, isDoubt: false))
            }
        }
        var realInputs: [DayTimelineInput] = []
        for s in sessions {
            realInputs.append(s.timelineInput)
        }
        let plannedSegments: [DaySegment] = DayTimeline.segments(day: day, inputs: plannedInputs, now: now, calendar: calendar)
        let realSegments: [DaySegment] = DayTimeline.segments(day: day, inputs: realInputs, now: now, calendar: calendar)
        let range: HourRange = DayTimeline.visibleRange(segments: plannedSegments + realSegments)
        let nowHour: Double? = DayTimeline.nowHour(day: day, now: now, calendar: calendar)
        let dayLeaves: [LeaveEntry] = leaves.filter { l in
            return PlanningRules.leaveCovers(day: day, startDay: l.startDay, endDay: l.endDay, calendar: calendar)
        }
        var allSlots: [PlanSlot] = []
        for s in shifts { allSlots.append(s.planSlot) }
        var real: [RealSlot] = []
        for s in sessions { real.append(s.planRealSlot) }
        let planned: Int = PlanningRules.plannedMinutes(day: day, slots: allSlots, calendar: calendar)
        let done: Int = PlanningRules.doneMinutes(day: day, real: real, now: now, calendar: calendar)

        return PLTScreen(title: Formatting.dayTitle(day, calendar: calendar)) {
            dayNavigation

            ForEach(dayLeaves) { leave in
                PLTBanner(kind: .info,
                          title: PlanningSupport.leaveKindTitle(leave.kindRaw),
                          message: leave.note.isEmpty ? nil : leave.note,
                          actionTitle: "Supprimer ce congé") {
                    context.delete(leave)
                    try? context.save()
                }
            }

            PLTSectionHeader(title: "Prévu contre réel")
            PLTCard {
                Text("Prévu")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                HourRibbon(segments: plannedSegments, range: range, nowHour: nowHour,
                           summary: "Prévu. " + DayTimeline.summary(segments: plannedSegments))
                Text("Réel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                HourRibbon(segments: realSegments, range: range, nowHour: nowHour,
                           summary: "Réel. " + DayTimeline.summary(segments: realSegments))
            }

            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                StatTile(label: "Prévu", value: Formatting.duration(minutes: planned), tone: .accent)
                StatTile(label: "Fait", value: Formatting.duration(minutes: done),
                         note: PlanningSupport.differenceText(minutes: done - planned), tone: .work)
            }

            PLTSectionHeader(title: "Créneaux prévus")
            if dayShifts.isEmpty {
                PLTEmptyState(symbol: "calendar.badge.plus",
                              title: "Rien de prévu ce jour-là",
                              message: "Ajoute un créneau si tu as des horaires.")
            } else {
                PLTListGroup {
                    ForEach(dayShifts) { s in
                        PLTRow(symbol: s.activity.symbolName,
                               tone: s.activity.tone,
                               title: "\(s.activity.title) \(PlanningSupport.range(start: s.start, end: s.end))",
                               subtitle: s.note.isEmpty ? nil : s.note,
                               value: Formatting.duration(minutes: Int(s.end.timeIntervalSince(s.start)) / 60),
                               showsChevron: true,
                               action: { editing = s })
                    }
                }
            }
            Button("Ajouter un créneau") { showAdd = true }
                .buttonStyle(.pltSecondary)
        }
        .sheet(isPresented: $showAdd) {
            PlanningShiftEditView(shift: nil, defaultDay: day)
        }
        .sheet(item: $editing) { shift in
            PlanningShiftEditView(shift: shift, defaultDay: day)
        }
    }

    private var dayNavigation: some View {
        HStack {
            Button {
                shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Jour précédent")
            Spacer()
            Text(PlanningSupport.dayMonth(day))
                .font(.headline.monospacedDigit())
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Button {
                shiftDay(1)
            } label: {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Jour suivant")
        }
        .foregroundStyle(palette.accent)
    }
}
