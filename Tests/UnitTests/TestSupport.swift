import Foundation

/// Calendriers et dates de test. Les dates sont construites à la main à partir de composantes, jamais copiées d'une sortie du code testé.
enum TestCalendar {
    static func make(_ identifier: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: identifier)!
        return c
    }

    static let utc: Calendar = TestCalendar.make("UTC")
    static let paris: Calendar = TestCalendar.make("Europe/Paris")
}

func makeDate(_ cal: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    var c = DateComponents()
    c.year = year
    c.month = month
    c.day = day
    c.hour = hour
    c.minute = minute
    c.second = second
    return cal.date(from: c)!
}

/// 16 novembre 2026 (un lundi) en UTC.
func nov16(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    return makeDate(TestCalendar.utc, 2026, 11, 16, hour, minute, second)
}

/// 17 novembre 2026 en UTC.
func nov17(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    return makeDate(TestCalendar.utc, 2026, 11, 17, hour, minute, second)
}

/// UserDefaults isolé pour un test. Appeler `removePersistentDomain(forName:)` avec `name` en fin de test.
func makeIsolatedDefaults() -> (defaults: UserDefaults, name: String) {
    let name = "PLTTests.\(UUID().uuidString)"
    return (UserDefaults(suiteName: name)!, name)
}
