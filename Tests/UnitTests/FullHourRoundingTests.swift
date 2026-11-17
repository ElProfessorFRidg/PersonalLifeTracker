import XCTest
@testable import PersonalLifeTracker

/// Les valeurs attendues viennent de spec/oracles.json (dérivées du prompt), pas du code testé.
final class FullHourRoundingTests: XCTestCase {
    private struct Case: Decodable { let hhmm: String; let expect: String; let minutes: Int? }
    private struct Oracles: Decodable { let rounding: [Case] }

    private func minutes(_ hhmm: String) -> Int {
        let p = hhmm.split(separator: ":").map { Int($0)! }
        return p[0] * 60 + p[1]
    }

    private func loadOracles() throws -> Oracles {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "oracles", withExtension: "json"),
                                "oracles.json absent du bundle de tests")
        return try JSONDecoder().decode(Oracles.self, from: Data(contentsOf: url))
    }

    func testRoundingMatchesSpecOracles() throws {
        let oracles = try loadOracles()
        XCTAssertGreaterThanOrEqual(oracles.rounding.count, 12, "table d'oracles tronquée")
        for c in oracles.rounding {
            let result = FullHourRounding.normalize(minutesFromMidnight: minutes(c.hhmm))
            switch (c.expect, result) {
            case ("rounded", .rounded(let m)): XCTAssertEqual(m, c.minutes, "arrondi de \(c.hhmm)")
            case ("doubt", .doubt(let m)): XCTAssertEqual(m, minutes(c.hhmm), "doute de \(c.hhmm)")
            default: XCTFail("\(c.hhmm): attendu \(c.expect), obtenu \(result)")
            }
        }
    }

    func testNormalizedDurationOfSpecExample() {
        // 17:56 -> 22:03 : exact 247 min, normalisé 240 min (section 13.1)
        XCTAssertEqual(FullHourRounding.normalizedDuration(startMinutes: 17*60+56, endMinutes: 22*60+3), 240)
        XCTAssertEqual((22*60+3) - (17*60+56), 247)
    }

    func testDoubtZoneGivesNoNormalizedDuration() {
        XCTAssertNil(FullHourRounding.normalizedDuration(startMinutes: 8*60, endMinutes: 17*60+30))
    }
}
