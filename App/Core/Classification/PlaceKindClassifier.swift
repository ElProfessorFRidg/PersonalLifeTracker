import Foundation

// Identification du type d'un lieu découvert : taf, école, courses, domicile (et sport, sortie avec Plans).
// Pur, Foundation seulement. Chaque signal ajoute des points à un type avec une raison en français.
// Les seuils sont des constantes nommées, expliquées dans notes/place_identification.md.

// MARK: Horaires

/// Résumé chiffré des passages d'un lieu. Les passages de nuit (milieu de nuit couvert) ne comptent que pour le domicile.
struct PlaceVisitPattern: Equatable {
    var visitCount: Int = 0
    var dayCount: Int = 0
    /// Passages du lundi au vendredi.
    var weekdayVisitCount: Int = 0
    /// Samedi avec départ avant 13 h 30 : compatible avec une école.
    var saturdayMorningCount: Int = 0
    /// Dimanche, ou samedi qui dépasse 13 h 30 : pas une école.
    var weekendWorkCount: Int = 0
    /// Arrivée à 17 h ou après, ou départ à 20 h ou après.
    var eveningCount: Int = 0
    var overnightDays: Int = 0
    /// Passages de 1 h à 9 h.
    var schoolLengthCount: Int = 0
    /// Passages de moins de 45 min.
    var shortCount: Int = 0
    /// Jours avec au moins un passage de 2 h ou plus.
    var longDayCount: Int = 0
    /// Part des jours dont la première arrivée est à plus ou moins 60 min de l'arrivée médiane.
    var regularStartShare: Double = 0
    /// Jours où l'on sort 30 à 150 min vers midi puis revient.
    var lunchGapDays: Int = 0
    /// Nombre de jours différents de la semaine (lundi à vendredi) vus.
    var distinctWeekdays: Int = 0
    /// Une semaine entière sans passage entre des semaines régulières (vacances).
    var hasHolidayGap: Bool = false
    var substantialCount: Int = 0
    /// Écart entre la plus longue et la plus courte présence de 45 min ou plus, en heures.
    var durationSpreadHours: Double = 0

    var isErrandShape: Bool { return visitCount >= 3 && shortCount * 10 >= visitCount * 7 }
    var isSchoolShape: Bool { return visitCount >= 1 && schoolLengthCount * 10 >= visitCount * 7 }

    /// Empreinte grossière des horaires, pour généraliser une correction à un autre lieu aux horaires pareils.
    var key: String {
        let week: String = weekendWorkCount > 0 ? "we" : "wd"
        let moment: String = eveningCount > 0 ? "ev" : "day"
        let shape: String = isErrandShape ? "short" : (isSchoolShape ? "long" : "mixed")
        return "\(week)-\(moment)-\(shape)"
    }

