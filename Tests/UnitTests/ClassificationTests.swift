import XCTest
@testable import PersonalLifeTracker

/// Section 11 (travail contre courses), section 12 (études), section 9 (habitudes).
/// Toutes les valeurs attendues sont écrites à la main depuis la spec (seuils 20 min, 2 h, 40, 75, 3 réponses).
final class ClassificationTests: XCTestCase {

    private let cal: Calendar = TestCalendar.utc
    private let placeKey: String = "lieu-intermarche"

    /// Visite dans un lieu de courses où l'on travaille aussi, arrivée le lundi 16 novembre 2026 à 11:00 UTC.
    private func dual(seconds: TimeInterval?, start: Date = nov16(11, 0), shifts: [VisitPlannedShift] = []) -> VisitContext {
        return VisitContext(placeKey: placeKey, placeType: .courses, alsoWorksHere: true, start: start,
                            durationSeconds: seconds, plannedShifts: shifts)
    }

    private func classify(_ visit: VisitContext, habits: HabitModel = HabitModel()) -> ClassificationResult {
        return VisitClassifier.classify(visit, habits: habits, now: nov16(18, 0), calendar: cal)
    }

    private func learn(_ habits: inout HabitModel, _ key: String, isWork: Bool,
                        start: Date = nov16(11, 0), now: Date = nov16(12, 0)) {
        habits.record(sessionKey: key, placeKey: placeKey, visitStart: start, isWork: isWork, now: now, calendar: cal)
    }

    // MARK: Types de lieu (sections 11 et 12)

    func testWorkPlaceIsWorkWhateverTheDuration() {
        let short = VisitContext(placeKey: "taf", placeType: .taf, alsoWorksHere: false, start: nov16(9, 0), durationSeconds: 60)
        let result = classify(short)
        XCTAssertEqual(result.activity, .work)
        XCTAssertEqual(result.confidence, 100)
        XCTAssertEqual(result.level, .automatic)
        XCTAssertFalse(result.needsConfirmation)
    }

    func testStudyPlaceIsEducationNeverWork() {
        let durations: [TimeInterval] = [60, 3 * 3600, 9 * 3600]
        for seconds in durations {
            let visit = VisitContext(placeKey: "lycee", placeType: .cours, alsoWorksHere: false, start: nov16(8, 0), durationSeconds: seconds)
            let result = classify(visit)
            XCTAssertEqual(result.activity, .education)
            XCTAssertEqual(result.level, .automatic)
        }
    }

    func testStudyPlaceIgnoresWorkHabits() {
        var habits = HabitModel()
        for i in 0..<3 {
            habits.record(sessionKey: "w\(i)", placeKey: "lycee", visitStart: nov16(8, 0), isWork: true, now: nov16(12, 0), calendar: cal)
        }
        let visit = VisitContext(placeKey: "lycee", placeType: .cours, alsoWorksHere: false, start: nov16(8, 0), durationSeconds: 3 * 3600)
        XCTAssertEqual(classify(visit, habits: habits).activity, .education)
    }

    func testPlainShoppingPlaceNeverCountsAsWork() {
        // Même avec une visite de 5 h, un créneau au planning et 3 réponses "travail" : jamais du travail.
        var habits = HabitModel()
        for i in 0..<3 {
            learn(&habits, "w\(i)", isWork: true)
        }
        let shift = VisitPlannedShift(start: nov16(10, 30), end: nov16(16, 0))
        let visit = VisitContext(placeKey: placeKey, placeType: .courses, alsoWorksHere: false, start: nov16(11, 0),
                                 durationSeconds: 5 * 3600, plannedShifts: [shift])
        let result = classify(visit, habits: habits)
        XCTAssertEqual(result.activity, .shopping)
        XCTAssertEqual(result.confidence, 100)
        XCTAssertFalse(result.needsConfirmation)
    }

    // MARK: Seuils de durée (section 11, facteur 3)

    func testDurationJustUnderTwentyMinutesIsProbablyShopping() {
        let result = classify(dual(seconds: 1199))
        XCTAssertEqual(result.activity, .shopping)
        XCTAssertEqual(result.confidence, 50)
        XCTAssertEqual(result.level, .provisional)
        XCTAssertTrue(result.needsConfirmation)
    }

    func testDurationExactlyTwentyMinutesIsAmbiguous() {
        let result = classify(dual(seconds: 1200))
        XCTAssertEqual(result.activity, .unknown)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertEqual(result.level, .unknown)
        XCTAssertTrue(result.needsConfirmation)
    }

    func testDurationJustOverTwentyMinutesIsAmbiguous() {
        let result = classify(dual(seconds: 1201))
        XCTAssertEqual(result.activity, .unknown)
        XCTAssertEqual(result.confidence, 0)
    }

