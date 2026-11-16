import Foundation

/// Analyse "Pourquoi l'app a raté ça ?" (section 132, module detection_help).
/// Foundation seulement : aucune dépendance à SwiftData, SwiftUI ou CoreLocation.
/// Tout arrive en valeurs simples. Les seuils sont des choix de l'app (voir notes/detection_help.md).

/// Ce qui s'est mal passé selon l'utilisateur.
enum MissQuestion: String, CaseIterable, Equatable {
    case missedArrival
    case missedDeparture
    case wrongHour
    case createdForNothing

    var title: String {
        switch self {
        case .missedArrival: return "Arrivée manquée"
        case .missedDeparture: return "Départ manqué"
        case .wrongHour: return "Heure décalée"
        case .createdForNothing: return "Session pour rien"
        }
    }

    /// Phrase courte pour la liste de choix.
    var hint: String {
        switch self {
        case .missedArrival: return "Je suis arrivé et rien ne s'est lancé."
        case .missedDeparture: return "Je suis parti et la session est restée ouverte."
        case .wrongHour: return "La détection a eu lieu, mais à la mauvaise heure."
        case .createdForNothing: return "Une session est apparue alors que je n'étais pas là."
        }
    }

    var isMiss: Bool {
        return self == .missedArrival || self == .missedDeparture
    }
}

enum MissConfidence: Int, Equatable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: MissConfidence, rhs: MissConfidence) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .low: return "Confiance faible"
        case .medium: return "Confiance moyenne"
        case .high: return "Confiance forte"
        }
    }

    /// Un cran de moins (quand la preuve est le réglage d'aujourd'hui et pas celui du jour concerné).
    var lowered: MissConfidence {
        switch self {
        case .high: return .medium
        case .medium: return .low
        case .low: return .low
        }
    }
}

/// État des capacités à un instant donné. Nil = on ne sait pas.
struct MissCapabilities: Equatable {
    var location: DiagLocationState?
    var preciseLocation: Bool?
    var backgroundRefreshOn: Bool?
    var lowPowerMode: Bool?

    init(location: DiagLocationState? = nil,
         preciseLocation: Bool? = nil,
         backgroundRefreshOn: Bool? = nil,
         lowPowerMode: Bool? = nil) {
        self.location = location
        self.preciseLocation = preciseLocation
        self.backgroundRefreshOn = backgroundRefreshOn
        self.lowPowerMode = lowPowerMode
    }
}

/// Une ligne du journal de détection, en valeurs simples.
struct MissEvent: Equatable {
    let kindRaw: String
    let date: Date
    let placeName: String?
    let accuracy: Double?

    init(kindRaw: String, date: Date, placeName: String? = nil, accuracy: Double? = nil) {
        self.kindRaw = kindRaw
        self.date = date
        self.placeName = placeName
        self.accuracy = accuracy
    }
}

struct MissInput: Equatable {
    var question: MissQuestion
    /// Fenêtre étudiée (les événements hors fenêtre sont ignorés).
    var windowStart: Date
    var windowEnd: Date
    var events: [MissEvent]
    /// Capacités pendant la fenêtre, nil si l'app n'a pas d'historique.
    var atTime: MissCapabilities?
    /// Capacités actuelles.
    var now: MissCapabilities
    /// Rayon du lieu en mètres, nil si pas de lieu.
    var placeRadius: Double?
    var placeName: String?
    var sessionStart: Date?
    var sessionEnd: Date?
    /// "gps" ou "manual" (valeur brute de SessionSource), nil si pas de session.
    var sessionSourceRaw: String?
    var calendar: Calendar

    init(question: MissQuestion,
         windowStart: Date,
         windowEnd: Date,
         events: [MissEvent],
         atTime: MissCapabilities?,
         now: MissCapabilities,
         placeRadius: Double?,
         placeName: String?,
         sessionStart: Date?,
         sessionEnd: Date?,
         sessionSourceRaw: String?,
         calendar: Calendar) {
        self.question = question
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.events = events
        self.atTime = atTime
        self.now = now
        self.placeRadius = placeRadius
        self.placeName = placeName
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
        self.sessionSourceRaw = sessionSourceRaw
        self.calendar = calendar
    }
}