    private static func minutesOfDay(_ date: Date, _ calendar: Calendar) -> Int {
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func analyze(_ allVisits: [PlaceVisitObservation], calendar: Calendar) -> PlaceVisitPattern {
        var pattern: PlaceVisitPattern = PlaceVisitPattern()
        var overnight: Set<Date> = []
        var visits: [PlaceVisitObservation] = []
        let ordered: [PlaceVisitObservation] = allVisits.sorted { (a: PlaceVisitObservation, b: PlaceVisitObservation) -> Bool in
            return a.arrival < b.arrival
        }
        for visit in ordered {
            if visit.departure <= visit.arrival { continue }
            if let night = PlaceDiscoveryRules.overnightDay(for: visit, calendar: calendar) {
                overnight.insert(night)
            } else {
                visits.append(visit)
            }
        }
        pattern.overnightDays = overnight.count
        pattern.visitCount = visits.count
        if visits.isEmpty { return pattern }

        var byDay: [Date: [PlaceVisitObservation]] = [:]
        var weekdaysSeen: Set<Int> = []
        var longDays: Set<Date> = []
        var substantialHours: [Double] = []
        for visit in visits {
            let day: Date = calendar.startOfDay(for: visit.arrival)
            var list: [PlaceVisitObservation] = byDay[day] ?? []
            list.append(visit)
            byDay[day] = list
            let weekday: Int = calendar.component(.weekday, from: visit.arrival)
            let startMinutes: Int = minutesOfDay(visit.arrival, calendar)
            let sameDay: Bool = calendar.isDate(visit.arrival, inSameDayAs: visit.departure)
            let endMinutes: Int = sameDay ? minutesOfDay(visit.departure, calendar) : 24 * 60
            if weekday == 1 {
                pattern.weekendWorkCount += 1
            } else if weekday == 7 {
                if sameDay && endMinutes <= 13 * 60 + 30 {
                    pattern.saturdayMorningCount += 1
                } else {
                    pattern.weekendWorkCount += 1
                }
            } else {
                pattern.weekdayVisitCount += 1
                weekdaysSeen.insert(weekday)
            }
            if startMinutes >= 17 * 60 || endMinutes >= 20 * 60 { pattern.eveningCount += 1 }
            let duration: TimeInterval = visit.duration
            if duration >= 3600 && duration <= 9 * 3600 { pattern.schoolLengthCount += 1 }
            if duration < 45 * 60 {
                pattern.shortCount += 1
            } else {
                substantialHours.append(duration / 3600)
            }
            if duration >= 2 * 3600 { longDays.insert(day) }
        }
        pattern.dayCount = byDay.count
        pattern.distinctWeekdays = weekdaysSeen.count
        pattern.longDayCount = longDays.count
        pattern.substantialCount = substantialHours.count
        if let longest = substantialHours.max(), let shortest = substantialHours.min() {
            pattern.durationSpreadHours = longest - shortest
        }

        let days: [Date] = byDay.keys.sorted()
        var starts: [Int] = []
        var lunchDays: Int = 0
        for day in days {
            guard let list = byDay[day], let first = list.first else { continue }
            starts.append(minutesOfDay(first.arrival, calendar))
            if list.count >= 2 {
                var found: Bool = false
                for index in 1..<list.count {
                    let gap: TimeInterval = list[index].arrival.timeIntervalSince(list[index - 1].departure)
                    let leaving: Int = minutesOfDay(list[index - 1].departure, calendar)
                    if gap >= 30 * 60 && gap <= 150 * 60 && leaving >= 11 * 60 && leaving <= 14 * 60 + 30 {
                        found = true
                    }
                }
                if found { lunchDays += 1 }
            }
        }
        pattern.lunchGapDays = lunchDays
        if !starts.isEmpty {
            let sortedStarts: [Int] = starts.sorted()
            let median: Int = sortedStarts[sortedStarts.count / 2]
            var near: Int = 0
            for start in starts where abs(start - median) <= 60 { near += 1 }
            pattern.regularStartShare = Double(near) / Double(starts.count)
        }
        pattern.hasHolidayGap = holidayGap(days: days, calendar: calendar)
        return pattern
    }

    /// Vrai s'il existe un lundi au dimanche sans aucun passage, avec au moins 3 jours de passage avant et 3 après.
    private static func holidayGap(days: [Date], calendar: Calendar) -> Bool {
        guard days.count >= 6, let first = days.first, let last = days.last else { return false }
        var monday: Date = first
        var steps: Int = 0
        while calendar.component(.weekday, from: monday) != 2 && steps < 8 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: monday) else { return false }
            monday = next
            steps += 1
        }
        if calendar.component(.weekday, from: monday) != 2 { return false }
        var safety: Int = 0
        while safety < 20 {
            safety += 1
            guard let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday) else { return false }
            if nextMonday > last { return false }
            let mondayValue: Date = monday
            let before: Int = days.filter { (day: Date) -> Bool in return day < mondayValue }.count
            let inside: Int = days.filter { (day: Date) -> Bool in return day >= mondayValue && day < nextMonday }.count
            let after: Int = days.filter { (day: Date) -> Bool in return day >= nextMonday }.count
            if inside == 0 && before >= 3 && after >= 3 { return true }
            monday = nextMonday
        }
        return false
    }
}

// MARK: Entrées et sortie

/// Un lieu déjà enregistré près du candidat.
struct NearbyPlaceHint: Equatable {
    let type: PlaceType
    let distance: Double
    let name: String
    /// Vrai si le lieu est rattaché à un contrat (`Contract.placeUIDs`).
    let isContractPlace: Bool
}

struct PlaceKindSignals {
    var visits: [PlaceVisitObservation] = []
    var name: String? = nil
    /// Catégorie Plans brute (`MKPointOfInterestCategory.rawValue`).
    var poi: String? = nil
    /// Ancienne catégorie déjà convertie en type de lieu (contextes enregistrés avant l'ajout de `poi`).
    var poiCategory: PlaceType? = nil
    var latitude: Double = 0
    var longitude: Double = 0
    var nearby: [NearbyPlaceHint] = []
    var lessons: [PlaceKindLesson] = []
    var calendar: Calendar = Calendar.current
}

