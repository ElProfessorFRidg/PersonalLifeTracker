import SwiftUI
import SwiftData
import MapKit

/// Écran `lieu` (détail). Poussé dans la NavigationStack de l'onglet : pas de NavigationStack propre.
struct LieuDetailView: View {
    let place: Place

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \Place.name) private var allPlaces: [Place]

    @State private var nameDraft: String
    @State private var camera: MapCameraPosition
    @State private var confirmsDelete: Bool = false
    @State private var isDeleted: Bool = false

    init(place: Place) {
        self.place = place
        _nameDraft = State(initialValue: place.name)
        _camera = State(initialValue: LieuDetailView.cameraPosition(for: place))
    }

    private static func cameraPosition(for place: Place) -> MapCameraPosition {
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let span: Double = max(place.radius * 4, 300)
        return .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: span, longitudinalMeters: span))
    }

    private var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    private var otherNames: [String] {
        return allPlaces.filter { $0.id != place.id }.map { $0.name }
    }

    private var nameIssue: PlaceRules.NameIssue? {
        return PlaceRules.nameIssue(nameDraft, existingNames: otherNames)
    }

    private var overlapNames: [String] {
        let me = PlaceRules.Zone(name: place.name, latitude: place.latitude, longitude: place.longitude, radius: place.radius)
        let others: [PlaceRules.Zone] = allPlaces.filter { $0.id != place.id }.map {
            PlaceRules.Zone(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radius: $0.radius)
        }
        return PlaceRules.overlappingNames(me, among: others)
    }

    private var typeBinding: Binding<PlaceType> {
        return Binding<PlaceType>(
            get: { place.type },
            set: { newValue in
                place.type = newValue
                if newValue != .courses { place.alsoWorksHere = false }
                try? context.save()
            })
    }

    private var radiusBinding: Binding<Double> {
        return Binding<Double>(
            get: { PlaceRules.clampRadius(place.radius) },
            set: { newValue in
                place.radius = PlaceRules.clampRadius(newValue)
                camera = LieuDetailView.cameraPosition(for: place)
            })
    }

    private var alsoWorksBinding: Binding<Bool> {
        return Binding<Bool>(
            get: { place.alsoWorksHere },
            set: { newValue in
                place.alsoWorksHere = newValue
                try? context.save()
            })
    }

    private var sortedSessions: [WorkSession] {
        return place.sessions.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        Group {
            if isDeleted {
                Color.clear
            } else {
                content
            }
        }
    }

    private var content: some View {
        PLTScreen(title: place.name) {
            mapThumbnail
            if let warning = PlaceRules.overlapWarning(names: overlapNames) {
                PLTBanner(kind: .warning, title: "Zones qui se touchent", message: warning)
            }
            settingsSection
            statsSection
            sessionsSection
            deleteSection
        }
        .confirmationDialog("Supprimer ce lieu ?",
                            isPresented: $confirmsDelete,
                            titleVisibility: .visible) {
            Button("Supprimer ce lieu", role: .destructive) { deletePlace() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes sessions déjà notées restent dans l'historique, juste sans ce lieu.")
        }
    }

    // MARK: Carte

    private var mapThumbnail: some View {
        Map(position: $camera, interactionModes: []) {
            MapCircle(center: coordinate, radius: place.radius)
                .foregroundStyle(place.type.tone.soft(palette).opacity(0.6))
                .stroke(place.type.tone.color(palette), lineWidth: 2)
            Marker(place.name, systemImage: place.type.symbolName, coordinate: coordinate)
                .tint(place.type.tone.color(palette))
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu de la carte : \(place.name), zone de \(Int(place.radius.rounded())) mètres")
    }

    // MARK: Réglage

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Réglage")
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Nom")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                TextField("Nom du lieu", text: $nameDraft)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minHeight: 44)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    .accessibilityLabel("Modifier le lieu : nom")
                    .onChange(of: nameDraft) {
                        applyName()
                    }
                if let issue = nameIssue {
                    Text(issue.message)
                        .font(.footnote)
                        .foregroundStyle(palette.danger)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Type")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                Picker("Type", selection: typeBinding) {
                    ForEach(PlaceType.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                if place.type == .courses {
                    Text("Les courses sont notées mais jamais comptées dans tes heures.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                    Toggle("J'y travaille aussi", isOn: alsoWorksBinding)
                        .frame(minHeight: 44)
                        .tint(palette.accent)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text("Rayon")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text("\(Int(place.radius.rounded())) m")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                }
                Slider(value: radiusBinding, in: PlaceRules.minRadius...PlaceRules.maxRadius, step: 10) { editing in
                    if !editing { try? context.save() }
                }
                .frame(minHeight: 44)
                .accessibilityLabel("Rayon")
                .accessibilityValue("\(Int(place.radius.rounded())) mètres")
                Text("La zone autour de l'épingle")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func applyName() {
        if PlaceRules.nameIssue(nameDraft, existingNames: otherNames) == nil {
            place.name = PlaceRules.cleanedName(nameDraft)
            try? context.save()
        }
    }

    // MARK: Stats

    private var monthStats: PlaceStats.Month {
        let visits: [PlaceVisitInput] = place.sessions.map {
            PlaceVisitInput(start: $0.startDate, end: $0.endDate, chosenStart: $0.chosenStart, chosenEnd: $0.chosenEnd)
        }
        return PlaceStats.month(visits: visits, now: Date(), base: settings.calculationBase, calendar: Calendar.current)
    }

    private var statsSection: some View {
        let stats: PlaceStats.Month = monthStats
        let last: Date? = place.sessions.map { $0.startDate }.max()
        let lastText: String = PlaceFormat.lastVisit(last, now: Date(), calendar: Calendar.current)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce mois-ci")
            HStack(spacing: Theme.Spacing.s) {
                if place.type == .courses {
                    StatTile(label: "Visites", value: "\(stats.visits)", note: lastText, tone: place.type.tone)
                    StatTile(label: "Temps passé", value: Formatting.duration(seconds: stats.seconds),
                             note: "Pas compté dans tes heures", tone: place.type.tone)
                } else {
                    StatTile(label: "Heures", value: Formatting.duration(seconds: stats.seconds),
                             note: stats.hasProvisional ? "Provisoire, il reste un doute à régler" : settings.calculationBase.title,
                             tone: place.type.tone)
                    StatTile(label: "Visites", value: "\(stats.visits)", note: lastText, tone: place.type.tone)
                }
            }
        }
    }

    // MARK: Sessions

    private var sessionsSection: some View {
        let recent: [WorkSession] = Array(sortedSessions.prefix(5))
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Dernières sessions")
            if recent.isEmpty {
                PLTCard {
                    Text("Pas encore de session ici. Dès que t'y arrives, je note tout.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(recent) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            PLTRow(title: PlaceFormat.dayLabel(session.startDate, now: Date(), calendar: Calendar.current),
                                   subtitle: sessionSubtitle(session),
                                   value: sessionValue(session),
                                   showsChevron: true,
                                   showsSeparator: session.id != recent.last?.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sessionSubtitle(_ session: WorkSession) -> String {
        let cal: Calendar = Calendar.current
        let start: String = Formatting.clock(session.startDate, calendar: cal)
        let end: String = session.endDate.map { Formatting.clock($0, calendar: cal) } ?? "en cours"
        let suffix: String = place.type == .courses ? ", pas compté" : ""
        return "\(start) à \(end)\(suffix)"
    }

    private func sessionValue(_ session: WorkSession) -> String {
        return Formatting.duration(seconds: session.exactSeconds(now: Date()))
    }

    // MARK: Suppression

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button("Supprimer ce lieu") { confirmsDelete = true }
                .buttonStyle(.pltDestructive)
            Text("Tes sessions déjà notées restent dans l'historique.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func deletePlace() {
        let placeCopy: ExportedPlace = UndoSnapshots.exportedPlace(place)
        let sessionCopies: [ExportedSession] = place.sessions.map { UndoSnapshots.exportedSession($0) }
        let ctx: ModelContext = context
        let placeName: String = place.name
        isDeleted = true
        context.delete(place)
        try? context.save()
        undoCenter?.register(message: "Lieu supprimé : \(placeName)") {
            try? UndoSnapshots.restorePlace(placeCopy, sessions: sessionCopies, context: ctx)
        }
        dismiss()
    }
}