/// Causes possibles. L'ordre de déclaration sert de départage stable à score égal.
enum MissCauseID: Int, CaseIterable, Equatable {
    case locationDenied
    case locationWhenInUse
    case monitoringFailed
    case backgroundRefreshOff
    case lowPowerMode
    case poorAccuracy
    case preciseLocationOff
    case delayedDelivery
    case briefPass
    case smallRadius
    case largeRadius
    case weakSignal
}

enum MissFixKind: Equatable {
    case none
    case openSettings
    case widenRadius(Double)
    case restartMonitoring
    case correctSession
}

struct MissFix: Equatable {
    let kind: MissFixKind
    let title: String
}

struct MissCause: Equatable {
    let id: MissCauseID
    let confidence: MissConfidence
    let title: String
    let explanation: String
    let fix: MissFix?
    let score: Int
}

enum MissCheckID: String, CaseIterable, Equatable {
    case location
    case precise
    case backgroundRefresh
    case lowPower
    case radius
    case accuracy
    case journal
}

enum MissCheckStatus: Int, Equatable {
    case unknown = 0
    case ok = 1
    case warning = 2
    case blocking = 3

    var title: String {
        switch self {
        case .unknown: return "Inconnu"
        case .ok: return "OK"
        case .warning: return "À régler"
        case .blocking: return "Bloquant"
        }
    }
}

struct MissCheck: Equatable {
    let id: MissCheckID
    let title: String
    let detail: String
    let status: MissCheckStatus
    let fix: MissFix?
}

enum MissVerdict: Equatable {
    /// Au moins une cause probable.
    case causes
    /// Des données, mais aucun réglage anormal : seule une piste faible reste.
    case nothingFound
    /// Aucune donnée pour cette période.
    case unknown
    /// Session saisie à la main : la détection n'y est pour rien.
    case manualSession
}

struct MissResult: Equatable {
    let verdict: MissVerdict
    /// Causes classées, la plus probable d'abord.
    let causes: [MissCause]
    let checks: [MissCheck]
    let bannerTitle: String
    let bannerText: String
    /// Vrai si les capacités viennent de l'historique du jour, faux si c'est le réglage actuel.
    let usesHistoricalCapabilities: Bool

    var topCause: MissCause? { return causes.first }
}

enum MissAnalysis {

    // MARK: Seuils (choix de l'app, voir notes/detection_help.md)

    /// Rayon en dessous duquel on le juge serré.
    static let smallRadiusThreshold: Double = 80
    /// Rayon à partir duquel on le juge large (session pour rien).
    static let largeRadiusThreshold: Double = 200
    /// Précision considérée mauvaise sans rayon connu (m).
    static let poorAccuracyDefault: Double = 100
    /// Plancher de la mauvaise précision quand le rayon est connu (m).
    static let poorAccuracyFloor: Double = 50
    /// Part du rayon à partir de laquelle la précision gêne.
    static let poorAccuracyRadiusShare: Double = 0.75
    /// Retard à partir duquel un événement reçu est jugé tardif (secondes).
    static let lateDeliverySeconds: TimeInterval = 300
    /// Durée sous laquelle une session ressemble à un simple passage (secondes).
    static let briefPassSeconds: TimeInterval = 600
    /// Agrandissement proposé du rayon (m).
    static let widenStep: Double = 40
    /// Marge avant le début de la session dans la fenêtre (secondes).
    static let windowBefore: TimeInterval = 3600
    /// Marge après la fin de la session dans la fenêtre (secondes).
    static let windowAfter: TimeInterval = 5400

    static let arrivalKinds: [String] = ["regionEntered", "arrivalConfirmed", "sessionStarted"]
    static let departureKinds: [String] = ["regionExited", "departureConfirmed", "sessionStopped"]

    /// Fenêtre étudiée autour d'une session.
    static func window(sessionStart: Date, sessionEnd: Date?, now: Date) -> (start: Date, end: Date) {
        let end: Date = sessionEnd ?? now
        return (sessionStart.addingTimeInterval(-windowBefore), end.addingTimeInterval(windowAfter))
    }

