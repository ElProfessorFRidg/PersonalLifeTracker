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
    @Query(sort: \Place.name) private var places: [Place]
    @AppStorage("plt.discovery.automaticMapsLookup") private var automaticMapsLookup = false
    @State private var showsAdd = false
    @State private var locationDenied = false
    @State private var selectedSuggestion: DiscoveredPlace?

    var body: some View {
        let discovery = geofence.discovery
        let discoveryActive = modules.isActive("place_discovery")
        let suggestions = discoveryActive ? discovery.suggestions(excluding: places) : []
        let lookupIDs = automaticMapsLookup ? suggestions.map(\.id).sorted { $0.uuidString < $1.uuidString } : []

        PLTScreen(title: "Lieux") {
            if locationDenied {
                PLTBanner(kind: .error,
                          title: "Localisation désactivée",
                          message: "Réactive la localisation pour détecter tes arrivées dans les lieux enregistrés et trouver de nouveaux lieux.",
                          actionTitle: "Ouvrir les réglages iOS",
                          action: openSettings)
            }
            if discoveryActive {
                discoverySection(suggestions)
            }
            savedPlacesSection
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: suggestions.map(\.id))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsAdd = true
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Ajouter un lieu")
            }
        }
        .sheet(isPresented: $showsAdd) {
            LieuAjoutView()
        }
        .sheet(item: $selectedSuggestion) { candidate in
            DiscoveredPlaceCard(candidate: candidate, discovery: discovery)
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

    private func discoverySection(_ suggestions: [DiscoveredPlace]) -> some View {
        let discovery = geofence.discovery

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Lieux à vérifier")
            if let error = discovery.error {
                PLTBanner(kind: .error, title: "Découverte des lieux", message: error)
            }
            if !locationDenied && !discovery.canMonitorVisits {
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

            if suggestions.isEmpty {
                if discovery.isMonitoring {
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

            if discovery.candidates.contains(where: { $0.dismissed }) {
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
        let type = discovery.recommendation(for: candidate)?.type
        let count = discovery.visitCount(for: candidate)
        let visits = count == 1 ? "1 passage" : "\(count) passages"
        let lastDate = candidate.arrivals.max()
        let recentVisit = lastDate.map { date in
            "\(PlaceFormat.dayLabel(date, now: Date(), calendar: .current)) à \(Formatting.clock(date, calendar: .current))"
        }
        let title = candidate.context?.name ?? candidate.context?.address ?? recentVisit ?? "Arrêt repéré"
        let address = candidate.context?.name == nil ? nil : candidate.context?.address
        let subtitle = [address, type.map { "\($0.title) possible" }, visits]
            .compactMap { $0 }
            .joined(separator: " · ")

        return PLTRow(symbol: type?.symbolName ?? "mappin",
                      tone: type?.tone ?? .accent,
                      title: title,
                      subtitle: subtitle,
                      showsChevron: true,
                      showsSeparator: candidate.id != lastID,
                      action: { selectedSuggestion = candidate })
    }

    private var savedPlacesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Tes lieux")
            if places.isEmpty {
                PLTCard {
                    PLTEmptyState(symbol: "mappin.and.ellipse",
                                  title: "Aucun lieu enregistré",
                                  message: "Ajoute un lieu de travail, de cours ou de sortie pour le retrouver ici.",
                                  actionTitle: "Ajouter un lieu",
                                  action: { showsAdd = true })
                }
            } else {
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
            }
        }
    }

    private func subtitle(for place: Place) -> String {
        let category = place.alsoWorksHere && place.type == .courses ? "Courses et travail" : place.type.title
        let location = place.address.isEmpty ? nil : place.address
        let last = place.sessions.map(\.startDate).max().map {
            PlaceFormat.lastVisit($0, now: Date(), calendar: .current)
        }
        return [category, location, last].compactMap { $0 }.joined(separator: "\n")
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
