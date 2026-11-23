import XCTest
@testable import PersonalLifeTracker

// Entrées et attentes écrites à la main : formats d'horaires, en-têtes, noms, grille complète (le planning du
// prototype 41), cases à cheval sur minuit, repos, noms ambigus, texte sans queue ni tête.

private enum Fixture {
    static let weekHeaders: [String] = ["L 23", "M 24", "M 25", "J 26", "V 27", "S 28", "D 29"]
    static let title: String = "Planning du 23 au 29 nov."

    static func line(_ text: String, midX: Double, midY: Double, width: Double = 0.06, confidence: Double = 1.0) -> OCRTextLine {
        return OCRTextLine(text: text, minX: midX - width / 2, minY: midY - 0.01, width: width, height: 0.02, confidence: confidence)
    }

    static func colX(_ i: Int) -> Double { return 0.30 + 0.09 * Double(i) }
    static func rowY(_ i: Int) -> Double { return 0.30 + 0.10 * Double(i) }

    /// Jours en colonnes, une personne par ligne. Les cases vides ("") ne produisent aucune ligne de texte.
    static func grid(title: String?,
                     headers: [String],
                     rows: [(name: String, cells: [String])],
                     cellConfidence: Double = 1.0) -> [OCRTextLine] {
        var lines: [OCRTextLine] = []
        if let t = title {
            lines.append(line(t, midX: 0.4, midY: 0.08, width: 0.5))
        }
        for (i, h) in headers.enumerated() {
            lines.append(line(h, midX: colX(i), midY: 0.20))
        }
        for (r, row) in rows.enumerated() {
            lines.append(line(row.name, midX: 0.08, midY: rowY(r), width: 0.10))
            for (c, text) in row.cells.enumerated() where !text.isEmpty {
                lines.append(line(text, midX: colX(c), midY: rowY(r), confidence: cellConfidence))
            }
        }
        return lines
    }

    static let prototypeRows: [(name: String, cells: [String])] = [
        (name: "Maëlle", cells: ["9-16", "9-16", "", "9-16", "R", "9-16", ""]),
        (name: "Léo", cells: ["18-21", "", "R", "18-21", "", "9-16", "10-14"]),
        (name: "Léa", cells: ["", "18-21", "18-21", "", "18-21", "R", ""]),
        (name: "Sofiane", cells: ["R", "9-16", "9-16", "", "9-16", "", "9-16"])
    ]

    static func options(_ names: [String], forced: Int? = nil, weekOffset: Int = 0) -> ScheduleParseOptions {
        return ScheduleParseOptions(names: names,
                                    referenceDate: nov17(9, 0),
                                    calendar: TestCalendar.utc,
                                    forcedRowIndex: forced,
                                    guessedWeekOffset: weekOffset)
    }

    static func day(_ d: Int) -> Date {
        return makeDate(TestCalendar.utc, 2026, 11, d, 0, 0)
    }
}

final class ScheduleTextParserTests: XCTestCase {

    // MARK: - Formats d'horaires

    private func ranges(_ text: String) -> [ShiftTimeRange] {
        return ScheduleTextParser.parseRanges(in: text)
    }