    // MARK: Analyse

    static func analyze(_ input: MissInput) -> MissResult {
        let historical: Bool = input.atTime != nil
        let caps: MissCapabilities = input.atTime ?? input.now

        if input.sessionSourceRaw == "manual" {
            let manualChecks: [MissCheck] = buildChecks(input: input, caps: caps, historical: historical, events: [])
            return MissResult(
                verdict: .manualSession,
                causes: [],
                checks: manualChecks,
                bannerTitle: "Cette session, c'est toi qui l'as saisie",
                bannerText: "Elle n'a pas été créée par la détection, donc je ne peux pas lui reprocher une erreur. Si l'heure n'est pas bonne, corrige-la à la main.",
                usesHistoricalCapabilities: historical)
        }

        let events: [MissEvent] = relevantEvents(input)

        if events.isEmpty && !historical {
            let unknownChecks: [MissCheck] = buildChecks(input: input, caps: caps, historical: historical, events: events)
            return MissResult(
                verdict: .unknown,
                causes: [],
                checks: unknownChecks,
                bannerTitle: "Je ne sais pas",
                bannerText: "Le journal de détection n'a rien pour cette période, et je n'ai pas gardé tes réglages de ce moment-là. Je ne vais pas inventer une cause. Les points ci-dessous montrent seulement ce qui est réglé aujourd'hui.",
                usesHistoricalCapabilities: false)
        }

        var causes: [MissCause] = buildCauses(input: input, caps: caps, historical: historical, events: events)
        causes.sort { (a: MissCause, b: MissCause) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.id.rawValue < b.id.rawValue
        }
        let checks: [MissCheck] = buildChecks(input: input, caps: caps, historical: historical, events: events)

        if causes.isEmpty {
            let weakCause: MissCause = weakSignalCause()
            return MissResult(
                verdict: .nothingFound,
                causes: [weakCause],
                checks: checks,
                bannerTitle: "Je ne trouve rien d'anormal",
                bannerText: "Tes réglages avaient l'air bons. Le plus probable : un signal GPS faible à l'endroit du lieu. \(MissConfidence.medium.title), je ne peux pas être certain.",
                usesHistoricalCapabilities: historical)
        }

        let top: MissCause = causes[0]
        var text: String = top.explanation + " " + top.confidence.title + "."
        if causes.count > 1 {
            text += " J'ai relevé \(causes.count - 1) autre\(causes.count - 1 > 1 ? "s" : "") piste\(causes.count - 1 > 1 ? "s" : "") plus bas."
        }
        return MissResult(
            verdict: .causes,
            causes: causes,
            checks: checks,
            bannerTitle: "Cause la plus probable : " + top.title,
            bannerText: text,
            usesHistoricalCapabilities: historical)
    }

    // MARK: Événements

    /// Événements de la fenêtre, pour le lieu étudié (ou sans lieu), triés par date puis genre.
    static func relevantEvents(_ input: MissInput) -> [MissEvent] {
        var result: [MissEvent] = []
        for event in input.events {
            if event.date < input.windowStart || event.date > input.windowEnd { continue }
            if let wanted = input.placeName, let name = event.placeName, name != wanted { continue }
            result.append(event)
        }
        result.sort { (a: MissEvent, b: MissEvent) -> Bool in
            if a.date != b.date { return a.date < b.date }
            return a.kindRaw < b.kindRaw
        }
        return result
    }

    private static func worstAccuracy(_ events: [MissEvent]) -> Double? {
        var worst: Double? = nil
        for event in events {
            if let value = event.accuracy, value >= 0 {
                if let current = worst {
                    if value > current { worst = value }
                } else {
                    worst = value
                }
            }
        }
        return worst
    }

    private static func isPoorAccuracy(worst: Double?, radius: Double?) -> Bool {
        guard let worst = worst else { return false }
        if let radius = radius {
            let limit: Double = max(poorAccuracyFloor, radius * poorAccuracyRadiusShare)
            return worst >= limit
        }
        return worst > poorAccuracyDefault
    }

