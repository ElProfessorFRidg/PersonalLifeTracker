import Foundation
import SwiftUI
import UserNotifications

/// Programme les rappels mensuels d'envoi des heures (notifications locales, aucune donnée ne quitte l'iPhone).
/// On garde les 3 prochaines dates programmées : si l'app n'est pas ouverte un mois, le suivant arrive quand même.
/// Reprogrammé à chaque activation de l'app, annulé quand le module est coupé.
struct SendHoursReminderScheduler {
    static let identifierPrefix: String = "plt.sendHoursReminder."
    static let slotCount: Int = 3
    static let dayKey: String = "plt.sendHoursReminder.day"
    static let hourKey: String = "plt.sendHoursReminder.hour"
    static let minuteKey: String = "plt.sendHoursReminder.minute"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    // MARK: Réglage enregistré

    var settings: SendHoursReminderSettings {
        let standard: SendHoursReminderSettings = SendHoursReminderSettings.standard
        let day: Int = defaults.object(forKey: SendHoursReminderScheduler.dayKey) as? Int ?? standard.dayOfMonth
        let hour: Int = defaults.object(forKey: SendHoursReminderScheduler.hourKey) as? Int ?? standard.hour
        let minute: Int = defaults.object(forKey: SendHoursReminderScheduler.minuteKey) as? Int ?? standard.minute
        return SendHoursReminderSettings(dayOfMonth: day, hour: hour, minute: minute).clamped
    }

    func save(_ value: SendHoursReminderSettings) {
        let s: SendHoursReminderSettings = value.clamped
        defaults.set(s.dayOfMonth, forKey: SendHoursReminderScheduler.dayKey)
        defaults.set(s.hour, forKey: SendHoursReminderScheduler.hourKey)
        defaults.set(s.minute, forKey: SendHoursReminderScheduler.minuteKey)
    }

    // MARK: Notifications

    private static var allIdentifiers: [String] {
        var ids: [String] = []
        for i in 0..<slotCount { ids.append(identifierPrefix + String(i)) }
        return ids
    }

    /// Vrai si iOS autorise déjà les notifications.
    func isAuthorized() async -> Bool {
        let current: UNNotificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Demande l'autorisation si elle n'a jamais été demandée. Retourne l'état final.
    func requestAuthorizationIfNeeded() async -> Bool {
        let current: UNNotificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        if current.authorizationStatus == .notDetermined {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            } catch {
                // Une erreur se lit comme un refus : l'état est relu ci-dessous.
            }
        }
        return await isAuthorized()
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: SendHoursReminderScheduler.allIdentifiers)
    }

    /// Remplace les rappels programmés. `enabled` faux (module coupé) ou notifications refusées : tout est annulé.
    func reschedule(enabled: Bool, now: Date = Date(), calendar: Calendar = Calendar.current) async {
        cancelAll()
        if !enabled { return }
        let allowed: Bool = await isAuthorized()
        if !allowed { return }
        let dates: [Date] = SendHoursReminderRules.upcomingFireDates(after: now,
                                                                     count: SendHoursReminderScheduler.slotCount,
                                                                     settings: settings, calendar: calendar)
        for (index, date) in dates.enumerated() {
            let content: UNMutableNotificationContent = UNMutableNotificationContent()
            content.title = SendHoursReminderRules.title
            content.body = SendHoursReminderRules.body
            content.sound = UNNotificationSound.default
            let comps: DateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger: UNCalendarNotificationTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request: UNNotificationRequest = UNNotificationRequest(identifier: SendHoursReminderScheduler.identifierPrefix + String(index),
                                                                       content: content, trigger: trigger)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                // Un rappel raté sera reprogrammé à la prochaine ouverture de l'app.
            }
        }
    }
}

/// Reprogramme le rappel à chaque activation de l'app et quand le module est activé ou coupé.
/// À appliquer AVANT les `.environment(...)` dans l'App, pour lire ModuleStore.
struct SendHoursReminderActivation: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ModuleStore.self) private var modules

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { (_: ScenePhase, phase: ScenePhase) in
                if phase == .active { refresh() }
            }
            .onChange(of: modules.isActive("send_hours_reminder")) { (_: Bool, _: Bool) in
                refresh()
            }
    }

    private func refresh() {
        let on: Bool = modules.isActive("send_hours_reminder")
        Task {
            await SendHoursReminderScheduler().reschedule(enabled: on)
        }
    }
}
