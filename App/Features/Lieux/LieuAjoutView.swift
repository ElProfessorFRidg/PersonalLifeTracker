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
                Button("Annuler") { dismiss() }
                    .font(.headline)
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
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
            PLTSectionHeader(title: "Où c'est ?", actionTitle: "Ma position", action: { locator.request() })
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
                Text("\(Int(radius.rounded())) m")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(palette.surface, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(Theme.Spacing.s)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(height: 220)
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
            Text("Rayon : \(Int(radius.rounded())) m")
                .font(.headline.monospacedDigit())
                .foregroundStyle(palette.textPrimary)
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
            PLTSectionHeader(title: "Nom")
            TextField("Ex. Supérette du Canal", text: $name)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .accessibilityLabel("Nom du lieu")
            if showsNameError, let issue = nameIssue {
                Text(issue.message)
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            } else {
                Text("Un nom court, pour te repérer dans la liste.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
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
            PLTSectionHeader(title: "Taf, cours ou courses ?")
            PLTListGroup {
                ForEach(PlaceType.allCases) { (placeType: PlaceType) in
                    PLTRadioRow(symbol: placeType.symbolName,
                                tone: placeType.tone,
                                title: placeType.title,
                                subtitle: typeExplanation(placeType),
                                selected: type == placeType,
                                showsSeparator: placeType != PlaceType.allCases.last,
                                action: {
                                    type = placeType
                                    if placeType != .courses { alsoWorksHere = false }
                                })
                }
            }
            if type == .courses {
                PLTCard {
                    Toggle("J'y travaille aussi", isOn: $alsoWorksHere)
                        .tint(palette.accent)
                        .frame(minHeight: 44)
                    Text("Pour un magasin où tu bosses et où tu fais aussi tes courses")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            if let type = type {
                PLTCard {
                    Text(type == .taf ? "Travail contre courses" : "Ce que ça change")
                        .font(.headline)
                    Text(type.usageDescription(alsoWorksHere: alsoWorksHere))
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    private func typeExplanation(_ placeType: PlaceType) -> String {
        switch placeType {
        case .taf: return "Tes heures comptent dans ton contrat et ta paie"
        case .cours: return "Comptées à part, jamais dans la paie"
        case .courses: return "Notées dans ton historique, mais pas comptées"
        case .domicile, .sport, .sortie, .autre: return "Lieu perso, hors des heures de travail"
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

/// Ligne de choix unique (radio) comme `role="radio"` de la maquette : tuile d'icône, titre, sous-titre, valeur et coche.
/// À placer dans un PLTListGroup.
struct PLTRadioRow: View {
    @Environment(\.palette) private var palette
    let symbol: String?
    let tone: PLTTone
    let title: String
    let subtitle: String?
    let value: String?
    let selected: Bool
    let showsSeparator: Bool
    let accessibilityText: String?
    let action: () -> Void

    init(symbol: String? = nil,
         tone: PLTTone = .accent,
         title: String,
         subtitle: String? = nil,
         value: String? = nil,
         selected: Bool,
         showsSeparator: Bool = true,
         accessibilityText: String? = nil,
         action: @escaping () -> Void) {
        self.symbol = symbol
        self.tone = tone
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.selected = selected
        self.showsSeparator = showsSeparator
        self.accessibilityText = accessibilityText
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tone.color(palette))
                        .frame(width: 36, height: 36)
                        .background(tone.soft(palette), in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: Theme.Spacing.s)
                if let value = value {
                    Text(value)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? palette.accent : palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if showsSeparator {
                    Rectangle()
                        .fill(palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, Theme.Spacing.m)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText ?? [title, subtitle, value].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}