enum PlaceKindVerdict: String, Equatable {
    /// Assez sûr : le type est présélectionné et l'app dit pourquoi.
    case confident
    /// Pas assez sûr : l'app pose une question avec trois boutons.
    case ask
}

struct PlaceKindDecision: Equatable {
    /// Type vers lequel penchent les indices (au moins 40 points et 15 d'avance), nil sinon.
    let leaning: PlaceType?
    /// 0 à 100.
    let confidence: Int
    let verdict: PlaceKindVerdict
    /// Raisons en français pour le type retenu (3 au maximum, les plus fortes d'abord), sans majuscule ni point.
    let reasons: [String]
    let scores: [PlaceType: Double]
    let patternKey: String
    /// Quand les noms ou Plans et les horaires se contredisent.
    let conflict: String?
    /// "Je pense que c'est ton école, parce que ...". Vide si `verdict == .ask`.
    let statement: String
    /// Question posée quand `verdict == .ask`.
    let question: String
    /// Pourquoi l'app pose la question.
    let explanation: String
}

fileprivate struct PlaceKindReason {
    let points: Double
    let text: String
}

fileprivate struct PlaceKindTally {
    var points: [PlaceType: Double] = [:]
    var reasons: [PlaceType: [PlaceKindReason]] = [:]

    mutating func add(_ type: PlaceType, _ value: Double, _ text: String) {
        points[type] = (points[type] ?? 0) + value
        var list: [PlaceKindReason] = reasons[type] ?? []
        list.append(PlaceKindReason(points: value, text: text))
        reasons[type] = list
    }

    func sortedReasons(for type: PlaceType) -> [PlaceKindReason] {
        let list: [PlaceKindReason] = reasons[type] ?? []
        return list.filter { (r: PlaceKindReason) -> Bool in return r.points > 0 }
            .sorted { (a: PlaceKindReason, b: PlaceKindReason) -> Bool in return a.points > b.points }
    }
}

fileprivate struct PlaceKeywordRule {
    let type: PlaceType
    let weight: Double
    let words: [String]
}

// MARK: Classeur

enum PlaceKindClassifier {

    // Seuils (voir notes/place_identification.md pour le raisonnement).
    /// Confiance minimale pour présélectionner un type. En dessous, l'app pose la question.
    static let confidentAt: Int = 70
    /// Score minimal du meilleur type pour "pencher" vers lui.
    static let leaningAt: Double = 40
    /// Avance minimale du meilleur type sur le second pour "pencher".
    static let leaningMargin: Double = 15
    /// Les horaires seuls ne dépassent jamais 69 points : sans nom, catégorie Plans ou réponse passée, on demande.
    static let timeOnlyCap: Double = 69
    /// Nombre de passages et de jours pour que les motifs d'horaires comptent.
    static let minimumPatternVisits: Int = 4
    static let nearbyRadius: Double = 400
    static let lessonRadius: Double = 400
    /// Réponses concordantes dans le voisinage qui remplacent toutes les heuristiques.
    static let lessonOverrideCount: Int = 2
    static let lessonNudge: Double = 45
    static let lessonPenalty: Double = 35
    static let patternLessonNudge: Double = 20
    /// Avance en confiance maximale quand horaires et noms se contredisent.
    static let conflictConfidenceCap: Int = 60

    // Poids des horaires.
    static let weightHomeNights: Double = 75
    static let weightHomeTwoNights: Double = 45
    static let weightSchoolWeekdays: Double = 25
    static let weightSchoolRegular: Double = 20
    static let weightSchoolLength: Double = 15
    static let weightSchoolLunch: Double = 15
    static let weightSchoolFiveDays: Double = 10
    static let weightSchoolHoliday: Double = 8
    static let weightWorkEvening: Double = 25
    static let weightWorkWeekend: Double = 25
    static let weightWorkIrregular: Double = 15
    static let weightWorkVaried: Double = 10
    static let weightWorkLongDays: Double = 15
    static let weightErrandShort: Double = 45
    static let weightErrandRecurring: Double = 10

