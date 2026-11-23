import SwiftUI
import SwiftData

/// Créneaux libres de révision (section 34), poussé depuis Réglages. "Réserver" ajoute un créneau prévu
/// de type Cours, source manuelle, note "Révision". Aucune culpabilisation : ce sont des idées, pas des devoirs.
struct CreneauxRevisionView: View {
    static let minMinutesKey: String = "plt.study.minMinutes"

    @Environment(ModuleStore.self) private var modules
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette

    @Query private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]

    @State private var minMinutes: Int = CreneauxRevisionView.storedMinMinutes()
    @State private var errorMessage: String? = nil

    private var calendar: Calendar { return Calendar.current }

    static func storedMinMinutes() -> Int {
        let stored: Int = UserDefaults.standard.integer(forKey: minMinutesKey)
        if stored == 0 { return StudySlotsRules.defaultMinMinutes }
        return max(15, min(180, stored))
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let slots: [StudySlot]
        var id: TimeInterval { return day.timeIntervalSince1970 }
    }

    var body: some View {
        let now: Date = Date()
        let slots: [StudySlot] = computeSlots(now: now)
        let groups: [DayGroup] = group(slots, now: now)
        return PLTScreen(title: "Créneaux de révision") {
            if let message = errorMessage {
                PLTBanner(kind: .error, title: message)
            }
            if modules.isActive("exam_mode") && ExamMode.isActive(now: now, calendar: calendar) {
                PLTBanner(kind: .info, title: "Mode examens en cours",
                          message: "Ces créneaux sont des idées, rien n'est obligatoire.")
            }
            settingsCard
            if groups.isEmpty {
                PLTEmptyState(symbol: "book",
                              title: "Pas de créneau libre pour l'instant",
                              message: "Je cherche des trous d'au moins \(Formatting.duration(minutes: minMinutes)) entre 08:00 et 21:00 sur les 7 prochains jours, avec une marge autour de tes cours et de ton taf.")
            } else {
                ForEach(groups) { (g: DayGroup) in
                    daySection(g, now: now)
                }
            }
        }
    }

    // MARK: Calcul

    private func computeSlots(now: Date) -> [StudySlot] {
        var config = StudySlotConfig()
        config.minMinutes = minMinutes
        var busy: [StudyBusy] = []
        for s in shifts {
            busy.append(StudyBusy(start: s.start, end: s.end))
        }
        for s in sessions {
            busy.append(StudyBusy(start: s.startDate, end: s.endDate ?? now))
        }
        var exams: [StudyExam] = []
        if modules.isActive("exam_mode"), let period = ExamModeStore().period() {
            for e in period.exams where e.start >= now {
                exams.append(StudyExam(title: e.title, start: e.start))
            }
        }
        return StudySlotsRules.slots(now: now, busy: busy, exams: exams, config: config, calendar: calendar)
    }

    private func group(_ slots: [StudySlot], now: Date) -> [DayGroup] {
        var order: [Date] = []
        var byDay: [Date: [StudySlot]] = [:]
        for s in slots {
            let d: Date = calendar.startOfDay(for: s.start)
            if byDay[d] == nil {
                byDay[d] = []
                order.append(d)
            }
            byDay[d]?.append(s)
        }
        var result: [DayGroup] = []
        for d in order {
            result.append(DayGroup(day: d, slots: byDay[d] ?? []))
        }
        return result
    }

    // MARK: Vues

    private var settingsCard: some View {
        PLTCard {
            Stepper(value: $minMinutes, in: 15...180, step: 15) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Durée minimale")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Text(Formatting.duration(minutes: minMinutes))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(minHeight: 44)
            .onChange(of: minMinutes) { (_: Int, newValue: Int) in
                UserDefaults.standard.set(newValue, forKey: CreneauxRevisionView.minMinutesKey)
            }
            .accessibilityLabel("Durée minimale d'un créneau, \(Formatting.duration(minutes: minMinutes))")
        }
    }

    private func daySection(_ g: DayGroup, now: Date) -> some View {
        let label: String = StudySlotsRules.dayLabel(g.day, now: now, calendar: calendar)
        let tag: String? = dayTag(g.day)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                PLTSectionHeader(title: label.prefix(1).uppercased() + String(label.dropFirst()))
                Spacer(minLength: Theme.Spacing.s)
                if let tag = tag {
                    PLTChip(tag, kind: .neutral)
                }
            }
            PLTListGroup {
                ForEach(Array(g.slots.enumerated()), id: \.element.id) { (index: Int, slot: StudySlot) in
                    slotRow(slot, showsSeparator: index < g.slots.count - 1)
                }
            }
        }
    }

    private func dayTag(_ day: Date) -> String? {
        if let name = SchoolCalendar.holidayName(day, calendar: calendar) { return name }
        if modules.isActive("school_calendar") && SchoolCalendar.isSchoolBreak(day, calendar: calendar) { return "Vacances" }
        return nil
    }

    private func slotRow(_ slot: StudySlot, showsSeparator: Bool) -> some View {
        let start: String = Formatting.clock(slot.start, calendar: calendar)
        let end: String = Formatting.clock(slot.end, calendar: calendar)
        let duration: String = Formatting.duration(minutes: slot.minutes)
        var subtitle: String = "\(duration) de libre"
        if let hint = StudySlotsRules.examHint(slot) { subtitle += ", " + hint }
        return HStack(spacing: Theme.Spacing.s) {
            PLTRow(symbol: "book.fill", tone: .study,
                   title: "\(start) à \(end)",
                   subtitle: subtitle,
                   showsSeparator: false)
            Button {
                reserve(slot)
            } label: {
                Text("Réserver")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Réserver le créneau de \(start) à \(end)")
        }
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Rectangle().fill(palette.separator).frame(height: 0.5).padding(.leading, Theme.Spacing.m)
            }
        }
    }

    private func reserve(_ slot: StudySlot) {
        let shift = PlannedShift(start: slot.start, end: slot.end, activity: .education,
                                 source: StudySlotsRules.reservedSource, note: StudySlotsRules.reservedNote)
        context.insert(shift)
        do {
            try context.save()
            errorMessage = nil
        } catch {
            errorMessage = "Je n'ai pas pu réserver ce créneau. Réessaie dans un instant."
        }
    }
}
