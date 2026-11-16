import Foundation

// Export du mois de paie en JSON et CSV (section 20.2 : relevé d'heures mensuel). Logique pure, testée.
// Le PDF n'est pas fait. Tout est une estimation, et le fichier le dit.
// CSV : séparateur ";" et virgule décimale (Excel et Numbers en français), UTF-8 avec BOM ajouté seulement à l'écriture du fichier.

struct PayExportRate: Codable, Equatable {
    /// Taux horaire brut en texte décimal avec point ("12.02").
    var hourlyGross: String
    var seconds: Int
    var grossCents: Int
}

struct PayExportDay: Codable, Equatable {
    /// "2026-11-16"
    var date: String
    var sessionCount: Int
    var exactSeconds: Int
    var fullHoursSeconds: Int
    var retainedSeconds: Int
    /// Borne en zone de doute sans choix : valeur exacte comptée.
    var hasUnresolvedDoubt: Bool
    var isOngoing: Bool
    var hourlyGross: String?
}

struct PayExportDocument: Codable, Equatable {
    var app: String
    var formatVersion: Int
    var kind: String
    var isEstimate: Bool
    var disclaimer: String
    var exportedAt: Date
    /// "2026-11"
    var month: String
    var currencyCode: String
    /// "fullHours" ou "exact"
    var base: String
    var netRatio: String
    var retainedSeconds: Int
    var exactSeconds: Int
    var fullHoursSeconds: Int
    var unratedSeconds: Int
    var grossCents: Int
    var netCents: Int
    var sessionCount: Int
    var doubtSessionCount: Int
    var liveSessionCount: Int
    var unconfirmedSessionCount: Int
    var rates: [PayExportRate]
    var days: [PayExportDay]
}

enum PayExport {
    static let appName: String = "PersonalLifeTracker"
    static let currentFormatVersion: Int = 1
    static let disclaimer: String = "Estimation d'après tes sessions et les taux que tu as saisis. Ta fiche de paie fait foi."

    // MARK: Document

    static func monthKey(year: Int, month: Int) -> String {
        return "\(year)-" + two(month)
    }