    /// Plus grand retard (secondes) entre l'heure d'une borne de la session et l'événement reçu correspondant.
    private static func lateDelay(_ input: MissInput, events: [MissEvent]) -> TimeInterval? {
        var best: TimeInterval? = nil
        if let start = input.sessionStart {
            for event in events where arrivalKinds.contains(event.kindRaw) {
                let delay: TimeInterval = event.date.timeIntervalSince(start)
                if delay >= lateDeliverySeconds && delay <= windowAfter {
                    if best == nil || delay > (best ?? 0) { best = delay }
                }
            }
        }
        if let end = input.sessionEnd {
            for event in events where departureKinds.contains(event.kindRaw) {
                let delay: TimeInterval = event.date.timeIntervalSince(end)
                if delay >= lateDeliverySeconds && delay <= windowAfter {
                    if best == nil || delay > (best ?? 0) { best = delay }
                }
            }
        }
        return best
    }

    // MARK: Pertinence par question

    /// Score d'une cause pour une question, 0 = hors sujet.
    static func score(_ cause: MissCauseID, for question: MissQuestion) -> Int {
        switch cause {
        case .locationDenied:
            return pick(question, arrival: 95, departure: 95, wrong: 80, nothing: 0)
        case .locationWhenInUse:
            return pick(question, arrival: 90, departure: 90, wrong: 60, nothing: 0)
        case .monitoringFailed:
            return pick(question, arrival: 88, departure: 88, wrong: 45, nothing: 0)
        case .backgroundRefreshOff:
            return pick(question, arrival: 80, departure: 85, wrong: 55, nothing: 0)
        case .lowPowerMode:
            return pick(question, arrival: 50, departure: 55, wrong: 65, nothing: 0)
        case .poorAccuracy:
            return pick(question, arrival: 60, departure: 60, wrong: 60, nothing: 70)
        case .preciseLocationOff:
            return pick(question, arrival: 58, departure: 58, wrong: 50, nothing: 60)
        case .delayedDelivery:
            return pick(question, arrival: 0, departure: 0, wrong: 75, nothing: 0)
        case .briefPass:
            return pick(question, arrival: 0, departure: 0, wrong: 0, nothing: 65)
        case .smallRadius:
            return pick(question, arrival: 45, departure: 50, wrong: 40, nothing: 0)
        case .largeRadius:
            return pick(question, arrival: 0, departure: 0, wrong: 0, nothing: 45)
        case .weakSignal:
            return 20
        }
    }

    private static func pick(_ q: MissQuestion, arrival: Int, departure: Int, wrong: Int, nothing: Int) -> Int {
        switch q {
        case .missedArrival: return arrival
        case .missedDeparture: return departure
        case .wrongHour: return wrong
        case .createdForNothing: return nothing
        }
    }

    // MARK: Causes

