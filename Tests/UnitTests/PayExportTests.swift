import XCTest
@testable import PersonalLifeTracker

/// Valeurs attendues écrites à la main (UTC, novembre 2026).
final class PayExportTests: XCTestCase {
    private let cal: Calendar = TestCalendar.utc

    private func d(_ day: Int, _ h: Int, _ min: Int) -> Date {
        return makeDate(cal, 2026, 11, day, h, min)
    }

    private func dec(_ s: String) -> Decimal {
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private let exportedAt: Date = Date(timeIntervalSince1970: 1_741_593_600)   // 2025-03-10T08:00:00Z

    /// 3 novembre 08:05 à 12:02 (heures pleines 4 h, exact 3 h 57 = 14220 s) et 4 novembre 08:00 à 12:00 (4 h), taux 12,02.
    /// Total heures pleines 8 h = 28800 s, exact 28620 s = 7,95 h. Brut 8 x 12,02 = 96,16. Net 9616 x 0,79 = 7596,64 donne 7597.
    private func sampleResult() -> PayMonthResult {
        let sessions = [PaySessionInput(start: d(3, 8, 5), end: d(3, 12, 2)),
                        PaySessionInput(start: d(4, 8, 0), end: d(4, 12, 0))]
        let rates = [PayRateEntry(effectiveDate: makeDate(cal, 2026, 10, 1, 0, 0), hourlyGross: dec("12.02"))]
        return PayCalculator.month(year: 2026, month: 11, sessions: sessions, rates: rates, base: .fullHours,
                                   netRatio: dec("0.79"), now: d(20, 12, 0), calendar: cal)
    }

    private func sampleDocument() -> PayExportDocument {
        return PayExport.makeDocument(result: sampleResult(), currencyCode: "EUR", exportedAt: exportedAt, calendar: cal)
    }

    // MARK: document

    func testDocumentValues() {
        let doc = sampleDocument()
        XCTAssertEqual(doc.month, "2026-11")
        XCTAssertEqual(doc.base, "fullHours")
        XCTAssertTrue(doc.isEstimate)
        XCTAssertEqual(doc.grossCents, 9616)
        XCTAssertEqual(doc.netCents, 7597)
        XCTAssertEqual(doc.retainedSeconds, 28800)
        XCTAssertEqual(doc.exactSeconds, 28620)
        XCTAssertEqual(doc.netRatio, "0.79")
        XCTAssertEqual(doc.days.count, 2)
        XCTAssertEqual(doc.days[0].date, "2026-11-03")
        XCTAssertEqual(doc.days[0].exactSeconds, 14220)
        XCTAssertEqual(doc.days[0].fullHoursSeconds, 14400)
        XCTAssertEqual(doc.days[0].hourlyGross, "12.02")
        XCTAssertEqual(doc.rates.count, 1)
        XCTAssertEqual(doc.rates[0].grossCents, 9616)
    }

    func testMonthAndDayKeys() {
        XCTAssertEqual(PayExport.monthKey(year: 2026, month: 3), "2026-03")
        XCTAssertEqual(PayExport.monthKey(year: 2026, month: 12), "2026-12")
        XCTAssertEqual(PayExport.dayKey(d(7, 23, 59), calendar: cal), "2026-11-07")
    }

    // MARK: JSON

    func testJSONContainsHandWrittenValuesAndRoundTrips() throws {
        let doc = sampleDocument()
        let data = try PayExport.encodeJSON(doc)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"month\" : \"2026-11\""))
        XCTAssertTrue(text.contains("\"grossCents\" : 9616"))
        XCTAssertTrue(text.contains("\"netCents\" : 7597"))
        XCTAssertTrue(text.contains("\"isEstimate\" : true"))
        XCTAssertTrue(text.contains("\"exportedAt\" : \"2025-03-10T08:00:00Z\""))
        XCTAssertTrue(text.contains("\"hourlyGross\" : \"12.02\""))
        let back = try PayExport.decodeJSON(data)
        XCTAssertEqual(back, doc)
    }

    // MARK: CSV

    func testCSVExactContent() {
        let csv = PayExport.csv(sampleDocument())
        let expected: [String] = [
            "Estimation d'après tes sessions et les taux que tu as saisis. Ta fiche de paie fait foi.",
            "Mois;2026-11",
            "Base de calcul;Heures pleines",
            "Devise;EUR",
            "",
            "Jour;Sessions;Heures pleines (h);Heure exacte (h);Heures retenues (h);Taux brut horaire;Remarque",
            "2026-11-03;1;4,00;3,95;4,00;12,02;",
            "2026-11-04;1;4,00;4,00;4,00;12,02;",
            "",
            "Total heures retenues (h);8,00",
            "Total heures pleines (h);8,00",
            "Total heure exacte (h);7,95",
            "Brut estimé au taux 12,02;8,00;96,16",
            "Brut estimé total;96,16",
            "Net estimé, ratio 0,79;75,97"
        ]
        XCTAssertEqual(csv, expected.joined(separator: "\r\n") + "\r\n")
    }

    func testCSVFlagsDoubtUnratedAndUnconfirmed() {
        // 5 novembre 17:56 à 21:20 : fin en zone de doute, exact 3 h 24 = 12240 s = 3,40 h, taux 10,00 depuis le 5.
        // 3 novembre 08:00 à 10:00 : avant le taux, 2 h sans taux. Une session non confirmée.
        let sessions = [PaySessionInput(start: d(3, 8, 0), end: d(3, 10, 0)),
                        PaySessionInput(start: d(5, 17, 56), end: d(5, 21, 20)),
                        PaySessionInput(start: d(6, 8, 0), end: d(6, 9, 0), isConfirmed: false)]
        let rates = [PayRateEntry(effectiveDate: d(5, 0, 0), hourlyGross: dec("10.00"))]
        let result = PayCalculator.month(year: 2026, month: 11, sessions: sessions, rates: rates, base: .fullHours,
                                         netRatio: dec("0.79"), now: d(20, 12, 0), calendar: cal)
        let doc = PayExport.makeDocument(result: result, currencyCode: "EUR", exportedAt: exportedAt, calendar: cal)
        let lines = PayExport.csv(doc).components(separatedBy: "\r\n")
        XCTAssertTrue(lines.contains("2026-11-03;1;2,00;2,00;2,00;;"))
        XCTAssertTrue(lines.contains("2026-11-05;1;3,40;3,40;3,40;10,00;zone de doute, heure exacte comptée"))
        XCTAssertTrue(lines.contains("Heures sans taux saisi, non payées dans l'estimation (h);2,00"))
        XCTAssertTrue(lines.contains("Sessions en zone de doute, heure exacte comptée;1"))
        XCTAssertTrue(lines.contains("Sessions à confirmer, non comptées;1"))
        // 3,4 h x 10,00 = 34,00
        XCTAssertTrue(lines.contains("Brut estimé total;34,00"))
    }

    func testCSVEscaping() {
        XCTAssertEqual(PayExport.csvField("abc"), "abc")
        XCTAssertEqual(PayExport.csvField(""), "")
        XCTAssertEqual(PayExport.csvField("12,02"), "12,02")
        XCTAssertEqual(PayExport.csvField("a;b"), "\"a;b\"")
        XCTAssertEqual(PayExport.csvField("dit \"oui\""), "\"dit \"\"oui\"\"\"")
        XCTAssertEqual(PayExport.csvField("ligne1\nligne2"), "\"ligne1\nligne2\"")
        XCTAssertEqual(PayExport.csvField("ligne1\r\nligne2"), "\"ligne1\r\nligne2\"")
    }

    func testCSVEscapesFieldsInsideTheDocument() {
        var doc = sampleDocument()
        doc.currencyCode = "EU;R"
        let lines = PayExport.csv(doc).components(separatedBy: "\r\n")
        XCTAssertTrue(lines.contains("Devise;\"EU;R\""))
    }

    func testDecimalTextHasAtLeastTwoDecimals() {
        XCTAssertEqual(PayExport.decimalText(dec("10")), "10.00")
        XCTAssertEqual(PayExport.decimalText(dec("10.00")), "10.00")
        XCTAssertEqual(PayExport.decimalText(dec("12.5")), "12.50")
        XCTAssertEqual(PayExport.decimalText(dec("12.0253")), "12.0253")
        XCTAssertEqual(PayExport.decimalText(dec("0.79")), "0.79")
    }

    func testNumberTexts() {
        XCTAssertEqual(PayExport.hoursText(seconds: 27000), "7,50")
        XCTAssertEqual(PayExport.hoursText(seconds: 3600), "1,00")
        XCTAssertEqual(PayExport.hoursText(seconds: 5400), "1,50")
        XCTAssertEqual(PayExport.hoursText(seconds: 0), "0,00")
        XCTAssertEqual(PayExport.hoursText(seconds: 1), "0,00")
        XCTAssertEqual(PayExport.hoursText(seconds: 3599), "1,00")
        XCTAssertEqual(PayExport.hoursText(seconds: 36), "0,01")
        XCTAssertEqual(PayExport.hoursText(seconds: 18), "0,01")      // 0,005 h arrondi vers le haut
        XCTAssertEqual(PayExport.centsText(9616), "96,16")
        XCTAssertEqual(PayExport.centsText(5), "0,05")
        XCTAssertEqual(PayExport.centsText(100), "1,00")
        XCTAssertEqual(PayExport.centsText(0), "0,00")
        XCTAssertEqual(PayExport.centsText(-105), "-1,05")
        XCTAssertEqual(PayExport.commaDecimal("12.02"), "12,02")
    }

    // MARK: fichiers

    func testCSVFileStartsWithBOMAndHasMonthName() throws {
        let doc = sampleDocument()
        let url = try PayExport.writeCSVFile(doc)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, "PersonalLifeTracker-paie-2026-11.csv")
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        let text = String(decoding: data.dropFirst(3), as: UTF8.self)
        XCTAssertEqual(text, PayExport.csv(doc))
    }

    func testJSONFileName() throws {
        let doc = sampleDocument()
        let url = try PayExport.writeJSONFile(doc)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, "PersonalLifeTracker-paie-2026-11.json")
        let back = try PayExport.decodeJSON(try Data(contentsOf: url))
        XCTAssertEqual(back, doc)
    }
}
