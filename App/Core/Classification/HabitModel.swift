import Foundation

/// Une confirmation ou une correction de l'utilisateur sur une visite à double usage (section 11).
/// Valeurs simples, exportables telles quelles.
struct HabitObservation: Codable, Equatable {
    /// Identifiant de la session concernée : une même session ne compte qu'une fois (la dernière réponse remplace la précédente).
    let sessionKey: String
    /// Identifiant du lieu (UUID en texte).
    let placeKey: String
    /// Jour de la semaine de l'arrivée, 1 à 7 selon le calendrier fourni (1 = dimanche en grégorien).
    let weekday: Int
    /// Heure d'arrivée, 0 à 23.
    let hourBucket: Int
    /// Vrai si l'utilisateur a classé la visite en travail, faux si en courses.
    let isWork: Bool
    /// Moment où l'utilisateur a répondu.
    let recordedAt: Date
}

/// Ce que l'historique dit d'un contexte (lieu, jour, plage horaire).
struct HabitEvidence: Equatable {
    let workCount: Int
    let errandCount: Int
    /// Non nil quand les `HabitModel.minimumObservations` dernières réponses du contexte sont concordantes :
    /// true = travail, false = courses.
    let learnedIsWork: Bool?
}

/// Apprentissage local des corrections (sections 9 et 11). Pur, Foundation seulement.
///
/// Section 11 : "Toute confirmation ou correction crée une règle locale limitée à son contexte (lieu, jour, plage horaire).
/// Après 3 confirmations concordantes dans un même contexte, la classification devient automatique pour ce contexte.
/// Jamais de correction appliquée à tous les contextes."
/// Section 9 : "Jamais d'habitude à partir d'une seule visite."
///
/// Choix de l'app (la spec ne donne pas de chiffre) : le contexte est le même lieu, le même jour de semaine et une heure
/// d'arrivée à plus ou moins 1 h ; seules les réponses des 180 derniers jours comptent (oubli progressif) ;
/// 500 réponses au maximum sont gardées.
struct HabitModel: Codable, Equatable {

    /// Section 11 : 3 confirmations concordantes.
    static let minimumObservations: Int = 3
    /// Écart d'heure d'arrivée toléré pour parler du même contexte : MON CHOIX.
    static let hourTolerance: Int = 1
    /// Oubli : au-delà de 180 jours une réponse ne compte plus : MON CHOIX.
    static let windowDays: Int = 180
    static let maxObservations: Int = 500

    var observations: [HabitObservation] = []

    init() {}

    init(observations: [HabitObservation]) {
        self.observations = observations
    }

    /// Les valeurs brutes, pour un export ou un affichage.
    var exportedValues: [HabitObservation] {
        return observations
    }

    private static func windowSeconds() -> TimeInterval {
        return TimeInterval(HabitModel.windowDays) * 86400
    }

    /// Enregistre une réponse. Une réponse déjà donnée pour la même session est remplacée (elle redevient la plus récente).
    mutating func record(sessionKey: String,
                         placeKey: String,
                         visitStart: Date,
                         isWork: Bool,
                         now: Date,
                         calendar: Calendar) {
        let weekday: Int = calendar.component(.weekday, from: visitStart)
        let hour: Int = calendar.component(.hour, from: visitStart)
        observations.removeAll { (existing: HabitObservation) -> Bool in
            return existing.sessionKey == sessionKey
        }
        observations.append(HabitObservation(sessionKey: sessionKey, placeKey: placeKey, weekday: weekday,
                                             hourBucket: hour, isWork: isWork, recordedAt: now))
        prune(now: now)
    }

    /// Retire les réponses trop anciennes et garde les `maxObservations` plus récentes.
    mutating func prune(now: Date) {
        let cutoff: Date = now.addingTimeInterval(-HabitModel.windowSeconds())
        observations.removeAll { (existing: HabitObservation) -> Bool in
            return existing.recordedAt < cutoff
        }
        if observations.count > HabitModel.maxObservations {
            observations.removeFirst(observations.count - HabitModel.maxObservations)
        }
    }

    /// Oublie tout.
    mutating func reset() {
        observations = []
    }

    /// Réponses du contexte dans la fenêtre de 180 jours, de la plus ancienne à la plus récente.
    func evidence(placeKey: String, weekday: Int, hourBucket: Int, now: Date) -> HabitEvidence {
        let cutoff: Date = now.addingTimeInterval(-HabitModel.windowSeconds())
        var matching: [HabitObservation] = []
        for item in observations {
            if item.placeKey != placeKey { continue }
            if item.weekday != weekday { continue }
            if abs(item.hourBucket - hourBucket) > HabitModel.hourTolerance { continue }
            if item.recordedAt < cutoff { continue }
            matching.append(item)
        }
        var work: Int = 0
        var errand: Int = 0
        for item in matching {
            if item.isWork { work += 1 } else { errand += 1 }
        }
        var learned: Bool? = nil
        if matching.count >= HabitModel.minimumObservations {
            let lastOnes: [HabitObservation] = Array(matching.suffix(HabitModel.minimumObservations))
            var allWork: Bool = true
            var allErrand: Bool = true
            for item in lastOnes {
                if item.isWork { allErrand = false } else { allWork = false }
            }
            if allWork {
                learned = true
            } else if allErrand {
                learned = false
            }
        }
        return HabitEvidence(workCount: work, errandCount: errand, learnedIsWork: learned)
    }
}