    func testDurationExactlyTwoHoursIsAmbiguous() {
        let result = classify(dual(seconds: 7200))
        XCTAssertEqual(result.activity, .unknown)
        XCTAssertEqual(result.confidence, 0)
    }

    func testDurationJustOverTwoHoursIsProbablyWork() {
        let result = classify(dual(seconds: 7201))
        XCTAssertEqual(result.activity, .work)
        XCTAssertEqual(result.confidence, 50)
        XCTAssertEqual(result.level, .provisional)
    }

    func testUnknownDurationGivesNoEvidence() {
        let result = classify(dual(seconds: nil))
        XCTAssertEqual(result.activity, .unknown)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertTrue(result.needsConfirmation)
    }

    // MARK: Seuils de score (section 11 : 40 et 75)

    func testLevelBoundaries() {
        XCTAssertEqual(VisitClassifier.level(forConfidence: 0), .unknown)
        XCTAssertEqual(VisitClassifier.level(forConfidence: 39), .unknown)
        XCTAssertEqual(VisitClassifier.level(forConfidence: 40), .provisional)
        XCTAssertEqual(VisitClassifier.level(forConfidence: 75), .provisional)
        XCTAssertEqual(VisitClassifier.level(forConfidence: 76), .automatic)
        XCTAssertEqual(VisitClassifier.level(forConfidence: 100), .automatic)
    }

    func testScoreExactlyFortyFromPlanningIsProvisionalWork() {
        // Durée ambiguë (0 point) et arrivée dans un créneau (40 points) : 40, donc provisoire et non "inconnu".
        let shift = VisitPlannedShift(start: nov16(10, 30), end: nov16(16, 0))
        let result = classify(dual(seconds: 1500, shifts: [shift]))
        XCTAssertEqual(result.confidence, 40)
        XCTAssertEqual(result.activity, .work)
        XCTAssertEqual(result.level, .provisional)
    }

    func testLongVisitInsideShiftIsAutomaticWork() {
        // 50 (durée) + 40 (planning) = 90, au-dessus de 75 : automatique, sans question.
        let shift = VisitPlannedShift(start: nov16(10, 30), end: nov16(16, 0))
        let result = classify(dual(seconds: 3 * 3600, shifts: [shift]))
        XCTAssertEqual(result.confidence, 90)
        XCTAssertEqual(result.activity, .work)
        XCTAssertEqual(result.level, .automatic)
        XCTAssertFalse(result.needsConfirmation)
    }

    func testLongVisitWhenPlanningSaysOtherwiseDropsToUnknown() {
        // 50 (durée) - 15 (créneaux prévus ailleurs) = 35, sous 40 : inconnu avec confirmation.
        let shift = VisitPlannedShift(start: nov16(14, 0), end: nov16(18, 0))
        let result = classify(dual(seconds: 3 * 3600, start: nov16(8, 0), shifts: [shift]))
        XCTAssertEqual(result.confidence, 35)
        XCTAssertEqual(result.activity, .unknown)
        XCTAssertEqual(result.level, .unknown)
    }

    func testPlanningToleranceBoundary() {
        // Le créneau commence à 11:30 : arriver à 11:00 pile est encore dans la tolérance de 30 min, 10:59:59 non.
        let shift = VisitPlannedShift(start: nov16(11, 30), end: nov16(16, 0))
        let inside = classify(dual(seconds: 1500, start: nov16(11, 0), shifts: [shift]))
        XCTAssertEqual(inside.confidence, 40)
        XCTAssertEqual(inside.activity, .work)
        let outside = classify(dual(seconds: 1500, start: nov16(10, 59, 59), shifts: [shift]))
        XCTAssertEqual(outside.confidence, 15)
        XCTAssertEqual(outside.activity, .unknown)
    }

    func testPlanningEndBoundary() {
        let shift = VisitPlannedShift(start: nov16(8, 0), end: nov16(11, 0))
        let atEnd = classify(dual(seconds: 1500, start: nov16(11, 0), shifts: [shift]))
        XCTAssertEqual(atEnd.confidence, 40)
        let afterEnd = classify(dual(seconds: 1500, start: nov16(11, 0, 1), shifts: [shift]))
        XCTAssertEqual(afterEnd.confidence, 15)
    }

    // MARK: Apprentissage (sections 9 et 11)

