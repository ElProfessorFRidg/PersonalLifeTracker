import Foundation
import UserNotifications

/// Réglages de l'alerte nuit courte (UserDefaults).
struct ShortNightSettings {
    static let thresholdKey: String = "plt.shortnight.thresholdMinutes"
    static let notifyKey: String = "plt.shortnight.notify"

    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    var thresholdMinutes: Int {
        get {
            let stored: Int = defaults.integer(forKey: ShortNightSettings.thresholdKey)
            if stored == 0 { return ShortNightRules.defaultThresholdMinutes }
            return max(ShortNightRules.minThresholdMinutes, min(ShortNightRules.maxThresholdMinutes, stored))
        }
        nonmutating set {
            defaults.set(newValue, forKey: ShortNightSettings.thresholdKey)
        }
    }

    /// Notification la veille, activée par défaut (désactivable).
    var notifyEnabled: Bool {
        get {
            if defaults.object(forKey: ShortNightSettings.notifyKey) == nil { return true }
            return defaults.bool(forKey: ShortNightSettings.notifyKey)
        }
        nonmutating set {
            defaults.set(newValue, forKey: ShortNightSettings.notifyKey)
        }
    }
}

/// Programme (ou retire) la notification locale de nuit courte. Ne demande jamais l'autorisation :
/// sans autorisation iOS, rien n'est programmé. Une seule notification en attente à la fois.
enum ShortNightNotifier {
    static let identifier: String = "plt.shortnight.next"

    /// Programme la notification de la veille pour `result`, ou retire l'ancienne s'il n'y a rien à dire.
    /// `allowedByExamMode` : faux pendant une période d'examens (les rappels se taisent).
    static func refresh(result: ShortNightResult?, now: Date, calendar: Calendar, enabled: Bool, allowedByExamMode: Bool) async {
        let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled, allowedByExamMode, let result = result, result.isShort else { return }
        guard let fire = ShortNightRules.notificationDate(for: result, now: now, calendar: calendar) else { return }
        let settings: UNNotificationSettings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined, .denied:
            return
        @unknown default:
            return
        }
        let content = UNMutableNotificationContent()
        content.title = ShortNightRules.title
        content.body = ShortNightRules.message(result, calendar: calendar)
        content.sound = UNNotificationSound.default
        let parts: DateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            // Un échec de programmation n'est pas grave : la carte de l'Accueil reste là.
        }
    }
}
