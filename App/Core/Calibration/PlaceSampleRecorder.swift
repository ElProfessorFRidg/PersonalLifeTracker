import Foundation
import SwiftData

/// Enregistre une mesure de calibration (section 130). À appeler par le service de détection, seulement
/// si `modules.isActive("place_calibration")`. Une ligne par arrivée, départ ou confirmation, jamais de trace.
enum PlaceSampleRecorder {
    /// Nombre maximal de mesures gardées par lieu : les plus anciennes sont supprimées.
    static let maxSamplesPerPlace: Int = 40

    /// Vrai si la mesure a été enregistrée. Une position invalide ou une précision inconnue (zéro, négative)
    /// est refusée sans erreur.
    @discardableResult
    static func record(placeUID: UUID,
                       latitude: Double,
                       longitude: Double,
                       horizontalAccuracy: Double,
                       kind: PlaceSampleKind,
                       date: Date = Date(),
                       in context: ModelContext) -> Bool {
        if !PlaceRules.isValidCoordinate(latitude: latitude, longitude: longitude) { return false }
        if horizontalAccuracy.isNaN || horizontalAccuracy <= 0 { return false }
        let sample: PlaceSample = PlaceSample(placeUID: placeUID,
                                              date: date,
                                              latitude: latitude,
                                              longitude: longitude,
                                              horizontalAccuracy: horizontalAccuracy,
                                              kind: kind)
        context.insert(sample)
        try? context.save()
        prune(placeUID: placeUID, in: context)
        try? context.save()
        return true
    }

    /// Supprime les mesures au-delà de la limite, en gardant les plus récentes.
    static func prune(placeUID: UUID, in context: ModelContext) {
        let uid: UUID = placeUID
        let descriptor: FetchDescriptor<PlaceSample> = FetchDescriptor<PlaceSample>(
            predicate: #Predicate<PlaceSample> { $0.placeUID == uid },
            sortBy: [SortDescriptor(\PlaceSample.date, order: .reverse)])
        guard let all = try? context.fetch(descriptor) else { return }
        if all.count <= maxSamplesPerPlace { return }
        for extra in all.dropFirst(maxSamplesPerPlace) {
            context.delete(extra)
        }
    }

    /// À appeler quand un lieu est supprimé : ses mesures n'ont plus de raison d'être gardées.
    static func removeSamples(placeUID: UUID, in context: ModelContext) {
        let uid: UUID = placeUID
        let descriptor: FetchDescriptor<PlaceSample> = FetchDescriptor<PlaceSample>(
            predicate: #Predicate<PlaceSample> { $0.placeUID == uid })
        guard let all = try? context.fetch(descriptor) else { return }
        for sample in all {
            context.delete(sample)
        }
        try? context.save()
    }

    /// Conversion vers les valeurs simples du calibrateur.
    static func calibrationSamples(_ samples: [PlaceSample]) -> [CalibrationSample] {
        return samples.map { (s: PlaceSample) -> CalibrationSample in
            let kind: CalibrationSample.Kind
            switch s.kind {
            case .arrival: kind = .arrival
            case .departure: kind = .departure
            case .manualConfirm: kind = .confirm
            }
            return CalibrationSample(date: s.date,
                                     latitude: s.latitude,
                                     longitude: s.longitude,
                                     accuracy: s.horizontalAccuracy,
                                     kind: kind)
        }
    }
}

/// Propositions que l'utilisateur a ignorées ("Ignorer"), gardées par lieu dans UserDefaults.
enum CalibrationDismissals {
    static let maxKept: Int = 10

    static func key(placeUID: UUID) -> String {
        return "plt.calibration.dismissed.\(placeUID.uuidString)"
    }

    static func isDismissed(signature: String, placeUID: UUID, defaults: UserDefaults = UserDefaults.standard) -> Bool {
        let list: [String] = defaults.stringArray(forKey: key(placeUID: placeUID)) ?? []
        return list.contains(signature)
    }

    static func dismiss(signature: String, placeUID: UUID, defaults: UserDefaults = UserDefaults.standard) {
        var list: [String] = defaults.stringArray(forKey: key(placeUID: placeUID)) ?? []
        if list.contains(signature) { return }
        list.append(signature)
        if list.count > maxKept {
            list = Array(list.suffix(maxKept))
        }
        defaults.set(list, forKey: key(placeUID: placeUID))
    }
}
