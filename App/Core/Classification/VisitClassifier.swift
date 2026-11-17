import Foundation

/// Un créneau du planning connu pour la semaine (section 11, facteur 2). Vide tant que le module planning n'alimente rien.
struct PlannedShift: Equatable {
    let start: Date
    let end: Date
}

/// Une visite à classer.
struct VisitContext {
    /// Identifiant du lieu (UUID en texte), clé des habitudes apprises.
    let placeKey: String
    let placeType: PlaceType
    /// "J'y travaille aussi" (lieu de courses où l'on peut aussi travailler).
    let alsoWorksHere: Bool
    /// Heure d'arrivée exacte.
    let start: Date
    /// Durée connue de la visite en secondes, nil si elle n'est pas finie.
    let durationSeconds: TimeInterval?
    /// Créneaux prévus connus (vide pour l'instant).
    let plannedShifts: [PlannedShift]

    init(placeKey: String,
         placeType: PlaceType,
         alsoWorksHere: Bool,
         start: Date,
         durationSeconds: TimeInterval?,
         plannedShifts: [PlannedShift] = []) {
        self.placeKey = placeKey
        self.placeType = placeType
        self.alsoWorksHere = alsoWorksHere
        self.start = start
        self.durationSeconds = durationSeconds
        self.plannedShifts = plannedShifts
    }
}

/// Niveau de certitude d'une classification (section 11, seuils).
enum ClassificationLevel: Equatable {
    /// Au-dessus de 75 : classement automatique sans question.
    case automatic
    /// De 40 à 75 : classement provisoire, confirmation proposée.
    case provisional
    /// Sous 40 : "inconnu", confirmation demandée.
    case unknown
}

struct ClassificationResult: Equatable {
    let activity: ActivityType
    /// Score de 0 à 100.
    let confidence: Int
    let level: ClassificationLevel
    /// Explication en français, pour "Pourquoi cette classification ?".
    let reason: String

    /// La session est créée non confirmée tant que le niveau n'est pas automatique.
    var needsConfirmation: Bool {
        return level != .automatic
    }
}

/// Classification travail, études, courses (sections 11 et 12). Pure, Foundation seulement.
///
/// Les types de lieu tranchent seuls : taf donne travail, cours donne études, courses donne courses et ne compte jamais
/// comme du travail. Seul un lieu de courses marqué "J'y travaille aussi" (section 11 : "Un supermarché peut être lieu
/// de travail, de courses et de visite") reçoit un score.
///
/// Le score est une somme de preuves signées (positif = travail, négatif = courses). Sa valeur absolue, plafonnée à 100,
/// est la confiance. Les poids sont MON CHOIX (la spec ne donne que l'ordre d'importance et les seuils), voir notes/core_classify.md.
enum VisitClassifier {

    // MARK: Seuils de la spec (section 11)

    /// "sous 20 minutes, probablement des courses" : strictement moins de 20 minutes.
    static let shortVisitSeconds: TimeInterval = 20 * 60
    /// "au-dessus de 2 heures, probablement du travail" : strictement plus de 2 heures.
    static let longVisitSeconds: TimeInterval = 2 * 60 * 60
    /// "au-dessus de 75, classement automatique sans question" : strictement au-dessus.
    static let automaticAbove: Int = 75
    /// "Entre 40 et 75, classement provisoire" ; "Sous 40, inconnu" : 40 est encore provisoire.
    static let provisionalFrom: Int = 40

    // MARK: Poids (mon choix)

    /// Facteur 3, durée : poids d'une visite courte (courses) ou longue (travail).
    static let durationWeight: Int = 50
    /// Facteur 2, planning : l'arrivée tombe dans un créneau prévu (à 30 minutes près avant son début).
    static let planningMatchWeight: Int = 40
    /// Facteur 2, planning : des créneaux existent mais aucun ne correspond.
    static let planningMismatchWeight: Int = 15
    static let planningToleranceSeconds: TimeInterval = 30 * 60
    /// Facteurs 1, 4 et 5 avant le minimum d'observations : un indice de 10 points par réponse nette, plafonné à 20.
    static let habitHintPerObservation: Int = 10
    static let habitHintCap: Int = 20
    /// Confiance d'une règle apprise (3 réponses concordantes) : automatique.
    static let learnedConfidence: Int = 90

    /// Section 11 : "au-dessus de 75 automatique, entre 40 et 75 provisoire, sous 40 inconnu".
    static func level(forConfidence confidence: Int) -> ClassificationLevel {
        if confidence > automaticAbove { return .automatic }
        if confidence >= provisionalFrom { return .provisional }
        return .unknown
    }

