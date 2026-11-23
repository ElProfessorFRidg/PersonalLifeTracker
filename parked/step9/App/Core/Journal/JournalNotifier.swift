import Foundation
import UserNotifications

/// Notifications locales des modules Pauses et Trajet. Un identifiant stable : replanifier remplace la précédente.
enum JournalNotifier {

    static let breakIdentifierPrefix: String = "plt.break."
    static let travelIdentifierPrefix: String = "plt.travel."

    /// Demande l'autorisation (la réponse arrive sur un thread quelconque).
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted: Bool, _: Error?) in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Planifie une notification à `date`. Ne fait rien si la date est dans moins d'une seconde.
    static func schedule(identifier: String, title: String, body: String, at date: Date) {
        let interval: TimeInterval = date.timeIntervalSinceNow
        if interval < 1 { return }
        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        let trigger: UNTimeIntervalNotificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request: UNNotificationRequest = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request) { (_: Error?) in }
    }

    static func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