    static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let c: DateComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let y: Int = c.year ?? 0
        return "\(y)-" + two(c.month ?? 0) + "-" + two(c.day ?? 0)
    }

    private static func two(_ n: Int) -> String {
        return n < 10 ? "0\(n)" : "\(n)"
    }

    /// Décimal en texte avec point et au moins 2 décimales : 10 donne "10.00", 12.5 donne "12.50", 12.0253 reste "12.0253".
    static func decimalText(_ value: Decimal) -> String {
        var text: String = NSDecimalNumber(decimal: value).stringValue
        if let dot = text.firstIndex(of: ".") {
            let decimals: Int = text.distance(from: dot, to: text.endIndex) - 1
            if decimals < 2 { text += String(repeating: "0", count: 2 - decimals) }
        } else {
            text += ".00"
        }
        return text
    }

    static func makeDocument(result: PayMonthResult, currencyCode: String, exportedAt: Date, calendar: Calendar) -> PayExportDocument {
        var rates: [PayExportRate] = []
        for line in result.rateLines {
            rates.append(PayExportRate(hourlyGross: decimalText(line.hourlyGross), seconds: line.seconds, grossCents: line.grossCents))
        }
        var days: [PayExportDay] = []
        for d in result.days {
            var rateText: String? = nil
            if let r = d.hourlyGross { rateText = decimalText(r) }
            days.append(PayExportDay(date: dayKey(d.day, calendar: calendar),
                                     sessionCount: d.sessionCount,
                                     exactSeconds: d.exactSeconds,
                                     fullHoursSeconds: d.fullHoursSeconds,
                                     retainedSeconds: d.retainedSeconds,
                                     hasUnresolvedDoubt: d.isProvisional,
                                     isOngoing: d.hasLive,
                                     hourlyGross: rateText))
        }
        return PayExportDocument(app: appName,
                                 formatVersion: currentFormatVersion,
                                 kind: "pay-month-estimate",
                                 isEstimate: true,
                                 disclaimer: disclaimer,
                                 exportedAt: exportedAt,
                                 month: monthKey(year: result.year, month: result.month),
                                 currencyCode: currencyCode,
                                 base: result.base.rawValue,
                                 netRatio: decimalText(result.netRatio),
                                 retainedSeconds: result.retainedSeconds,
                                 exactSeconds: result.exactSeconds,
                                 fullHoursSeconds: result.fullHoursSeconds,
                                 unratedSeconds: result.unratedSeconds,
                                 grossCents: result.grossCents,
                                 netCents: result.netCents,
                                 sessionCount: result.sessionCount,
                                 doubtSessionCount: result.doubtSessionCount,
                                 liveSessionCount: result.liveSessionCount,
                                 unconfirmedSessionCount: result.unconfirmedSessionCount,
                                 rates: rates,
                                 days: days)
    }

    // MARK: JSON

    /// JSON lisible, clés triées (sortie stable), dates ISO 8601.
    static func encodeJSON(_ document: PayExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    static func decodeJSON(_ data: Data) throws -> PayExportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PayExportDocument.self, from: data)
    }

    // MARK: CSV

    static let csvSeparator: String = ";"
    static let csvLineBreak: String = "\r\n"

    /// Protège un champ : entre guillemets s'il contient ";", un guillemet ou un saut de ligne ; les guillemets internes sont doublés.
    static func csvField(_ text: String) -> String {
        let needsQuotes: Bool = text.contains(";") || text.contains("\"") || text.contains("\n") || text.contains("\r")
        if !needsQuotes { return text }
        let doubled: String = text.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + doubled + "\""
    }

    private static func row(_ fields: [String]) -> String {
        var escaped: [String] = []
        for f in fields { escaped.append(csvField(f)) }
        return escaped.joined(separator: csvSeparator)
    }

    /// Heures en décimal avec virgule, 2 décimales, arrondi commercial : 27000 s donne "7,50", 3600 s donne "1,00", 1 s donne "0,00".
    static func hoursText(seconds: Int) -> String {
        let hundredths: Int = PayMath.roundedCents(Decimal(max(0, seconds)) / 3600)
        return centsText(hundredths)
    }

    /// Centimes vers "348,58" (virgule, sans symbole : la devise est dans une colonne à part). Négatif : "-1,05".
    static func centsText(_ cents: Int) -> String {
        let sign: String = cents < 0 ? "-" : ""
        let a: Int = abs(cents)
        let frac: Int = a % 100
        return sign + "\(a / 100)," + (frac < 10 ? "0\(frac)" : "\(frac)")
    }

    /// Taux "12.02" vers "12,02".
    static func commaDecimal(_ text: String) -> String {
        return text.replacingOccurrences(of: ".", with: ",")
    }

    static func baseTitle(_ rawBase: String) -> String {
        if let b = CalculationBase(rawValue: rawBase) { return b.title }
        return rawBase
    }

    /// CSV du mois : en-tête d'estimation, un tableau par jour avec session, puis les totaux.
    static func csv(_ doc: PayExportDocument) -> String {
        var lines: [String] = []
        lines.append(row([doc.disclaimer]))
        lines.append(row(["Mois", doc.month]))
        lines.append(row(["Base de calcul", baseTitle(doc.base)]))
        lines.append(row(["Devise", doc.currencyCode]))
        lines.append("")
        lines.append(row(["Jour", "Sessions", "Heures pleines (h)", "Heure exacte (h)", "Heures retenues (h)", "Taux brut horaire", "Remarque"]))
        for d in doc.days {
            var notes: [String] = []
            if d.hasUnresolvedDoubt { notes.append("zone de doute, heure exacte comptée") }
            if d.isOngoing { notes.append("session en cours") }
            var rateField: String = ""
            if let g = d.hourlyGross { rateField = commaDecimal(g) }
            let fields: [String] = [d.date,
                                    "\(d.sessionCount)",
                                    hoursText(seconds: d.fullHoursSeconds),
                                    hoursText(seconds: d.exactSeconds),
                                    hoursText(seconds: d.retainedSeconds),
                                    rateField,
                                    notes.joined(separator: ", ")]
            lines.append(row(fields))
        }
        lines.append("")
        lines.append(row(["Total heures retenues (h)", hoursText(seconds: doc.retainedSeconds)]))
        lines.append(row(["Total heures pleines (h)", hoursText(seconds: doc.fullHoursSeconds)]))
        lines.append(row(["Total heure exacte (h)", hoursText(seconds: doc.exactSeconds)]))
        for r in doc.rates {
            lines.append(row(["Brut estimé au taux " + commaDecimal(r.hourlyGross), hoursText(seconds: r.seconds), centsText(r.grossCents)]))
        }
        lines.append(row(["Brut estimé total", centsText(doc.grossCents)]))
        lines.append(row(["Net estimé, ratio " + commaDecimal(doc.netRatio), centsText(doc.netCents)]))
        if doc.unratedSeconds > 0 {
            lines.append(row(["Heures sans taux saisi, non payées dans l'estimation (h)", hoursText(seconds: doc.unratedSeconds)]))
        }
        if doc.doubtSessionCount > 0 {
            lines.append(row(["Sessions en zone de doute, heure exacte comptée", "\(doc.doubtSessionCount)"]))
        }
        if doc.unconfirmedSessionCount > 0 {
            lines.append(row(["Sessions à confirmer, non comptées", "\(doc.unconfirmedSessionCount)"]))
        }
        return lines.joined(separator: csvLineBreak) + csvLineBreak
    }

    // MARK: Fichiers

    static func fileName(month: String, ext: String) -> String {
        return "PersonalLifeTracker-paie-\(month).\(ext)"
    }

    static func writeJSONFile(_ doc: PayExportDocument) throws -> URL {
        let data: Data = try encodeJSON(doc)
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(month: doc.month, ext: "json"))
        try data.write(to: url, options: [.atomic])
        return url
    }

    /// UTF-8 avec BOM : Excel ouvre les accents correctement.
    static func writeCSVFile(_ doc: PayExportDocument) throws -> URL {
        let text: String = "\u{FEFF}" + csv(doc)
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(month: doc.month, ext: "csv"))
        try Data(text.utf8).write(to: url, options: [.atomic])
        return url
    }
}
