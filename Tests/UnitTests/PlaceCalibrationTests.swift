import XCTest
import SwiftData
@testable import PersonalLifeTracker

/// Valeurs calculées à la main. Le lieu est en 48,0 N / 2,0 E.
/// 1 degré de latitude = 6 371 000 x pi / 180 = 111 194,93 m.
/// 1 degré de longitude à 48 N = 111 194,93 x cos(48 degrés = 0,6691306) = 74 403,9 m.
final class PlaceCalibrationTests: XCTestCase {
    private let baseLat: Double = 48.0
    private let baseLon: Double = 2.0
    private let metersPerLat: Double = 111_194.93
    private let metersPerLon: Double = 74_403.9

    private func zone(radius: Double) -> CalibrationZone {
        return CalibrationZone(latitude: baseLat, longitude: baseLon, radius: radius)
    }

    /// Une mesure placée à `north` mètres au nord et `east` mètres à l'est du centre du lieu.
    private func sample(north: Double, east: Double, accuracy: Double = 10, kind: CalibrationSample.Kind = .arrival, day: Int = 1) -> CalibrationSample {
        return CalibrationSample(date: makeDate(TestCalendar.utc, 2026, 11, day, 9, 0),
                                 latitude: baseLat + north / metersPerLat,
                                 longitude: baseLon + east / metersPerLon,
                                 accuracy: accuracy,
                                 kind: kind)
    }

    /// 9 mesures autour du point (north, east) : 5 au centre, 4 à 40 m (N, S, E, O).
    /// Médiane des écarts = le point. 90e centile par rang le plus proche : 9e valeur sur 9 = 40 m.
    private func cluster(north: Double, east: Double, spread: Double = 40) -> [CalibrationSample] {
        var result: [CalibrationSample] = []
        for i in 0..<5 {
            result.append(sample(north: north, east: east, day: 1 + i))
        }
        result.append(sample(north: north + spread, east: east, day: 6))
        result.append(sample(north: north - spread, east: east, day: 7))
        result.append(sample(north: north, east: east + spread, day: 8))
        result.append(sample(north: north, east: east - spread, day: 9))
        return result
    }

    // MARK: Nombre minimal

    func testFiveSamplesGiveNoSuggestion() {
        var samples: [CalibrationSample] = []
        for i in 0..<5 {
            samples.append(sample(north: 100, east: 0, day: 1 + i))
        }
        XCTAssertNil(PlaceCalibrator.suggest(current: zone(radius: 100), samples: samples))
    }

