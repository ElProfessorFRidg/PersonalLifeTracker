import Foundation

/// Une mesure d'arrivée ou de départ, en valeurs simples (aucune dépendance à SwiftData).
struct CalibrationSample: Equatable {
    enum Kind: Equatable {
        case arrival
        case departure
        case confirm
    }

    var date: Date
    var latitude: Double
    var longitude: Double
    /// Précision horizontale en mètres. Zéro ou négatif : mesure invalide, ignorée.
    var accuracy: Double
    var kind: Kind
}

/// Une zone : centre et rayon en mètres.
struct CalibrationZone: Equatable {
    var latitude: Double
    var longitude: Double
    var radius: Double
}

/// Ce que l'auto-calibration propose pour un lieu. Jamais appliqué sans confirmation.
struct CalibrationSuggestion: Equatable {
    let current: CalibrationZone
    let proposed: CalibrationZone
    let sampleCount: Int
    /// Distance entre le centre actuel et le centre estimé (0 si le centre ne bouge pas).
    let centerShiftMeters: Double
    /// Cap du déplacement du centre, en degrés depuis le nord (0 à 360), nil si le centre ne bouge pas.
    let bearingDegrees: Double?
    /// Distance qui couvre 90 % des mesures autour du centre proposé.
    let observedRadiusMeters: Double
    let movesCenter: Bool
    let changesRadius: Bool
    let explanation: String
    /// Identifiant stable de la proposition, pour ne pas la reproposer après "Ignorer".
    let signature: String
}

/// Auto-calibration (section 130). Logique pure : Foundation seulement.
/// Méthode : centre = médiane des écarts est et nord (robuste aux valeurs aberrantes),
/// rayon = 90e centile des distances au centre retenu, plus une marge, borné par PlaceRules.
enum PlaceCalibrator {
    /// Nombre minimal de mesures exploitables avant de proposer quoi que ce soit. Spec section 130 : 6.
    static let minSamples: Int = 6
    /// Mesures plus imprécises que cela ignorées. MON CHOIX (la spec ne donne pas de chiffre).
    static let maxAccuracy: Double = 50
    /// Nombre maximal de mesures récentes utilisées. MON CHOIX.
    static let maxSamplesUsed: Int = 30
    /// Le centre ne bouge que si l'écart atteint ce seuil (mètres). MON CHOIX.
    static let centerThreshold: Double = 30
    /// Le rayon ne change que si l'écart atteint ce seuil (mètres). MON CHOIX.
    static let radiusThreshold: Double = 20
    /// Part des mesures que la zone doit couvrir. MON CHOIX.
    static let coverage: Double = 0.9
    /// Marge ajoutée au 90e centile (mètres). MON CHOIX.
    static let radiusMargin: Double = 10
    /// Arrondi du rayon proposé (mètres), comme le curseur de l'écran lieu.
    static let radiusStep: Double = 10

    /// Mètres par degré de latitude, cohérent avec PlaceRules.
    static var metersPerDegree: Double {
        return PlaceRules.earthRadius * Double.pi / 180.0
    }

    /// Mesures exploitables : coordonnées valides, précision connue et assez bonne, les plus récentes d'abord limitées.
    static func usableSamples(_ samples: [CalibrationSample]) -> [CalibrationSample] {
        let good: [CalibrationSample] = samples.filter { (s: CalibrationSample) -> Bool in
            if !PlaceRules.isValidCoordinate(latitude: s.latitude, longitude: s.longitude) { return false }
            if s.accuracy.isNaN { return false }
            return s.accuracy > 0 && s.accuracy <= maxAccuracy
        }
        let recentFirst: [CalibrationSample] = good.sorted { (a: CalibrationSample, b: CalibrationSample) -> Bool in
            return a.date > b.date
        }
        return Array(recentFirst.prefix(maxSamplesUsed))
    }

    static func median(_ values: [Double]) -> Double {
        if values.isEmpty { return 0 }
        let sorted: [Double] = values.sorted()
        let n: Int = sorted.count
        if n % 2 == 1 { return sorted[n / 2] }
        return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    }

    /// Centile par rang le plus proche : le plus petit élément couvrant au moins `fraction` des valeurs.
    static func percentile(_ values: [Double], fraction: Double) -> Double {
        if values.isEmpty { return 0 }
        let sorted: [Double] = values.sorted()
        let rank: Int = Int((fraction * Double(sorted.count) - 0.000_000_001).rounded(.up))
        let index: Int = min(max(rank - 1, 0), sorted.count - 1)
        return sorted[index]
    }

