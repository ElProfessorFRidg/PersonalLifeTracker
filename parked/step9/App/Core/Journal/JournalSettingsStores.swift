import Foundation
import Observation

/// Réglages du module Pauses (UserDefaults).
@Observable
final class BreakSettingsStore {
    static let shared: BreakSettingsStore = BreakSettingsStore()

    private static let modeKey: String = "plt.breaks.mode"
    private static let paidKey: String = "plt.breaks.paid"
    private static let hoursKey: String = "plt.breaks.reminderHours"
    private static let remindedKey: String = "plt.breaks.remindedSessions"

    /// Aucune, info ou rappel. Défaut : aucune (les pauses ne sont jamais imposées, spec 32).
    private(set) var mode: BreakMode
    /// Pause payée : vrai = rien n'est déduit du temps de travail. Défaut : non payée (mon choix).
    private(set) var isPaid: Bool
    private(set) var reminderHours: Double

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        let rawMode: String = defaults.string(forKey: BreakSettingsStore.modeKey) ?? BreakMode.none.rawValue
        self.mode = BreakMode(rawValue: rawMode) ?? BreakMode.none
        self.isPaid = defaults.bool(forKey: BreakSettingsStore.paidKey)
        let storedHours: Double = defaults.double(forKey: BreakSettingsStore.hoursKey)
        self.reminderHours = storedHours > 0 ? storedHours : BreaksRules.defaultReminderHours
    }

    func setMode(_ newValue: BreakMode) {
        mode = newValue
        defaults.set(newValue.rawValue, forKey: BreakSettingsStore.modeKey)
    }

    func setPaid(_ newValue: Bool) {
        isPaid = newValue
        defaults.set(newValue, forKey: BreakSettingsStore.paidKey)
    }

    func setReminderHours(_ newValue: Double) {
        let clamped: Double = min(max(newValue, BreaksRules.minReminderHours), BreaksRules.maxReminderHours)
        reminderHours = clamped
        defaults.set(clamped, forKey: BreakSettingsStore.hoursKey)
    }

    /// Sessions déjà rappelées (un seul rappel par session).
    func hasReminded(sessionUID: UUID) -> Bool {
        let list: [String] = defaults.stringArray(forKey: BreakSettingsStore.remindedKey) ?? []
        return list.contains(sessionUID.uuidString)
    }

    func markReminded(sessionUID: UUID) {
        var list: [String] = defaults.stringArray(forKey: BreakSettingsStore.remindedKey) ?? []
        if list.contains(sessionUID.uuidString) { return }
        list.append(sessionUID.uuidString)
        if list.count > 50 { list = Array(list.suffix(50)) }
        defaults.set(list, forKey: BreakSettingsStore.remindedKey)
    }
}

/// Réglage de trajet propre à un lieu.
struct PlaceTravelSetting: Codable, Equatable {
    var modeRaw: String
    var notify: Bool
}

/// Réglages du module Trajet (section 35).
struct TravelSettings: Codable, Equatable {
    var defaultModeRaw: String = TravelMode.walking.rawValue
    var marginMinutes: Int = TravelDepartureRules.defaultMarginMinutes
    var windowMinutes: Int = TravelDepartureRules.defaultWindowMinutes
    var fallbackMinutes: Int = TravelDepartureRules.defaultFallbackTravelMinutes
    /// Notification activée par défaut pour les lieux sans réglage propre. Défaut : non.
    var notifyByDefault: Bool = false
    /// Réglages par lieu, clé = `Place.uid.uuidString`.
    var places: [String: PlaceTravelSetting] = [:]

    var defaultMode: TravelMode {
        return TravelMode(rawValue: defaultModeRaw) ?? TravelMode.walking
    }

    func mode(for placeUID: UUID) -> TravelMode {
        if let s = places[placeUID.uuidString], let m = TravelMode(rawValue: s.modeRaw) { return m }
        return defaultMode
    }

    func notifies(for placeUID: UUID) -> Bool {
        if let s = places[placeUID.uuidString] { return s.notify }
        return notifyByDefault
    }

    mutating func setMode(_ mode: TravelMode, for placeUID: UUID) {
        let current: Bool = notifies(for: placeUID)
        places[placeUID.uuidString] = PlaceTravelSetting(modeRaw: mode.rawValue, notify: current)
    }

    mutating func setNotify(_ notify: Bool, for placeUID: UUID) {
        let current: TravelMode = mode(for: placeUID)
        places[placeUID.uuidString] = PlaceTravelSetting(modeRaw: current.rawValue, notify: notify)
    }
}

@Observable
final class TravelSettingsStore {
    static let shared: TravelSettingsStore = TravelSettingsStore()
    private static let key: String = "plt.travel.settings"

    private(set) var settings: TravelSettings

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: TravelSettingsStore.key),
           let decoded = try? JSONDecoder().decode(TravelSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = TravelSettings()
        }
    }

    /// Modifie les réglages puis les enregistre.
    func update(_ change: (inout TravelSettings) -> Void) {
        var copy: TravelSettings = settings
        change(&copy)
        settings = copy
        if let data = try? JSONEncoder().encode(copy) {
            defaults.set(data, forKey: TravelSettingsStore.key)
        }
    }
}

/// Créneaux "Ignorer" de la détection d'heures manquantes, avec la date, oubliés après 30 jours.
@Observable
final class MissingHoursIgnoreStore {
    static let shared: MissingHoursIgnoreStore = MissingHoursIgnoreStore()
    private static let key: String = "plt.missingHours.ignored"
    /// Clé utilisée par la section Planning existante (PlannedWorkReviewSection) : ses "Ignorer" restent valables.
    private static let legacyKey: String = "plt.planning.dismissedWorkReviews"

    private struct LegacyDismissal: Codable {
        let date: Date
        let reason: String
    }

    private(set) var ignored: [String: Date] = [:]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        self.ignored = loadAll()
    }

    /// Identifiants à exclure de la détection (ceux de moins de 30 jours).
    func activeIDs(now: Date = Date()) -> Set<String> {
        let limit: TimeInterval = Double(MissingHoursRules.ignoreRetentionDays) * 86400
        var result: Set<String> = []
        for (id, date) in ignored where now.timeIntervalSince(date) < limit {
            result.insert(id)
        }
        return result
    }

    func ignore(id: String, now: Date = Date()) {
        ignored[id] = now
        save()
    }

    func unignore(id: String) {
        ignored[id] = nil
        save()
    }

    func resetAll() {
        ignored = [:]
        save()
    }

    private func loadAll() -> [String: Date] {
        var result: [String: Date] = [:]
        if let data = defaults.data(forKey: MissingHoursIgnoreStore.legacyKey),
           let legacy = try? JSONDecoder().decode([String: LegacyDismissal].self, from: data) {
            for (id, value) in legacy { result[id] = value.date }
        }
        if let data = defaults.data(forKey: MissingHoursIgnoreStore.key),
           let own = try? JSONDecoder().decode([String: Date].self, from: data) {
            for (id, date) in own { result[id] = date }
        }
        return result
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ignored) {
            defaults.set(data, forKey: MissingHoursIgnoreStore.key)
        }
    }
}
