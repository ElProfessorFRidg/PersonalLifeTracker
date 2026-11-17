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
    @State private var type: PlaceType = .taf
    @State private var alsoWorksHere: Bool = false
    @State private var showsNameError: Bool = false
    @State private var saveFailed: Bool = false

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
                if let warning = PlaceRules.overlapWarning(names: overlapNames) {
                    PLTBanner(kind: .warning, title: "Zones qui se touchent", message: warning)
                }
                nameSection
                typeSection
                if saveFailed {
                    PLTBanner(kind: .error, title: "Oups, ça a pas marché.", message: "Le lieu n'a pas été enregistré. Réessaie ?")
                }
                Button("Enregistrer ce lieu") { save() }
                    .buttonStyle(.pltPrimary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: locator.state) {
                if case .located(let lat, let lon) = locator.state {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    center = coordinate
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
            } else {
                Text("Un nom court, pour te repérer dans la liste.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: Type

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Taf, cours ou courses ?")
            PLTListGroup {
                typeRow(.taf, note: "Tes heures comptent dans ton contrat et ta paie", showsSeparator: true)
                typeRow(.cours, note: "Comptées à part, jamais dans la paie", showsSeparator: true)
                typeRow(.courses, note: "Notées dans ton historique, mais pas comptées", showsSeparator: false)
            }
            if type == .courses {
                Toggle(isOn: $alsoWorksHere) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("J'y travaille aussi")
                            .font(.body)
                            .foregroundStyle(palette.textPrimary)
                        Text("Pour un magasin où tu bosses et où tu fais aussi tes courses")
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(minHeight: 44)
                .tint(palette.accent)
            }
            PLTCard {
                Text("Travail contre courses")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(type == .courses && alsoWorksHere
                     ? "Pour un lieu à double usage, je regarde la durée, ton planning et tes corrections pour deviner. Si j'hésite, je te demande. Une visite de 15 min compte comme des courses, pas comme du taf."
                     : "Ici, chaque passage compte comme du travail. C'est pour ton vrai lieu de taf.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func typeRow(_ rowType: PlaceType, note: String, showsSeparator: Bool) -> some View {
        let selected: Bool = type == rowType
        return Button {
            type = rowType
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: rowType.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(rowType.tone.color(palette))
                    .frame(width: 36, height: 36)
                    .background(rowType.tone.soft(palette), in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(rowType.title)
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rowType.title). \(note)")
        .accessibilityAddTraits(selectedTraits(selected))
    }

    private func selectedTraits(_ selected: Bool) -> AccessibilityTraits {
        if selected {
            return AccessibilityTraits([.isButton, .isSelected])
        }
        return AccessibilityTraits.isButton
    }

    // MARK: Actions

    private func save() {
        showsNameError = true
        if nameIssue != nil { return }
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
                          address: "",
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
