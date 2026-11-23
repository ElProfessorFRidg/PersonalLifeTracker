import XCTest
@testable import PersonalLifeTracker

final class SchoolCalendarTests: XCTestCase {
    private let paris: Calendar = TestCalendar.paris

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        return makeDate(paris, y, m, d, 0, 0)
    }

    // Dates de Pâques connues (almanach) : écrites à la main.
    func testEasterSundayKnownYears() {
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2024, calendar: paris), day(2024, 3, 31))
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2025, calendar: paris), day(2025, 4, 20))
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2026, calendar: paris), day(2026, 4, 5))
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2027, calendar: paris), day(2027, 3, 28))
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2028, calendar: paris), day(2028, 4, 16))
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2029, calendar: paris), day(2029, 4, 1))
        XCTAssertEqual(SchoolCalendarRules.easterSunday(year: 2030, calendar: paris), day(2030, 4, 21))
    }

    func testHolidays2026AllTwelveInOrder() {
        let list: [PublicHoliday] = SchoolCalendarRules.publicHolidays(year: 2026, calendar: paris)
        let expected: [(Int, Int, String)] = [
            (1, 1, "Jour de l'an"), (4, 5, "Pâques"), (4, 6, "Lundi de Pâques"), (5, 1, "Fête du Travail"),
            (5, 8, "Victoire 1945"), (5, 14, "Ascension"), (5, 25, "Lundi de Pentecôte"), (7, 14, "Fête nationale"),
            (8, 15, "Assomption"), (11, 1, "Toussaint"), (11, 11, "Armistice 1918"), (12, 25, "Noël")
        ]
        XCTAssertEqual(list.count, 12)
        for (i, item) in expected.enumerated() where i < list.count {
            XCTAssertEqual(list[i].day, day(2026, item.0, item.1), item.2)
            XCTAssertEqual(list[i].name, item.2)
        }
    }

    func testMovingHolidays2027And2025And2024() {
        // 2027 : Pâques 28 mars, lundi 29 mars, Ascension 6 mai (jeudi), lundi de Pentecôte 17 mai.
        let h2027: [PublicHoliday] = SchoolCalendarRules.publicHolidays(year: 2027, calendar: paris)
        XCTAssertTrue(h2027.contains(PublicHoliday(day: day(2027, 3, 29), name: "Lundi de Pâques")))
        XCTAssertTrue(h2027.contains(PublicHoliday(day: day(2027, 5, 6), name: "Ascension")))
        XCTAssertTrue(h2027.contains(PublicHoliday(day: day(2027, 5, 17), name: "Lundi de Pentecôte")))
        // 2025 : Pâques 20 avril, Ascension 29 mai, lundi de Pentecôte 9 juin.
        let h2025: [PublicHoliday] = SchoolCalendarRules.publicHolidays(year: 2025, calendar: paris)
        XCTAssertTrue(h2025.contains(PublicHoliday(day: day(2025, 4, 21), name: "Lundi de Pâques")))
        XCTAssertTrue(h2025.contains(PublicHoliday(day: day(2025, 5, 29), name: "Ascension")))
        XCTAssertTrue(h2025.contains(PublicHoliday(day: day(2025, 6, 9), name: "Lundi de Pentecôte")))
        // 2024 (bissextile) : Pâques 31 mars, lundi 1 avril, Ascension 9 mai, lundi de Pentecôte 20 mai.
        let h2024: [PublicHoliday] = SchoolCalendarRules.publicHolidays(year: 2024, calendar: paris)
        XCTAssertTrue(h2024.contains(PublicHoliday(day: day(2024, 4, 1), name: "Lundi de Pâques")))
        XCTAssertTrue(h2024.contains(PublicHoliday(day: day(2024, 5, 9), name: "Ascension")))
        XCTAssertTrue(h2024.contains(PublicHoliday(day: day(2024, 5, 20), name: "Lundi de Pentecôte")))
    }

    func testHolidayLookupIgnoresTimeOfDay() {
        XCTAssertEqual(SchoolCalendarRules.holiday(on: makeDate(paris, 2026, 7, 14, 15, 30), calendar: paris)?.name, "Fête nationale")
        XCTAssertEqual(SchoolCalendarRules.holiday(on: makeDate(paris, 2026, 7, 14, 23, 59), calendar: paris)?.name, "Fête nationale")
        XCTAssertNil(SchoolCalendarRules.holiday(on: makeDate(paris, 2026, 7, 13, 23, 59), calendar: paris))
        XCTAssertNil(SchoolCalendarRules.holiday(on: makeDate(paris, 2026, 7, 15, 0, 0), calendar: paris))
        XCTAssertTrue(SchoolCalendarRules.isPublicHoliday(makeDate(paris, 2026, 5, 14, 12, 0), calendar: paris))
        XCTAssertFalse(SchoolCalendarRules.isPublicHoliday(makeDate(paris, 2026, 5, 15, 12, 0), calendar: paris))
    }

    func testHolidayFacadeUsesCalendarArgument() {
        XCTAssertTrue(SchoolCalendar.isHoliday(makeDate(paris, 2026, 12, 25, 10, 0), calendar: paris))
        XCTAssertEqual(SchoolCalendar.holidayName(makeDate(paris, 2026, 11, 11, 10, 0), calendar: paris), "Armistice 1918")
        XCTAssertFalse(SchoolCalendar.isHoliday(makeDate(paris, 2026, 12, 24, 10, 0), calendar: paris))
    }

    func testUpcomingHolidaysCrossYear() {
        let list: [PublicHoliday] = SchoolCalendarRules.upcomingHolidays(from: makeDate(paris, 2026, 11, 23, 9, 0), count: 3, calendar: paris)
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list[0].day, day(2026, 12, 25))
        XCTAssertEqual(list[1].day, day(2027, 1, 1))
        XCTAssertEqual(list[2].day, day(2027, 3, 28))
        // Le jour même compte.
        let same: [PublicHoliday] = SchoolCalendarRules.upcomingHolidays(from: makeDate(paris, 2026, 12, 25, 18, 0), count: 1, calendar: paris)
        XCTAssertEqual(same.first?.day, day(2026, 12, 25))
    }

    // MARK: Jours en texte

    func testParseDay() {
        XCTAssertEqual(SchoolCalendarRules.parseDay("2026-10-17", calendar: paris), day(2026, 10, 17))
        XCTAssertEqual(SchoolCalendarRules.parseDay("2024-02-29", calendar: paris), day(2024, 2, 29))
        XCTAssertNil(SchoolCalendarRules.parseDay("2026-02-31", calendar: paris))
        XCTAssertNil(SchoolCalendarRules.parseDay("2025-02-29", calendar: paris))
        XCTAssertNil(SchoolCalendarRules.parseDay("2026-13-01", calendar: paris))
        XCTAssertNil(SchoolCalendarRules.parseDay("2026-10", calendar: paris))
        XCTAssertNil(SchoolCalendarRules.parseDay("abc", calendar: paris))
    }

    func testDayText() {
        XCTAssertEqual(SchoolCalendarRules.dayText(makeDate(paris, 2026, 3, 5, 23, 59), calendar: paris), "2026-03-05")
        XCTAssertEqual(SchoolCalendarRules.dayText(makeDate(paris, 2026, 12, 25, 0, 0), calendar: paris), "2026-12-25")
    }

    // MARK: Vacances

    private func sample() -> [SchoolBreak] {
        return [
            SchoolBreak(id: "t", name: "Toussaint", zone: "all", startDay: "2026-10-17", endDay: "2026-11-01"),
            SchoolBreak(id: "a", name: "Hiver", zone: "A", startDay: "2026-02-07", endDay: "2026-02-22"),
            SchoolBreak(id: "b", name: "Hiver", zone: "B", startDay: "2026-02-14", endDay: "2026-03-01"),
            SchoolBreak(id: "bad1", name: "Fin avant début", zone: "all", startDay: "2026-06-10", endDay: "2026-06-01"),
            SchoolBreak(id: "bad2", name: "Date cassée", zone: "all", startDay: "2026-06-31", endDay: "2026-07-02")
        ]
    }

    func testBreakBoundsAreInclusiveAndZoneSpecific() {
        let list: [SchoolBreak] = sample()
        XCTAssertTrue(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 7, 0, 0), in: list, zone: .a, calendar: paris))
        XCTAssertTrue(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 22, 23, 59), in: list, zone: .a, calendar: paris))
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 23, 0, 0), in: list, zone: .a, calendar: paris))
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 6, 23, 59), in: list, zone: .a, calendar: paris))
        // Zone B encore en vacances le 22 février, zone A non le 23.
        XCTAssertTrue(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 23, 12, 0), in: list, zone: .b, calendar: paris))
        // Zone C : aucune plage d'hiver dans cet échantillon.
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 10, 12, 0), in: list, zone: .c, calendar: paris))
    }

    func testUnknownZoneOnlyCountsCommonBreaks() {
        let list: [SchoolBreak] = sample()
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 10, 12, 0), in: list, zone: nil, calendar: paris))
        XCTAssertTrue(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 10, 25, 12, 0), in: list, zone: nil, calendar: paris))
    }

    func testInvalidBreaksAreIgnored() {
        let list: [SchoolBreak] = sample()
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 6, 5, 12, 0), in: list, zone: nil, calendar: paris))
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 7, 1, 12, 0), in: list, zone: nil, calendar: paris))
        XCTAssertEqual(SchoolCalendarRules.breaks(list, zone: nil, calendar: paris).count, 1)
    }

    func testBreakCoveringAcrossSpringForward() {
        // Le changement d'heure est le 29 mars 2026 : le jour reste un jour entier.
        let list: [SchoolBreak] = [SchoolBreak(id: "x", name: "Pause", zone: "all", startDay: "2026-03-28", endDay: "2026-03-29", isCustom: true)]
        XCTAssertEqual(SchoolCalendarRules.breakCovering(makeDate(paris, 2026, 3, 29, 23, 30), in: list, zone: nil, calendar: paris)?.id, "x")
        XCTAssertNil(SchoolCalendarRules.breakCovering(makeDate(paris, 2026, 3, 30, 0, 30), in: list, zone: nil, calendar: paris))
    }

    func testNextBreak() {
        let list: [SchoolBreak] = sample()
        // Le 1 novembre est encore dans la Toussaint : c'est la plage "en cours".
        XCTAssertEqual(SchoolCalendarRules.nextBreak(from: makeDate(paris, 2026, 11, 1, 20, 0), in: list, zone: nil, calendar: paris)?.id, "t")
        XCTAssertNil(SchoolCalendarRules.nextBreak(from: makeDate(paris, 2026, 11, 2, 0, 0), in: list, zone: nil, calendar: paris))
        XCTAssertEqual(SchoolCalendarRules.nextBreak(from: makeDate(paris, 2026, 1, 5, 9, 0), in: list, zone: .b, calendar: paris)?.id, "b")
    }

    func testBreaksInYear() {
        let list: [SchoolBreak] = [
            SchoolBreak(id: "noel", name: "Noël", zone: "all", startDay: "2026-12-19", endDay: "2027-01-03"),
            SchoolBreak(id: "ete", name: "Été", zone: "all", startDay: "2026-07-04", endDay: "2026-08-31")
        ]
        XCTAssertEqual(SchoolCalendarRules.breaks(inYear: 2027, in: list, zone: nil, calendar: paris).map { $0.id }, ["noel"])
        XCTAssertEqual(SchoolCalendarRules.breaks(inYear: 2026, in: list, zone: nil, calendar: paris).map { $0.id }, ["ete", "noel"])
        XCTAssertEqual(SchoolCalendarRules.breaks(inYear: 2025, in: list, zone: nil, calendar: paris).count, 0)
    }

    func testDaysBetweenIsCalendarDaysAcrossDST() {
        // 47 heures réelles entre le 28 mars 12:00 et le 30 mars 12:00 (changement d'heure) : 2 jours.
        let a: Date = makeDate(paris, 2026, 3, 28, 12, 0)
        let b: Date = makeDate(paris, 2026, 3, 30, 12, 0)
        XCTAssertEqual(SchoolCalendarRules.daysBetween(a, b, calendar: paris), 2)
        XCTAssertEqual(SchoolCalendarRules.daysBetween(b, a, calendar: paris), -2)
        XCTAssertEqual(SchoolCalendarRules.daysBetween(makeDate(paris, 2026, 3, 28, 23, 59), makeDate(paris, 2026, 3, 29, 0, 1), calendar: paris), 1)
    }

    func testValidateBreak() {
        let s: Date = makeDate(paris, 2026, 5, 4, 0, 0)
        XCTAssertEqual(SchoolCalendarRules.validate(name: "Stage", start: s, end: s, calendar: paris), .valid)
        XCTAssertEqual(SchoolCalendarRules.validate(name: "  ", start: s, end: s, calendar: paris), .emptyName)
        XCTAssertEqual(SchoolCalendarRules.validate(name: "Stage", start: s, end: makeDate(paris, 2026, 5, 3, 23, 0), calendar: paris), .endBeforeStart)
    }

    func testRangeText() {
        XCTAssertEqual(SchoolCalendarRules.rangeText(start: day(2026, 10, 17), end: day(2026, 11, 1), calendar: paris), "du 17 octobre au 1 novembre")
    }

    // MARK: Fichier de données

    private func dataFileURL() -> URL {
        // Tests/UnitTests/SchoolCalendarTests.swift : trois niveaux jusqu'à la racine du dépôt.
        let root: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return root.appendingPathComponent("App/Resources/reference/school_calendar.json")
    }

    func testBundledJSONIsConsistent() throws {
        let data: Data = try Data(contentsOf: dataFileURL())
        let decoded: SchoolCalendarData = try JSONDecoder().decode(SchoolCalendarData.self, from: data)
        XCTAssertFalse(decoded.breaks.isEmpty)
        XCTAssertTrue(decoded.verificationNote.contains("À vérifier"))
        var ids: Set<String> = []
        for b in decoded.breaks {
            XCTAssertTrue(["A", "B", "C", "all"].contains(b.zone), b.id)
            XCTAssertFalse(ids.contains(b.id), "id en double : \(b.id)")
            ids.insert(b.id)
            let s: Date? = SchoolCalendarRules.parseDay(b.startDay, calendar: paris)
            let e: Date? = SchoolCalendarRules.parseDay(b.endDay, calendar: paris)
            XCTAssertNotNil(s, b.id)
            XCTAssertNotNil(e, b.id)
            if let s = s, let e = e { XCTAssertTrue(e >= s, b.id) }
            XCTAssertTrue(b.note.contains("À vérifier"), b.id)
            XCTAssertFalse(b.isCustom, b.id)
        }
        // Valeur connue : la Toussaint 2025 couvre le 25 octobre 2025 pour toutes les zones.
        XCTAssertTrue(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2025, 10, 25, 12, 0), in: decoded.breaks, zone: nil, calendar: paris))
        // Valeur connue : le 1 février 2026 n'est dans aucune vacance.
        XCTAssertFalse(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 2, 1, 12, 0), in: decoded.breaks, zone: .a, calendar: paris))
    }

    func testStoreUserBreaksAndZoneRoundTrip() {
        let iso = makeIsolatedDefaults()
        defer { iso.defaults.removePersistentDomain(forName: iso.name) }
        let store = SchoolCalendarStore(defaults: iso.defaults)
        XCTAssertNil(store.zone)
        XCTAssertEqual(store.userBreaks().count, 0)
        store.zone = .b
        XCTAssertEqual(store.zone, .b)
        store.zone = nil
        XCTAssertNil(store.zone)
        let mine = SchoolBreak(id: "custom-1", name: "Stage", zone: "all", startDay: "2026-05-04", endDay: "2026-05-08", isCustom: true)
        store.saveUserBreaks([mine])
        XCTAssertEqual(store.userBreaks(), [mine])
        XCTAssertTrue(SchoolCalendarRules.isSchoolBreak(makeDate(paris, 2026, 5, 6, 12, 0), in: store.userBreaks(), zone: nil, calendar: paris))
    }
}
