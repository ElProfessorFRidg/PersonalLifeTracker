import Foundation

/// Un lieu vu par le moteur : aucune dépendance à CoreLocation ni à SwiftData.
struct DetectionPlace: Equatable {
    let uid: UUID
    let name: String
    let type: PlaceType
    let alsoWorksHere: Bool

    init(uid: UUID, name: String, type: PlaceType, alsoWorksHere: Bool = false) {
        self.uid = uid
        self.name = name
        self.type = type
        self.alsoWorksHere = alsoWorksHere
    }

    /// Les lieux de courses sont notés mais ne créent jamais de session comptée.
    var createsSessions: Bool {
        return type == .taf || type == .cours
    }
}

/// Ce que le moteur reçoit.
enum DetectionInput: Equatable {
    /// Entrée dans la zone d'un lieu. `accuracy` en mètres, nil si inconnue.
    case entered(place: DetectionPlace, date: Date, accuracy: Double?)
    case exited(place: DetectionPlace, date: Date)
    /// Le temps passe : les délais (présence minimale, délai de grâce) sont évalués.
    case tick(date: Date)
}

enum DetectionBound: Equatable {
    case arrival
    case departure
}

/// Ce que le moteur demande à l'extérieur de faire. Les dates sont exactes, jamais arrondies.
enum DetectionDecision: Equatable {
    /// Démarrer une session à `date` (l'heure de l'entrée, pas celle du calcul).
    case startSession(place: DetectionPlace, date: Date, isUncertain: Bool)
    /// Arrêter la session en cours à `date` (l'heure de la sortie, pas celle de la fin du délai de grâce).
    case stopSession(place: DetectionPlace, date: Date)
    /// Passage trop court : aucune session.
    case ignoreShortVisit(place: DetectionPlace, entered: Date, exited: Date)
    /// Demander à l'utilisateur de confirmer l'arrivée ou le départ à `date`.
    case askConfirmation(place: DetectionPlace, bound: DetectionBound, date: Date)
    /// Lieu de courses : visite notée, pas de session comptée.
    case noteVisit(place: DetectionPlace, entered: Date)
    /// Une session tourne déjà : l'entrée dans ce lieu ne démarre rien.
    case skipBecauseSessionRunning(place: DetectionPlace, date: Date)
    /// Retour dans la zone pendant le délai de grâce : la session continue.
    case departureCancelled(place: DetectionPlace, date: Date)
    /// Sortie d'un lieu dont on n'avait pas vu l'entrée et sans session en cours : rien à faire.
    case ignoreExitWithoutEntry(place: DetectionPlace, date: Date)
    /// Fin d'une visite notée dans un lieu de courses où l'on travaille aussi (section 11) : la durée est connue,
    /// l'appelant peut la classer (travail ou courses). Jamais émis pour un lieu de courses ordinaire.
    case visitEnded(place: DetectionPlace, entered: Date, exited: Date)
}

/// Machine à états de la détection (sections 8, 13 et 14). Foundation seulement.
/// Le moteur ne lit jamais l'horloge : toutes les dates viennent des événements.
struct DetectionEngine {

    // MARK: Seuils (choix de l'app : la spec ne donne aucun chiffre pour ces délais, voir notes/core_geofence.md)

    /// Présence minimale avant de compter une arrivée : 5 minutes.
    static let minimumDwellSeconds: TimeInterval = 5 * 60
    /// Délai de grâce avant de confirmer un départ : 3 minutes.
    static let departureGraceSeconds: TimeInterval = 3 * 60
    /// Au-delà de cette précision (mètres), une arrivée est marquée incertaine : 100 m.
    static let maxTrustedAccuracyMeters: Double = 100

    private struct PendingArrival {
        let place: DetectionPlace
        let entered: Date
        let accuracy: Double?
    }

    private struct PendingDeparture {
        let place: DetectionPlace
        let exited: Date
    }

    private var pendingArrivals: [UUID: PendingArrival] = [:]
    private var pendingDepartures: [UUID: PendingDeparture] = [:]
    /// Lieux de courses dont la visite est notée et pas encore terminée, avec l'heure d'entrée.
    private var notedVisits: [UUID: Date] = [:]
    /// Lieu de la session en cours (nil si aucune). Les sessions manuelles ont un lieu nil mais comptent comme en cours.
    private(set) var runningPlace: DetectionPlace?
    private(set) var isSessionRunning: Bool = false

    init() {}

    /// À appeler avant chaque événement : l'état réel de la base (une session peut avoir été démarrée ou arrêtée à la main,
    /// ou l'app relancée). Le moteur ne devine rien tout seul.
    mutating func syncRunningSession(isRunning: Bool, place: DetectionPlace?) {
        isSessionRunning = isRunning
        runningPlace = isRunning ? place : nil
        if !isRunning {
            pendingDepartures.removeAll()
        }
    }

    /// Vrai s'il reste un délai en cours (utile pour garder le suivi actif le temps nécessaire).
    var hasPendingWork: Bool {
        return !pendingArrivals.isEmpty || !pendingDepartures.isEmpty
    }