    // Poids des indices de texte et de l'utilisateur.
    static let weightNameStrong: Double = 50
    static let weightNameWeak: Double = 25
    static let weightNameWork: Double = 40
    static let weightNameErrand: Double = 40
    static let weightNameLeisure: Double = 30
    static let weightPoiSchool: Double = 45
    static let weightPoiLibrary: Double = 20
    static let weightPoiErrand: Double = 30
    static let weightPoiLeisure: Double = 30
    static let weightPoiHospital: Double = 30
    static let weightPoiSport: Double = 40
    static let weightNearbySameKind: Double = 25
    static let weightNearbyContract: Double = 35

    // MARK: Phrases

    /// "ton école", "ton taf"... pour "Je pense que c'est ...".
    static func noun(_ type: PlaceType) -> String {
        switch type {
        case .taf: return "ton taf"
        case .cours: return "ton école"
        case .courses: return "un lieu de courses"
        case .domicile: return "ton domicile"
        case .sport: return "un lieu de sport"
        case .sortie: return "un lieu de sortie"
        case .autre: return "un autre lieu"
        }
    }

    static func joinFragments(_ parts: [String]) -> String {
        if parts.isEmpty { return "" }
        if parts.count == 1 { return parts[0] }
        let head: String = parts.dropLast().joined(separator: ", ")
        return head + " et " + parts[parts.count - 1]
    }

    // MARK: Entrée principale

    static func decide(_ signals: PlaceKindSignals) -> PlaceKindDecision {
        let pattern: PlaceVisitPattern = PlaceVisitPattern.analyze(signals.visits, calendar: signals.calendar)
        let time: PlaceKindTally = timeEvidence(pattern)
        var total: PlaceKindTally = PlaceKindTally()
        var rawTime: [PlaceType: Double] = [:]
        for type in PlaceType.allCases {
            let raw: Double = time.points[type] ?? 0
            rawTime[type] = raw
            let capped: Double = type == .domicile ? min(raw, 100) : min(raw, timeOnlyCap)
            if capped <= 0 { continue }
            let reasons: [PlaceKindReason] = time.sortedReasons(for: type)
            if let strongest = reasons.first {
                total.add(type, capped - strongest.points, strongest.text)
                total.points[type] = capped
                var list: [PlaceKindReason] = [strongest]
                list.append(contentsOf: reasons.dropFirst())
                total.reasons[type] = list
            }
        }

        var text: PlaceKindTally = PlaceKindTally()
        textEvidence(&text, name: signals.name, poi: signals.poi, category: signals.poiCategory)
        for type in PlaceType.allCases {
            guard let value = text.points[type] else { continue }
            total.points[type] = (total.points[type] ?? 0) + value
            var list: [PlaceKindReason] = total.reasons[type] ?? []
            list.append(contentsOf: text.reasons[type] ?? [])
            total.reasons[type] = list
        }

        var user: PlaceKindTally = PlaceKindTally()
        nearbyEvidence(&user, hints: signals.nearby)
        let override: PlaceType? = lessonEvidence(&user, signals: signals, patternKey: pattern.key)
        for type in PlaceType.allCases {
            guard let value = user.points[type] else { continue }
            total.points[type] = (total.points[type] ?? 0) + value
            var list: [PlaceKindReason] = total.reasons[type] ?? []
            list.append(contentsOf: user.reasons[type] ?? [])
            total.reasons[type] = list
        }

        var scores: [PlaceType: Double] = [:]
        for type in PlaceType.allCases {
            scores[type] = min(100, max(0, total.points[type] ?? 0))
        }
        if let forced = override {
            for type in PlaceType.allCases {
                if type == forced { scores[type] = 100 } else { scores[type] = min(scores[type] ?? 0, 35) }
            }
        }

        var ranked: [(index: Int, type: PlaceType, score: Double)] = []
        var index: Int = 0
        for type in PlaceType.allCases {
            ranked.append((index: index, type: type, score: scores[type] ?? 0))
            index += 1
        }
        ranked.sort { (a: (index: Int, type: PlaceType, score: Double), b: (index: Int, type: PlaceType, score: Double)) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.index < b.index
        }
        let best = ranked[0]
        let second: Double = ranked.count > 1 ? ranked[1].score : 0
        let margin: Double = best.score - second
        let factor: Double = 0.5 + 0.5 * min(1, margin / 40)
        var confidence: Int = Int((min(100, best.score) * factor).rounded())
        var leaning: PlaceType? = nil
        if best.score >= leaningAt && margin >= leaningMargin { leaning = best.type }
        if override != nil { confidence = max(confidence, 95) }

        var conflict: String? = nil
        if override == nil, let chosen = leaning {
            conflict = conflictMessage(time: rawTime, text: text, leaning: chosen)
            if conflict != nil { confidence = min(confidence, conflictConfidenceCap) }
        }

        let verdict: PlaceKindVerdict = (leaning != nil && confidence >= confidentAt) ? .confident : .ask
        var fragments: [String] = []
        if let chosen = leaning {
            for reason in total.sortedReasons(for: chosen).prefix(3) { fragments.append(reason.text) }
        }
        var statement: String = ""
        if verdict == .confident, let chosen = leaning {
            statement = "Je pense que c'est \(noun(chosen)), parce que \(joinFragments(fragments))."
        }
        let question: String = "C'est ton taf, ton école ou autre chose ?"
        var explanation: String
        if let chosen = leaning {
            explanation = "Je penche pour \(noun(chosen)) (\(joinFragments(fragments))), mais ça ne suffit pas pour décider à ta place."
        } else {
            explanation = "Je n'ai pas assez d'indices pour deviner : passe quelques fois de plus ou dis-moi ce que c'est."
        }
        if let message = conflict {
            explanation = message + ". Je préfère te demander plutôt que me tromper."
        }
        return PlaceKindDecision(leaning: leaning, confidence: confidence, verdict: verdict,
                                 reasons: fragments, scores: scores, patternKey: pattern.key,
                                 conflict: conflict, statement: statement, question: question,
                                 explanation: explanation)
    }

