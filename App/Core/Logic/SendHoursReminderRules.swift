import Foundation

/// Jour, heure et minute du rappel mensuel d'envoi des heures (module send_hours_reminder).
struct SendHoursReminderSettings: Equatable {
    /// 0 = dernier jour du mois, sinon 1 à 31 (un jour absent du mois tombe sur son dernier jour).
    var dayOfMonth: Int
    var hour: Int
    var minute: Int

    static let lastDayOfMonth: Int = 0
    /// Par défaut : dernier jour du mois à 18:00.
    static let standard: SendHoursReminderSettings = SendHoursReminderSettings(dayOfMonth: 0, hour: 18, minute: 0)

    /// Valeurs ramenées dans leurs bornes (jour 0 à 31, heure 0 à 23, minute 0 à 59).
    var clamped: SendHoursReminderSettings {
        return SendHoursReminderSettings(dayOfMonth: max(0, min(31, dayOfMonth)),
                                         hour: max(0, min(23, hour)),
                                         minute: max(0, min(59, minute)))
    }
}

/// Calcul des prochaines dates du rappel. Logique pure (Foundation).
enum SendHoursReminderRules {
    static let title: String = "Rappel d'envoi des heures"
    /// Texte fixe : le total n'est pas connu au moment où iOS déclenche la notification, donc aucun chiffre.
    static let body: String = "C'est le moment d'envoyer tes heures."

    /// Date du rappel pour le mois qui contient `monthReference`, nil si le calendrier ne sait pas la construire.
    static func fireDate(inMonthOf monthReference: Date, settings: SendHoursReminderSettings, calendar: Calendar) -> Date? {
        let s: SendHoursReminderSettings = settings.clamped
        let monthComps: DateComponents = calendar.dateComponents([.year, .month], from: monthReference)
        guard let monthStart = calendar.date(from: monthComps),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let daysInMonth: Int = range.count
        let day: Int = (s.dayOfMonth == SendHoursReminderSettings.lastDayOfMonth) ? daysInMonth : min(s.dayOfMonth, daysInMonth)
        var c: DateComponents = DateComponents()
        c.year = monthComps.year
        c.month = monthComps.month
        c.day = day
        c.hour = s.hour
        c.minute = s.minute
        c.second = 0
        return calendar.date(from: c)
    }

    /// Les `count` prochaines dates strictement après `now`, dans l'ordre.
    static func upcomingFireDates(after now: Date, count: Int, settings: SendHoursReminderSettings, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        if count <= 0 { return result }
        var offset: Int = 0
        while result.count < count && offset < count + 14 {
            if let month = calendar.date(byAdding: .month, value: offset, to: now),
               let fire = fireDate(inMonthOf: month, settings: settings, calendar: calendar),
               fire > now {
                result.append(fire)
            }
            offset += 1
        }
        return result
    }

    /// Prochaine date strictement après `now`, nil si introuvable.
    static func nextFireDate(after now: Date, settings: SendHoursReminderSettings, calendar: Calendar) -> Date? {
        return upcomingFireDates(after: now, count: 1, settings: settings, calendar: calendar).first
    }
}