    static func suggest(current: CalibrationZone, samples: [CalibrationSample]) -> CalibrationSuggestion? {
        if !PlaceRules.isValidCoordinate(latitude: current.latitude, longitude: current.longitude) { return nil }
        let usable: [CalibrationSample] = usableSamples(samples)
        if usable.count < minSamples { return nil }

        let cosLat: Double = cos(current.latitude * Double.pi / 180.0)
        if cosLat < 0.000_001 { return nil }
        let mPerDeg: Double = metersPerDegree

        var eastOffsets: [Double] = []
        var northOffsets: [Double] = []
        for s in usable {
            eastOffsets.append((s.longitude - current.longitude) * mPerDeg * cosLat)
            northOffsets.append((s.latitude - current.latitude) * mPerDeg)
        }
        let medianEast: Double = median(eastOffsets)
        let medianNorth: Double = median(northOffsets)
        let shift: Double = (medianEast * medianEast + medianNorth * medianNorth).squareRoot()
        let movesCenter: Bool = shift >= centerThreshold

        let centerEast: Double = movesCenter ? medianEast : 0
        let centerNorth: Double = movesCenter ? medianNorth : 0

        var distances: [Double] = []
        for i in 0..<usable.count {
            let de: Double = eastOffsets[i] - centerEast
            let dn: Double = northOffsets[i] - centerNorth
            distances.append((de * de + dn * dn).squareRoot())
        }
        let observed: Double = percentile(distances, fraction: coverage)
        let rawRadius: Double = observed + radiusMargin
        let stepped: Double = (rawRadius / radiusStep).rounded() * radiusStep
        let candidateRadius: Double = PlaceRules.clampRadius(stepped)
        let currentRadius: Double = PlaceRules.clampRadius(current.radius)
        let changesRadius: Bool = abs(candidateRadius - currentRadius) >= radiusThreshold

        if !movesCenter && !changesRadius { return nil }

        let proposedLatitude: Double = current.latitude + centerNorth / mPerDeg
        let proposedLongitude: Double = current.longitude + centerEast / (mPerDeg * cosLat)
        let proposedRadius: Double = changesRadius ? candidateRadius : current.radius
        let proposed: CalibrationZone = CalibrationZone(latitude: proposedLatitude,
                                                        longitude: proposedLongitude,
                                                        radius: proposedRadius)
        let bearing: Double? = movesCenter ? bearingDegrees(east: medianEast, north: medianNorth) : nil
        let arrivalsOnly: Bool = usable.allSatisfy { (s: CalibrationSample) -> Bool in return s.kind == .arrival }
        let text: String = explanation(count: usable.count,
                                       arrivalsOnly: arrivalsOnly,
                                       movesCenter: movesCenter,
                                       shift: shift,
                                       bearing: bearing,
                                       changesRadius: changesRadius,
                                       observed: observed,
                                       currentRadius: current.radius,
                                       proposedRadius: proposedRadius)
        return CalibrationSuggestion(current: current,
                                     proposed: proposed,
                                     sampleCount: usable.count,
                                     centerShiftMeters: movesCenter ? shift : 0,
                                     bearingDegrees: bearing,
                                     observedRadiusMeters: observed,
                                     movesCenter: movesCenter,
                                     changesRadius: changesRadius,
                                     explanation: text,
                                     signature: signature(of: proposed))
    }

    /// Cap en degrés depuis le nord, de 0 inclus à 360 exclu.
    static func bearingDegrees(east: Double, north: Double) -> Double {
        var degrees: Double = atan2(east, north) * 180.0 / Double.pi
        if degrees < 0 { degrees += 360.0 }
        if degrees >= 360.0 { degrees -= 360.0 }
        return degrees
    }

    /// Point cardinal en français (8 secteurs de 45 degrés centrés sur N, NE, E...).
    static func compassName(degrees: Double) -> String {
        let names: [String] = ["nord", "nord-est", "est", "sud-est", "sud", "sud-ouest", "ouest", "nord-ouest"]
        let normalized: Double = degrees.truncatingRemainder(dividingBy: 360.0)
        let positive: Double = normalized < 0 ? normalized + 360.0 : normalized
        let index: Int = Int((positive + 22.5) / 45.0) % 8
        return names[index]
    }

    /// Empreinte d'une proposition : centre à environ 11 m près et rayon entier.
    static func signature(of zone: CalibrationZone) -> String {
        let lat: Int = Int((zone.latitude * 10_000).rounded())
        let lon: Int = Int((zone.longitude * 10_000).rounded())
        let radius: Int = Int(zone.radius.rounded())
        return "\(lat)|\(lon)|\(radius)"
    }

    static func explanation(count: Int,
                            arrivalsOnly: Bool,
                            movesCenter: Bool,
                            shift: Double,
                            bearing: Double?,
                            changesRadius: Bool,
                            observed: Double,
                            currentRadius: Double,
                            proposedRadius: Double) -> String {
        let noun: String = arrivalsOnly ? "arrivées" : "détections"
        var parts: [String] = []
        if movesCenter {
            let distance: Int = Int(shift.rounded())
            var sentence: String = "Tes \(count) dernières \(noun) tombent en moyenne à \(distance) m de l'épingle"
            if let b = bearing {
                sentence += ", vers le \(compassName(degrees: b))"
            }
            sentence += "."
            parts.append(sentence)
        }
        if changesRadius {
            let observedInt: Int = Int(observed.rounded())
            let newRadius: Int = Int(proposedRadius.rounded())
            let oldRadius: Int = Int(currentRadius.rounded())
            let lead: String = movesCenter ? "9 sur 10 tombent" : "Tes \(count) dernières \(noun) tombent, pour 9 sur 10,"
            parts.append("\(lead) à \(observedInt) m du centre, donc je propose une zone de \(newRadius) m au lieu de \(oldRadius) m.")
        }
        return parts.joined(separator: " ")
    }
}