    // MARK: Signaux depuis un candidat

    static func signals(for candidate: DiscoveredPlace, places: [PlaceSnapshot], contractPlaceUIDs: Set<UUID>,
                        memory: PlaceKindMemory, now: Date, calendar: Calendar) -> PlaceKindSignals {
        var hints: [NearbyPlaceHint] = []
        for place in places {
            let meters: Double = PlaceRules.distanceMeters(latitude1: candidate.latitude, longitude1: candidate.longitude,
                                                           latitude2: place.latitude, longitude2: place.longitude)
            hints.append(NearbyPlaceHint(type: place.type, distance: meters, name: place.name,
                                         isContractPlace: contractPlaceUIDs.contains(place.id)))
        }
        return PlaceKindSignals(visits: PlaceDiscoveryRules.observations(candidate, now: now),
                                name: candidate.context?.name,
                                poi: candidate.context?.poi,
                                poiCategory: candidate.context?.category,
                                latitude: candidate.latitude,
                                longitude: candidate.longitude,
                                nearby: hints,
                                lessons: memory.lessons,
                                calendar: calendar)
    }

    static func identify(_ candidate: DiscoveredPlace, places: [PlaceSnapshot], contractPlaceUIDs: Set<UUID>,
                         memory: PlaceKindMemory, now: Date, calendar: Calendar) -> PlaceKindDecision {
        let input: PlaceKindSignals = signals(for: candidate, places: places, contractPlaceUIDs: contractPlaceUIDs,
                                              memory: memory, now: now, calendar: calendar)
        return decide(input)
    }

    /// Type vers lequel penche un candidat avec ses seuls indices propres (utilisé pour décider si deux arrêts voisins vont ensemble).
    static func leaning(of candidate: DiscoveredPlace, now: Date, calendar: Calendar) -> PlaceType? {
        let input: PlaceKindSignals = signals(for: candidate, places: [], contractPlaceUIDs: [],
                                              memory: PlaceKindMemory(), now: now, calendar: calendar)
        return decide(input).leaning
    }

    // MARK: Horaires