    private static func buildCauses(input: MissInput, caps: MissCapabilities, historical: Bool, events: [MissEvent]) -> [MissCause] {
        let q: MissQuestion = input.question
        let cal: Calendar = input.calendar
        var result: [MissCause] = []
        let hint: String = historical ? "" : " C'est le réglage d'aujourd'hui : je n'ai pas gardé celui de ce jour-là, donc c'est une piste, pas une preuve."

        func add(_ id: MissCauseID, base: MissConfidence, capabilityBased: Bool, title: String, explanation: String, fix: MissFix?) {
            let s: Int = score(id, for: q)
            if s <= 0 { return }
            let lowered: Bool = capabilityBased && !historical
            let confidence: MissConfidence = lowered ? base.lowered : base
            let text: String = capabilityBased ? explanation + hint : explanation
            result.append(MissCause(id: id, confidence: confidence, title: title, explanation: text, fix: fix, score: s))
        }

        let openSettings: MissFix = MissFix(kind: .openSettings, title: "Ouvrir les réglages iOS")

        // Autorisation de localisation.
        if let location = caps.location {
            switch location {
            case .denied, .restricted, .notDetermined:
                add(.locationDenied, base: .high, capabilityBased: true,
                    title: "L'accès à ta position n'est pas accordé",
                    explanation: "Sans l'accès à ta position, iOS ne me prévient d'aucune arrivée ni d'aucun départ.",
                    fix: openSettings)
            case .whenInUse:
                add(.locationWhenInUse, base: .high, capabilityBased: true,
                    title: "La localisation n'est pas sur Toujours",
                    explanation: "Sur « Pendant l'utilisation », iOS ne me réveille pas quand l'app est fermée ou que ton écran est verrouillé. Je rate donc les arrivées et les départs.",
                    fix: MissFix(kind: .openSettings, title: "Passer sur Toujours"))
            case .always:
                break
            }
        }

        // Erreur de surveillance notée dans le journal.
        if let failure = events.first(where: { (e: MissEvent) -> Bool in e.kindRaw == "monitoringFailed" }) {
            add(.monitoringFailed, base: .high, capabilityBased: false,
                title: "La surveillance a eu une erreur",
                explanation: "Le journal montre une erreur de surveillance à \(Formatting.clock(failure.date, calendar: cal)). Pendant ce temps, tes lieux n'étaient peut-être plus surveillés.",
                fix: MissFix(kind: .restartMonitoring, title: "Relancer le suivi"))
        }

        // Actualisation en arrière-plan.
        if caps.backgroundRefreshOn == false {
            let departure: Bool = (q == .missedDeparture)
            add(.backgroundRefreshOff, base: (q == .wrongHour || q == .createdForNothing) ? .medium : .high, capabilityBased: true,
                title: "L'actualisation en arrière-plan est coupée",
                explanation: departure
                    ? "Sans elle, iOS réveille moins bien l'app quand tu bouges, donc je n'ai pas vu ta sortie."
                    : "Sans elle, iOS réveille moins bien l'app quand tu bouges. Je peux voir ton arrivée ou ton départ très tard, ou pas du tout.",
                fix: MissFix(kind: .openSettings, title: "Autoriser l'actualisation en arrière-plan"))
        }

        // Mode économie d'énergie.
        if caps.lowPowerMode == true {
            add(.lowPowerMode, base: .medium, capabilityBased: true,
                title: "Le Mode économie d'énergie était actif",
                explanation: "iOS retarde alors les mises à jour de position pour économiser la batterie. La détection peut avoir plusieurs minutes de retard.",
                fix: MissFix(kind: .openSettings, title: "Désactiver le Mode économie d'énergie"))
        }

        // Précision.
        let worst: Double? = worstAccuracy(events)
        if isPoorAccuracy(worst: worst, radius: input.placeRadius), let worstValue = worst {
            let meters: Int = Int(worstValue.rounded())
            var text: String = "La position notée avait une précision de \(meters) m"
            if let radius = input.placeRadius {
                text += " pour un rayon de \(Int(radius.rounded())) m. Quand la précision approche le rayon, une entrée ou une sortie peut passer inaperçue ou arriver à la mauvaise heure."
            } else {
                text += ". Avec une position aussi floue, une entrée ou une sortie peut passer inaperçue ou arriver à la mauvaise heure."
            }
            add(.poorAccuracy, base: .medium, capabilityBased: false,
                title: "Le GPS était imprécis",
                explanation: text,
                fix: widenFix(radius: input.placeRadius))
        }

        // Position exacte.
        if caps.preciseLocation == false {
            add(.preciseLocationOff, base: .medium, capabilityBased: true,
                title: "La position exacte est désactivée",
                explanation: "Avec une position approximative, iOS déclenche les zones moins finement, surtout pour un petit lieu.",
                fix: MissFix(kind: .openSettings, title: "Activer la position exacte"))
        }

        // Événement reçu en retard.
        if let delay = lateDelay(input, events: events) {
            let minutes: Int = Int((delay / 60).rounded())
            add(.delayedDelivery, base: .medium, capabilityBased: false,
                title: "iOS m'a prévenu en retard",
                explanation: "L'événement m'est arrivé \(minutes) min après l'heure de la session. iOS groupe parfois les alertes de zone pour économiser la batterie, ce qui décale l'heure.",
                fix: MissFix(kind: .correctSession, title: "Corriger la session"))
        }

        // Simple passage.
        if let start = input.sessionStart, let end = input.sessionEnd, end.timeIntervalSince(start) < briefPassSeconds {
            add(.briefPass, base: .medium, capabilityBased: false,
                title: "Tu es probablement juste passé près du lieu",
                explanation: "La session a duré moins de 10 min. Ça ressemble à un passage devant le lieu plutôt qu'à une vraie visite.",
                fix: MissFix(kind: .correctSession, title: "Corriger la session"))
        }

        // Rayon.
        if let radius = input.placeRadius {
            if radius < smallRadiusThreshold {
                add(.smallRadius, base: .low, capabilityBased: false,
                    title: "Le rayon du lieu est serré",
                    explanation: "Ton lieu a un rayon de \(Int(radius.rounded())) m. En ville ou dans un bâtiment, le GPS dérive souvent de plus que ça, donc une sortie peut ne pas être vue.",
                    fix: widenFix(radius: radius))
            }
            if radius >= largeRadiusThreshold {
                add(.largeRadius, base: .low, capabilityBased: false,
                    title: "Le rayon du lieu est large",
                    explanation: "Avec \(Int(radius.rounded())) m de rayon, passer dans la rue d'à côté peut suffire à déclencher la zone.",
                    fix: MissFix(kind: .correctSession, title: "Corriger la session"))
            }
        }

        return result
    }