    func testSixSamplesAreEnough() {
        var samples: [CalibrationSample] = []
        for i in 0..<6 {
            samples.append(sample(north: 100, east: 0, day: 1 + i))
        }
        let suggestion: CalibrationSuggestion? = PlaceCalibrator.suggest(current: zone(radius: 100), samples: samples)
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.sampleCount, 6)
    }

    // MARK: Centre

    func testClusterOffsetNorthGivesExpectedCenter() throws {
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: cluster(north: 100, east: 0)))
        // 100 m au nord = 100 / 111 194,93 = 0,00089932 degré.
        XCTAssertEqual(suggestion.proposed.latitude, 48.00089932, accuracy: 0.00001)
        XCTAssertEqual(suggestion.proposed.longitude, 2.0, accuracy: 0.00001)
        XCTAssertEqual(suggestion.centerShiftMeters, 100, accuracy: 1.5)
        XCTAssertTrue(suggestion.movesCenter)
        let bearing: Double = try XCTUnwrap(suggestion.bearingDegrees)
        let distanceFromNorth: Double = min(bearing, 360 - bearing)
        XCTAssertEqual(distanceFromNorth, 0, accuracy: 1.0, "plein nord (0 ou 360 degrés)")
    }

    func testClusterOffsetEastGivesExpectedCenter() throws {
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: cluster(north: 0, east: 100)))
        // 100 m à l'est = 100 / 74 403,9 = 0,001344 degré.
        XCTAssertEqual(suggestion.proposed.longitude, 2.001344, accuracy: 0.00002)
        XCTAssertEqual(suggestion.proposed.latitude, 48.0, accuracy: 0.00001)
        let bearing: Double = try XCTUnwrap(suggestion.bearingDegrees)
        XCTAssertEqual(bearing, 90, accuracy: 1.0)
    }

    func testRadiusIsNinetiethPercentilePlusMarginRounded() throws {
        // 40 m (90e centile) + 10 m de marge = 50 m, déjà multiple de 10, dans les bornes.
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: cluster(north: 100, east: 0)))
        XCTAssertEqual(suggestion.observedRadiusMeters, 40, accuracy: 1.0)
        XCTAssertEqual(suggestion.proposed.radius, 50, accuracy: 0.001)
        XCTAssertTrue(suggestion.changesRadius)
    }

    func testCenterOnlyChangeKeepsCurrentRadius() throws {
        // Rayon actuel 50, rayon calculé 50 : seul le centre bouge.
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 50), samples: cluster(north: 100, east: 0)))
        XCTAssertTrue(suggestion.movesCenter)
        XCTAssertFalse(suggestion.changesRadius)
        XCTAssertEqual(suggestion.proposed.radius, 50, accuracy: 0.001)
    }

    // MARK: Valeurs aberrantes et précision

    func testOutlierIsIgnored() throws {
        var samples: [CalibrationSample] = cluster(north: 100, east: 0)
        samples.append(sample(north: 100, east: 0, day: 10))
        samples.append(sample(north: 100, east: 0, day: 11))
        // Valeur aberrante précise mais à 5 km à l'est. 12 mesures au total.
        samples.append(sample(north: 100, east: 5_000, day: 12))
        XCTAssertEqual(samples.count, 12)
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: samples))
        // Médiane nord : 100. Médiane est : 0 (la valeur à 5 000 m ne compte qu'une fois).
        XCTAssertEqual(suggestion.proposed.latitude, 48.00089932, accuracy: 0.00001)
        XCTAssertEqual(suggestion.proposed.longitude, 2.0, accuracy: 0.00001)
        XCTAssertEqual(suggestion.sampleCount, 12)
        XCTAssertTrue(suggestion.explanation.contains("12 dernières arrivées"))
    }

    func testPoorAccuracySamplesAreIgnored() throws {
        var samples: [CalibrationSample] = []
        for i in 0..<6 {
            samples.append(sample(north: 100, east: 0, accuracy: 10, day: 1 + i))
        }
        // 6 mesures à 500 m au sud, avec 200 m d'imprécision : ignorées.
        for i in 0..<6 {
            samples.append(sample(north: -500, east: 0, accuracy: 200, day: 10 + i))
        }
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: samples))
        XCTAssertEqual(suggestion.sampleCount, 6)
        XCTAssertEqual(suggestion.proposed.latitude, 48.00089932, accuracy: 0.00001)
    }

    func testTooFewGoodSamplesAmongPoorOnesGiveNothing() {
        var samples: [CalibrationSample] = []
        for i in 0..<5 {
            samples.append(sample(north: 100, east: 0, accuracy: 10, day: 1 + i))
        }
        for i in 0..<10 {
            samples.append(sample(north: 100, east: 0, accuracy: 80, day: 10 + i))
        }
        XCTAssertNil(PlaceCalibrator.suggest(current: zone(radius: 100), samples: samples))
    }

    func testInvalidAccuracyValuesAreIgnored() {
        var samples: [CalibrationSample] = []
        for i in 0..<3 {
            samples.append(sample(north: 100, east: 0, accuracy: 0, day: 1 + i))
            samples.append(sample(north: 100, east: 0, accuracy: -1, day: 5 + i))
        }
        XCTAssertEqual(PlaceCalibrator.usableSamples(samples).count, 0)
        XCTAssertNil(PlaceCalibrator.suggest(current: zone(radius: 100), samples: samples))
    }

    func testAccuracyExactlyAtLimitIsKept() {
        let kept: [CalibrationSample] = [sample(north: 0, east: 0, accuracy: 50)]
        let dropped: [CalibrationSample] = [sample(north: 0, east: 0, accuracy: 50.5)]
        XCTAssertEqual(PlaceCalibrator.usableSamples(kept).count, 1)
        XCTAssertEqual(PlaceCalibrator.usableSamples(dropped).count, 0)
    }

    // MARK: Bornes du rayon et seuils

    func testRadiusIsClampedToMaximum() throws {
        // Dispersion de 400 m autour du centre actuel : 400 + 10 = 410, ramené à 300.
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: cluster(north: 0, east: 0, spread: 400)))
        XCTAssertEqual(suggestion.proposed.radius, PlaceRules.maxRadius, accuracy: 0.001)
        XCTAssertEqual(suggestion.proposed.radius, 300, accuracy: 0.001)
        XCTAssertFalse(suggestion.movesCenter, "la médiane est au centre actuel")
        XCTAssertEqual(suggestion.proposed.latitude, 48.0, accuracy: 0.000001)
        XCTAssertEqual(suggestion.proposed.longitude, 2.0, accuracy: 0.000001)
    }

    func testRadiusIsClampedToMinimum() throws {
        // Mesures toutes au centre : 0 + 10 = 10, ramené à 50. Rayon actuel 200, écart 150.
        var samples: [CalibrationSample] = []
        for i in 0..<6 {
            samples.append(sample(north: 0, east: 0, day: 1 + i))
        }
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 200), samples: samples))
        XCTAssertEqual(suggestion.proposed.radius, PlaceRules.minRadius, accuracy: 0.001)
        XCTAssertEqual(suggestion.proposed.radius, 50, accuracy: 0.001)
    }

    func testNoSuggestionWhenChangeIsBelowThresholds() {
        // Centre décalé de 10 m (< 30 m). Rayon actuel 50 : distances au centre actuel
        // 10, 10, 10, 10, 10, 30, 41,2, 41,2, 50 : 9e valeur = 50, plus 10 = 60, écart 10 m (< 20 m).
        let samples: [CalibrationSample] = cluster(north: 10, east: 0)
        XCTAssertNil(PlaceCalibrator.suggest(current: zone(radius: 50), samples: samples))
    }

    func testCenterThresholdBoundary() {
        // Décalage de 20 m : sous le seuil de 30 m. Le 9e écart au centre actuel vaut 60 (N à 20 + 40),
        // plus 10 = 70, face à un rayon de 60 : écart 10 m, sous le seuil de 20 m. Rien.
        XCTAssertNil(PlaceCalibrator.suggest(current: zone(radius: 60), samples: cluster(north: 20, east: 0)))
        // Décalage de 40 m : au-dessus du seuil, le centre bouge.
        let moved: CalibrationSuggestion? = PlaceCalibrator.suggest(current: zone(radius: 50), samples: cluster(north: 40, east: 0))
        XCTAssertNotNil(moved)
        XCTAssertEqual(moved?.movesCenter, true)
    }

    func testOnlyMostRecentThirtySamplesAreUsed() {
        var samples: [CalibrationSample] = []
        for i in 0..<35 {
            samples.append(sample(north: 0, east: 0, day: 1 + (i % 28)))
        }
        XCTAssertEqual(PlaceCalibrator.usableSamples(samples).count, 30)
    }

    // MARK: Aides pures

    func testMedianAndPercentile() {
        XCTAssertEqual(PlaceCalibrator.median([3, 1, 2]), 2, accuracy: 0.0001)
        XCTAssertEqual(PlaceCalibrator.median([1, 2, 3, 4]), 2.5, accuracy: 0.0001)
        XCTAssertEqual(PlaceCalibrator.median([]), 0, accuracy: 0.0001)
        let ten: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        XCTAssertEqual(PlaceCalibrator.percentile(ten, fraction: 0.9), 9, accuracy: 0.0001)
        let nine: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        XCTAssertEqual(PlaceCalibrator.percentile(nine, fraction: 0.9), 9, accuracy: 0.0001)
        let twelve: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        XCTAssertEqual(PlaceCalibrator.percentile(twelve, fraction: 0.9), 11, accuracy: 0.0001)
    }

    func testCompassNames() {
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 0), "nord")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 45), "nord-est")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 90), "est")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 180), "sud")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 225), "sud-ouest")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 270), "ouest")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 315), "nord-ouest")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 359), "nord")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 22), "nord")
        XCTAssertEqual(PlaceCalibrator.compassName(degrees: 23), "nord-est")
    }

    func testBearingFromOffsets() {
        XCTAssertEqual(PlaceCalibrator.bearingDegrees(east: 0, north: 10), 0, accuracy: 0.001)
        XCTAssertEqual(PlaceCalibrator.bearingDegrees(east: 10, north: 0), 90, accuracy: 0.001)
        XCTAssertEqual(PlaceCalibrator.bearingDegrees(east: 0, north: -10), 180, accuracy: 0.001)
        XCTAssertEqual(PlaceCalibrator.bearingDegrees(east: -10, north: 0), 270, accuracy: 0.001)
    }

    func testExplanationMentionsDistanceDirectionAndRadius() throws {
        let suggestion: CalibrationSuggestion = try XCTUnwrap(
            PlaceCalibrator.suggest(current: zone(radius: 100), samples: cluster(north: 100, east: 0)))
        XCTAssertTrue(suggestion.explanation.contains("9 dernières arrivées"), suggestion.explanation)
        XCTAssertTrue(suggestion.explanation.contains("100 m"), suggestion.explanation)
        XCTAssertTrue(suggestion.explanation.contains("vers le nord"), suggestion.explanation)
        XCTAssertTrue(suggestion.explanation.contains("50 m au lieu de 100 m"), suggestion.explanation)
        XCTAssertFalse(suggestion.explanation.contains("\u{2014}"))
    }

    // MARK: Ignorer

    func testSignatureIsStableAndDistinguishesZones() {
        let a: CalibrationZone = CalibrationZone(latitude: 48.00089932, longitude: 2.0, radius: 50)
        let sameWithin5m: CalibrationZone = CalibrationZone(latitude: 48.00090500, longitude: 2.00000100, radius: 50.2)
        let farther: CalibrationZone = CalibrationZone(latitude: 48.00290000, longitude: 2.0, radius: 50)
        let otherRadius: CalibrationZone = CalibrationZone(latitude: 48.00089932, longitude: 2.0, radius: 80)
        XCTAssertEqual(PlaceCalibrator.signature(of: a), PlaceCalibrator.signature(of: sameWithin5m))
        XCTAssertNotEqual(PlaceCalibrator.signature(of: a), PlaceCalibrator.signature(of: farther))
        XCTAssertNotEqual(PlaceCalibrator.signature(of: a), PlaceCalibrator.signature(of: otherRadius))
    }

    func testDismissedSuggestionIsRemembered() throws {
        let suite: String = "plt.test.calibration.\(UUID().uuidString)"
        let defaults: UserDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let placeUID: UUID = UUID()
        let otherPlace: UUID = UUID()
        XCTAssertFalse(CalibrationDismissals.isDismissed(signature: "x", placeUID: placeUID, defaults: defaults))
        CalibrationDismissals.dismiss(signature: "x", placeUID: placeUID, defaults: defaults)
        XCTAssertTrue(CalibrationDismissals.isDismissed(signature: "x", placeUID: placeUID, defaults: defaults))
        XCTAssertFalse(CalibrationDismissals.isDismissed(signature: "y", placeUID: placeUID, defaults: defaults))
        XCTAssertFalse(CalibrationDismissals.isDismissed(signature: "x", placeUID: otherPlace, defaults: defaults))
    }

    // MARK: Enregistrement (SwiftData en mémoire)

    func testRecorderStoresValidSampleAndRejectsInvalid() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let uid: UUID = UUID()
        XCTAssertTrue(PlaceSampleRecorder.record(placeUID: uid, latitude: 48.0, longitude: 2.0,
                                                 horizontalAccuracy: 12, kind: .arrival, in: context))
        XCTAssertFalse(PlaceSampleRecorder.record(placeUID: uid, latitude: 48.0, longitude: 2.0,
                                                  horizontalAccuracy: -1, kind: .arrival, in: context))
        XCTAssertFalse(PlaceSampleRecorder.record(placeUID: uid, latitude: 95.0, longitude: 2.0,
                                                  horizontalAccuracy: 10, kind: .arrival, in: context))
        let stored: [PlaceSample] = try context.fetch(FetchDescriptor<PlaceSample>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].placeUID, uid)
        XCTAssertEqual(stored[0].kind, .arrival)
        XCTAssertEqual(stored[0].horizontalAccuracy, 12, accuracy: 0.0001)
    }

    func testRecorderKeepsOnlyTheFortyMostRecentPerPlace() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let uid: UUID = UUID()
        let other: UUID = UUID()
        let start: Date = nov16(8, 0)
        for i in 0..<45 {
            let when: Date = start.addingTimeInterval(Double(i) * 3600)
            _ = PlaceSampleRecorder.record(placeUID: uid, latitude: 48.0, longitude: 2.0,
                                           horizontalAccuracy: 10, kind: .arrival, date: when, in: context)
        }
        _ = PlaceSampleRecorder.record(placeUID: other, latitude: 48.0, longitude: 2.0,
                                       horizontalAccuracy: 10, kind: .departure, date: start, in: context)
        let descriptor: FetchDescriptor<PlaceSample> = FetchDescriptor<PlaceSample>(
            predicate: #Predicate<PlaceSample> { $0.placeUID == uid },
            sortBy: [SortDescriptor(\PlaceSample.date, order: .forward)])
        let kept: [PlaceSample] = try context.fetch(descriptor)
        XCTAssertEqual(kept.count, 40)
        // Les 5 plus anciennes (heures 0 à 4) sont parties : la plus ancienne gardée est l'heure 5.
        XCTAssertEqual(kept[0].date, start.addingTimeInterval(5 * 3600))
        let all: [PlaceSample] = try context.fetch(FetchDescriptor<PlaceSample>())
        XCTAssertEqual(all.count, 41, "le deuxième lieu garde sa mesure")
    }

    func testRemoveSamplesDeletesOnlyThatPlace() throws {
        let container: ModelContainer = try AppModelContainer.make(inMemory: true)
        let context: ModelContext = ModelContext(container)
        let uid: UUID = UUID()
        let other: UUID = UUID()
        for _ in 0..<3 {
            _ = PlaceSampleRecorder.record(placeUID: uid, latitude: 48.0, longitude: 2.0,
                                           horizontalAccuracy: 10, kind: .manualConfirm, in: context)
        }
        _ = PlaceSampleRecorder.record(placeUID: other, latitude: 48.0, longitude: 2.0,
                                       horizontalAccuracy: 10, kind: .arrival, in: context)
        PlaceSampleRecorder.removeSamples(placeUID: uid, in: context)
        let left: [PlaceSample] = try context.fetch(FetchDescriptor<PlaceSample>())
        XCTAssertEqual(left.count, 1)
        XCTAssertEqual(left[0].placeUID, other)
    }

    func testCalibrationSamplesMapsKinds() {
        let uid: UUID = UUID()
        let a: PlaceSample = PlaceSample(placeUID: uid, latitude: 48.0, longitude: 2.0, horizontalAccuracy: 10, kind: .arrival)
        let b: PlaceSample = PlaceSample(placeUID: uid, latitude: 48.0, longitude: 2.0, horizontalAccuracy: 10, kind: .departure)
        let c: PlaceSample = PlaceSample(placeUID: uid, latitude: 48.0, longitude: 2.0, horizontalAccuracy: 10, kind: .manualConfirm)
        let mapped: [CalibrationSample] = PlaceSampleRecorder.calibrationSamples([a, b, c])
        XCTAssertEqual(mapped.map { $0.kind }, [.arrival, .departure, .confirm])
    }
}
