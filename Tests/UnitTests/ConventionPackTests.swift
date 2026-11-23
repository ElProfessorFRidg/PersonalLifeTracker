import XCTest
@testable import PersonalLifeTracker

/// Les pourcentages et seuils des fixtures sont des DONNÉES DE TEST, pas des valeurs légales.
final class ConventionPackTests: XCTestCase {

    private func validPack(id: String = "test-pack", name: String = "Pack de test", idcc: String? = "2216",
                           keywords: [String] = ["supermarché", "caisse"], rules: ConventionRules = ConventionRules()) -> ConventionPack {
        return ConventionPack(id: id, name: name, idcc: idcc, sector: "Secteur de test", keywords: keywords,
                              summary: "Résumé de test", sourceNote: "Test", rules: rules)
    }

    private func validRules() -> ConventionRules {
        return ConventionRules(
            night: PackNightRule(startMinute: 1260, endMinute: 360, percent: 25, source: "Source test", sourceDate: "2026-11-17"),
            sunday: PackPercentRule(percent: 50, source: "Source test", sourceDate: "2026-11-17"),
            publicHoliday: PackHolidayRule(scope: "all", percent: 100, source: "Source test"),
            overtime: PackOvertimeRule(weeklyThresholdMinutes: 2100,
                                       bands: [PackOvertimeBand(overMinutes: 480, percent: 25), PackOvertimeBand(overMinutes: nil, percent: 50)],
                                       source: "Source test"),
            minimumRate: PackMinimumRate(hourlyCents: 1250, label: "Minimum test", source: "Source test"))
    }

    // MARK: validation

    func testValidPackHasNoErrors() {
        XCTAssertEqual(ConventionPackValidator.validate(validPack(rules: validRules())), [])
    }

    func testEmptyPackIsValid() {
        XCTAssertEqual(ConventionPackValidator.validate(validPack()), [])
    }

    func testEmptyIDAndName() {
        let errors = ConventionPackValidator.validate(validPack(id: "  ", name: ""))
        XCTAssertTrue(errors.contains(.emptyID))
        XCTAssertTrue(errors.contains(.emptyName))
    }

    func testInvalidIDCC() {
        XCTAssertTrue(ConventionPackValidator.validate(validPack(idcc: "ABC")).contains(.invalidIDCC("ABC")))
        XCTAssertTrue(ConventionPackValidator.validate(validPack(idcc: "12345")).contains(.invalidIDCC("12345")))
        XCTAssertTrue(ConventionPackValidator.validate(validPack(idcc: "")).contains(.invalidIDCC("")))
        XCTAssertEqual(ConventionPackValidator.validate(validPack(idcc: "16")), [])
        XCTAssertEqual(ConventionPackValidator.validate(validPack(idcc: "0016")), [])
    }

