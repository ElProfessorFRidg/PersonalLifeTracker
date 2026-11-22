import SwiftUI
import MapKit

struct DiscoveredPlaceCard: View {
    let candidate: DiscoveredPlace
    let discovery: PlaceDiscovery

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var type: PlaceType?
    @State private var name = ""
    @State private var alsoWorksHere = false
    @State private var saveFailed = false
    @State private var lookupResult: Bool?
    @State private var showsVisits = false
    @State private var lookupAttempt = 0

    private var currentCandidate: DiscoveredPlace {
        discovery.candidates.first(where: { $0.id == candidate.id }) ?? candidate
    }

    var body: some View {
        let current = currentCandidate
        let typeHint = discovery.recommendation(for: current)

        NavigationStack {
            PLTScreen(title: "Vérifier le lieu") {
                locationSection(current)
                if let typeHint {
                    suggestionSection(typeHint, venueType: current.context?.category)
                }
                visitSection(current)
                typeSection
                if saveFailed {
                    PLTBanner(kind: .error, title: "Lieu non enregistré",
                              message: discovery.confirmationError ?? "Vérifie le nom et réessaie.")
                }
                Button("Enregistrer le lieu") { save(current) }
                    .buttonStyle(.pltPrimary)
                    .disabled(type == nil)
                Button("Ignorer ce lieu", role: .destructive) {
                    discovery.dismiss(current.id)
                    dismiss()
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task(id: lookupAttempt) {
                lookupResult = nil
                let succeeded = await discovery.enrich(currentCandidate)
                if !Task.isCancelled {
                    lookupResult = succeeded
                }
            }
        }
    }

    private func locationSection(_ current: DiscoveredPlace) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate, latitudinalMeters: 350, longitudinalMeters: 350)),
                interactionModes: []) {
                Marker("Arrêt détecté", coordinate: coordinate)
                    .tint(palette.accent)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Carte de l'arrêt détecté")
            .accessibilityValue(current.context?.address ?? coordinateAccessibilityValue(coordinate))

            PLTCard {
                Label(current.context?.name ?? "Position de l'arrêt", systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if let address = current.context?.address {
                    Text(address)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
                if lookupResult == nil && current.context == nil {
                    ProgressView("Recherche dans Plans…")
                        .font(.footnote)
                } else if current.context?.address == nil && current.context?.name == nil {
                    Text(lookupResult == true
                         ? "Plans n'a pas trouvé d'adresse pour cet arrêt."
                         : "La recherche d'adresse n'a pas abouti. L'arrêt reste visible sur la carte.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    if lookupResult == false {
                        Button("Relancer la recherche") { lookupAttempt += 1 }
                            .font(.subheadline)
                            .frame(minHeight: 44)
                    }
                }
                Text("Adresse et établissements proches recherchés dans Apple Plans.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func coordinateAccessibilityValue(_ coordinate: CLLocationCoordinate2D) -> String {
        let latitude = coordinate.latitude.formatted(.number.precision(.fractionLength(4)))
        let longitude = coordinate.longitude.formatted(.number.precision(.fractionLength(4)))
        return "Latitude \(latitude), longitude \(longitude)"
    }

    private func suggestionSection(_ recommendation: PlaceRecommendation, venueType: PlaceType?) -> some View {
        PLTCard {
            Label("\(recommendation.type.title) possible", systemImage: recommendation.type.symbolName)
                .font(.headline)
                .foregroundStyle(recommendation.type.tone.color(palette))
            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            if recommendation.type == .taf && venueType == .courses && !(type == .courses && alsoWorksHere) {
                Button("Je travaille et je fais mes courses ici") {
                    type = .courses
                    alsoWorksHere = true
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            if type != recommendation.type {
                Button("Choisir « \(recommendation.type.title) »") {
                    type = recommendation.type
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
        }
    }

    private func visitSection(_ current: DiscoveredPlace) -> some View {
        let visits = discovery.observations(for: current).sorted { $0.arrival > $1.arrival }
        let count = discovery.visitCount(for: current)
        let title = count == 1 ? "1 passage repéré" : "\(count) passages repérés"

        return PLTCard {
            if visits.isEmpty {
                Text(title).font(.headline)
                Text("Les heures de ces anciens passages sont incomplètes.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            } else {
                DisclosureGroup(isExpanded: $showsVisits) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        ForEach(visits.prefix(7), id: \.arrival) { visit in
                            HStack(alignment: .firstTextBaseline) {
                                Text(PlaceFormat.dayLabel(visit.arrival, now: Date(), calendar: .current))
                                Spacer(minLength: Theme.Spacing.s)
                                Text(visitHours(visit))
                                    .multilineTextAlignment(.trailing)
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, Theme.Spacing.s)
                } label: {
                    Text(title)
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showsVisits)
            }
        }
    }

    private func visitHours(_ visit: PlaceVisitObservation) -> String {
        let calendar = Calendar.current
        let start = Formatting.clock(visit.arrival, calendar: calendar)
        let departure = visit.departure
        let end = Formatting.clock(departure, calendar: calendar)
        if calendar.isDate(visit.arrival, inSameDayAs: departure) {
            return "\(start) à \(end)"
        }
        let day = PlaceFormat.dayLabel(departure, now: Date(), calendar: calendar)
        return "\(start) à \(end) (\(day))"
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Qu'est-ce que tu y fais ?")

            PLTCard {
                PlaceCategoryPicker(type: $type, alsoWorksHere: $alsoWorksHere)
                TextField(currentCandidate.context?.name ?? "Nom du lieu (facultatif)", text: $name)
                    .textContentType(.organizationName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Nom du lieu")
                    .frame(minHeight: 44)
            }
        }
    }

    private func save(_ current: DiscoveredPlace) {
        guard let type else { return }
        if discovery.confirm(current, type: type, name: name, alsoWorksHere: alsoWorksHere) {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}

struct PlaceCategoryPicker: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var type: PlaceType?
    @Binding var alsoWorksHere: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Picker("Type de lieu", selection: $type) {
                Text("Choisis un type").tag(nil as PlaceType?)
                ForEach(PlaceType.allCases) { placeType in
                    Label(placeType.title, systemImage: placeType.symbolName).tag(Optional(placeType))
                }
            }
            .frame(minHeight: 44)
            if type == .courses {
                Toggle("J'y travaille aussi", isOn: $alsoWorksHere)
                    .tint(palette.accent)
                    .frame(minHeight: 44)
                    .transition(.opacity)
            }
            if let type {
                Text(type.usageDescription(alsoWorksHere: alsoWorksHere))
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: type)
        .onChange(of: type) { _, newType in
            if newType != .courses { alsoWorksHere = false }
        }
    }
}

extension PlaceType {
    func usageDescription(alsoWorksHere: Bool = false) -> String {
        switch self {
        case .taf:
            return "Les passages confirmés comptent dans tes heures de travail."
        case .cours:
            return "Tes heures de cours sont suivies à part de tes heures de travail."
        case .courses where alsoWorksHere:
            return "Life Tracker s'appuie sur la durée et ton planning pour distinguer tes courses de tes heures de travail."
        case .courses, .domicile, .sport, .sortie, .autre:
            return "Ce lieu reste dans tes lieux perso, hors des heures de travail."
        }
    }
}
