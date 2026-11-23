import Foundation

/// Période d'examens et choix "Pas aujourd'hui", gardés en local (UserDefaults, JSON).
struct ExamModeStore {
    static let periodKey: String = "plt.exam.period"
    static let skippedDayKey: String = "plt.exam.skippedDay"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    func period() -> ExamPeriod? {
        guard let data = defaults.data(forKey: ExamModeStore.periodKey) else { return nil }
        return try? JSONDecoder().decode(ExamPeriod.self, from: data)
    }

    func save(_ period: ExamPeriod?) {
        if let period = period, let data = try? JSONEncoder().encode(period) {
            defaults.set(data, forKey: ExamModeStore.periodKey)
        } else {
            defaults.removeObject(forKey: ExamModeStore.periodKey)
        }
    }

    var skippedDay: String? {
        return defaults.string(forKey: ExamModeStore.skippedDayKey)
    }

    func skipToday(now: Date, calendar: Calendar) {
        defaults.set(SchoolCalendarRules.dayText(now, calendar: calendar), forKey: ExamModeStore.skippedDayKey)
    }

    func clearSkip() {
        defaults.removeObject(forKey: ExamModeStore.skippedDayKey)
    }
}

/// Façade pour les autres modules : le mode examens est-il en cours, un message a-t-il le droit de partir ?
/// Sans le module actif, rien ne change (le module est une période, jamais une obligation).
enum ExamMode {
    static func isActive(now: Date = Date(), calendar: Calendar = Calendar.current,
                         store: ExamModeStore = ExamModeStore()) -> Bool {
        return ExamModeRules.isActive(store.period(), now: now, calendar: calendar)
    }

    static func allows(_ kind: ExamNotificationClass, now: Date = Date(), calendar: Calendar = Calendar.current,
                       store: ExamModeStore = ExamModeStore()) -> Bool {
        return ExamModeRules.allows(kind, period: store.period(), now: now, calendar: calendar)
    }
}