    fileprivate static func timeEvidence(_ p: PlaceVisitPattern) -> PlaceKindTally {
        var t: PlaceKindTally = PlaceKindTally()
        if p.overnightDays >= 3 {
            t.add(.domicile, weightHomeNights, "tu y passes plusieurs nuits")
        } else if p.overnightDays == 2 {
            t.add(.domicile, weightHomeTwoNights, "tu y as passé deux nuits")
        }
        if p.visitCount == 0 { return t }
        if p.isErrandShape {
            t.add(.courses, weightErrandShort, "tes passages durent moins de 45 minutes")
            if p.dayCount >= 3 {
                t.add(.courses, weightErrandRecurring, "tu y repasses sur plusieurs jours")
            }
            return t
        }
        if p.longDayCount >= 3 {
            t.add(.taf, weightWorkLongDays, "tu y as passé plus de 2 heures sur plusieurs jours")
        }
        let enough: Bool = p.visitCount >= minimumPatternVisits && p.dayCount >= minimumPatternVisits
        if !enough { return t }
        if p.isSchoolShape && p.weekendWorkCount == 0 {
            t.add(.cours, weightSchoolWeekdays, "tu y vas du lundi au vendredi, sans week-end")
            if p.regularStartShare >= 0.75 && p.eveningCount == 0 {
                t.add(.cours, weightSchoolRegular, "tu arrives à peu près à la même heure")
            }
            t.add(.cours, weightSchoolLength, "tu y restes de 1 à 9 heures")
            if p.lunchGapDays >= 2 {
                t.add(.cours, weightSchoolLunch, "tu en sors à midi pour revenir l'après-midi")
            }
            if p.distinctWeekdays >= 4 {
                t.add(.cours, weightSchoolFiveDays, "tu y viens presque tous les jours de la semaine")
            }
            if p.hasHolidayGap {
                t.add(.cours, weightSchoolHoliday, "tu n'y es pas allé pendant une semaine entière")
            }
        }
        if p.eveningCount >= 2 && p.eveningCount * 3 >= p.visitCount {
            t.add(.taf, weightWorkEvening, "tu y vas souvent le soir")
        }
        if p.weekendWorkCount >= 2 {
            t.add(.taf, weightWorkWeekend, "tu y vas le week-end")
        }
        if p.regularStartShare < 0.6 {
            t.add(.taf, weightWorkIrregular, "tes heures d'arrivée changent d'un jour à l'autre")
        }
        if p.substantialCount >= 4 && p.durationSpreadHours >= 3 {
            t.add(.taf, weightWorkVaried, "la durée de tes présences varie beaucoup")
        }
        return t
    }

    // MARK: Nom et catégorie Plans

    private static let keywordRules: [PlaceKeywordRule] = [
        PlaceKeywordRule(type: .cours, weight: 50, words: [
            "lycee", "college", "ecole", "universite", "fac", "faculte", "iut", "bts", "campus", "cfa",
            "ufr", "iae", "sorbonne", "polytechnique", "maternelle", "primaire"]),
        PlaceKeywordRule(type: .cours, weight: 25, words: ["institut", "formation", "academie", "superieur", "etudes"]),
        PlaceKeywordRule(type: .taf, weight: 40, words: [
            "societe", "sarl", "sas", "sasu", "agence", "bureau", "entreprise", "hopital", "clinique", "usine",
            "entrepot", "atelier", "cabinet", "mairie", "siege", "logistique", "chu", "ehpad", "laboratoire", "garage"]),
        PlaceKeywordRule(type: .courses, weight: 40, words: [
            "magasin", "superette", "supermarche", "hypermarche", "boulangerie", "pharmacie", "epicerie",
            "carrefour", "leclerc", "lidl", "aldi", "auchan", "intermarche", "monoprix", "franprix",
            "boucherie", "tabac", "banque", "marche", "poste", "drive", "pressing", "bricolage"]),
        PlaceKeywordRule(type: .sortie, weight: 30, words: [
            "restaurant", "brasserie", "cafe", "bar", "pizzeria", "cinema", "theatre", "musee"]),
        PlaceKeywordRule(type: .sport, weight: 30, words: [
            "gym", "fitness", "piscine", "stade", "tennis", "crossfit", "musculation"])
    ]

    private static func fold(_ text: String) -> String {
        return text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
    }

    private static func tokenMatches(_ token: String, _ word: String) -> Bool {
        if token == word { return true }
        return word.count >= 5 && token.hasPrefix(word)
    }

    /// Un seul résultat par type : le mot le plus fort trouvé dans le nom.
    fileprivate static func nameHits(_ name: String?) -> [(type: PlaceType, weight: Double, display: String)] {
        guard let name = name, !name.isEmpty else { return [] }
        let rawTokens: [String] = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        var best: [PlaceType: (weight: Double, display: String)] = [:]
        for raw in rawTokens {
            let token: String = fold(raw)
            for rule in keywordRules {
                for word in rule.words where tokenMatches(token, word) {
                    let current: Double = best[rule.type]?.weight ?? 0
                    if rule.weight > current {
                        best[rule.type] = (weight: rule.weight, display: raw.lowercased())
                    }
                }
            }
        }
        var hits: [(type: PlaceType, weight: Double, display: String)] = []
        for type in PlaceType.allCases {
            if let found = best[type] {
                hits.append((type: type, weight: found.weight, display: found.display))
            }
        }
        return hits
    }