    func testBareHoursRange() {
        XCTAssertEqual(ranges("9-16"), [ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)])
        XCTAssertEqual(ranges("18-21"), [ShiftTimeRange(startMinutes: 1080, endMinutes: 1260, crossesMidnight: false)])
    }

    func testHourWithHLetter() {
        XCTAssertEqual(ranges("9h-16h"), [ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)])
        XCTAssertEqual(ranges("9H - 16H"), [ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)])
    }

    func testHourAndMinutesWithH() {
        XCTAssertEqual(ranges("9h30-16h"), [ShiftTimeRange(startMinutes: 570, endMinutes: 960, crossesMidnight: false)])
        XCTAssertEqual(ranges("8h15-12h45"), [ShiftTimeRange(startMinutes: 495, endMinutes: 765, crossesMidnight: false)])
    }

    func testColonFormat() {
        XCTAssertEqual(ranges("09:00-16:30"), [ShiftTimeRange(startMinutes: 540, endMinutes: 990, crossesMidnight: false)])
        XCTAssertEqual(ranges("9:00 - 16:30"), [ShiftTimeRange(startMinutes: 540, endMinutes: 990, crossesMidnight: false)])
    }

    func testDashVariants() {
        let expected = [ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)]
        XCTAssertEqual(ranges("9\u{2013}16"), expected)
        XCTAssertEqual(ranges("9\u{2014}16"), expected)
        XCTAssertEqual(ranges("9 - 16"), expected)
    }

    func testWordSeparatorA() {
        XCTAssertEqual(ranges("9h à 16h"), [ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)])
        XCTAssertEqual(ranges("9 a 16"), [ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)])
    }

    func testSplitShiftGivesTwoRanges() {
        let expected = [ShiftTimeRange(startMinutes: 480, endMinutes: 720, crossesMidnight: false),
                        ShiftTimeRange(startMinutes: 840, endMinutes: 1080, crossesMidnight: false)]
        XCTAssertEqual(ranges("8h-12h / 14h-18h"), expected)
        XCTAssertEqual(ranges("8-12/14-18"), expected)
        XCTAssertEqual(ranges("8h-12h 14h-18h"), expected)
    }

    func testMidnightCrossingEndsNextDay() {
        XCTAssertEqual(ranges("22-6"), [ShiftTimeRange(startMinutes: 1320, endMinutes: 1800, crossesMidnight: true)])
        XCTAssertEqual(ranges("22h-6h30"), [ShiftTimeRange(startMinutes: 1320, endMinutes: 1830, crossesMidnight: true)])
        XCTAssertEqual(ranges("20h-00h"), [ShiftTimeRange(startMinutes: 1200, endMinutes: 1440, crossesMidnight: true)])
    }

    func testEndAtTwentyFourIsNotCrossing() {
        XCTAssertEqual(ranges("18-24"), [ShiftTimeRange(startMinutes: 1080, endMinutes: 1440, crossesMidnight: false)])
    }

    func testInvalidRangesAreIgnored() {
        XCTAssertEqual(ranges("25-30"), [])
        XCTAssertEqual(ranges("9-9"), [])
        XCTAssertEqual(ranges("9:75-16"), [])
        XCTAssertEqual(ranges("2026"), [])
        XCTAssertEqual(ranges("23/11"), [])
        XCTAssertEqual(ranges(""), [])
    }

    func testClockInput() {
        XCTAssertEqual(ScheduleTextParser.parseClockInput("9:00"), 540)
        XCTAssertEqual(ScheduleTextParser.parseClockInput("09h"), 540)
        XCTAssertEqual(ScheduleTextParser.parseClockInput("9h30"), 570)
        XCTAssertEqual(ScheduleTextParser.parseClockInput(" 16:45 "), 1005)
        XCTAssertEqual(ScheduleTextParser.parseClockInput("00:00"), 0)
        XCTAssertNil(ScheduleTextParser.parseClockInput("24:00"))
        XCTAssertNil(ScheduleTextParser.parseClockInput("25:00"))
        XCTAssertNil(ScheduleTextParser.parseClockInput("9:5"))
        XCTAssertNil(ScheduleTextParser.parseClockInput("9-16"))
        XCTAssertNil(ScheduleTextParser.parseClockInput("abc"))
        XCTAssertNil(ScheduleTextParser.parseClockInput(""))
    }

    // MARK: - Contenu d'une case

    func testRestCells() {
        XCTAssertEqual(ScheduleTextParser.parseCell("R"), .rest(.rest))
        XCTAssertEqual(ScheduleTextParser.parseCell("r"), .rest(.rest))
        XCTAssertEqual(ScheduleTextParser.parseCell("Repos"), .rest(.rest))
        XCTAssertEqual(ScheduleTextParser.parseCell("REPOS"), .rest(.rest))
        XCTAssertEqual(ScheduleTextParser.parseCell("RH"), .rest(.rest))
    }

    func testLeaveCells() {
        XCTAssertEqual(ScheduleTextParser.parseCell("CP"), .rest(.leave))
        XCTAssertEqual(ScheduleTextParser.parseCell("Congé"), .rest(.leave))
        XCTAssertEqual(ScheduleTextParser.parseCell("CONGES"), .rest(.leave))
        XCTAssertEqual(ScheduleTextParser.parseCell("RTT"), .rest(.leave))
    }

    func testEmptyCells() {
        XCTAssertEqual(ScheduleTextParser.parseCell(""), .empty)
        XCTAssertEqual(ScheduleTextParser.parseCell("   "), .empty)
        XCTAssertEqual(ScheduleTextParser.parseCell("-"), .empty)
        XCTAssertEqual(ScheduleTextParser.parseCell("/"), .empty)
        XCTAssertEqual(ScheduleTextParser.parseCell(" - - "), .empty)
    }

    func testShiftCell() {
        XCTAssertEqual(ScheduleTextParser.parseCell("9h-16h"),
                       .shifts([ShiftTimeRange(startMinutes: 540, endMinutes: 960, crossesMidnight: false)]))
    }

    func testGarbageCellsAreUnreadable() {
        XCTAssertEqual(ScheduleTextParser.parseCell("abc"), .unreadable)
        XCTAssertEqual(ScheduleTextParser.parseCell("§§"), .unreadable)
        XCTAssertEqual(ScheduleTextParser.parseCell("9"), .unreadable)
        XCTAssertEqual(ScheduleTextParser.parseCell("2026"), .unreadable)
        XCTAssertEqual(ScheduleTextParser.parseCell("25-30"), .unreadable)
    }

    func testRestWordTogetherWithHoursIsUnreadable() {
        XCTAssertEqual(ScheduleTextParser.parseCell("9-16 R"), .unreadable)
    }

    // MARK: - En-têtes et titre

    func testDayHeaders() {
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("L 23"), ScheduleDayHeader(weekdays: [0], dayOfMonth: 23, month: nil))
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("Lun. 23"), ScheduleDayHeader(weekdays: [0], dayOfMonth: 23, month: nil))
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("Mardi 24/11"), ScheduleDayHeader(weekdays: [1], dayOfMonth: 24, month: 11))
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("mer 25 nov."), ScheduleDayHeader(weekdays: [2], dayOfMonth: 25, month: 11))
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("Dim"), ScheduleDayHeader(weekdays: [6], dayOfMonth: nil, month: nil))
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("M"), ScheduleDayHeader(weekdays: [1, 2], dayOfMonth: nil, month: nil))
        XCTAssertEqual(ScheduleTextParser.parseDayHeader("J26"), ScheduleDayHeader(weekdays: [3], dayOfMonth: 26, month: nil))
    }

    func testNamesAreNotDayHeaders() {
        XCTAssertNil(ScheduleTextParser.parseDayHeader("Léo"))
        XCTAssertNil(ScheduleTextParser.parseDayHeader("Marie"))
        XCTAssertNil(ScheduleTextParser.parseDayHeader("Planning"))
        XCTAssertNil(ScheduleTextParser.parseDayHeader("9-16"))
        XCTAssertNil(ScheduleTextParser.parseDayHeader("Lundi matin"))
        XCTAssertNil(ScheduleTextParser.parseDayHeader(""))
    }

    func testWeekTitles() {
        XCTAssertEqual(ScheduleTextParser.parseWeekTitle("Planning du 23 au 29 nov."),
                       ScheduleWeekTitle(day: 23, startMonth: 11, year: nil))
        XCTAssertEqual(ScheduleTextParser.parseWeekTitle("Semaine du 23/11 au 29/11"),
                       ScheduleWeekTitle(day: 23, startMonth: 11, year: nil))
        XCTAssertEqual(ScheduleTextParser.parseWeekTitle("du 28 au 3 déc."),
                       ScheduleWeekTitle(day: 28, startMonth: 11, year: nil))
        XCTAssertEqual(ScheduleTextParser.parseWeekTitle("Planning du 23 novembre 2026 au 29 novembre 2026"),
                       ScheduleWeekTitle(day: 23, startMonth: 11, year: 2026))
        XCTAssertNil(ScheduleTextParser.parseWeekTitle("Menu du jour"))
        XCTAssertNil(ScheduleTextParser.parseWeekTitle("Planning"))
    }

    func testMonthNumbers() {
        XCTAssertEqual(ScheduleTextParser.monthNumber("nov"), 11)
        XCTAssertEqual(ScheduleTextParser.monthNumber("janv"), 1)
        XCTAssertEqual(ScheduleTextParser.monthNumber("fev"), 2)
        XCTAssertEqual(ScheduleTextParser.monthNumber("juin"), 6)
        XCTAssertEqual(ScheduleTextParser.monthNumber("juil"), 7)
        XCTAssertNil(ScheduleTextParser.monthNumber("jui"))
        XCTAssertNil(ScheduleTextParser.monthNumber("au"))
        XCTAssertNil(ScheduleTextParser.monthNumber("xyz"))
    }

    // MARK: - Noms

    func testEditDistance() {
        XCTAssertEqual(ScheduleTextParser.editDistance("leo", "lea"), 1)
        XCTAssertEqual(ScheduleTextParser.editDistance("leo", "leo"), 0)
        XCTAssertEqual(ScheduleTextParser.editDistance("", "abc"), 3)
        XCTAssertEqual(ScheduleTextParser.editDistance("kitten", "sitting"), 3)
    }

    func testNameScores() {
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Léo", variants: ["LEO"]), 1.0, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "L.M.", variants: ["LM"]), 1.0, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Léo Martin", variants: ["Léo"]), 0.9, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Léo Martin", variants: ["LM"]), 0.8, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Léa", variants: ["Léo"]), 0.55, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Maëlle", variants: ["Léo"]), 0, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Paul Martin", variants: ["Léo Martin"]), 0, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "", variants: ["Léo"]), 0, accuracy: 0.0001)
        XCTAssertEqual(ScheduleTextParser.nameScore(rowName: "Léo", variants: []), 0, accuracy: 0.0001)
    }

    func testConfidenceLevels() {
        XCTAssertEqual(ScheduleConfidence.level(0.97), .high)
        XCTAssertEqual(ScheduleConfidence.level(0.85), .high)
        XCTAssertEqual(ScheduleConfidence.level(0.84), .mid)
        XCTAssertEqual(ScheduleConfidence.level(0.60), .mid)
        XCTAssertEqual(ScheduleConfidence.level(0.59), .low)
        XCTAssertEqual(ScheduleConfidence.level(0.38), .low)
        XCTAssertEqual(ScheduleConfidence.percent(0.974), 97)
        XCTAssertEqual(ScheduleConfidence.percent(1.4), 100)
        XCTAssertEqual(ScheduleConfidence.percent(-1), 0)
    }

    // MARK: - Grille complète (planning du prototype 41)

    func testPrototypeGridForLeo() {
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: Fixture.prototypeRows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))

        XCTAssertNil(result.failure)
        XCTAssertEqual(result.rowNames, ["Maëlle", "Léo", "Léa", "Sofiane"])
        XCTAssertEqual(result.chosenRowIndex, 1)
        XCTAssertTrue(result.needsLineChoice, "Léo et Léa se ressemblent : l'utilisateur doit confirmer")
        XCTAssertEqual(result.candidates.map { $0.rowIndex }, [1, 2])
        XCTAssertEqual(result.candidates[0].score, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.candidates[1].score, 0.55, accuracy: 0.0001)
        XCTAssertFalse(result.datesGuessed)
        XCTAssertEqual(result.weekStart, Fixture.day(23))

        XCTAssertEqual(result.shifts.count, 4)
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23), Fixture.day(26), Fixture.day(28), Fixture.day(29)])
        XCTAssertEqual(result.shifts.map { $0.startMinutes }, [1080, 1080, 540, 600])
        XCTAssertEqual(result.shifts.map { $0.endMinutes }, [1260, 1260, 960, 840])
        for shift in result.shifts {
            XCTAssertEqual(shift.confidence, 1.0, accuracy: 0.0001)
            XCTAssertEqual(shift.level, .high)
            XCTAssertNil(shift.reason)
        }
        XCTAssertEqual(result.restDays, [ParsedRestDay(day: Fixture.day(25), kind: .rest)])
        XCTAssertEqual(result.emptyCellCount, 2)
        XCTAssertEqual(result.unreadable.count, 0)
    }

    func testPrototypeGridHighlightCoversLeoRow() {
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: Fixture.prototypeRows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        guard let h = result.highlight else {
            XCTFail("la ligne retenue doit être surlignée")
            return
        }
        XCTAssertEqual(h.x, 0.022, accuracy: 0.002)
        XCTAssertEqual(h.y, 0.382, accuracy: 0.002)
        XCTAssertEqual(h.width, 0.856, accuracy: 0.002)
        XCTAssertEqual(h.height, 0.036, accuracy: 0.002)
    }

    func testForcedRowReadsLea() {
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: Fixture.prototypeRows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"], forced: 2))

        XCTAssertEqual(result.chosenRowIndex, 2)
        XCTAssertFalse(result.needsLineChoice, "l'utilisateur a tranché")
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(24), Fixture.day(25), Fixture.day(27)])
        XCTAssertEqual(result.shifts.map { $0.startMinutes }, [1080, 1080, 1080])
        XCTAssertEqual(result.restDays, [ParsedRestDay(day: Fixture.day(28), kind: .rest)])
    }

    func testNameMatchIgnoresAccentsAndCase() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Maëlle", cells: ["9-16"]),
            (name: "Léo", cells: ["18-21"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["LEO"]))
        XCTAssertEqual(result.chosenRowIndex, 1)
        XCTAssertFalse(result.needsLineChoice)
        XCTAssertEqual(result.shifts.count, 1)
        XCTAssertEqual(result.shifts[0].startMinutes, 1080)
    }

    func testInitialsVariantMatchesRowWithDots() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Maëlle", cells: ["9-16"]),
            (name: "L.M.", cells: ["", "10-14"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo Martin", "LM"]))
        XCTAssertEqual(result.chosenRowIndex, 1)
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(24)])
        XCTAssertEqual(result.shifts.map { $0.startMinutes }, [600])
    }

    func testTwoIdenticalNamesAreNeverGuessed() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["9-16"]),
            (name: "Maëlle", cells: ["9-16"]),
            (name: "Léo", cells: ["18-21"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertNil(result.failure)
        XCTAssertNil(result.chosenRowIndex)
        XCTAssertTrue(result.needsLineChoice)
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertTrue(result.shifts.isEmpty, "aucun créneau tant que la ligne n'est pas choisie")
    }

    func testSimilarButNotIdenticalSingleNameIsFlaggedUncertain() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Maëlle", cells: ["9-16"]),
            (name: "Léa", cells: ["18-21"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.chosenRowIndex, 1)
        XCTAssertEqual(result.shifts.count, 1)
        XCTAssertEqual(result.shifts[0].confidence, 0.65, accuracy: 0.0001)
        XCTAssertEqual(result.shifts[0].level, .mid)
        XCTAssertEqual(result.shifts[0].reason, "Le nom de la ligne est écrit un peu différemment du tien.")
    }

    func testUnknownNameReportsNameNotFoundWithRowList() {
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: Fixture.prototypeRows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Zoé"]))
        XCTAssertEqual(result.failure, .nameNotFound)
        XCTAssertNil(result.chosenRowIndex)
        XCTAssertEqual(result.rowNames.count, 4)
        XCTAssertTrue(result.shifts.isEmpty)
    }

    func testNoProfileNameAlsoAsksForTheLine() {
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: Fixture.prototypeRows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options([]))
        XCTAssertEqual(result.failure, .nameNotFound)
        XCTAssertEqual(result.rowNames, ["Maëlle", "Léo", "Léa", "Sofiane"])
    }

    // MARK: - Cases particulières

    func testMidnightCrossingShiftInGrid() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["22-6"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.count, 1)
        let shift = result.shifts[0]
        XCTAssertTrue(shift.crossesMidnight)
        XCTAssertEqual(shift.startMinutes, 1320)
        XCTAssertEqual(shift.endMinutes, 1800)
        XCTAssertEqual(shift.confidence, 0.8, accuracy: 0.0001)
        XCTAssertEqual(shift.level, .mid, "un créneau de nuit se confirme d'un tap")
        XCTAssertEqual(shift.reason, "La fin tombe le lendemain, vérifie.")
        let interval = shift.interval(calendar: TestCalendar.utc)
        XCTAssertEqual(interval.start, makeDate(TestCalendar.utc, 2026, 11, 23, 22, 0))
        XCTAssertEqual(interval.end, makeDate(TestCalendar.utc, 2026, 11, 24, 6, 0))
    }

    func testVeryLongAndVeryShortShiftsAreFlagged() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["6-20", "9-9h30"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.count, 2)
        XCTAssertEqual(result.shifts[0].confidence, 0.6, accuracy: 0.0001)
        XCTAssertEqual(result.shifts[0].reason, "Plus de 12 h d'affilée, regarde la photo avant de garder.")
        XCTAssertEqual(result.shifts[1].confidence, 0.6, accuracy: 0.0001)
        XCTAssertEqual(result.shifts[1].reason, "Moins d'une heure, regarde la photo avant de garder.")
    }

    func testSplitShiftInOneCell() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["8h-12h / 14h-18h"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.map { $0.startMinutes }, [480, 840])
        XCTAssertEqual(result.shifts.map { $0.endMinutes }, [720, 1080])
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23), Fixture.day(23)])
    }

    func testCellWrittenOnTwoLinesIsMergedIntoOneDay() {
        var lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders,
                                 rows: [(name: "Léo", cells: ["8h-12h"])])
        lines.append(Fixture.line("14h-18h", midX: Fixture.colX(0), midY: Fixture.rowY(0) + 0.025))
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.map { $0.startMinutes }, [480, 840])
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23), Fixture.day(23)])
    }

    func testUnnamedFarAwayRowIsNotMergedIntoTheRowAbove() {
        var lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders,
                                 rows: [(name: "Léo", cells: ["8h-12h"])])
        lines.append(Fixture.line("14h-18h", midX: Fixture.colX(0), midY: Fixture.rowY(0) + 0.20))
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.count, 1, "une case sans nom loin de la ligne ne lui est pas rattachée")
        XCTAssertTrue(result.warnings.contains("Du texte hors des colonnes a été ignoré."))
    }

    func testUnreadableCellIsReportedNotGuessed() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["9-16", "§x7?"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.count, 1)
        XCTAssertEqual(result.unreadable, [UnreadableCell(day: Fixture.day(24), rawText: "§x7?")])
    }

    func testLeaveDayIsNotAShift() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["CP", "Congé", "R"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertTrue(result.shifts.isEmpty)
        XCTAssertEqual(result.restDays, [ParsedRestDay(day: Fixture.day(23), kind: .leave),
                                         ParsedRestDay(day: Fixture.day(24), kind: .leave),
                                         ParsedRestDay(day: Fixture.day(25), kind: .rest)])
    }

    func testBlurryOCRLowersConfidence() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["9-16"])
        ]
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: rows, cellConfidence: 0.5)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.count, 1)
        XCTAssertEqual(result.shifts[0].confidence, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.shifts[0].level, .low)
        XCTAssertEqual(result.shifts[0].reason, "La lecture de cette case est peu nette.")
    }

    // MARK: - Dates

    func testDatesFromHeaderNumbersWithoutTitle() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["9-16"])
        ]
        let lines = Fixture.grid(title: nil, headers: Fixture.weekHeaders, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertFalse(result.datesGuessed)
        XCTAssertEqual(result.weekStart, Fixture.day(23))
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23)])
        XCTAssertEqual(result.shifts[0].confidence, 1.0, accuracy: 0.0001)
    }

    func testDatesFromTitleWithoutHeaderNumbers() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["", "9-16"])
        ]
        let headers: [String] = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
        let lines = Fixture.grid(title: Fixture.title, headers: headers, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertFalse(result.datesGuessed)
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(24)])
    }

    func testGuessedWeekIsFlaggedAndCapped() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["9-16"])
        ]
        let headers: [String] = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
        let lines = Fixture.grid(title: nil, headers: headers, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertTrue(result.datesGuessed)
        XCTAssertEqual(result.weekStart, Fixture.day(23), "le 17 nov. 2026 est un mardi : prochain lundi = 23")
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23)])
        XCTAssertEqual(result.shifts[0].confidence, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.shifts[0].level, .low)

        let later = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"], weekOffset: 1))
        XCTAssertEqual(later.weekStart, Fixture.day(30))
        XCTAssertEqual(later.shifts.map { $0.day }, [Fixture.day(30)])
    }

    func testSingleLetterHeadersResolveTuesdayAndWednesday() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["", "9-16", "R"])
        ]
        let headers: [String] = ["L", "M", "M", "J", "V", "S", "D"]
        let lines = Fixture.grid(title: Fixture.title, headers: headers, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(24)])
        XCTAssertEqual(result.restDays, [ParsedRestDay(day: Fixture.day(25), kind: .rest)])
    }

    func testHeaderNumberThatContradictsWeekdayFallsBackToTitleWithWarning() {
        let rows: [(name: String, cells: [String])] = [
            (name: "Léo", cells: ["9-16"])
        ]
        // "L 24" : le 24 novembre 2026 est un mardi, pas un lundi.
        let headers: [String] = ["L 24", "M 24", "M 25", "J 26", "V 27", "S 28", "D 29"]
        let lines = Fixture.grid(title: Fixture.title, headers: headers, rows: rows)
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23)])
        XCTAssertTrue(result.warnings.contains("Un numéro de jour de l'en-tête ne colle pas avec son jour de la semaine."))
    }

    // MARK: - Jours en lignes, personnes en colonnes

    func testDaysAsRowsLayout() {
        var lines: [OCRTextLine] = []
        lines.append(Fixture.line(Fixture.title, midX: 0.5, midY: 0.08, width: 0.5))
        lines.append(Fixture.line("Léo", midX: 0.30, midY: 0.20, width: 0.10))
        lines.append(Fixture.line("Zoé", midX: 0.40, midY: 0.20, width: 0.10))
        for (d, label) in Fixture.weekHeaders.enumerated() {
            lines.append(Fixture.line(label, midX: 0.08, midY: Fixture.rowY(d), width: 0.10))
        }
        lines.append(Fixture.line("18-21", midX: 0.30, midY: Fixture.rowY(0)))
        lines.append(Fixture.line("R", midX: 0.30, midY: Fixture.rowY(2)))
        lines.append(Fixture.line("18-21", midX: 0.30, midY: Fixture.rowY(3)))
        lines.append(Fixture.line("9-16", midX: 0.40, midY: Fixture.rowY(1)))

        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.shifts.map { $0.day }, [Fixture.day(23), Fixture.day(26)])
        XCTAssertEqual(result.shifts.map { $0.startMinutes }, [1080, 1080])
        XCTAssertEqual(result.restDays, [ParsedRestDay(day: Fixture.day(25), kind: .rest)])
        guard let h = result.highlight else {
            XCTFail("la colonne retenue doit être surlignée")
            return
        }
        XCTAssertEqual(h.x, 0.242, accuracy: 0.002)
        XCTAssertEqual(h.y, 0.182, accuracy: 0.002)
        XCTAssertEqual(h.width, 0.116, accuracy: 0.002)
        XCTAssertEqual(h.height, 0.436, accuracy: 0.002)
    }

    // MARK: - Entrées inutilisables

    func testEmptyInputFailsWithNoText() {
        XCTAssertEqual(ScheduleTextParser.parse(lines: [], options: Fixture.options(["Léo"])).failure, .noText)
        let blanks = [Fixture.line("   ", midX: 0.5, midY: 0.5), Fixture.line("", midX: 0.2, midY: 0.2)]
        XCTAssertEqual(ScheduleTextParser.parse(lines: blanks, options: Fixture.options(["Léo"])).failure, .noText)
    }

    func testGarbageWithoutDayHeadersFailsWithNoHeader() {
        let lines = [
            Fixture.line("xx", midX: 0.2, midY: 0.2),
            Fixture.line("?!", midX: 0.5, midY: 0.3),
            Fixture.line("9-16", midX: 0.4, midY: 0.5),
            Fixture.line("Léo", midX: 0.1, midY: 0.5),
            Fixture.line("lorem ipsum", midX: 0.6, midY: 0.7, width: 0.3)
        ]
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.failure, .noHeader)
        XCTAssertTrue(result.shifts.isEmpty)
    }

    func testTwoDayHeadersAreNotEnoughToCallItATable() {
        let lines = [
            Fixture.line("Lun", midX: 0.3, midY: 0.2),
            Fixture.line("Mar", midX: 0.4, midY: 0.2),
            Fixture.line("Léo", midX: 0.1, midY: 0.3),
            Fixture.line("9-16", midX: 0.3, midY: 0.3)
        ]
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.failure, .noHeader)
    }

    func testFooterLegendIsNotACandidateRow() {
        var lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders,
                                 rows: [(name: "Léo", cells: ["9-16"])])
        lines.append(Fixture.line("R = repos", midX: 0.08, midY: 0.55, width: 0.10))
        let result = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        XCTAssertEqual(result.rowNames, ["Léo"])
    }

    func testSameInputGivesSameOutput() {
        let lines = Fixture.grid(title: Fixture.title, headers: Fixture.weekHeaders, rows: Fixture.prototypeRows)
        let a = ScheduleTextParser.parse(lines: lines, options: Fixture.options(["Léo"]))
        let b = ScheduleTextParser.parse(lines: Array(lines.reversed()), options: Fixture.options(["Léo"]))
        XCTAssertEqual(a.shifts, b.shifts, "l'ordre d'arrivée du texte ne compte pas, seule la position compte")
        XCTAssertEqual(a.rowNames, b.rowNames)
    }

    func testDateHelperHandlesNextDayMinutes() {
        let day = Fixture.day(23)
        XCTAssertEqual(ScheduleTextParser.date(day: day, minutes: 1320, calendar: TestCalendar.utc),
                       makeDate(TestCalendar.utc, 2026, 11, 23, 22, 0))
        XCTAssertEqual(ScheduleTextParser.date(day: day, minutes: 1830, calendar: TestCalendar.utc),
                       makeDate(TestCalendar.utc, 2026, 11, 24, 6, 30))
        XCTAssertEqual(ScheduleTextParser.date(day: day, minutes: 1440, calendar: TestCalendar.utc),
                       makeDate(TestCalendar.utc, 2026, 11, 24, 0, 0))
    }

    func testDateHelperAcrossDaylightSavingChange() {
        // Passage à l'heure d'hiver à Paris : dimanche 25 octobre 2026. 22:00 la veille jusqu'à 06:00 : 9 h réelles.
        let paris = TestCalendar.paris
        let day = makeDate(paris, 2026, 10, 24, 0, 0)
        let start = ScheduleTextParser.date(day: day, minutes: 22 * 60, calendar: paris)
        let end = ScheduleTextParser.date(day: day, minutes: 30 * 60, calendar: paris)
        XCTAssertEqual(start, makeDate(paris, 2026, 10, 24, 22, 0))
        XCTAssertEqual(end, makeDate(paris, 2026, 10, 25, 6, 0))
        XCTAssertEqual(end.timeIntervalSince(start), 9 * 3600, accuracy: 0.5)
    }
}
