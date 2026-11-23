import SwiftUI
import SwiftData

/// Carte Accueil "Pars à HH:MM" / "Pars maintenant" (section 35). N'affiche rien si le module travel_departure
/// n'est pas actif, s'il n'y a pas de créneau avec lieu dans l'horizon, hors fenêtre, ou si une session tourne déjà.
/// `alwaysShown` sert à l'écran Trajet : montre le prochain créneau sans tenir compte de la fenêtre.
struct PartirMaintenantCard: View {
    @Environment(ModuleStore.self) private var modules
    @Query(sort: \PlannedShift.start) private var shifts: [PlannedShift]
    @Query private var places: [Place]
    @Query private var sessions: [WorkSession]

    let alwaysShown: Bool

    private let settingsStore: TravelSettingsStore = TravelSettingsStore.shared

    init(alwaysShown: Bool = false) {
        self.alwaysShown = alwaysShown
    }

    var body: some View {
        Group {
            if modules.isActive("travel_departure") {
                TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                    cardIfAny(now: timeline.date)
                }
            }
        }
    }

    @ViewBuilder
    private func cardIfAny(now: Date) -> some View {
        let settings: TravelSettings = settingsStore.settings
        let running: Bool = sessions.contains(where: { (s: WorkSession) -> Bool in return s.endDate == nil })
        let candidates: [TravelShift] = travelShifts()
        let next: TravelShift? = TravelDepartureRules.nextShift(shifts: candidates, now: now)
        if let shift = next, let place = places.first(where: { (p: Place) -> Bool in return p.uid == shift.placeUID }) {
            let mode: TravelMode = settings.mode(for: place.uid)
            let fallback: TravelEstimate = TravelEstimate(seconds: settings.fallbackMinutes * 60, source: .fallback)
            let departure: Date = TravelDepartureRules.departure(shiftStart: shift.start, travelSeconds: fallback.seconds,
                                                                 marginMinutes: settings.marginMinutes)
            let visible: Bool = alwaysShown
                || (!running && TravelDepartureRules.isInWindow(now: now, shiftStart: shift.start, departure: departure,
                                                                windowMinutes: settings.windowMinutes))
            if visible {
                PartirMaintenantContent(shift: shift, placeName: place.name, placeLatitude: place.latitude,
                                        placeLongitude: place.longitude, placeRadius: place.radius,
                                        mode: mode, now: now, alwaysShown: alwaysShown)
            }
        } else if alwaysShown {
            PLTBanner(kind: .info,
                      title: "Aucun créneau avec un lieu bientôt",
                      message: "Il faut un créneau prévu dans les \(TravelDepartureRules.horizonHours) prochaines heures, rattaché à un lieu.")
        }
    }

    private func travelShifts() -> [TravelShift] {
        var result: [TravelShift] = []
        for s in shifts {
            guard let placeUID = s.placeUID else { continue }
            if s.end <= s.start { continue }
            result.append(TravelShift(id: s.uid, start: s.start, end: s.end, placeUID: placeUID, activity: s.activity))
        }
        return result
    }
}

/// Résultat d'un calcul de trajet gardé en mémoire (cache de la carte).
private struct ComputedTravel: Equatable {
    let estimate: TravelEstimate
    let distanceMeters: Double?
    let fetchedAt: Date
}

/// Contenu de la carte : position, MKDirections (une requête, jamais de polling), repli, notification locale.
private struct PartirMaintenantContent: View {
    @Environment(\.palette) private var palette

    let shift: TravelShift
    let placeName: String
    let placeLatitude: Double
    let placeLongitude: Double
    let placeRadius: Double
    let mode: TravelMode
    let now: Date
    let alwaysShown: Bool

    private let settingsStore: TravelSettingsStore = TravelSettingsStore.shared

    @StateObject private var locator: LocationOnce = LocationOnce()
    @State private var computed: ComputedTravel? = nil
    @State private var isRefreshing: Bool = false

    private var calendar: Calendar { return Calendar.current }

    var body: some View {
        let settings: TravelSettings = settingsStore.settings
        let estimate: TravelEstimate = computed?.estimate
            ?? TravelEstimate(seconds: settings.fallbackMinutes * 60, source: .fallback)
        let departure: Date = TravelDepartureRules.departure(shiftStart: shift.start, travelSeconds: estimate.seconds,
                                                             marginMinutes: settings.marginMinutes)
        let onSite: Bool = TravelDepartureRules.isOnSite(distanceMeters: computed?.distanceMeters, radius: placeRadius)
        let late: Int = TravelDepartureRules.lateMinutes(now: now, travelSeconds: estimate.seconds, shiftStart: shift.start)
        let leaveNow: Bool = now >= departure
        return Group {
            if onSite {
                if alwaysShown {
                    PLTBanner(kind: .info, title: "Tu es déjà sur place", message: "Rien n'est envoyé.")
                }
            } else {
                card(estimate: estimate, departure: departure, late: late, leaveNow: leaveNow, margin: settings.marginMinutes)
            }
        }
        .task(id: shift.id) {
            await refresh(force: false)
        }
    }