    static func classify(_ visit: VisitContext,
                         habits: HabitModel,
                         now: Date,
                         calendar: Calendar) -> ClassificationResult {
        switch visit.placeType {
        case .domicile, .autre:
            return fixed(.personal, "Lieu personnel.")
        case .taf:
            return fixed(.work, "Ce lieu est un lieu de taf.")
        case .cours:
            // Section 12 : les lieux éducatifs donnent des études, comptées à part du travail.
            return fixed(.education, "Ce lieu est un lieu d'études.")
        case .courses:
            if !visit.alsoWorksHere {
                return fixed(.shopping, "C'est un lieu de courses : ça ne compte jamais comme du travail.")
            }
            return classifyDualUse(visit, habits: habits, now: now, calendar: calendar)
        }
    }

    private static func fixed(_ activity: ActivityType, _ reason: String) -> ClassificationResult {
        return ClassificationResult(activity: activity, confidence: 100, level: .automatic, reason: reason)
    }

    private static func classifyDualUse(_ visit: VisitContext,
                                        habits: HabitModel,
                                        now: Date,
                                        calendar: Calendar) -> ClassificationResult {
        let weekday: Int = calendar.component(.weekday, from: visit.start)
        let hour: Int = calendar.component(.hour, from: visit.start)

        // Facteur 1 : correction manuelle antérieure dans un contexte similaire.
        // Section 11 : après 3 confirmations concordantes, la classification devient automatique pour ce contexte.
        let evidence: HabitEvidence = habits.evidence(placeKey: visit.placeKey, weekday: weekday, hourBucket: hour, now: now)
        if let learnedIsWork = evidence.learnedIsWork {
            let activity: ActivityType = learnedIsWork ? .work : .shopping
            let label: String = learnedIsWork ? "du travail" : "des courses"
            return ClassificationResult(
                activity: activity,
                confidence: learnedConfidence,
                level: level(forConfidence: learnedConfidence),
                reason: "Tu as classé les dernières visites de ce lieu à ce moment de la semaine comme \(label) "
                    + "(\(HabitModel.minimumObservations) fois de suite), donc je fais pareil.")
        }

        var net: Int = 0
        var parts: [String] = []

        // Facteur 3 : durée.
        if let duration = visit.durationSeconds {
            if duration < shortVisitSeconds {
                net -= durationWeight
                parts.append("Visite de moins de 20 minutes : plutôt des courses.")
            } else if duration > longVisitSeconds {
                net += durationWeight
                parts.append("Visite de plus de 2 heures : plutôt du travail.")
            } else {
                parts.append("Durée entre 20 minutes et 2 heures : ça ne tranche pas.")
            }
        } else {
            parts.append("La visite n'est pas finie : la durée ne compte pas encore.")
        }

        // Facteur 2 : créneau du planning.
        if !visit.plannedShifts.isEmpty {
            var matches: Bool = false
            for shift in visit.plannedShifts {
                let earliest: Date = shift.start.addingTimeInterval(-planningToleranceSeconds)
                if visit.start >= earliest && visit.start <= shift.end {
                    matches = true
                }
            }
            if matches {
                net += planningMatchWeight
                parts.append("Tu arrives pendant un créneau prévu au planning.")
            } else {
                net -= planningMismatchWeight
                parts.append("Le planning a des créneaux mais pas à ce moment.")
            }
        }

        // Facteurs 1, 4 et 5 avant le minimum : un indice, jamais une décision.
        let netObservations: Int = evidence.workCount - evidence.errandCount
        if netObservations != 0 {
            var hint: Int = netObservations * habitHintPerObservation
            if hint > habitHintCap { hint = habitHintCap }
            if hint < -habitHintCap { hint = -habitHintCap }
            net += hint
            if hint > 0 {
                parts.append("Tes réponses passées penchent un peu vers le travail, mais il en faut \(HabitModel.minimumObservations) pour que ça compte vraiment.")
            } else {
                parts.append("Tes réponses passées penchent un peu vers les courses, mais il en faut \(HabitModel.minimumObservations) pour que ça compte vraiment.")
            }
        }

        var confidence: Int = abs(net)
        if confidence > 100 { confidence = 100 }
        let lvl: ClassificationLevel = level(forConfidence: confidence)
        var activity: ActivityType = .unknown
        if lvl != .unknown {
            activity = net > 0 ? .work : .shopping
        }
        parts.append("Score \(confidence) sur 100.")
        return ClassificationResult(activity: activity, confidence: confidence, level: lvl,
                                    reason: parts.joined(separator: " "))
    }
}
