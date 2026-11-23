import SwiftUI

/// Réglage du rappel mensuel d'envoi des heures (affiché dans Réglages quand le module send_hours_reminder est actif).
struct SendHoursReminderCard: View {
    @Environment(\.palette) private var palette

    @State private var current: SendHoursReminderSettings = SendHoursReminderScheduler().settings
    @State private var notificationsBlocked: Bool = false

    private var dayBinding: Binding<Int> {
        return Binding<Int>(get: { current.dayOfMonth },
                            set: { (newValue: Int) in
                                current.dayOfMonth = newValue
                                commit()
                            })
    }

    private var timeBinding: Binding<Date> {
        return Binding<Date>(get: {
            let cal: Calendar = Calendar.current
            var c: DateComponents = cal.dateComponents([.year, .month, .day], from: Date())
            c.hour = current.hour
            c.minute = current.minute
            return cal.date(from: c) ?? Date()
        }, set: { (newValue: Date) in
            let c: DateComponents = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            current.hour = c.hour ?? 18
            current.minute = c.minute ?? 0
            commit()
        })
    }

    private var dayChoices: [Int] {
        return Array(1...28)
    }

    private var nextText: String {
        let cal: Calendar = Calendar.current
        guard let next = SendHoursReminderRules.nextFireDate(after: Date(), settings: current, calendar: cal) else {
            return "Pas de prochain rappel trouvé."
        }
        return "Prochain rappel : \(HoursSummaryText.dayLabel(next, calendar: cal)) à \(Formatting.clock(next, calendar: cal))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Rappel d'envoi des heures")
            if notificationsBlocked {
                PLTBanner(kind: .warning,
                          title: "Les notifications sont coupées",
                          message: "Active-les pour Life Tracker dans les réglages iOS, sinon le rappel ne sonnera pas.")
            }
            PLTCard {
                HStack {
                    Text("Jour")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Jour du rappel", selection: dayBinding) {
                        Text("Dernier jour du mois").tag(0)
                        ForEach(dayChoices, id: \.self) { (day: Int) in
                            Text("Le \(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 44)
                DatePicker("Heure", selection: timeBinding, displayedComponents: [.hourAndMinute])
                    .frame(minHeight: 44)
                Text(nextText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
                    .frame(minHeight: 44, alignment: .leading)
            }
            Text("Une notification sur ton iPhone, sans chiffre. Rien ne quitte ton téléphone.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
        .task {
            let ok: Bool = await SendHoursReminderScheduler().requestAuthorizationIfNeeded()
            notificationsBlocked = !ok
            await SendHoursReminderScheduler().reschedule(enabled: true)
        }
    }

    private func commit() {
        let value: SendHoursReminderSettings = current
        SendHoursReminderScheduler().save(value)
        Task {
            let ok: Bool = await SendHoursReminderScheduler().requestAuthorizationIfNeeded()
            notificationsBlocked = !ok
            await SendHoursReminderScheduler().reschedule(enabled: true)
        }
    }
}
