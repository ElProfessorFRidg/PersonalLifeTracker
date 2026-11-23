import SwiftUI
import SwiftData
import MapKit
import UIKit

/// Écran `lieu-ajout`. Présenté en feuille : il porte sa propre NavigationStack.
struct LieuAjoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query(sort: \Place.name) private var places: [Place]
    @StateObject private var locator: LocationOnce = LocationOnce()

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
                           latitudinalMeters: 700, longitudinalMeters: 700))
    @State private var center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    @State private var radius: Double = PlaceRules.defaultRadius
    @State private var name: String = ""
    @State private var type: PlaceType?
    @State private var address: String = ""
    @State private var positionChosen: Bool = false
    @State private var showsLocationError: Bool = false
    @State private var alsoWorksHere: Bool = false
    @State private var showsNameError: Bool = false
    @State private var saveFailed: Bool = false

    private let locateOnOpen: Bool

    init(locateOnOpen: Bool = false, initialType: PlaceType? = nil) {
        self.locateOnOpen = locateOnOpen
        _type = State(initialValue: initialType)
    }

    private var nameIssue: PlaceRules.NameIssue? {
        return PlaceRules.nameIssue(name, existingNames: places.map { $0.name })
    }

    private var overlapNames: [String] {
        let candidate = PlaceRules.Zone(name: name, latitude: center.latitude, longitude: center.longitude, radius: radius)
        let others: [PlaceRules.Zone] = places.map {
            PlaceRules.Zone(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radius: $0.radius)
        }
        return PlaceRules.overlappingNames(candidate, among: others)
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Nouveau lieu") {
                mapSection
                locationFeedback
                radiusSection
                if positionChosen, let warning = PlaceRules.overlapWarning(names: overlapNames) {
                    PLTBanner(kind: .warning, title: "Zones qui se touchent", message: warning)
                }
                nameSection
                typeSection
                if saveFailed {
                    PLTBanner(kind: .error, title: "Oups, ça a pas marché.", message: "Le lieu n'a pas été enregistré. Réessaie ?")
                }
                Button("Enregistrer ce lieu") { save() }
                    .buttonStyle(.pltPrimary)
                    .disabled(type == nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task {
                if locateOnOpen, case .idle = locator.state { locator.request() }
            }
            .onChange(of: locator.state) {
                if case .located(let lat, let lon) = locator.state {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    center = coordinate
                    positionChosen = true
                    showsLocationError = false
                    camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 700, longitudinalMeters: 700))
                }
            }
        }
    }

    // MARK: Carte

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Où c'est ?")
            ZStack {
                Map(position: $camera) {
                    MapCircle(center: center, radius: radius)
                        .foregroundStyle(palette.accent.opacity(0.18))
                        .stroke(palette.accent, lineWidth: 2)
                }
                .onMapCameraChange(frequency: .continuous) { mapContext in
                    center = mapContext.region.center
                    if !positionChosen && camera.positionedByUser {
                        positionChosen = true
                        showsLocationError = false
                    }
                }
                // Épingle fixe : le bas de l'épingle est au centre de la carte.
                Image(systemName: "mappin")
                    .font(.title)
                    .foregroundStyle(palette.accent)
                    .offset(y: -14)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Carte avec une épingle au centre et un cercle de \(Int(radius.rounded())) mètres autour")
            Text("Déplace la carte pour mettre l'épingle sur ton lieu.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            if showsLocationError {
                Text("Place l'épingle sur la carte ou utilise « Ma position ».")
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            }
            Button {
                locator.request()
            } label: {
                Label("Ma position", systemImage: "location.fill")
            }
            .buttonStyle(.pltSecondary)
        }
    }

    @ViewBuilder
    private var locationFeedback: some View {
        switch locator.state {
        case .denied:
            PLTBanner(kind: .warning,
                      title: "Je peux pas te localiser",
                      message: "Pas grave, déplace la carte à la main. Pour activer la position : Réglages iOS, Personal Life Tracker, Localisation, puis \"Pendant l'utilisation\".",
                      actionTitle: "Ouvrir les réglages iOS",
                      action: { openSettings() })
        case .failed:
            PLTBanner(kind: .info,
                      title: "Position introuvable",
                      message: "Réessaie dans un endroit dégagé, ou déplace la carte à la main.")
        case .locating:
            Text("Je cherche où t'es...")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        case .idle, .located:
            EmptyView()
        }
    }

    // MARK: Rayon

    private var radiusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("Rayon")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(Int(radius.rounded())) m")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            Slider(value: $radius, in: PlaceRules.minRadius...PlaceRules.maxRadius, step: 10)
                .frame(minHeight: 44)
                .accessibilityLabel("Rayon")
                .accessibilityValue("\(Int(radius.rounded())) mètres")
            Text("Plus petit = plus précis. Plus grand = tu seras repéré plus tôt. 100 m marche bien pour la plupart des lieux.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Nom

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Nom du lieu")
            TextField("Par exemple : Supérette du Canal", text: $name)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Nom du lieu")
            if showsNameError, let issue = nameIssue {
                Text(issue.message)
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            }
            TextField("Adresse (facultative)", text: $address)
                .textContentType(.fullStreetAddress)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
    }

    // MARK: Type

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Qu'est-ce que tu y fais ?")
            PLTCard {
                PlaceCategoryPicker(type: $type, alsoWorksHere: $alsoWorksHere)
            }
        }
    }

    // MARK: Actions

    private func save() {
        showsNameError = true
        showsLocationError = !positionChosen
        guard let type, nameIssue == nil, positionChosen else { return }
        guard PlaceRules.isRadiusValid(radius),
              PlaceRules.isValidCoordinate(latitude: center.latitude, longitude: center.longitude) else {
            saveFailed = true
            return
        }
        let place = Place(name: PlaceRules.cleanedName(name),
                          type: type,
                          latitude: center.latitude,
                          longitude: center.longitude,
                          radius: radius,
                          address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                          alsoWorksHere: type == .courses ? alsoWorksHere : false)
        context.insert(place)
        do {
            try context.save()
            dismiss()
        } catch {
            context.delete(place)
            saveFailed = true
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
