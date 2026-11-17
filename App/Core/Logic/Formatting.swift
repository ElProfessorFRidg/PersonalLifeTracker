import Foundation

/// Formats français des heures et durées (24 h, "3 h 04", "25 min"). Logique pure, sans SwiftUI.
enum Formatting {
    private static func two(_ n: Int) -> String {
        return n < 10 ? "0\(n)" : "\(n)"
    }

    /// Durée en minutes : "25 min", "3 h 04", "4 h 00". Les valeurs négatives donnent "0 min".
    static func duration(minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m) min" }
        return "\(m / 60) h \(two(m % 60))"
    }

    /// Durée en secondes, tronquée à la minute inférieure (3 h 04 min 59 s donne "3 h 04").
    static func duration(seconds: Int) -> String {
        return duration(minutes: max(0, seconds) / 60)
    }

    /// Heure 24 h depuis minuit : 485 donne "08:05", 1440 donne "24:00".
    static func clock(minutesFromMidnight m: Int) -> String {
        let v = max(0, m)
        return "\(two(v / 60)):\(two(v % 60))"
    }

    /// Heure 24 h d'un instant dans le calendrier donné (fuseau compris).
    static func clock(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return clock(minutesFromMidnight: (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    /// Heure 24 h depuis une heure décimale (17.5 donne "17:30").
    static func clock(hour: Double) -> String {
        return clock(minutesFromMidnight: Int((hour * 60).rounded()))
    }

    /// Grand chrono : 4447 donne "1:14:07", 847 donne "14:07", 7 donne "0:07".
    static func timer(seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return "\(h):\(two(m)):\(two(r))" }
        return "\(m):\(two(r))"
    }

    /// Marge d'erreur d'un horodatage : "à plus ou moins 3 min".
    static func margin(minutes: Int) -> String {
        return "à plus ou moins \(max(0, minutes)) min"
    }

    /// "lundi 16 novembre" dans le fuseau du calendrier.
    static func dayTitle(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }
}

/// Montants : séparateur de milliers (espace fine insécable), virgule décimale, symbole après.
enum MoneyFormat {
    static func format(amount: Double, symbol: String, fractionDigits: Int) -> String {
        let digits = max(0, min(fractionDigits, 3))
        var factor: Double = 1
        for _ in 0..<digits { factor *= 10 }
        let scaled = (abs(amount) * factor).rounded()
        let total = Int(scaled)
        let intPart = total / Int(factor)
        let fracPart = total % Int(factor)

        var groups: [String] = []
        var rest = intPart
        if rest == 0 { groups.append("0") }
        while rest > 0 {
            let chunk = rest % 1000
            rest = rest / 1000
            if rest > 0 {
                let s = String(chunk)
                groups.insert(String(repeating: "0", count: 3 - s.count) + s, at: 0)
            } else {
                groups.insert(String(chunk), at: 0)
            }
        }
        var text = groups.joined(separator: "\u{202F}")
        if digits > 0 {
            let f = String(fracPart)
            text += "," + String(repeating: "0", count: digits - f.count) + f
        }
        let negative = amount < 0 && total != 0
        return (negative ? "-" : "") + text + "\u{00A0}" + symbol
    }
}
