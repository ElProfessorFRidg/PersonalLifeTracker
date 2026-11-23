import SwiftUI
import SwiftData
import UIKit

struct LieuxView: View {
    @Environment(GeofenceService.self) private var geofence
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var contracts: [Contract]
    @AppStorage("plt.discovery.automaticMapsLookup") private var automaticMapsLookup = false
    @State private var showsAdd = false
    @State private var showsMerge = false
    @State private var ignoredAuditIDs: Set<String> = PlaceAuditIgnore.load()
    @State private var configureCurrentWorkplace = false
    @State private var permissions = PermissionRequester()
    @State private var isRequestingLocation = false
    @State private var locationDenied = false
    @State private var selectedSuggestion: DiscoveredPlace?

    var body: some View {
        let discovery = geofence.discovery
        let discoveryActive = modules.isActive("place_discovery")
        let plan: PlaceSuggestionPlan = discoveryActive ? discovery.suggestionPlan(excluding: places) : PlaceSuggestionPlan()
        let suggestions: [DiscoveredPlace] = plan.suggestions.map { (i: PlaceSuggestionItem) -> DiscoveredPlace in return i.suggestion }
        let lookupIDs = automaticMapsLookup ? suggestions.map(\.id).sorted { $0.uuidString < $1.uuidString } : []

        PLTScreen(title: "Lieux", hidesNavigationBar: true) {
            PLTRootHeader(eyebrow: headerEyebrow, title: "Lieux") {
                PLTIconButton(systemName: "plus", label: "Ajouter un lieu") {
                    configureCurrentWorkplace = false
                    showsAdd = true
                }
            }
            if locationDenied {
                PLTBanner(kind: .error,
                          title: "Localisation désactivée",
                          message: "Réactive la localisation pour détecter tes arrivées dans les lieux enregistrés et trouver de nouveaux lieux.",
                          actionTitle: "Ouvrir les réglages iOS",
                          action: openSettings)
            }
            if !auditProblems.isEmpty {
                auditBanner(auditProblems)
            }
            savedPlacesSection
            if !places.isEmpty {
                howItCountsSection
            }
            if !places.contains(where: { $0.type == .taf || ($0.type == .courses && $0.alsoWorksHere) }) {
                PLTBanner(kind: .info, title: "Configure ton lieu de travail",
                          message: "Si tu y es, utilise ta position et vérifie l’épingle. Tu peux l’enregistrer dès ton premier service.",
                          actionTitle: "Enregistrer mon travail ici") {
                    configureCurrentWorkplace = true
                    showsAdd = true
                }
            }
            if discoveryActive {
                discoverySection(suggestions, enlargements: plan.enlargements)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: suggestions.map(\.id))
        .sheet(isPresented: $showsAdd) {
            LieuAjoutView(locateOnOpen: configureCurrentWorkplace, initialType: configureCurrentWorkplace ? .taf : nil)
        }
        .sheet(isPresented: $showsMerge) {
            LieuFusionView()
        }
        .sheet(item: $selectedSuggestion) { candidate in
            DiscoveredPlaceCard(candidate: candidate, discovery: discovery, contractPlaceUIDs: contractPlaceUIDs)
        }
        .task(id: lookupIDs) {
            guard automaticMapsLookup else { return }
            let pendingLookups = suggestions.filter { $0.context == nil }.prefix(5)
            for candidate in pendingLookups {
                guard !Task.isCancelled else { return }
                await discovery.enrich(candidate)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                locationDenied = LocationOnce.isDenied()
                discovery.refresh()
            }
        }
    }

    private var auditProblems: [PlaceAuditProblem] {
        let now: Date = Date()
        let calendar: Calendar = Calendar.current
        let snapshots: [PlaceSnapshot] = places.map { (p: Place) -> PlaceSnapshot in return p.snapshot }
        let candidates: [DiscoveredPlace] = modules.isActive("place_discovery") ? geofence.discovery.candidates : []
        let found: [PlaceAuditProblem] = PlaceSuggestionAudit.audit(
            places: snapshots, candidates: candidates, now: now, calendar: calendar,
            learnedDistance: geofence.discovery.kindStore.memory.learnedMergeDistance,
            leaning: { (c: DiscoveredPlace) -> PlaceType? in
                return PlaceKindClassifier.leaning(of: c, now: now, calendar: calendar)
            })
        return found.filter { (p: PlaceAuditProblem) -> Bool in return !ignoredAuditIDs.contains(p.id) }
    }

    /// Bandeau compact : le problème le plus important, un bouton pour le corriger, un pour l'ignorer.
    private func auditBanner(_ problems: [PlaceAuditProblem]) -> some View {
        let first: PlaceAuditProblem? = problems.first
        let others: Int = max(0, problems.count - 1)
        return PLTCard {
            Label(problems.count == 1 ? "À vérifier" : "À vérifier (\(problems.count))", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(palette.warning)
                .accessibilityAddTraits(.isHeader)
            if let problem = first {
                Text(problem.message)
                    .font(.subheadline)
                if others > 0 {
                    Text(others == 1 ? "Et 1 autre point ensuite." : "Et \(others) autres points ensuite.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
                Button(problem.fixTitle) {
                    PlaceFixActions.apply(problem.fix, context: context, undo: undoCenter, geofence: geofence)
                }
                .buttonStyle(.pltPrimary)
                Button("Ignorer ce point") {
                    ignoredAuditIDs.insert(problem.id)
                    PlaceAuditIgnore.save(ignoredAuditIDs)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private var contractPlaceUIDs: Set<UUID> {
        var uids: Set<UUID> = []
        for contract in contracts { for uid in contract.placeUIDs { uids.insert(uid) } }
        return uids
    }

    private func discoverySection(_ suggestions: [DiscoveredPlace], enlargements: [PlaceEnlargeProposal]) -> some View {
        let discovery = geofence.discovery

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Lieux à vérifier")
            if let error = discovery.error {
                PLTBanner(kind: .error, title: "Découverte des lieux", message: error)
            }
            if discovery.needsPermissionRequest {
                PLTBanner(kind: .info,
                          title: "Active la découverte de lieux",
                          message: "Autorise la localisation pour repérer tes arrêts suffisamment longs et te les proposer ici.",
                          actionTitle: isRequestingLocation ? nil : "Autoriser la localisation",
                          action: isRequestingLocation ? nil : requestLocation)
            } else if !locationDenied && !discovery.canMonitorVisits {
                PLTBanner(kind: .warning,
                          title: "Découverte en pause",
                          message: "Choisis « Toujours » dans Réglages iOS > Life Tracker > Localisation. La découverte pourra reprendre lorsque l'app est en arrière-plan.",
                          actionTitle: "Ouvrir les réglages iOS",
                          action: openSettings)
            } else if !locationDenied && discovery.canMonitorVisits && !discovery.hasPreciseLocation {
                PLTBanner(kind: .warning,
                          title: "Position approximative",
                          message: "Active « Position exacte » pour aider Life Tracker à distinguer les lieux proches.",
                          actionTitle: "Ouvrir les réglages iOS",
                          action: openSettings)
            }

            PLTCard {
                Toggle("Identifier les lieux avec Plans", isOn: $automaticMapsLookup)
                    .tint(palette.accent)
                    .frame(minHeight: 44)
                Text("Plans reçoit la position des arrêts à vérifier pour rechercher une adresse ou un établissement proche.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            if discovery.isMonitoring && discovery.hasRecentArrivalAwaitingDeparture() {
                PLTBanner(kind: .info, title: "Arrivée reçue",
                          message: "iOS a transmis une arrivée. La durée sera disponible après réception du départ.")
            }

            ForEach(enlargements, id: \.shape.placeID) { proposal in
                enlargeCard(proposal)
            }

            if suggestions.isEmpty {
                if discovery.isMonitoring && enlargements.isEmpty {
                    PLTCard {
                        Label("Aucun nouveau lieu à vérifier", systemImage: "location.magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                        Text("Tes arrêts assez longs ou répétés apparaîtront ici. iOS peut les transmettre avec du retard.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            } else {
                Text("Ouvre un lieu pour vérifier l'adresse, les passages repérés et l'activité proposée.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)

                PLTListGroup {
                    ForEach(suggestions) { candidate in
                        suggestionRow(candidate, lastID: suggestions.last?.id)
                    }
                }
            }

            if discovery.hasIgnoredSuggestions(excluding: places) {
                Button("Revoir les lieux ignorés") {
                    discovery.restoreSuggestions()
                }
                .font(.subheadline)
                .frame(minHeight: 44)
            }
        }
    }

    private func suggestionRow(_ candidate: DiscoveredPlace, lastID: UUID?) -> some View {
        let discovery = geofence.discovery
        let decision: PlaceKindDecision = discovery.identification(for: candidate, places: places,
                                                                   contractPlaceUIDs: contractPlaceUIDs)
        let type: PlaceType? = decision.verdict == .confident ? decision.leaning : nil
        let count = discovery.visitCount(for: candidate)
        let visits = count == 1 ? "1 passage" : "\(count) passages"
        let lastDate = candidate.arrivals.max()
        let recentVisit = lastDate.map { date in
            "\(PlaceFormat.dayLabel(date, now: Date(), calendar: .current)) à \(Formatting.clock(date, calendar: .current))"
        }
        let title = candidate.context?.name ?? candidate.context?.address ?? recentVisit ?? "Arrêt repéré"
        let address = candidate.context?.name == nil ? nil : candidate.context?.address
        let guess: String = type.map { "\($0.title) probable" } ?? "À préciser"
        let buildings: String? = (candidate.mergedIDs?.count ?? 0) > 1 ? "\(candidate.mergedIDs?.count ?? 0) bâtiments réunis" : nil
        let subtitle = [address, guess, buildings, visits]
            .compactMap { $0 }
            .joined(separator: " · ")

        return PLTRow(symbol: type?.symbolName ?? "questionmark.circle",
                      tone: type?.tone ?? .accent,
                      title: title,
                      subtitle: subtitle,
                      showsChevron: true,
                      showsSeparator: candidate.id != lastID,
                      action: { selectedSuggestion = candidate })
    }

    private func enlargeCard(_ proposal: PlaceEnlargeProposal) -> some View {
        let shape: PlaceEnlargeShape = proposal.shape
        return PLTCard {
            Label("Agrandir « \(shape.placeName) » ?", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.headline)
            Text("Un arrêt récurrent touche déjà ce lieu. Plutôt que d'ajouter un doublon, j'étends sa zone à \(Int(shape.radius.rounded())) m.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Button("Agrandir ce lieu") { applyEnlargement(proposal) }
                .buttonStyle(.pltPrimary)
            Button("Ne pas agrandir") { geofence.discovery.markHandled(proposal.memberIDs) }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func applyEnlargement(_ proposal: PlaceEnlargeProposal) {
        let shape: PlaceEnlargeShape = proposal.shape
        guard let place = places.first(where: { $0.uid == shape.placeID }) else { return }
        let before: (latitude: Double, longitude: Double, radius: Double) = (place.latitude, place.longitude, place.radius)
        let uid: UUID = place.uid
        let ctx: ModelContext = context
        place.latitude = shape.latitude
        place.longitude = shape.longitude
        place.radius = PlaceRules.clampRadius(shape.radius)
        try? context.save()
        geofence.discovery.markHandled(proposal.memberIDs)
        geofence.refreshMonitoredPlaces()
        let service: GeofenceService = geofence
        undoCenter?.register(message: "Lieu agrandi : \(shape.placeName)") {
            let all: [Place] = (try? ctx.fetch(FetchDescriptor<Place>())) ?? []
            if let found = all.first(where: { $0.uid == uid }) {
                found.latitude = before.latitude
                found.longitude = before.longitude
                found.radius = before.radius
                try? ctx.save()
                Task { @MainActor in service.refreshMonitoredPlaces() }
            }
        }
    }

    private var headerEyebrow: String {
        if places.isEmpty { return "Aucun lieu" }
        return places.count == 1 ? "1 lieu" : "\(places.count) lieux"
    }

    private var savedPlacesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if places.isEmpty {
                PLTCard {
                    PLTEmptyState(symbol: "mappin.and.ellipse",
                                  title: "Aucun lieu pour l'instant.",
                                  message: "Ajoute ton taf ou ta fac. Dès que t'y es, je note tes heures tout seul. Tout reste sur ton tel.",
                                  actionTitle: "Ajouter un lieu",
                                  action: {
                                      configureCurrentWorkplace = false
                                      showsAdd = true
                                  })
                }
            } else {
                PLTSectionHeader(title: "Tes lieux")
                PLTListGroup {
                    ForEach(places) { place in
                        NavigationLink {
                            LieuDetailView(place: place)
                        } label: {
                            PLTRow(symbol: place.type.symbolName,
                                   tone: place.type.tone,
                                   title: place.name,
                                   subtitle: subtitle(for: place),
                                   showsChevron: true,
                                   showsSeparator: place.id != places.last?.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if places.count >= 2 {
                    Button("Fusionner deux lieux") { showsMerge = true }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityLabel("Fusionner deux lieux")
                }
                Text("Touche un lieu pour voir ses sessions et régler son nom, son rayon et son type.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var howItCountsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Comment ça compte")
            PLTCard {
                HStack(spacing: Theme.Spacing.s) {
                    PLTChip("Taf", kind: .work)
                    PLTChip("Cours", kind: .study)
                    PLTChip("Courses", kind: .errand)
                }
                Text("Taf et cours comptent dans tes heures. Les courses sont notées mais jamais comptées, pour pas gonfler ta paie par erreur.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func subtitle(for place: Place) -> String {
        let category = place.alsoWorksHere && place.type == .courses ? "Courses et travail" : place.type.title
        let notCounted = place.type == .courses && !place.alsoWorksHere ? ", pas compté" : ""
        let first = "\(category), rayon \(Int(place.radius.rounded())) m\(notCounted)"
        let last = PlaceFormat.lastVisit(place.sessions.map(\.startDate).max(), now: Date(), calendar: .current)
        return first + "\n" + last
    }

    private func requestLocation() {
        isRequestingLocation = true
        Task { @MainActor in
            await permissions.requestLocationAccess()
            locationDenied = LocationOnce.isDenied()
            geofence.discovery.refresh()
            isRequestingLocation = false
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
