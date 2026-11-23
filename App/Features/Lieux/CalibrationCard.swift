import SwiftUI
import SwiftData
import MapKit

/// Carte de calibration d'un lieu (section 130). Rien n'est affiché sans proposition.
/// À n'insérer que si `modules.isActive("place_calibration")`. Rien n'est appliqué sans appui sur "Appliquer".
struct CalibrationCard: View {
    let place: Place

    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Environment(GeofenceService.self) private var geofence: GeofenceService?
    @Query private var samples: [PlaceSample]

    @State private var dismissedSignatures: [String] = []

    init(place: Place) {
        self.place = place
        let uid: UUID = place.uid
        _samples = Query(filter: #Predicate<PlaceSample> { $0.placeUID == uid },
                         sort: [SortDescriptor(\PlaceSample.date, order: .reverse)])
    }

    private var currentZone: CalibrationZone {
        return CalibrationZone(latitude: place.latitude, longitude: place.longitude, radius: place.radius)
    }

    private var suggestion: CalibrationSuggestion? {
        let found: CalibrationSuggestion? = PlaceCalibrator.suggest(
            current: currentZone,
            samples: PlaceSampleRecorder.calibrationSamples(samples))
        guard let s = found else { return nil }
        if dismissedSignatures.contains(s.signature) { return nil }
        if CalibrationDismissals.isDismissed(signature: s.signature, placeUID: place.uid) { return nil }
        return s
    }

    var body: some View {
        if let s = suggestion {
            card(for: s)
        }
    }

    private func card(for s: CalibrationSuggestion) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ajuster la zone")
            PLTCard {
                Text(s.explanation)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                preview(for: s)
                zoneRow(title: "Actuelle", zone: s.current)
                zoneRow(title: "Proposée", zone: s.proposed)
                Text("Rien ne change sans ton accord. Tu pourras annuler juste après.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                Button("Appliquer") { apply(s) }
                    .buttonStyle(.pltPrimary)
                    .accessibilityLabel("Appliquer la zone proposée")
                Button("Ignorer") { ignore(s) }
                    .buttonStyle(.pltSecondary)
                    .accessibilityLabel("Ignorer cette proposition")
            }
        }
    }

    private func zoneRow(title: String, zone: CalibrationZone) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Spacer()
            Text("Rayon \(Int(zone.radius.rounded())) m")
                .font(.body.monospacedDigit())
                .foregroundStyle(palette.textPrimary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zone \(title.lowercased()) : rayon \(Int(zone.radius.rounded())) mètres")
    }

    private func preview(for s: CalibrationSuggestion) -> some View {
        let currentCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: s.current.latitude,
                                                                          longitude: s.current.longitude)
        let proposedCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: s.proposed.latitude,
                                                                           longitude: s.proposed.longitude)
        let span: Double = max(max(s.current.radius, s.proposed.radius) * 4 + s.centerShiftMeters * 2, 300)
        let position: MapCameraPosition = .region(MKCoordinateRegion(center: proposedCenter,
                                                                     latitudinalMeters: span,
                                                                     longitudinalMeters: span))
        return Map(initialPosition: position, interactionModes: []) {
            MapCircle(center: currentCenter, radius: s.current.radius)
                .foregroundStyle(PLTTone.neutral.soft(palette).opacity(0.5))
                .stroke(PLTTone.neutral.color(palette), lineWidth: 2)
            MapCircle(center: proposedCenter, radius: s.proposed.radius)
                .foregroundStyle(PLTTone.accent.soft(palette).opacity(0.6))
                .stroke(PLTTone.accent.color(palette), lineWidth: 2)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu de la carte : zone actuelle de \(Int(s.current.radius.rounded())) mètres et zone proposée de \(Int(s.proposed.radius.rounded())) mètres")
    }

    private func apply(_ s: CalibrationSuggestion) {
        let before: CalibrationZone = currentZone
        let target: Place = place
        let ctx: ModelContext = context
        let service: GeofenceService? = geofence
        let name: String = place.name
        CalibrationCard.write(s.proposed, to: target, context: ctx, geofence: service)
        undoCenter?.register(message: "Zone ajustée : \(name)") {
            CalibrationCard.write(before, to: target, context: ctx, geofence: service)
        }
    }

    private static func write(_ zone: CalibrationZone, to target: Place, context ctx: ModelContext, geofence service: GeofenceService?) {
        target.latitude = zone.latitude
        target.longitude = zone.longitude
        target.radius = PlaceRules.clampRadius(zone.radius)
        try? ctx.save()
        service?.refreshMonitoredPlaces()
    }

    private func ignore(_ s: CalibrationSuggestion) {
        CalibrationDismissals.dismiss(signature: s.signature, placeUID: place.uid)
        dismissedSignatures.append(s.signature)
    }
}
