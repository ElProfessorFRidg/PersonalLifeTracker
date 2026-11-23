import XCTest
@testable import PersonalLifeTracker

/// Taf, école, courses : valeurs attendues calculées à la main à partir des poids de notes/place_identification.md.
final class PlaceKindClassifierTests: XCTestCase {
    private let calendar: Calendar = TestCalendar.paris

    private func visit(_ month: Int, _ day: Int, _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int) -> PlaceVisitObservation {
        return PlaceVisitObservation(arrival: makeDate(calendar, 2026, month, day, h1, m1),
                                     departure: makeDate(calendar, 2026, month, day, h2, m2), accuracy: 20)
    }

    /// Deux semaines du lundi au vendredi (9 au 13 et 16 au 20 novembre 2026), 8 h 30 à 12 h puis 13 h 30 à 17 h 30.
    private var schoolVisits: [PlaceVisitObservation] {
        var list: [PlaceVisitObservation] = []
        for day in [9, 10, 11, 12, 13, 16, 17, 18, 19, 20] {
            list.append(visit(11, day, 8, 30, 12, 0))
            list.append(visit(11, day, 13, 30, 17, 30))
        }
        return list
    }

    /// Mercredis 18 h à 21 h (4, 11, 18 novembre) et samedis 9 h à 17 h (7, 14, 21 novembre).
    private var shiftVisits: [PlaceVisitObservation] {
        var list: [PlaceVisitObservation] = []
        for day in [4, 11, 18] { list.append(visit(11, day, 18, 0, 21, 0)) }
        for day in [7, 14, 21] { list.append(visit(11, day, 9, 0, 17, 0)) }
        return list
    }

    /// Mardis de 10 h à 10 h 20 (27 octobre, 3, 10 et 17 novembre).
    private var errandVisits: [PlaceVisitObservation] {
        return [visit(10, 27, 10, 0, 10, 20), visit(11, 3, 10, 0, 10, 20),
                visit(11, 10, 10, 0, 10, 20), visit(11, 17, 10, 0, 10, 20)]
    }

    private func signals(visits: [PlaceVisitObservation] = [], name: String? = nil, poi: String? = nil,
                         nearby: [NearbyPlaceHint] = [], lessons: [PlaceKindLesson] = []) -> PlaceKindSignals {
        return PlaceKindSignals(visits: visits, name: name, poi: poi, poiCategory: nil, latitude: 48.85, longitude: 2.35,
                                nearby: nearby, lessons: lessons, calendar: calendar)
    }

    private func lesson(_ key: String, chosen: PlaceType?, suggested: PlaceType?) -> PlaceKindLesson {
        return PlaceKindLesson(key: key, latitude: 48.8501, longitude: 2.35, chosen: chosen?.rawValue,
                               suggested: suggested?.rawValue, patternKey: nil,
                               date: makeDate(calendar, 2026, 11, 20, 12, 0))
    }

    // MARK: Horaires