    func testTwoAnswersAreOnlyAHintNotARule() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        // Durée ambiguë : 0 point, plus un indice de -20 : score 20, donc "inconnu", pas "courses".
        let result = classify(dual(seconds: 1500), habits: habits)
        XCTAssertEqual(result.activity, .unknown)
        XCTAssertEqual(result.confidence, 20)
        XCTAssertEqual(result.level, .unknown)
    }

    func testThirdConcordantAnswerMakesTheContextAutomatic() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        learn(&habits, "c", isWork: false)
        let result = classify(dual(seconds: 1500), habits: habits)
        XCTAssertEqual(result.activity, .shopping)
        XCTAssertEqual(result.confidence, 90)
        XCTAssertEqual(result.level, .automatic)
    }

    func testOneSingleAnswerNeverCreatesAHabit() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: true)
        let result = classify(dual(seconds: 1500), habits: habits)
        // Un seul avis : indice de +10, score 10, "inconnu".
        XCTAssertEqual(result.confidence, 10)
        XCTAssertEqual(result.activity, .unknown)
    }

    func testTwoWorkAnswersNudgeALongVisitButStayProvisional() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: true)
        learn(&habits, "b", isWork: true)
        // 50 (durée) + 20 (indice) = 70, pas encore au-dessus de 75.
        let result = classify(dual(seconds: 3 * 3600), habits: habits)
        XCTAssertEqual(result.confidence, 70)
        XCTAssertEqual(result.level, .provisional)
        XCTAssertEqual(result.activity, .work)
    }

    func testThreeCorrectionsFlipTheNextClassification() {
        // Sans habitude, une visite de 3 h est du travail provisoire. Après 3 corrections vers "courses", elle est courses.
        let before = classify(dual(seconds: 3 * 3600))
        XCTAssertEqual(before.activity, .work)
        XCTAssertEqual(before.level, .provisional)
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        learn(&habits, "c", isWork: false)
        let after = classify(dual(seconds: 3 * 3600), habits: habits)
        XCTAssertEqual(after.activity, .shopping)
        XCTAssertEqual(after.level, .automatic)
    }

    func testNewAnswersCanFlipALearnedRuleBack() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        learn(&habits, "c", isWork: false)
        learn(&habits, "d", isWork: true, now: nov16(13, 0))
        // Les 3 dernières ne sont plus concordantes : la règle apprise ne s'applique plus.
        let mixed = classify(dual(seconds: 1500), habits: habits)
        XCTAssertNotEqual(mixed.confidence, 90)
        learn(&habits, "e", isWork: true, now: nov16(14, 0))
        learn(&habits, "f", isWork: true, now: nov16(15, 0))
        let flipped = classify(dual(seconds: 1500), habits: habits)
        XCTAssertEqual(flipped.activity, .work)
        XCTAssertEqual(flipped.confidence, 90)
    }

    func testMixedAnswersGiveOnlyANetHint() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: true)
        learn(&habits, "b", isWork: true)
        learn(&habits, "c", isWork: false)
        // 2 travail, 1 courses : indice net de +10, pas de règle.
        let result = classify(dual(seconds: 1500), habits: habits)
        XCTAssertEqual(result.confidence, 10)
    }

    func testSameSessionAnsweredThreeTimesCountsOnce() {
        var habits = HabitModel()
        learn(&habits, "same", isWork: false)
        learn(&habits, "same", isWork: false)
        learn(&habits, "same", isWork: false)
        XCTAssertEqual(habits.observations.count, 1)
        XCTAssertNotEqual(classify(dual(seconds: 1500), habits: habits).confidence, 90)
    }

    func testChangingYourMindOnASessionReplacesTheAnswer() {
        var habits = HabitModel()
        learn(&habits, "x", isWork: false)
        learn(&habits, "x", isWork: true)
        XCTAssertEqual(habits.observations.count, 1)
        XCTAssertTrue(habits.observations[0].isWork)
    }

    func testLearningStaysInItsContext() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        learn(&habits, "c", isWork: false)
        // Un autre jour (mardi 17), la règle du lundi ne s'applique pas.
        let tuesday = VisitContext(placeKey: placeKey, placeType: .courses, alsoWorksHere: true,
                                   start: nov17(11, 0), durationSeconds: 1500)
        XCTAssertEqual(classify(tuesday, habits: habits).confidence, 0)
        // Un autre lieu non plus.
        let other = VisitContext(placeKey: "autre-lieu", placeType: .courses, alsoWorksHere: true,
                                 start: nov16(11, 0), durationSeconds: 1500)
        XCTAssertEqual(classify(other, habits: habits).confidence, 0)
    }

    func testHourToleranceIsOneHour() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        learn(&habits, "c", isWork: false)
        // Réponses à 11 h : une arrivée à 12:59 (heure 12) est dans le contexte, 13:00 (heure 13) non.
        let near = classify(dual(seconds: 1500, start: nov16(12, 59)), habits: habits)
        XCTAssertEqual(near.confidence, 90)
        let far = classify(dual(seconds: 1500, start: nov16(13, 0)), habits: habits)
        XCTAssertEqual(far.confidence, 0)
        let before = classify(dual(seconds: 1500, start: nov16(10, 0)), habits: habits)
        XCTAssertEqual(before.confidence, 90)
        let tooEarly = classify(dual(seconds: 1500, start: nov16(9, 59)), habits: habits)
        XCTAssertEqual(tooEarly.confidence, 0)
    }

    func testOldAnswersAreForgotten() {
        var habits = HabitModel()
        let answered: Date = nov16(12, 0)
        for key in ["a", "b", "c"] {
            habits.record(sessionKey: key, placeKey: placeKey, visitStart: nov16(11, 0), isWork: false, now: answered, calendar: cal)
        }
        let visit = dual(seconds: 1500)
        let day: TimeInterval = 86400
        // Exactement 180 jours plus tard : encore comptées.
        let atLimit = VisitClassifier.classify(visit, habits: habits, now: answered.addingTimeInterval(180 * day), calendar: cal)
        XCTAssertEqual(atLimit.confidence, 90)
        // Une seconde de plus : oubliées.
        let past = VisitClassifier.classify(visit, habits: habits, now: answered.addingTimeInterval(180 * day + 1), calendar: cal)
        XCTAssertEqual(past.confidence, 0)
    }

    func testResetForgetsEverything() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: false)
        learn(&habits, "b", isWork: false)
        learn(&habits, "c", isWork: false)
        habits.reset()
        XCTAssertEqual(habits.observations.count, 0)
        XCTAssertEqual(classify(dual(seconds: 1500), habits: habits).confidence, 0)
    }

    func testExportedValuesArePlainAndComplete() {
        var habits = HabitModel()
        learn(&habits, "a", isWork: true, start: nov16(11, 30), now: nov16(12, 0))
        let values = habits.exportedValues
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0].sessionKey, "a")
        XCTAssertEqual(values[0].placeKey, placeKey)
        XCTAssertEqual(values[0].weekday, 2)
        XCTAssertEqual(values[0].hourBucket, 11)
        XCTAssertTrue(values[0].isWork)
        XCTAssertEqual(values[0].recordedAt, nov16(12, 0))
    }

    func testObservationCountIsCapped() {
        var habits = HabitModel()
        for i in 0..<(HabitModel.maxObservations + 5) {
            learn(&habits, "s\(i)", isWork: i % 2 == 0)
        }
        XCTAssertEqual(habits.observations.count, 500)
        XCTAssertEqual(habits.observations[0].sessionKey, "s5")
    }

    // MARK: HabitStore (persistance locale)

    func testStorePersistsAndResets() {
        let isolated = makeIsolatedDefaults()
        defer { isolated.defaults.removePersistentDomain(forName: isolated.name) }
        let store = HabitStore(defaults: isolated.defaults, key: "test.habits")
        for key in ["a", "b", "c"] {
            store.record(sessionKey: key, placeKey: placeKey, visitStart: nov16(11, 0), isWork: false,
                         now: nov16(12, 0), calendar: cal)
        }
        // Un second magasin sur les mêmes réglages relit tout.
        let reopened = HabitStore(defaults: isolated.defaults, key: "test.habits")
        XCTAssertEqual(reopened.exportedObservations().count, 3)
        let result = VisitClassifier.classify(dual(seconds: 1500), habits: reopened.model, now: nov16(18, 0), calendar: cal)
        XCTAssertEqual(result.activity, .shopping)
        XCTAssertEqual(result.confidence, 90)
        reopened.reset()
        XCTAssertEqual(store.exportedObservations().count, 0)
    }

    func testStoreWithGarbageDataIsEmpty() {
        let isolated = makeIsolatedDefaults()
        defer { isolated.defaults.removePersistentDomain(forName: isolated.name) }
        isolated.defaults.set(Data([0x01, 0x02, 0x03]), forKey: "test.habits")
        let store = HabitStore(defaults: isolated.defaults, key: "test.habits")
        XCTAssertEqual(store.exportedObservations().count, 0)
    }

    // MARK: Raisons

    func testReasonsAreInFrenchAndExplainTheRule() {
        let short = classify(dual(seconds: 600))
        XCTAssertTrue(short.reason.contains("moins de 20 minutes"))
        XCTAssertTrue(short.reason.contains("Score 50 sur 100"))
        let long = classify(dual(seconds: 3 * 3600))
        XCTAssertTrue(long.reason.contains("plus de 2 heures"))
        XCTAssertFalse(short.reason.contains("\u{2014}"))
    }

    func testLearnedLabelOnlyForWorkAndShopping() {
        XCTAssertEqual(HabitLearning.learnedLabel(for: .work), true)
        XCTAssertEqual(HabitLearning.learnedLabel(for: .shopping), false)
        XCTAssertNil(HabitLearning.learnedLabel(for: .education))
        XCTAssertNil(HabitLearning.learnedLabel(for: .personal))
        XCTAssertNil(HabitLearning.learnedLabel(for: .travel))
        XCTAssertNil(HabitLearning.learnedLabel(for: .unknown))
    }
}