    /// Catégorie Plans : type visé, poids et texte. nil si rien d'utile.
    fileprivate static func poiHit(raw: String?, category: PlaceType?) -> (type: PlaceType, weight: Double, text: String)? {
        if let raw = raw?.lowercased(), !raw.isEmpty {
            if raw.contains("university") || raw.contains("school") {
                return (.cours, weightPoiSchool, "Plans indique une école ou une université à cet endroit")
            }
            if raw.contains("library") {
                return (.cours, weightPoiLibrary, "Plans indique une bibliothèque à cet endroit")
            }
            if raw.contains("hospital") {
                return (.taf, weightPoiHospital, "Plans indique un hôpital à cet endroit")
            }
            let errands: [String] = ["store", "foodmarket", "bakery", "pharmacy", "bank", "atm", "postoffice",
                                     "laundry", "gasstation", "evcharger"]
            for word in errands where raw.contains(word) {
                return (.courses, weightPoiErrand, "Plans indique un commerce ou un service à cet endroit")
            }
            let leisure: [String] = ["restaurant", "cafe", "nightlife", "brewery", "winery", "movietheater",
                                     "theater", "museum", "musicvenue"]
            for word in leisure where raw.contains(word) {
                return (.sortie, weightPoiLeisure, "Plans indique un lieu de sortie à cet endroit")
            }
            let sport: [String] = ["fitness", "stadium", "swimming", "tennis"]
            for word in sport where raw.contains(word) {
                return (.sport, weightPoiSport, "Plans indique un lieu de sport à cet endroit")
            }
        }
        // Contexte enregistré avant l'ajout de la catégorie brute : on garde la conversion d'alors.
        guard let category = category else { return nil }
        switch category {
        case .cours: return (.cours, weightPoiSchool, "Plans indique une école ou une université à cet endroit")
        case .courses: return (.courses, weightPoiErrand, "Plans indique un commerce ou un service à cet endroit")
        case .sortie: return (.sortie, weightPoiLeisure, "Plans indique un lieu de sortie à cet endroit")
        case .sport: return (.sport, weightPoiSport, "Plans indique un lieu de sport à cet endroit")
        case .taf, .domicile, .autre: return nil
        }
    }

    /// Précédence : un mot du nom l'emporte sur une catégorie Plans qui dit autre chose (le poids de Plans est divisé par 2).
    fileprivate static func textEvidence(_ tally: inout PlaceKindTally, name: String?, poi: String?, category: PlaceType?) {
        let hits: [(type: PlaceType, weight: Double, display: String)] = nameHits(name)
        for hit in hits {
            tally.add(hit.type, hit.weight, "le nom contient « \(hit.display) »")
        }
        if let found = poiHit(raw: poi, category: category) {
            let disagrees: Bool = hits.contains { (h: (type: PlaceType, weight: Double, display: String)) -> Bool in
                return h.type != found.type && h.weight >= 40
            }
            tally.add(found.type, disagrees ? found.weight / 2 : found.weight, found.text)
        }
    }

    // MARK: Ce que l'utilisateur a déjà dit

    fileprivate static func nearbyEvidence(_ tally: inout PlaceKindTally, hints: [NearbyPlaceHint]) {
        let close: [NearbyPlaceHint] = hints.filter { (h: NearbyPlaceHint) -> Bool in
            return h.distance <= nearbyRadius
        }.sorted { (a: NearbyPlaceHint, b: NearbyPlaceHint) -> Bool in return a.distance < b.distance }
        if let contract = close.first(where: { (h: NearbyPlaceHint) -> Bool in return h.isContractPlace && h.type == .taf }) {
            tally.add(.taf, weightNearbyContract,
                      "ton lieu de contrat « \(contract.name) » est à \(Int(contract.distance.rounded())) m")
        } else if let work = close.first(where: { (h: NearbyPlaceHint) -> Bool in return h.type == .taf }) {
            tally.add(.taf, weightNearbySameKind,
                      "tu as déjà un lieu de travail, « \(work.name) », à \(Int(work.distance.rounded())) m")
        }
        if let school = close.first(where: { (h: NearbyPlaceHint) -> Bool in return h.type == .cours }) {
            tally.add(.cours, weightNearbySameKind,
                      "tu as déjà une école, « \(school.name) », à \(Int(school.distance.rounded())) m")
        }
    }