    private func card(estimate: TravelEstimate, departure: Date, late: Int, leaveNow: Bool, margin: Int) -> some View {
        let title: String = leaveNow ? "Pars maintenant" : TravelDepartureRules.headline(departure: departure, calendar: calendar)
        let noun: String = shift.activity == .education ? "ton cours" : "ton poste"
        let arrival: Date = TravelDepartureRules.arrival(now: now, travelSeconds: estimate.seconds)
        return PLTCard(isNow: leaveNow) {
            HStack(spacing: Theme.Spacing.s) {
                PLTChip(mode.title, kind: .neutral)
                PLTChip(estimate.source.title, kind: .neutral)
            }
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Text("Tu prends \(noun) à \(Formatting.clock(shift.start, calendar: calendar)), \(placeName). "
                 + "Trajet : \(TravelDepartureRules.minutesCeil(estimate.seconds)) min, marge de \(margin) min.")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(palette.textSecondary)
            if late > 0 && leaveNow {
                Text(TravelDepartureRules.lateText(arrival: arrival, calendar: calendar))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.danger)
            }
            Text("Estimation, sans garantie : le trafic peut changer.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            Button {
                Task { await refresh(force: true) }
            } label: {
                Label(isRefreshing ? "Calcul en cours" : "Recalculer", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.pltSecondary)
            .disabled(isRefreshing)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Calcul

    private func locationIsFinished() -> Bool {
        switch locator.state {
        case .idle, .locating:
            return false
        case .denied, .failed, .located:
            return true
        }
    }

    @MainActor
    private func refresh(force: Bool) async {
        let started: Date = Date()
        if !force && !TravelDepartureRules.shouldRefresh(lastFetch: computed?.fetchedAt, now: started) { return }
        isRefreshing = true
        locator.request()
        var attempts: Int = 0
        while !locationIsFinished() && attempts < 20 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            attempts += 1
        }
        var meters: Double? = nil
        var mapKitSeconds: Int? = nil
        if case .located(let lat, let lon) = locator.state {
            let distance: Double = TravelDepartureRules.straightLineMeters(fromLatitude: lat, fromLongitude: lon,
                                                                           toLatitude: placeLatitude, toLongitude: placeLongitude)
            meters = distance
            if !TravelDepartureRules.isOnSite(distanceMeters: distance, radius: placeRadius) {
                mapKitSeconds = await TravelETAService.expectedTravelSeconds(fromLatitude: lat, fromLongitude: lon,
                                                                             toLatitude: placeLatitude, toLongitude: placeLongitude,
                                                                             mode: mode)
            }
        }
        let settings: TravelSettings = settingsStore.settings
        let estimate: TravelEstimate = TravelDepartureRules.resolve(mapKitSeconds: mapKitSeconds, distanceMeters: meters,
                                                                    mode: mode, fallbackMinutes: settings.fallbackMinutes)
        computed = ComputedTravel(estimate: estimate, distanceMeters: meters, fetchedAt: Date())
        isRefreshing = false
        scheduleNotification(estimate: estimate, settings: settings,
                             onSite: TravelDepartureRules.isOnSite(distanceMeters: meters, radius: placeRadius))
    }

    private func scheduleNotification(estimate: TravelEstimate, settings: TravelSettings, onSite: Bool) {
        let identifier: String = JournalNotifier.travelIdentifierPrefix + shift.id.uuidString
        if !settings.notifies(for: shift.placeUID) || onSite {
            JournalNotifier.cancel(identifier: identifier)
            return
        }
        let departure: Date = TravelDepartureRules.departure(shiftStart: shift.start, travelSeconds: estimate.seconds,
                                                             marginMinutes: settings.marginMinutes)
        guard let fireDate = TravelDepartureRules.notificationDate(departure: departure, now: Date()) else {
            JournalNotifier.cancel(identifier: identifier)
            return
        }
        let body: String = TravelDepartureRules.notificationBody(departure: departure, travelSeconds: estimate.seconds,
                                                                 shiftStart: shift.start, activity: shift.activity,
                                                                 calendar: calendar)
        JournalNotifier.schedule(identifier: identifier, title: "Pars maintenant", body: body, at: fireDate)
    }
}
