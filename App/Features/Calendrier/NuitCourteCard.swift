import SwiftUI
import SwiftData

/// Convertit les créneaux de travail et de cours (prévus et réels terminés) en entrée pure de ShortNightRules.
enum ShortNightInputs {
    static func slots(shifts: [PlannedShift], sessions: [WorkSession]) -> [ShortNightSlot] {
        var result: [ShortNightSlot] = []
        for s in shifts where s.activity == .work || s.activity == .education {
            result.append(ShortNightSlot(start: s.start, end: s.end))
        }
        for s in sessions where s.activity == .work || s.activity == .education {
            if let end = s.endDate {
                result.append(ShortNightSlot(start: s.startDate, end: end))
            }
        }
        return result
    }
}

/// Carte de l'Accueil (section 33) : la veille au soir, rappelle que la nuit sera courte, avec la durée de repos maximale.
/// Visible seulement si le module est actif. Programme aussi la notification locale de la veille si elle est activée.
struct NuitCourteCard: View {
    @Environment(ModuleStore.self) private var modules

    @Query private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]

    private let now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    var body: some View {
        Group {
            if modules.isActive("short_night") {
                inner
            }
        }
    }

    private var refreshKey: String {
        let settings: ShortNightSettings = ShortNightSettings()
        let day: String = SchoolCalendarRules.dayText(now, calendar: Calendar.current)
        return "\(shifts.count)-\(sessions.count)-\(settings.thresholdMinutes)-\(settings.notifyEnabled)-\(day)"
    }

    @ViewBuilder
    private var inner: some View {
        let calendar: Calendar = Calendar.current
        let settings: ShortNightSettings = ShortNightSettings()
        let slots: [ShortNightSlot] = ShortNightInputs.slots(shifts: shifts, sessions: sessions)
        let alert: ShortNightResult? = ShortNightRules.alert(now: now, slots: slots,
                                                              thresholdMinutes: settings.thresholdMinutes, calendar: calendar)
        Group {
            if let result = alert {
                NavigationLink {
                    NuitCourteView()
                } label: {
                    PLTBanner(kind: .warning,
                              title: ShortNightRules.title,
                              message: ShortNightRules.message(result, calendar: calendar))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(ShortNightRules.title). \(ShortNightRules.message(result, calendar: calendar))")
            }
        }
        .task(id: refreshKey) {
            await refreshNotification()
        }
    }

    private func refreshNotification() async {
        let calendar: Calendar = Calendar.current
        let settings: ShortNightSettings = ShortNightSettings()
        let slots: [ShortNightSlot] = ShortNightInputs.slots(shifts: shifts, sessions: sessions)
        let current: Date = Date()
        let result: ShortNightResult? = ShortNightRules.nextNight(now: current, slots: slots,
                                                                  thresholdMinutes: settings.thresholdMinutes, calendar: calendar)
        let examAllows: Bool = !modules.isActive("exam_mode")
            || ExamMode.allows(.reminder, now: current, calendar: calendar)
        await ShortNightNotifier.refresh(result: result, now: current, calendar: calendar,
                                         enabled: settings.notifyEnabled, allowedByExamMode: examAllows)
    }
}

/// Réglages de l'alerte nuit courte, poussés depuis Réglages ou depuis la carte.
struct NuitCourteView: View {
    @Environment(\.palette) private var palette
    @Query private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]

    @State private var threshold: Int = ShortNightSettings().thresholdMinutes
    @State private var notifyEnabled: Bool = ShortNightSettings().notifyEnabled

    var body: some View {
        let calendar: Calendar = Calendar.current
        let now: Date = Date()
        let slots: [ShortNightSlot] = ShortNightInputs.slots(shifts: shifts, sessions: sessions)
        let upcoming: ShortNightResult? = ShortNightRules.nextNight(now: now, slots: slots,
                                                                    thresholdMinutes: threshold, calendar: calendar)
        return PLTScreen(title: "Alerte nuit courte") {
            PLTCard {
                Stepper(value: $threshold,
                        in: ShortNightRules.minThresholdMinutes...ShortNightRules.maxThresholdMinutes,
                        step: 30) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Seuil de repos")
                            .font(.body)
                            .foregroundStyle(palette.textPrimary)
                        Text(Formatting.duration(minutes: threshold))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(minHeight: 44)
                .onChange(of: threshold) { (_: Int, newValue: Int) in
                    let settings: ShortNightSettings = ShortNightSettings()
                    settings.thresholdMinutes = newValue
                }
                .accessibilityLabel("Seuil de repos, \(Formatting.duration(minutes: threshold))")
                Toggle("Notification la veille à 20:00", isOn: $notifyEnabled)
                    .frame(minHeight: 44)
                    .onChange(of: notifyEnabled) { (_: Bool, newValue: Bool) in
                        let settings: ShortNightSettings = ShortNightSettings()
                        settings.notifyEnabled = newValue
                    }
            }
            if let result = upcoming {
                PLTBanner(kind: result.isShort ? .warning : .info,
                          title: result.isShort ? "Prochaine nuit courte" : "Prochaine nuit",
                          message: ShortNightRules.message(result, calendar: calendar))
            } else {
                Text("Je n'ai pas de fin de journée suivie d'un début le lendemain dans ton planning pour l'instant.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            Text("Je compare la fin de ta dernière session (prévue ou faite) et le début de ton prochain cours ou taf. C'est un maximum de temps pour dormir, pas un conseil de santé. Ce seuil est le tien : il est distinct du repos minimal du droit du travail.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }
}
