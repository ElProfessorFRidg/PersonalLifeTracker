import SwiftUI
import MapKit
import SwiftData

struct DiscoveredPlaceCard: View {
    let candidate: DiscoveredPlace
    let discovery: PlaceDiscovery
    var contractPlaceUIDs: Set<UUID> = []

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
    @Query private var places: [Place]

    private var currentCandidate: DiscoveredPlace {
        discovery.current(candidate)
    }

    var body: some View {
        let current = currentCandidate
        let decision: PlaceKindDecision = discovery.identification(for: current, places: places,
                                                                  contractPlaceUIDs: contractPlaceUIDs)

        NavigationStack {
            PLTScreen(title: "Vérifier le lieu") {
                locationSection(current)
                identificationSection(decision, venueType: current.context?.category, current: current)
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
                    discovery.dismissSuggestion(current)
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
            .onAppear {
                if type == nil, decision.verdict == .confident, let guess = decision.leaning {
                    type = guess
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

    private func identificationSection(_ decision: PlaceKindDecision, venueType: PlaceType?, current: DiscoveredPlace) -> some View {
        let buildings: Int = current.mergedIDs?.count ?? 1
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if buildings > 1 {
                PLTBanner(kind: .info, title: "\(buildings) arrêts voisins réunis",
                          message: "Ces arrêts sont à quelques dizaines de mètres les uns des autres. Je les compte comme un seul lieu, dont la zone couvre tous les bâtiments.")
            }
            if decision.verdict == .confident, let guess = decision.leaning {
                PLTCard {
                    Label("\(guess.title) probable", systemImage: guess.symbolName)
                        .font(.headline)
                        .foregroundStyle(guess.tone.color(palette))
                    Text(decision.statement)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    if guess == .taf && venueType == .courses && !(type == .courses && alsoWorksHere) {
                        Button("Je travaille et je fais mes courses ici") {
                            type = .courses
                            alsoWorksHere = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                    if type != guess {
                        Button("Choisir « \(guess.title) »") { type = guess }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                }
            } else {
                PLTCard {
                    Label(decision.question, systemImage: "questionmark.circle")
                        .font(.headline)
                    Text(decision.explanation)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    HStack(spacing: Theme.Spacing.s) {
                        answerButton("Mon taf", isOn: type == .taf) { type = .taf; alsoWorksHere = false }
                        answerButton("Mon école", isOn: type == .cours) { type = .cours; alsoWorksHere = false }
                        answerButton("Autre", isOn: type != nil && type != .taf && type != .cours) {
                            if type == .taf || type == .cours { type = nil }
                        }
                    }
                    Text("Ta réponse m'aide à ne plus me tromper sur les lieux de ce genre.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    private func answerButton(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isOn ? palette.accentOn : palette.accent)
                .background(isOn ? palette.accent : palette.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func visitSection(_ current: DiscoveredPlace) -> some View {
        let now = Date()
        let arrivals = PlaceDiscoveryRules.freshArrivals(current, now: now).sorted(by: >)
        let visits = discovery.observations(for: current, now: now)
        let count = arrivals.count
        let title = count == 1 ? "1 passage repéré" : "\(count) passages repérés"

        return PLTCard {
            DisclosureGroup(isExpanded: $showsVisits) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(arrivals, id: \.self) { arrival in
                        let departure = visits.first { $0.arrival == arrival }?.departure
                        HStack(alignment: .firstTextBaseline) {
                            Text(PlaceFormat.dayLabel(arrival, now: now, calendar: .current))
                            Spacer(minLength: Theme.Spacing.s)
                            Text(visitHours(arrival: arrival, departure: departure, now: now))
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

    private func visitHours(arrival: Date, departure: Date?, now: Date) -> String {
        let calendar = Calendar.current
        let start = Formatting.clock(arrival, calendar: calendar)
        guard let departure else { return "\(start) · Départ inconnu" }
        let end = Formatting.clock(departure, calendar: calendar)
        if calendar.isDate(arrival, inSameDayAs: departure) {
            return "\(start) à \(end)"
        }
        let day = PlaceFormat.dayLabel(departure, now: now, calendar: calendar)
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
