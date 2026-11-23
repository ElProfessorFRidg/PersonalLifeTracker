import Foundation

/// Accès au calendrier scolaire : données du bundle, pauses de l'utilisateur et zone, tout en local.
/// `SchoolCalendar.isHoliday(_:)` et `SchoolCalendar.isSchoolBreak(_:)` sont faits pour les autres modules
/// (planning, heures du contrat, majorations).
struct SchoolCalendarStore {
    static let zoneKey: String = "plt.school.zone"
    static let userBreaksKey: String = "plt.school.userBreaks"
    static let resourceName: String = "school_calendar"

    let defaults: UserDefaults
    let bundle: Bundle

    init(defaults: UserDefaults = UserDefaults.standard, bundle: Bundle = Bundle.main) {
        self.defaults = defaults
        self.bundle = bundle
    }

    // MARK: Zone

    /// Zone choisie. Nil tant que l'utilisateur n'a pas choisi : seules les plages communes comptent.
    var zone: SchoolZone? {
        get {
            guard let raw = defaults.string(forKey: SchoolCalendarStore.zoneKey) else { return nil }
            return SchoolZone(rawValue: raw)
        }
        nonmutating set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: SchoolCalendarStore.zoneKey)
            } else {
                defaults.removeObject(forKey: SchoolCalendarStore.zoneKey)
            }
        }
    }

    // MARK: Données du bundle

    /// Données du fichier JSON. Un fichier absent ou cassé donne une liste vide, jamais un plantage.
    func bundledData() -> SchoolCalendarData {
        let empty = SchoolCalendarData(source: "Aucune donnée de vacances lisible dans l'app.",
                                       verificationNote: "Ajoute les vacances toi-même dans cet écran.",
                                       breaks: [])
        guard let url = bundle.url(forResource: SchoolCalendarStore.resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(SchoolCalendarData.self, from: data) else {
            return empty
        }
        return decoded
    }

    // MARK: Pauses de l'utilisateur

    func userBreaks() -> [SchoolBreak] {
        guard let data = defaults.data(forKey: SchoolCalendarStore.userBreaksKey),
              let list = try? JSONDecoder().decode([SchoolBreak].self, from: data) else { return [] }
        return list
    }

    func saveUserBreaks(_ list: [SchoolBreak]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: SchoolCalendarStore.userBreaksKey)
        }
    }

    /// Toutes les plages : celles du bundle puis celles de l'utilisateur.
    func allBreaks() -> [SchoolBreak] {
        var result: [SchoolBreak] = bundledData().breaks
        result.append(contentsOf: userBreaks())
        return result
    }
}

/// Façade pour les autres modules.
enum SchoolCalendar {
    /// Jour férié français (calculé, sans donnée).
    static func isHoliday(_ day: Date, calendar: Calendar = Calendar.current) -> Bool {
        return SchoolCalendarRules.isPublicHoliday(day, calendar: calendar)
    }

    /// Nom du jour férié, s'il y en a un.
    static func holidayName(_ day: Date, calendar: Calendar = Calendar.current) -> String? {
        return SchoolCalendarRules.holiday(on: day, calendar: calendar)?.name
    }

    /// Jour de vacances scolaires ou de pause de l'utilisateur, pour la zone choisie.
    static func isSchoolBreak(_ day: Date, calendar: Calendar = Calendar.current,
                              store: SchoolCalendarStore = SchoolCalendarStore()) -> Bool {
        return SchoolCalendarRules.isSchoolBreak(day, in: store.allBreaks(), zone: store.zone, calendar: calendar)
    }
}
