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
    @Environment(ModuleStore.self) private var modules
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \Place.name) private var allPlaces: [Place]
    @Query private var visitEvents: [DetectionEvent]

    @State private var nameDraft: String
    @State private var camera: MapCameraPosition
    @State private var confirmsDelete: Bool = false
    @State private var isDeleted: Bool = false
    @State private var showsEdit: Bool = false

    init(place: Place) {
        self.place = place
        _nameDraft = State(initialValue: place.name)
        _camera = State(initialValue: LieuDetailView.cameraPosition(for: place))
        let uid: UUID? = place.uid
        let arrivalKind = DetectionEventKind.arrivalConfirmed.rawValue
        let visitKind = DetectionEventKind.visitNoted.rawValue
        _visitEvents = Query(filter: #Predicate<DetectionEvent> {
            $0.placeUID == uid && ($0.kindRaw == visitKind || $0.kindRaw == arrivalKind)
        }, sort: [SortDescriptor(\DetectionEvent.date, order: .reverse)])
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
            if !place.address.isEmpty {
                Label(place.address, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)
            }
            if let warning = PlaceRules.overlapWarning(names: overlapNames) {
                PLTBanner(kind: .warning, title: "Zones qui se touchent", message: warning)
            }
            settingsSection
            if modules.isActive("place_calibration") {
                CalibrationCard(place: place)
            }
            statsSection
            if place.type != .taf && place.type != .cours {
                loggedVisitsSection
            }
            sessionsSection
            deleteSection
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Modifier le lieu")
            }
        }
        .sheet(isPresented: $showsEdit) {
            NavigationStack {
                PLTScreen(title: "Modifier le lieu") {
                    editForm
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { showsEdit = false }
                    }
                }
            }
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
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu de la carte : \(place.name), zone de \(Int(place.radius.rounded())) mètres")
    }

    // MARK: Réglage

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Réglage")
            PLTListGroup {
                settingRow(title: "Type", subtitle: nil, showsSeparator: true) {
                    PLTChip(place.type.title, kind: placeChipKind)
                }
                if place.type == .courses {
                    settingRow(title: "J'y travaille aussi", subtitle: nil, showsSeparator: true) {
                        Text(place.alsoWorksHere ? "Oui" : "Non")
                            .font(.body)
                            .foregroundStyle(palette.textPrimary)
                    }
                }
                settingRow(title: "Rayon", subtitle: "La zone autour de l'épingle", showsSeparator: false) {
                    Text("\(Int(place.radius.rounded())) m")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                }
            }
            Text(place.type.usageDescription(alsoWorksHere: place.alsoWorksHere))
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var placeChipKind: PLTChipKind {
        return place.type.defaultActivity.chipKind
    }

    private func settingRow<Trailing: View>(title: String,
                                            subtitle: String?,
                                            showsSeparator: Bool,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        let trailingView: Trailing = trailing()
        return HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            trailingView
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Formulaire de modification (nom, type, rayon), présenté dans la feuille « Modifier le lieu ».
    private var editForm: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
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
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                if place.type == .courses {
                    Toggle("J'y travaille aussi", isOn: alsoWorksBinding)
                        .frame(minHeight: 44)
                        .tint(palette.accent)
                }
                Text(place.type.usageDescription(alsoWorksHere: place.alsoWorksHere))
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
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
                if place.type != .taf && place.type != .cours {
                    StatTile(label: "Passages GPS", value: "\(loggedVisitsThisMonth.count)",
                             note: PlaceFormat.lastVisit(loggedVisits.first?.date, now: Date(), calendar: .current),
                             tone: place.type.tone)
                    StatTile(label: "Temps en session", value: Formatting.duration(seconds: stats.seconds),
                             note: "Sessions enregistrées", tone: place.type.tone)
                } else {
                    StatTile(label: "Heures", value: Formatting.duration(seconds: stats.seconds),
                             note: stats.hasProvisional ? "Provisoire, il reste un doute à régler" : settings.calculationBase.title,
                             tone: place.type.tone)
                    StatTile(label: "Visites", value: "\(stats.visits)", note: lastText, tone: .neutral)
                }
            }
        }
    }

    private var loggedVisits: [DetectionEvent] {
        visitEvents.filter {
            if $0.kind == .visitNoted { return true }
            // Older builds distinguished arrivals and later classifications by their journal text.
            return $0.detail.hasPrefix("Visite notée") || $0.detail.hasPrefix("Lieu de courses : visite notée")
        }
    }

    private var loggedVisitsThisMonth: [DetectionEvent] {
        guard let month = Calendar.current.dateInterval(of: .month, for: Date()) else { return [] }
        return loggedVisits.filter { $0.date >= month.start && $0.date < month.end }
    }

    private var loggedVisitsSection: some View {
        let recent = loggedVisits.prefix(5)

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Derniers passages détectés")
            if recent.isEmpty {
                PLTCard {
                    Text("Aucun passage détecté pour l'instant.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(recent) { visit in
                        PLTRow(symbol: place.type.symbolName,
                               tone: place.type.tone,
                               title: PlaceFormat.dayLabel(visit.date, now: Date(), calendar: .current),
                               value: Formatting.clock(visit.date, calendar: .current),
                               showsSeparator: visit.id != recent.last?.id)
                    }
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
                    Text("Pas encore de session enregistrée ici.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(recent) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            PLTRow(symbol: place.type.symbolName,
                                   tone: place.type.tone,
                                   title: PlaceFormat.dayLabel(session.startDate, now: Date(), calendar: Calendar.current),
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
        let suffix: String = (place.type != .taf && place.type != .cours) ? ", pas compté" : ""
        return "\(start) à \(end)\(suffix)"
    }

    private func sessionValue(_ session: WorkSession) -> String {
        return Formatting.duration(seconds: session.exactSeconds(now: Date()))
    }

    // MARK: Suppression

    private var deleteSection: some View {
        PLTListGroup {
            PLTRow(symbol: "trash",
                   tone: .danger,
                   title: "Supprimer ce lieu",
                   subtitle: "Tes sessions déjà notées restent dans l'historique",
                   showsSeparator: false,
                   action: { confirmsDelete = true })
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