    /// Ajoute l'effet des corrections passées. Renvoie le type imposé quand l'utilisateur a répondu assez de fois dans le voisinage.
    fileprivate static func lessonEvidence(_ tally: inout PlaceKindTally, signals: PlaceKindSignals, patternKey: String) -> PlaceType? {
        var chosenCount: [PlaceType: Int] = [:]
        var penaltyCount: [PlaceType: Int] = [:]
        var patternCount: [PlaceType: Int] = [:]
        for lesson in signals.lessons {
            let meters: Double = PlaceRules.distanceMeters(latitude1: signals.latitude, longitude1: signals.longitude,
                                                           latitude2: lesson.latitude, longitude2: lesson.longitude)
            var chosenType: PlaceType? = nil
            if let rawChosen = lesson.chosen { chosenType = PlaceType(rawValue: rawChosen) }
            var suggestedType: PlaceType? = nil
            if let rawSuggested = lesson.suggested { suggestedType = PlaceType(rawValue: rawSuggested) }
            if meters <= lessonRadius {
                if let chosen = chosenType {
                    chosenCount[chosen] = (chosenCount[chosen] ?? 0) + 1
                    if let suggested = suggestedType, suggested != chosen {
                        penaltyCount[suggested] = (penaltyCount[suggested] ?? 0) + 1
                    }
                } else if let suggested = suggestedType {
                    penaltyCount[suggested] = (penaltyCount[suggested] ?? 0) + 1
                }
            } else if let chosen = chosenType, let key = lesson.patternKey, key == patternKey {
                patternCount[chosen] = (patternCount[chosen] ?? 0) + 1
            }
        }
        var forced: PlaceType? = nil
        var topCount: Int = 0
        var secondCount: Int = 0
        for type in PlaceType.allCases {
            let count: Int = chosenCount[type] ?? 0
            if count > topCount {
                secondCount = topCount
                topCount = count
                forced = type
            } else if count > secondCount {
                secondCount = count
            }
        }
        let isOverride: Bool = topCount >= lessonOverrideCount && topCount > secondCount
        for type in PlaceType.allCases {
            let count: Int = chosenCount[type] ?? 0
            if count >= 1 && !(isOverride && forced == type) {
                tally.add(type, lessonNudge, "tu m'as déjà dit que c'était \(noun(type)) tout près")
            }
            let penalties: Int = min(2, penaltyCount[type] ?? 0)
            if penalties > 0 {
                tally.add(type, -lessonPenalty * Double(penalties), "tu m'as déjà corrigé ici")
            }
            if (patternCount[type] ?? 0) >= 2 {
                tally.add(type, patternLessonNudge, "tu as déjà classé ainsi des lieux aux horaires pareils")
            }
        }
        if isOverride, let type = forced {
            tally.add(type, 100, "tu m'as déjà répondu \(topCount) fois que c'était \(noun(type)) par ici")
            return type
        }
        return nil
    }

    /// Détecte le désaccord entre le texte (nom, Plans) et les horaires, pour les trois types qui comptent.
    private static func conflictMessage(time: [PlaceType: Double], text: PlaceKindTally, leaning: PlaceType) -> String? {
        let important: [PlaceType] = [.taf, .cours, .courses]
        if !important.contains(leaning) { return nil }
        var textType: PlaceType? = nil
        var textPoints: Double = 0
        for type in important {
            let value: Double = text.points[type] ?? 0
            if value > textPoints { textPoints = value; textType = type }
        }
        var timeType: PlaceType? = nil
        var timePoints: Double = 0
        for type in important {
            let value: Double = time[type] ?? 0
            if value > timePoints { timePoints = value; timeType = type }
        }
        guard let writtenType = textType, let scheduleType = timeType else { return nil }
        if textPoints < 40 || timePoints < 50 || writtenType == scheduleType { return nil }
        return "Le nom ou Plans indique \(noun(writtenType)), mais tes horaires ressemblent plutôt à \(noun(scheduleType))"
    }
}