    private static func weakSignalCause() -> MissCause {
        return MissCause(id: .weakSignal,
                         confidence: .medium,
                         title: "Un signal GPS faible",
                         explanation: "Dans un bâtiment ou un sous-sol, le GPS peut dériver sans que rien ne soit anormal dans tes réglages.",
                         fix: MissFix(kind: .correctSession, title: "Corriger la session"),
                         score: score(.weakSignal, for: .missedArrival))
    }

    private static func widenFix(radius: Double?) -> MissFix? {
        guard let radius = radius else { return nil }
        let delta: Double = min(widenStep, PlaceRules.maxRadius - radius)
        if delta < 1 { return nil }
        return MissFix(kind: .widenRadius(delta), title: "Agrandir le rayon de \(Int(delta.rounded())) m")
    }

    // MARK: Vérifications

    private static func buildChecks(input: MissInput, caps: MissCapabilities, historical: Bool, events: [MissEvent]) -> [MissCheck] {
        let q: MissQuestion = input.question
        let cal: Calendar = input.calendar
        let scope: String = historical ? "" : " (réglage d'aujourd'hui)"
        let unknownText: String = "Je n'ai pas cette information."
        var checks: [MissCheck] = []
        let openSettings: MissFix = MissFix(kind: .openSettings, title: "Ouvrir les réglages iOS")

        // Localisation
        var locStatus: MissCheckStatus = .unknown
        var locDetail: String = unknownText
        var locFix: MissFix? = nil
        if let location = caps.location {
            switch location {
            case .always:
                locStatus = .ok
                locDetail = "Réglée sur Toujours\(scope)."
            case .whenInUse:
                locStatus = q.isMiss ? .blocking : .warning
                locDetail = "Réglée sur « Pendant l'utilisation »\(scope). Écran verrouillé, je ne suis pas réveillé."
                locFix = MissFix(kind: .openSettings, title: "Passer sur Toujours")
            case .denied, .restricted, .notDetermined:
                locStatus = .blocking
                locDetail = "L'accès à ta position n'est pas accordé\(scope)."
                locFix = openSettings
            }
        }
        checks.append(MissCheck(id: .location, title: "Localisation sur « Toujours »", detail: locDetail, status: locStatus, fix: locFix))

        // Position exacte
        var preStatus: MissCheckStatus = .unknown
        var preDetail: String = unknownText
        var preFix: MissFix? = nil
        if let precise = caps.preciseLocation {
            if precise {
                preStatus = .ok
                preDetail = "Position exacte activée\(scope)."
            } else {
                preStatus = .warning
                preDetail = "Position exacte désactivée\(scope). Les zones se déclenchent moins finement."
                preFix = MissFix(kind: .openSettings, title: "Activer la position exacte")
            }
        }
        checks.append(MissCheck(id: .precise, title: "Position exacte", detail: preDetail, status: preStatus, fix: preFix))

        // Actualisation en arrière-plan
        var bgStatus: MissCheckStatus = .unknown
        var bgDetail: String = unknownText
        var bgFix: MissFix? = nil
        if let on = caps.backgroundRefreshOn {
            if on {
                bgStatus = .ok
                bgDetail = "Activée\(scope)."
            } else {
                bgStatus = q.isMiss ? .blocking : .warning
                bgDetail = "Désactivée\(scope). Sans elle, je peux ne pas voir une sortie quand l'app dort."
                bgFix = MissFix(kind: .openSettings, title: "Autoriser l'actualisation en arrière-plan")
            }
        }
        checks.append(MissCheck(id: .backgroundRefresh, title: "Actualisation en arrière-plan", detail: bgDetail, status: bgStatus, fix: bgFix))

        // Économie d'énergie
        var lpStatus: MissCheckStatus = .unknown
        var lpDetail: String = unknownText
        var lpFix: MissFix? = nil
        if let low = caps.lowPowerMode {
            if low {
                lpStatus = .warning
                lpDetail = "Actif\(scope). La détection peut avoir quelques minutes de retard."
                lpFix = MissFix(kind: .openSettings, title: "Désactiver le Mode économie d'énergie")
            } else {
                lpStatus = .ok
                lpDetail = "Pas actif\(scope)."
            }
        }
        checks.append(MissCheck(id: .lowPower, title: "Mode économie d'énergie", detail: lpDetail, status: lpStatus, fix: lpFix))

        // Rayon
        var radStatus: MissCheckStatus = .unknown
        var radDetail: String = "Pas de lieu lié, je ne connais pas le rayon."
        var radFix: MissFix? = nil
        if let radius = input.placeRadius {
            let meters: Int = Int(radius.rounded())
            if q != .createdForNothing && radius < smallRadiusThreshold {
                radStatus = .warning
                radDetail = "Rayon de \(meters) m, c'est serré."
                radFix = widenFix(radius: radius)
            } else if q == .createdForNothing && radius >= largeRadiusThreshold {
                radStatus = .warning
                radDetail = "Rayon de \(meters) m, c'est large."
            } else {
                radStatus = .ok
                radDetail = "Rayon de \(meters) m."
            }
        }
        checks.append(MissCheck(id: .radius, title: "Rayon du lieu", detail: radDetail, status: radStatus, fix: radFix))

        // Précision des positions
        let worst: Double? = worstAccuracy(events)
        var accStatus: MissCheckStatus = .unknown
        var accDetail: String = "Aucune précision notée dans le journal."
        var accFix: MissFix? = nil
        if let worstValue = worst {
            let meters: Int = Int(worstValue.rounded())
            if isPoorAccuracy(worst: worst, radius: input.placeRadius) {
                accStatus = .warning
                accDetail = "Précision jusqu'à \(meters) m, c'est flou."
                accFix = widenFix(radius: input.placeRadius)
            } else {
                accStatus = .ok
                accDetail = "Précision jusqu'à \(meters) m, c'est correct."
            }
        }
        checks.append(MissCheck(id: .accuracy, title: "Précision du GPS", detail: accDetail, status: accStatus, fix: accFix))

        // Journal
        var jStatus: MissCheckStatus = .ok
        var jDetail: String = "\(events.count) ligne\(events.count > 1 ? "s" : "") dans le journal pour cette période, sans erreur."
        var jFix: MissFix? = nil
        if events.isEmpty {
            jStatus = .unknown
            jDetail = "Le journal n'a rien pour cette période."
        } else if let failure = events.first(where: { (e: MissEvent) -> Bool in e.kindRaw == "monitoringFailed" }) {
            jStatus = .blocking
            jDetail = "Erreur de surveillance à \(Formatting.clock(failure.date, calendar: cal))."
            jFix = MissFix(kind: .restartMonitoring, title: "Relancer le suivi")
        }
        checks.append(MissCheck(id: .journal, title: "Journal de détection", detail: jDetail, status: jStatus, fix: jFix))

        return checks
    }
}
