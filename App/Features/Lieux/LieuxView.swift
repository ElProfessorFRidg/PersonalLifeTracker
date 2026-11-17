import SwiftUI
import SwiftData
import UIKit

/// Onglet Lieux (écran `lieux`).
struct LieuxView: View {
    @Environment(GeofenceService.self) private var geofence
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Query(sort: \Place.name) private var places: [Place]
    @State private var showsAdd: Bool = false
    @State private var locationDenied: Bool = false

    var body: some View {
        PLTScreen(title: "Lieux") {
            if locationDenied {
                PLTBanner(kind: .error,
                          title: "Je peux pas te localiser",
                          message: "La localisation est refusée pour l'app. Tes lieux sont gardés, mais je ne note plus tes arrivées. Tu peux toujours ajouter tes heures à la main.",
                          actionTitle: "Ouvrir les réglages iOS",
                          action: { openSettings() })
            }
            if modules.isActive("place_discovery") {
                if let error = geofence.discovery.error {
                    Text(error).foregroundStyle(.red)
                }
                if !geofence.discovery.isMonitoring {
                    Text("Découverte : autorise la localisation Toujours.")
                        .font(.footnote)
                }
                ForEach(suggestions) { candidate in
                    DiscoveredPlaceCard(candidate: candidate, discovery: geofence.discovery)
                }
                if geofence.discovery.candidates.contains(where: { $0.dismissed }) {
                    Button("Revoir les lieux ignorés") { geofence.discovery.restoreSuggestions() }
                }
            }
            if places.isEmpty {
                PLTCard {
                    PLTEmptyState(symbol: "mappin.and.ellipse",
                                  title: "Aucun lieu pour l'instant.",
                                  message: modules.isActive("place_discovery") ? "Les lieux réguliers apparaîtront ici." : "Ajoute un lieu pour démarrer.",
                                  actionTitle: "Ajouter un lieu",
                                  action: { showsAdd = true })
                }
            } else {
                placesSection
            }
            explanationSection
        }
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
        .onAppear {
            locationDenied = LocationOnce.isDenied()
        }
    }

    private var suggestions: [DiscoveredPlace] {
        geofence.discovery.candidates.filter { candidate in
            candidate.isReady && !candidate.dismissed && !places.contains {
                PlaceDiscoveryRules.distance(candidate.latitude, candidate.longitude,
                                             $0.latitude, $0.longitude) <= max(100, $0.radius)
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
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
            Text("Touche un lieu pour le modifier ou voir ses stats du mois.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var explanationSection: some View {
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
        let radius: Int = Int(place.radius.rounded())
        let counted: String = (place.type != .taf && place.type != .cours) ? ", pas compté" : ""
        let last: Date? = place.sessions.map { $0.startDate }.max()
        let lastText: String = PlaceFormat.lastVisit(last, now: Date(), calendar: Calendar.current)
        return "\(place.type.title), rayon \(radius) m\(counted)\n\(lastText)"
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