    func testFiveDayPatternWithLunchGapAndNoWeekendLeansSchoolButAsks() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits))
        // École : 25 (lundi au vendredi) + 20 (heure régulière) + 15 (durée) + 15 (midi) + 10 (5 jours) = 85, plafonné à 69 pour les horaires seuls.
        // Taf : 15 (plus de 2 h sur plusieurs jours).
        XCTAssertEqual(decision.scores[.cours], 69)
        XCTAssertEqual(decision.scores[.taf], 15)
        XCTAssertEqual(decision.leaning, .cours)
        XCTAssertEqual(decision.verdict, .ask)
        XCTAssertEqual(decision.confidence, 69)
        XCTAssertTrue(decision.explanation.contains("ton école"))
        XCTAssertTrue(decision.reasons.contains("tu y vas du lundi au vendredi, sans week-end"))
    }

    func testShiftsOnWednesdayEveningAndSaturdayLeanWork() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: shiftVisits))
        // Taf : 15 + 25 (soirs) + 25 (week-end) + 15 (heures irrégulières) + 10 (durées variables) = 90, plafonné à 69. École : 0.
        XCTAssertEqual(decision.scores[.taf], 69)
        XCTAssertEqual(decision.scores[.cours], 0)
        XCTAssertEqual(decision.leaning, .taf)
        XCTAssertEqual(decision.verdict, .ask)
    }

    func testShortRepeatedTuesdayVisitsAreErrands() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: errandVisits))
        // Courses : 45 (moins de 45 min) + 10 (plusieurs jours) = 55. Rien d'autre.
        XCTAssertEqual(decision.scores[.courses], 55)
        XCTAssertEqual(decision.scores[.taf], 0)
        XCTAssertEqual(decision.scores[.cours], 0)
        XCTAssertEqual(decision.leaning, .courses)
        XCTAssertEqual(decision.verdict, .ask)
    }

    func testThreeNightsMeansHomeAndIsConfident() {
        var visits: [PlaceVisitObservation] = []
        for day in [16, 17, 18] {
            visits.append(PlaceVisitObservation(arrival: makeDate(calendar, 2026, 11, day, 22, 0),
                                                departure: makeDate(calendar, 2026, 11, day + 1, 6, 0), accuracy: 20))
        }
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: visits))
        XCTAssertEqual(decision.scores[.domicile], 75)
        XCTAssertEqual(decision.leaning, .domicile)
        XCTAssertEqual(decision.verdict, .confident)
        XCTAssertTrue(decision.statement.hasPrefix("Je pense que c'est ton domicile, parce que"))
    }

    func testNoSignalAsksWithoutGuessing() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals())
        XCTAssertNil(decision.leaning)
        XCTAssertEqual(decision.verdict, .ask)
        XCTAssertEqual(decision.statement, "")
        XCTAssertTrue(decision.explanation.contains("pas assez d'indices"))
        XCTAssertEqual(decision.question, "C'est ton taf, ton école ou autre chose ?")
    }

    func testTooFewVisitsDoNotCountAsAPattern() {
        // Trois passages seulement : aucun motif d'horaires (minimum 4), école à 0.
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: Array(schoolVisits.prefix(3))))
        XCTAssertEqual(decision.scores[.cours], 0)
        XCTAssertEqual(decision.verdict, .ask)
    }

    func testHolidayWeekIsDetectedBetweenRegularWeeks() {
        // Semaines du 2 et du 16 novembre présentes, celle du 9 vide : une semaine entière sans passage entre deux semaines régulières.
        var visits: [PlaceVisitObservation] = []
        for day in [2, 3, 4, 5, 6, 16, 17, 18, 19, 20] {
            visits.append(visit(11, day, 8, 30, 12, 0))
            visits.append(visit(11, day, 13, 30, 17, 30))
        }
        let pattern: PlaceVisitPattern = PlaceVisitPattern.analyze(visits, calendar: calendar)
        XCTAssertTrue(pattern.hasHolidayGap)
        let none: PlaceVisitPattern = PlaceVisitPattern.analyze(schoolVisits, calendar: calendar)
        XCTAssertFalse(none.hasHolidayGap)
    }

    // MARK: Nom et catégorie Plans

    func testSchoolNameAndTimePatternAreConfident() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, name: "Lycée Pasteur"))
        // 69 (horaires) + 50 (nom) = 119, plafonné à 100 ; taf 15.
        XCTAssertEqual(decision.scores[.cours], 100)
        XCTAssertEqual(decision.verdict, .confident)
        XCTAssertEqual(decision.leaning, .cours)
        XCTAssertTrue(decision.statement.hasPrefix("Je pense que c'est ton école, parce que"))
        XCTAssertTrue(decision.statement.contains("le nom contient « lycée »"))
    }

    func testNameKeywordOutranksConflictingPlansCategory() {
        // Nom d'école (50) contre catégorie commerce (30, divisée par 2 car le nom dit autre chose = 15).
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(name: "Lycée Pasteur", poi: "MKPOICategoryStore"))
        XCTAssertEqual(decision.scores[.cours], 50)
        XCTAssertEqual(decision.scores[.courses], 15)
        XCTAssertEqual(decision.leaning, .cours)
        XCTAssertEqual(decision.verdict, .ask)
    }

    func testPlansSchoolCategoryAloneLeansSchoolButAsks() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(poi: "MKPOICategorySchool"))
        XCTAssertEqual(decision.scores[.cours], 45)
        XCTAssertEqual(decision.leaning, .cours)
        XCTAssertEqual(decision.verdict, .ask)
        let library: PlaceKindDecision = PlaceKindClassifier.decide(signals(poi: "MKPOICategoryLibrary"))
        XCTAssertEqual(library.scores[.cours], 20)
        XCTAssertNil(library.leaning)
    }

    func testNameAndCategoryThatAgreeAreConfident() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(name: "Boulangerie Paul", poi: "MKPOICategoryBakery"))
        // 40 (mot du nom) + 30 (catégorie) = 70, sans concurrent : confiance 70, seuil atteint.
        XCTAssertEqual(decision.scores[.courses], 70)
        XCTAssertEqual(decision.confidence, 70)
        XCTAssertEqual(decision.verdict, .confident)
    }

    func testShortKeywordsNeedWholeWords() {
        // "fac" est un mot entier ; "facture" ne doit pas compter. "bar" idem pour "barbier".
        XCTAssertEqual(PlaceKindClassifier.decide(signals(name: "Fac de droit")).scores[.cours], 50)
        XCTAssertEqual(PlaceKindClassifier.decide(signals(name: "Facture express")).scores[.cours], 0)
        XCTAssertEqual(PlaceKindClassifier.decide(signals(name: "Barbier")).scores[.sortie], 0)
    }

    func testNameContradictingScheduleAsksAndExplainsTheConflict() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, name: "Hôpital Nord"))
        // Nom : taf 40 (+15 horaires) = 55 ; horaires : école 69. Désaccord franc : on ne devine pas, on demande, confiance plafonnée à 60.
        XCTAssertNotNil(decision.conflict)
        XCTAssertEqual(decision.verdict, .ask)
        XCTAssertLessThanOrEqual(decision.confidence, 60)
        XCTAssertTrue(decision.explanation.contains("Le nom ou Plans indique ton taf"))
    }

    func testPlansSchoolButShiftScheduleIsAConflict() {
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: shiftVisits, poi: "MKPOICategoryUniversity"))
        XCTAssertEqual(decision.leaning, .taf)
        XCTAssertEqual(decision.verdict, .ask)
        XCTAssertTrue(decision.explanation.contains("ton école"))
    }

    // MARK: Ce que l'utilisateur a déjà dit

    func testExistingSchoolNearbyAddsPointsAndMakesItConfident() {
        let hint: NearbyPlaceHint = NearbyPlaceHint(type: .cours, distance: 200, name: "Lycée A", isContractPlace: false)
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, nearby: [hint]))
        XCTAssertEqual(decision.scores[.cours], 94)
        XCTAssertEqual(decision.verdict, .confident)
        XCTAssertTrue(decision.statement.contains("tu as déjà une école, « Lycée A », à 200 m"))
    }

    func testContractPlaceNearbyMakesShiftsConfidentlyWork() {
        let hint: NearbyPlaceHint = NearbyPlaceHint(type: .taf, distance: 100, name: "Magasin Dupont", isContractPlace: true)
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: shiftVisits, nearby: [hint]))
        XCTAssertEqual(decision.scores[.taf], 100)
        XCTAssertEqual(decision.verdict, .confident)
        XCTAssertTrue(decision.statement.contains("ton lieu de contrat « Magasin Dupont » est à 100 m"))
        let far: NearbyPlaceHint = NearbyPlaceHint(type: .taf, distance: 900, name: "Loin", isContractPlace: true)
        XCTAssertEqual(PlaceKindClassifier.decide(signals(nearby: [far])).scores[.taf], 0)
    }

    func testOneCorrectionFlipsTheNextDecision() {
        let before: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits))
        XCTAssertEqual(before.leaning, .cours)
        let corrected: PlaceKindLesson = lesson("a", chosen: .taf, suggested: .cours)
        let after: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, lessons: [corrected]))
        // École : 69 - 35 (corrigé) = 34. Taf : 15 + 45 (réponse voisine) = 60.
        XCTAssertEqual(after.scores[.cours], 34)
        XCTAssertEqual(after.scores[.taf], 60)
        XCTAssertEqual(after.leaning, .taf)
        XCTAssertEqual(after.verdict, .ask)
    }

    func testTwoConcordantAnswersOverrideEveryHeuristic() {
        let lessons: [PlaceKindLesson] = [lesson("a", chosen: .taf, suggested: .cours), lesson("b", chosen: .taf, suggested: .cours)]
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, name: "Lycée Pasteur", lessons: lessons))
        // École : 69 + 50 - 70 (deux corrections) = 49, ramenée à 35 par la réponse imposée.
        XCTAssertEqual(decision.scores[.taf], 100)
        XCTAssertEqual(decision.scores[.cours], 35)
        XCTAssertEqual(decision.leaning, .taf)
        XCTAssertEqual(decision.verdict, .confident)
        XCTAssertGreaterThanOrEqual(decision.confidence, 95)
        XCTAssertTrue(decision.statement.contains("tu m'as déjà répondu 2 fois que c'était ton taf"))
    }

    func testRefusedSuggestionLowersThatKindNearby() {
        let refusal: PlaceKindLesson = lesson("r", chosen: nil, suggested: .cours)
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, lessons: [refusal]))
        XCTAssertEqual(decision.scores[.cours], 34)
    }

    func testFarAwayLessonsDoNotApply() {
        let far: PlaceKindLesson = PlaceKindLesson(key: "far", latitude: 48.90, longitude: 2.35, chosen: "taf",
                                                   suggested: "cours", patternKey: nil, date: makeDate(calendar, 2026, 11, 20, 12, 0))
        let decision: PlaceKindDecision = PlaceKindClassifier.decide(signals(visits: schoolVisits, lessons: [far]))
        XCTAssertEqual(decision.scores[.cours], 69)
    }

    // MARK: Mémoire

    func testStoreReplacesSameKeyIgnoresInvalidAndLearnsMergeDistance() {
        let (defaults, name) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store: PlaceKindStore = PlaceKindStore(defaults: defaults)
        let now: Date = makeDate(calendar, 2026, 11, 20, 12, 0)
        store.recordChoice(key: "s1", latitude: 48.85, longitude: 2.35, chosen: .cours, suggested: .taf, patternKey: nil, now: now)
        store.recordChoice(key: "s1", latitude: 48.85, longitude: 2.35, chosen: .taf, suggested: .taf, patternKey: nil, now: now)
        store.recordChoice(key: "zero", latitude: 0, longitude: 0, chosen: .taf, suggested: nil, patternKey: nil, now: now)
        store.recordRefusal(key: "nothing", latitude: 48.85, longitude: 2.35, suggested: nil, patternKey: nil, now: now)
        XCTAssertEqual(store.memory.lessons.count, 1)
        XCTAssertEqual(store.memory.lessons.first?.chosen, "taf")
        XCTAssertNil(store.memory.learnedMergeDistance)
        store.recordMerge(gap: 180)
        store.recordMerge(gap: 90)
        XCTAssertEqual(store.memory.learnedMergeDistance, 200)
        XCTAssertEqual(PlaceSuggestionMerge.mergeDistance(accuracyA: 20, accuracyB: 20,
                                                          learnedDistance: store.memory.learnedMergeDistance), 200)
        store.reset()
        XCTAssertTrue(store.memory.lessons.isEmpty)
    }

    func testLessonsOlderThanAYearAreForgotten() {
        var memory: PlaceKindMemory = PlaceKindMemory()
        let old: Date = makeDate(calendar, 2025, 1, 10, 12, 0)
        let now: Date = makeDate(calendar, 2026, 11, 20, 12, 0)
        memory.record(PlaceKindLesson(key: "old", latitude: 48.85, longitude: 2.35, chosen: "taf", suggested: nil,
                                      patternKey: nil, date: old), now: now)
        XCTAssertTrue(memory.lessons.isEmpty)
    }

    func testSessionActivityMapsToPlaceType() {
        XCTAssertEqual(HabitLearning.placeType(for: .work), .taf)
        XCTAssertEqual(HabitLearning.placeType(for: .education), .cours)
        XCTAssertEqual(HabitLearning.placeType(for: .shopping), .courses)
        XCTAssertNil(HabitLearning.placeType(for: .personal))
        XCTAssertNil(HabitLearning.placeType(for: .travel))
        XCTAssertNil(HabitLearning.placeType(for: .unknown))
    }
}