    /// Prochaine date où un tick changerait quelque chose, nil s'il n'y a rien à attendre.
    func nextDeadline() -> Date? {
        var dates: [Date] = []
        for pending in pendingArrivals.values {
            dates.append(pending.entered.addingTimeInterval(DetectionEngine.minimumDwellSeconds))
        }
        for pending in pendingDepartures.values {
            dates.append(pending.exited.addingTimeInterval(DetectionEngine.departureGraceSeconds))
        }
        return dates.min()
    }

    mutating func handle(_ input: DetectionInput) -> [DetectionDecision] {
        switch input {
        case .entered(let place, let date, let accuracy):
            return handleEntered(place: place, date: date, accuracy: accuracy)
        case .exited(let place, let date):
            return handleExited(place: place, date: date)
        case .tick(let date):
            return handleTick(now: date)
        }
    }

    // MARK: Entrée

    private mutating func handleEntered(place: DetectionPlace, date: Date, accuracy: Double?) -> [DetectionDecision] {
        // Retour dans la zone pendant le délai de grâce : le départ n'a jamais eu lieu.
        if pendingDepartures[place.uid] != nil {
            pendingDepartures[place.uid] = nil
            return [.departureCancelled(place: place, date: date)]
        }
        // Déjà en cours dans ce lieu, ou déjà noté : doublon d'événement.
        if isSessionRunning, let running = runningPlace, running.uid == place.uid {
            return []
        }
        if pendingArrivals[place.uid] != nil || notedVisits[place.uid] != nil {
            return []
        }
        pendingArrivals[place.uid] = PendingArrival(place: place, entered: date, accuracy: accuracy)
        return []
    }

    // MARK: Sortie

    private mutating func handleExited(place: DetectionPlace, date: Date) -> [DetectionDecision] {
        var decisions: [DetectionDecision] = []

        if let arrival = pendingArrivals[place.uid] {
            pendingArrivals[place.uid] = nil
            let dwell: TimeInterval = date.timeIntervalSince(arrival.entered)
            if dwell < DetectionEngine.minimumDwellSeconds {
                return [.ignoreShortVisit(place: place, entered: arrival.entered, exited: date)]
            }
            // Présence suffisante, mais le tick n'est pas passé avant la sortie : on compte l'arrivée maintenant.
            decisions.append(contentsOf: promote(arrival))
        }

        if let notedEntry = notedVisits[place.uid] {
            notedVisits[place.uid] = nil
            if place.alsoWorksHere {
                decisions.append(.visitEnded(place: place, entered: notedEntry, exited: date))
            }
            return decisions
        }

        if isSessionRunning, let running = runningPlace, running.uid == place.uid {
            pendingDepartures[place.uid] = PendingDeparture(place: place, exited: date)
            return decisions
        }

        if decisions.isEmpty {
            decisions.append(.ignoreExitWithoutEntry(place: place, date: date))
        }
        return decisions
    }

    // MARK: Temps

    private mutating func handleTick(now: Date) -> [DetectionDecision] {
        var decisions: [DetectionDecision] = []

        // Départs d'abord, pour libérer la place avant d'examiner une arrivée dans un autre lieu.
        let departures: [PendingDeparture] = pendingDepartures.values
            .filter { now.timeIntervalSince($0.exited) >= DetectionEngine.departureGraceSeconds }
            .sorted { $0.exited < $1.exited }
        for departure in departures {
            pendingDepartures[departure.place.uid] = nil
            isSessionRunning = false
            runningPlace = nil
            decisions.append(.stopSession(place: departure.place, date: departure.exited))
            decisions.append(.askConfirmation(place: departure.place, bound: .departure, date: departure.exited))
        }

        let arrivals: [PendingArrival] = pendingArrivals.values
            .filter { now.timeIntervalSince($0.entered) >= DetectionEngine.minimumDwellSeconds }
            .sorted { $0.entered < $1.entered }
        for arrival in arrivals {
            pendingArrivals[arrival.place.uid] = nil
            decisions.append(contentsOf: promote(arrival))
        }
        return decisions
    }

    // MARK: Arrivée comptée

    private mutating func promote(_ arrival: PendingArrival) -> [DetectionDecision] {
        let place: DetectionPlace = arrival.place
        if !place.createsSessions {
            notedVisits[place.uid] = arrival.entered
            return [.noteVisit(place: place, entered: arrival.entered)]
        }
        if isSessionRunning {
            return [.skipBecauseSessionRunning(place: place, date: arrival.entered)]
        }
        isSessionRunning = true
        runningPlace = place
        var uncertain: Bool = false
        if let accuracy = arrival.accuracy, accuracy > DetectionEngine.maxTrustedAccuracyMeters {
            uncertain = true
        }
        return [
            .startSession(place: place, date: arrival.entered, isUncertain: uncertain),
            .askConfirmation(place: place, bound: .arrival, date: arrival.entered)
        ]
    }
}