    func testPercentOutOfRange() {
        var rules = validRules()
        rules.sunday = PackPercentRule(percent: 301, source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.percentOutOfRange(rule: "dimanche", value: 301)))
        rules.sunday = PackPercentRule(percent: -1, source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.percentOutOfRange(rule: "dimanche", value: -1)))
        rules.sunday = PackPercentRule(percent: 300, source: "Test")
        XCTAssertEqual(ConventionPackValidator.validate(validPack(rules: rules)), [])
        rules.sunday = PackPercentRule(percent: 0, source: "Test")
        XCTAssertEqual(ConventionPackValidator.validate(validPack(rules: rules)), [])
    }

    func testNaNPercentIsRejected() {
        XCTAssertFalse(ConventionPackValidator.isValidPercent(Double.nan))
        XCTAssertFalse(ConventionPackValidator.isValidPercent(Double.infinity))
        XCTAssertTrue(ConventionPackValidator.isValidPercent(12.5))
    }

    func testNightWindowErrors() {
        var rules = validRules()
        rules.night = PackNightRule(startMinute: 360, endMinute: 360, percent: 25, source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidNightWindow(start: 360, end: 360)))
        rules.night = PackNightRule(startMinute: 1440, endMinute: 360, percent: 25, source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidNightWindow(start: 1440, end: 360)))
        rules.night = PackNightRule(startMinute: -1, endMinute: 360, percent: 25, source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidNightWindow(start: -1, end: 360)))
        rules.night = PackNightRule(startMinute: 1439, endMinute: 0, percent: 25, source: "Test")
        XCTAssertEqual(ConventionPackValidator.validate(validPack(rules: rules)), [])
    }

    func testDateValidation() {
        XCTAssertTrue(ConventionPackValidator.isValidDate("2026-11-17"))
        XCTAssertTrue(ConventionPackValidator.isValidDate("2028-02-29"))
        XCTAssertFalse(ConventionPackValidator.isValidDate("2026-02-29"))
        XCTAssertFalse(ConventionPackValidator.isValidDate("2026-13-01"))
        XCTAssertFalse(ConventionPackValidator.isValidDate("2026-04-31"))
        XCTAssertFalse(ConventionPackValidator.isValidDate("2026-1-5"))
        XCTAssertFalse(ConventionPackValidator.isValidDate("17/11/2026"))
        XCTAssertFalse(ConventionPackValidator.isValidDate(""))
        XCTAssertFalse(ConventionPackValidator.isValidDate("1800-01-01"))
    }

    func testInvalidDatesInPack() {
        var pack = validPack(rules: validRules())
        pack.validFrom = "2026-13-01"
        pack.verifiedOn = "demain"
        let errors = ConventionPackValidator.validate(pack)
        XCTAssertTrue(errors.contains(.invalidDate(field: "validité", value: "2026-13-01")))
        XCTAssertTrue(errors.contains(.invalidDate(field: "vérification", value: "demain")))
        var rules = validRules()
        rules.sunday = PackPercentRule(percent: 50, source: "Test", sourceDate: "2026-02-30")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidDate(field: "dimanche", value: "2026-02-30")))
    }

    func testRuleWithoutSourceIsRejected() {
        var rules = validRules()
        rules.sunday = PackPercentRule(percent: 50, source: "   ")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.missingSource(rule: "dimanche")))
    }

    func testOvertimeErrors() {
        var rules = validRules()
        rules.overtime = PackOvertimeRule(weeklyThresholdMinutes: 0, bands: [PackOvertimeBand(overMinutes: nil, percent: 25)], source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidOvertimeThreshold(0)))
        rules.overtime = PackOvertimeRule(weeklyThresholdMinutes: 20000, bands: [PackOvertimeBand(overMinutes: nil, percent: 25)], source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidOvertimeThreshold(20000)))
        rules.overtime = PackOvertimeRule(weeklyThresholdMinutes: 2100, bands: [], source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidOvertimeBands("aucune tranche")))
        // Dernière tranche bornée.
        rules.overtime = PackOvertimeRule(weeklyThresholdMinutes: 2100, bands: [PackOvertimeBand(overMinutes: 480, percent: 25)], source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidOvertimeBands("la dernière tranche doit être sans limite")))
        // Tranche sans limite au milieu.
        rules.overtime = PackOvertimeRule(weeklyThresholdMinutes: 2100,
                                          bands: [PackOvertimeBand(overMinutes: nil, percent: 25), PackOvertimeBand(overMinutes: nil, percent: 50)],
                                          source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidOvertimeBands("seule la dernière tranche peut être sans limite")))
        // Durée de tranche nulle.
        rules.overtime = PackOvertimeRule(weeklyThresholdMinutes: 2100,
                                          bands: [PackOvertimeBand(overMinutes: 0, percent: 25), PackOvertimeBand(overMinutes: nil, percent: 50)],
                                          source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidOvertimeBands("une tranche a une durée nulle ou négative")))
    }

    func testMinimumRateHolidayScopeAndCumulationErrors() {
        var rules = validRules()
        rules.minimumRate = PackMinimumRate(hourlyCents: 0, label: "x", source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.invalidMinimumRate(0)))
        rules = validRules()
        rules.publicHoliday = PackHolidayRule(scope: "toujours", percent: 100, source: "Test")
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.unknownHolidayScope("toujours")))
        rules = validRules()
        rules.cumulation = "multiply"
        XCTAssertTrue(ConventionPackValidator.validate(validPack(rules: rules)).contains(.unknownCumulation("multiply")))
        rules.cumulation = "sum"
        XCTAssertEqual(ConventionPackValidator.validate(validPack(rules: rules)), [])
    }

    func testErrorMessagesAreFrenchAndHaveNoEmDash() {
        let errors: [PackValidationError] = [.emptyID, .duplicateID("a"), .emptyName, .invalidIDCC("x"), .invalidDate(field: "f", value: "v"),
                                             .percentOutOfRange(rule: "r", value: 1), .invalidNightWindow(start: 1, end: 1),
                                             .invalidOvertimeThreshold(0), .invalidOvertimeBands("b"), .invalidMinimumRate(0),
                                             .unknownHolidayScope("s"), .unknownCumulation("c"), .missingSource(rule: "r")]
        for e in errors {
            XCTAssertFalse(e.message.isEmpty)
            XCTAssertFalse(e.message.contains("\u{2014}"))
        }
    }

    // MARK: décodage et chargement

    private let packJSON: String = """
    {
      "id": "json-pack",
      "name": "Pack JSON",
      "idcc": "1517",
      "keywords": ["magasin"],
      "rules": {
        "sunday": {"percent": 20, "source": "Test", "sourceDate": "2026-11-17"},
        "overtime": {"weeklyThresholdMinutes": 2100, "bands": [{"overMinutes": 480, "percent": 25}, {"percent": 50}], "source": "Test"}
      }
    }
    """

    func testDecodeSinglePackWithMissingOptionalFields() throws {
        let packs = try ConventionPackLoader.decode(data: Data(packJSON.utf8))
        XCTAssertEqual(packs.count, 1)
        XCTAssertEqual(packs[0].id, "json-pack")
        XCTAssertEqual(packs[0].idcc, "1517")
        XCTAssertEqual(packs[0].summary, "")
        XCTAssertEqual(packs[0].toFill, [])
        XCTAssertNil(packs[0].verifiedOn)
        XCTAssertTrue(packs[0].isUnverified)
        XCTAssertEqual(packs[0].rules.sunday?.percent, 20)
        XCTAssertEqual(packs[0].rules.overtime?.weeklyThresholdMinutes, 2100)
        XCTAssertEqual(packs[0].rules.overtime?.bands.count, 2)
        XCTAssertNil(packs[0].rules.overtime?.bands[1].overMinutes)
        XCTAssertNil(packs[0].rules.night)
        XCTAssertEqual(ConventionPackValidator.validate(packs[0]), [])
    }

    func testDecodeArrayOfPacks() throws {
        let json: String = "[" + packJSON + ", {\"id\": \"second\", \"name\": \"Second\"}]"
        let packs = try ConventionPackLoader.decode(data: Data(json.utf8))
        XCTAssertEqual(packs.map { (p: ConventionPack) -> String in p.id }, ["json-pack", "second"])
        XCTAssertTrue(packs[1].rules.isEmpty)
    }

    func testDecodeInvalidJSONThrows() {
        XCTAssertThrowsError(try ConventionPackLoader.decode(data: Data("pas du json".utf8)))
        XCTAssertThrowsError(try ConventionPackLoader.decode(data: Data("{\"name\": \"sans id\"}".utf8)))
    }

    func testPackEncodesAndDecodesToTheSameValue() throws {
        let pack = validPack(rules: validRules())
        let data = try JSONEncoder().encode(pack)
        let back = try JSONDecoder().decode(ConventionPack.self, from: data)
        XCTAssertEqual(back, pack)
    }

    func testAcceptRejectsInvalidAndDuplicatePacks() {
        var bad = validPack(id: "bad")
        bad.rules.sunday = PackPercentRule(percent: 999, source: "Test")
        let outcome = ConventionPackLoader.accept([validPack(id: "ok"), bad, validPack(id: "ok")], fileName: "convention_test.json")
        XCTAssertEqual(outcome.accepted.count, 1)
        XCTAssertEqual(outcome.accepted[0].id, "ok")
        XCTAssertEqual(outcome.rejected.count, 2)
        XCTAssertEqual(outcome.rejected[0].packID, "bad")
        XCTAssertEqual(outcome.rejected[0].errors, [.percentOutOfRange(rule: "dimanche", value: 999)])
        XCTAssertEqual(outcome.rejected[1].errors, [.duplicateID("ok")])
        XCTAssertEqual(outcome.rejected[1].fileName, "convention_test.json")
    }

    // MARK: fichiers livrés avec l'app

    func testBundledPacksLoadWithoutRejection() {
        let loaded = ConventionCatalog.bundled
        XCTAssertEqual(loaded.rejected, [])
        XCTAssertEqual(loaded.unreadableFiles, [])
        XCTAssertGreaterThanOrEqual(loaded.packs.count, 2)
        var ids: Set<String> = []
        for p in loaded.packs {
            XCTAssertFalse(ids.contains(p.id))
            ids.insert(p.id)
        }
    }

    func testBundledGenericPackIsMarkedUnverifiedWithSources() {
        guard let generic = ConventionCatalog.bundled.packs.first(where: { (p: ConventionPack) -> Bool in p.id == ConventionCatalog.genericID }) else {
            XCTFail("Le pack général est absent du bundle")
            return
        }
        XCTAssertTrue(generic.name.contains("valeurs à vérifier"))
        XCTAssertTrue(generic.isUnverified)
        XCTAssertFalse(generic.sourceNote.isEmpty)
        XCTAssertNotNil(generic.rules.overtime)
        XCTAssertNil(generic.rules.night)
        XCTAssertNil(generic.rules.sunday)
        XCTAssertFalse(generic.toFill.isEmpty)
    }

    func testBundledPacksOtherThanGenericHaveNoRuleValues() {
        // Seuls les noms et numéros IDCC sont livrés : aucune règle inventée dans les packs de la liste.
        for p in ConventionCatalog.bundled.packs where p.id != ConventionCatalog.genericID {
            XCTAssertTrue(p.rules.isEmpty, "Le pack \(p.id) contient des règles non sourcées")
            XCTAssertTrue(p.isUnverified)
        }
    }

    func testBundledSupermarketPackIsFoundByIDCC() {
        let found = ConventionCatalog.search("2216", in: ConventionCatalog.bundled.packs)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].idcc, "2216")
    }

    // MARK: recherche

    private func catalog() -> [ConventionPack] {
        return [validPack(id: "idcc-2216", name: "Commerce à prédominance alimentaire", idcc: "2216", keywords: ["supermarché", "caisse"]),
                validPack(id: "idcc-1090", name: "Commerce et réparation de l'automobile", idcc: "1090", keywords: ["garage", "vendeur auto"]),
                validPack(id: "idcc-16", name: "Transports routiers", idcc: "16", keywords: ["livraison"]),
                validPack(id: "custom", name: "Personnalisée", idcc: nil, keywords: ["perso"])]
    }

    func testSearchIgnoresAccentsAndCase() {
        XCTAssertEqual(ConventionCatalog.search("SUPERMARCHE", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-2216"])
        XCTAssertEqual(ConventionCatalog.search("supermarché", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-2216"])
        XCTAssertEqual(ConventionCatalog.search("reparation", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-1090"])
    }

    func testSearchByIDCCWithAndWithoutLeadingZero() {
        XCTAssertEqual(ConventionCatalog.search("2216", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-2216"])
        XCTAssertEqual(ConventionCatalog.search("0016", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-16"])
        XCTAssertEqual(ConventionCatalog.search("16", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-16"])
        XCTAssertEqual(ConventionCatalog.search("9999", in: catalog()), [])
    }

    func testSearchToleratesOneTypoOnLongWords() {
        // "supermarce" est à une lettre de "supermarche".
        XCTAssertEqual(ConventionCatalog.search("supermarce", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-2216"])
        // Un mot court ne tolère pas de faute : "gara" n'est pas "garage" par faute, mais il est contenu dedans.
        XCTAssertEqual(ConventionCatalog.search("gara", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-1090"])
        XCTAssertEqual(ConventionCatalog.search("boulangerie", in: catalog()), [])
    }

    func testSearchNeedsAllWordsAndEmptyQueryReturnsEverything() {
        XCTAssertEqual(ConventionCatalog.search("commerce garage", in: catalog()).map { (p: ConventionPack) -> String in p.id }, ["idcc-1090"])
        XCTAssertEqual(ConventionCatalog.search("commerce piscine", in: catalog()), [])
        XCTAssertEqual(ConventionCatalog.search("", in: catalog()).count, 4)
        XCTAssertEqual(ConventionCatalog.search("   ", in: catalog()).count, 4)
    }

    func testEditDistance() {
        XCTAssertEqual(ConventionCatalog.editDistance("chat", "chat"), 0)
        XCTAssertEqual(ConventionCatalog.editDistance("chat", "chats"), 1)
        XCTAssertEqual(ConventionCatalog.editDistance("chat", "chut"), 1)
        XCTAssertEqual(ConventionCatalog.editDistance("kitten", "sitting"), 3)
        XCTAssertEqual(ConventionCatalog.editDistance("", "abc"), 3)
    }

    // MARK: choix d'un pack

    func testPackResolution() {
        let packs: [ConventionPack] = catalog() + [validPack(id: ConventionCatalog.genericID, name: "Général", idcc: nil)]
        XCTAssertEqual(ConventionCatalog.pack(for: "idcc-1090", in: packs).id, "idcc-1090")
        XCTAssertEqual(ConventionCatalog.pack(for: "2216", in: packs).id, "idcc-2216")
        XCTAssertEqual(ConventionCatalog.pack(for: "02216", in: packs).id, "idcc-2216")
        XCTAssertEqual(ConventionCatalog.pack(for: nil, in: packs).id, ConventionCatalog.genericID)
        XCTAssertEqual(ConventionCatalog.pack(for: "", in: packs).id, ConventionCatalog.genericID)
        XCTAssertEqual(ConventionCatalog.pack(for: "inconnue", in: packs).id, ConventionCatalog.genericID)
    }

    func testPackResolutionWithNoPacksGivesAnEmptyFallback() {
        let pack = ConventionCatalog.pack(for: "2216", in: [])
        XCTAssertTrue(pack.rules.isEmpty)
        XCTAssertNil(pack.rules.overtime)
    }

    // MARK: surcharges

    func testOverridesRoundTripAndPriority() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let pack = validPack(id: "p1", rules: validRules())
        XCTAssertEqual(ConventionOverrides.load(packID: "p1", defaults: defaults), ConventionRules())
        let mine = ConventionRules(sunday: PackPercentRule(percent: 30, source: "Saisi par toi"))
        XCTAssertEqual(ConventionOverrides.save(mine, packID: "p1", defaults: defaults), [])
        XCTAssertEqual(ConventionOverrides.load(packID: "p1", defaults: defaults), mine)
        let effective = ConventionOverrides.effectiveRules(pack: pack, overrides: mine)
        XCTAssertEqual(effective.sunday?.percent, 30)
        XCTAssertEqual(effective.night?.percent, 25)
        XCTAssertEqual(effective.overtime?.weeklyThresholdMinutes, 2100)
        // Les surcharges d'un pack ne touchent pas un autre pack.
        XCTAssertEqual(ConventionOverrides.load(packID: "p2", defaults: defaults), ConventionRules())
    }

    func testInvalidOverridesAreNotWritten() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let bad = ConventionRules(sunday: PackPercentRule(percent: 1000, source: "Saisi par toi"))
        let errors = ConventionOverrides.save(bad, packID: "p1", defaults: defaults)
        XCTAssertEqual(errors, [.percentOutOfRange(rule: "dimanche", value: 1000)])
        XCTAssertNil(defaults.data(forKey: ConventionOverrides.key(packID: "p1")))
    }

    func testSavingEmptyOverridesAndClearRemoveTheKey() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let mine = ConventionRules(sunday: PackPercentRule(percent: 30, source: "Saisi par toi"))
        ConventionOverrides.save(mine, packID: "p1", defaults: defaults)
        XCTAssertNotNil(defaults.data(forKey: ConventionOverrides.key(packID: "p1")))
        ConventionOverrides.save(ConventionRules(), packID: "p1", defaults: defaults)
        XCTAssertNil(defaults.data(forKey: ConventionOverrides.key(packID: "p1")))
        ConventionOverrides.save(mine, packID: "p1", defaults: defaults)
        ConventionOverrides.clear(packID: "p1", defaults: defaults)
        XCTAssertEqual(ConventionOverrides.load(packID: "p1", defaults: defaults), ConventionRules())
    }

    func testCorruptedOverridesReadAsEmpty() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("pas du json".utf8), forKey: ConventionOverrides.key(packID: "p1"))
        XCTAssertEqual(ConventionOverrides.load(packID: "p1", defaults: defaults), ConventionRules())
    }

    func testMergedPrefersTheUsersRulesRuleByRule() {
        let base = validRules()
        let mine = ConventionRules(night: PackNightRule(startMinute: 1200, endMinute: 300, percent: 40, source: "Saisi par toi"), cumulation: "sum")
        let merged = mine.merged(over: base)
        XCTAssertEqual(merged.night?.percent, 40)
        XCTAssertEqual(merged.night?.startMinute, 1200)
        XCTAssertEqual(merged.sunday?.percent, 50)
        XCTAssertEqual(merged.cumulationMode, .sum)
        XCTAssertEqual(base.cumulationMode, .highest)
    }

    // MARK: primes stockées

    func testPremiumStoreRoundTripKeepsEveryField() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let start: Date = makeDate(TestCalendar.utc, 2026, 11, 1, 0, 0)
        let p = PayPremium(id: "fixed-id", employerKey: "emp", name: "Prime soirée", kind: .repas, amountType: .fixed, amountCents: 550,
                           percent: 0, frequency: .perDay, basis: .net, subjectToContributions: false, condition: .evening,
                           eveningStartMinute: 1200, startDate: start, endDate: nil, anchorDate: nil, note: "note")
        XCTAssertTrue(PremiumStore.save([p], defaults: defaults))
        let loaded = PremiumStore.load(defaults: defaults)
        XCTAssertFalse(loaded.failed)
        XCTAssertEqual(loaded.premiums, [p])
    }

    func testPremiumStoreEmptyAndCorrupted() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(PremiumStore.load(defaults: defaults), PremiumLoad(premiums: [], failed: false))
        defaults.set(Data("pas du json".utf8), forKey: PremiumStore.key)
        let loaded = PremiumStore.load(defaults: defaults)
        XCTAssertTrue(loaded.failed)
        XCTAssertTrue(loaded.premiums.isEmpty)
    }

    func testPremiumStoreUpsertRemoveAndFilterByEmployer() {
        let a = PayPremium(id: "a", employerKey: "e1", name: "A", amountCents: 100, frequency: .monthly)
        let b = PayPremium(id: "b", employerKey: "e2", name: "B", amountCents: 200, frequency: .monthly)
        var all: [PayPremium] = [a, b]
        var changed = a
        changed.amountCents = 150
        all = PremiumStore.upserting(changed, in: all)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].amountCents, 150)
        all = PremiumStore.upserting(PayPremium(id: "c", employerKey: "e1", name: "C", amountCents: 300, frequency: .monthly), in: all)
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(PremiumStore.premiums(for: "e1", in: all).map { (p: PayPremium) -> String in p.id }, ["a", "c"])
        all = PremiumStore.removing(id: "a", from: all)
        XCTAssertEqual(all.map { (p: PayPremium) -> String in p.id }, ["b", "c"])
    }
}
