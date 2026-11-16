import Foundation
import SwiftData
import UserNotifications

/// Résultat d'une tentative d'envoi.
enum DetectionNotifyOutcome: Equatable {
    case queued(body: String)
    case skipped(reason: String)
}

/// Session à corriger demandée depuis une notification : les vues la lisent plus tard.
struct PendingCorrectionStore {
    static let key: String = "plt.pendingCorrectionSessionUID"
    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    var sessionUID: UUID? {
        guard let text = defaults.string(forKey: PendingCorrectionStore.key) else { return nil }
        return UUID(uuidString: text)
    }

    func set(_ uid: UUID) {
        defaults.set(uid.uuidString, forKey: PendingCorrectionStore.key)
    }

    func clear() {
        defaults.removeObject(forKey: PendingCorrectionStore.key)
    }
}

/// Notifications locales de détection (section 45) : actions "Oui, c'est bon" et "Corriger".
@MainActor
final class DetectionNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let confirmCategory: String = "plt.detection.confirm"
    static let doubtCategory: String = "plt.detection.doubt"
    static let confirmActionID: String = "plt.action.confirm"
    static let correctActionID: String = "plt.action.correct"
    private static let sentDatesKey: String = "plt.notifications.sentDates"

    private let container: ModelContainer
    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    private let calendarProvider: () -> Calendar

    init(container: ModelContainer,
         defaults: UserDefaults = UserDefaults.standard,
         center: UNUserNotificationCenter = UNUserNotificationCenter.current(),
         calendarProvider: @escaping () -> Calendar = { Calendar.current }) {
        self.container = container
        self.defaults = defaults
        self.center = center
        self.calendarProvider = calendarProvider
        super.init()
    }

    var pendingCorrection: PendingCorrectionStore {
        return PendingCorrectionStore(defaults: defaults)
    }

    /// À appeler au lancement, avant la fin du démarrage de l'app (le delegate doit exister quand une action arrive).
    func install() {
        center.delegate = self
        let confirm = UNNotificationAction(identifier: DetectionNotifier.confirmActionID,
                                           title: "Oui, c'est bon", options: [])
        let correct = UNNotificationAction(identifier: DetectionNotifier.correctActionID,
                                           title: "Corriger", options: [.foreground])
        let confirmCategory = UNNotificationCategory(identifier: DetectionNotifier.confirmCategory,
                                                     actions: [confirm, correct],
                                                     intentIdentifiers: [], options: [])
        let doubtCategory = UNNotificationCategory(identifier: DetectionNotifier.doubtCategory,
                                                   actions: [correct],
                                                   intentIdentifiers: [], options: [])
        center.setNotificationCategories([confirmCategory, doubtCategory])
    }

    // MARK: Envoi

    private func sentDates() -> [Date] {
        let raw: [Double] = (defaults.array(forKey: DetectionNotifier.sentDatesKey) as? [Double]) ?? []
        return raw.map { Date(timeIntervalSince1970: $0) }
    }

    private func remember(_ date: Date) {
        var raw: [Double] = (defaults.array(forKey: DetectionNotifier.sentDatesKey) as? [Double]) ?? []
        raw.append(date.timeIntervalSince1970)
        if raw.count > 60 { raw = Array(raw.suffix(60)) }
        defaults.set(raw, forKey: DetectionNotifier.sentDatesKey)
    }

    /// Programme la notification d'une borne si les limites le permettent. Un identifiant par session et par borne :
    /// un doublon remplace l'ancienne notification au lieu de s'ajouter.
    func notify(kind: DetectionNotificationKind, sessionUID: UUID, placeName: String, placeType: PlaceType,
                bound: Date, now: Date = Date()) -> DetectionNotifyOutcome {
        let calendar: Calendar = calendarProvider()
        let verdict: DetectionNotificationRules.Verdict = DetectionNotificationRules.verdict(now: now, sentDates: sentDates(), calendar: calendar)
        switch verdict {
        case .quietHours:
            return .skipped(reason: "heures silencieuses")
        case .dailyLimitReached:
            return .skipped(reason: "maximum quotidien atteint")
        case .send:
            break
        }
        let text: DetectionNotificationText = DetectionNotificationRules.text(kind: kind, placeName: placeName,
                                                                              placeType: placeType, bound: bound, calendar: calendar)
        let inDoubt: Bool = DetectionNotificationRules.isInDoubtZone(bound, calendar: calendar)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = inDoubt ? DetectionNotifier.doubtCategory : DetectionNotifier.confirmCategory
        content.userInfo = ["sessionUID": sessionUID.uuidString, "kind": kind.rawValue, "doubt": inDoubt]
        let request = UNNotificationRequest(identifier: "plt.\(kind.rawValue).\(sessionUID.uuidString)",
                                            content: content, trigger: nil)
        center.add(request) { _ in }
        remember(now)
        return .queued(body: text.body)
    }

    // MARK: Réponses

    private func log(_ kind: DetectionEventKind, detail: String) {
        let context: ModelContext = container.mainContext
        context.insert(DetectionEvent(kind: kind, detail: detail))
        try? context.save()
    }

    private func session(with uid: UUID) -> WorkSession? {
        let context: ModelContext = container.mainContext
        let all: [WorkSession] = (try? context.fetch(FetchDescriptor<WorkSession>())) ?? []
        return all.first { $0.uid == uid }
    }

    func handleResponse(actionID: String, sessionUIDText: String?, isDoubt: Bool) {
        guard let text = sessionUIDText, let uid = UUID(uuidString: text) else { return }
        if actionID == DetectionNotifier.confirmActionID {
            if let s = session(with: uid) {
                s.isConfirmed = true
                try? container.mainContext.save()
                log(.arrivalConfirmed, detail: "Confirmé depuis la notification (session \(uid.uuidString))")
            }
        } else if actionID == DetectionNotifier.correctActionID
                    || (actionID == UNNotificationDefaultActionIdentifier && isDoubt) {
            // Le tap simple ouvre l'app : on retient la session à corriger seulement pour un doute ou l'action "Corriger".
            pendingCorrection.set(uid)
            log(.userCorrected, detail: "Correction demandée depuis la notification (session \(uid.uuidString))")
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID: String = response.actionIdentifier
        let uidText: String? = response.notification.request.content.userInfo["sessionUID"] as? String
        let doubt: Bool = (response.notification.request.content.userInfo["doubt"] as? Bool) ?? false
        Task { @MainActor in
            self.handleResponse(actionID: actionID, sessionUIDText: uidText, isDoubt: doubt)
            completionHandler()
        }
    }
}
