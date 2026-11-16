import SwiftUI
import SwiftData

/// Résumé du premier lieu créé, gardé par l'onboarding pour le récap.
struct OnboardingPlaceSummary: Equatable {
    let name: String
    let typeTitle: String
    let radius: Double
}

/// Étape 6 : premier lieu (Taf ou Cours) à la position actuelle. Passable.
struct OnboardingPlaceStep: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    let permissions: PermissionRequester
    let created: OnboardingPlaceSummary?
    let onCreated: (OnboardingPlaceSummary) -> Void
    let onContinue: () -> Void

    @State private var type: PlaceType = .taf
    @State private var name: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var nameFocused: Bool

    private var hasLocation: Bool {
        return permissions.location == .whenInUse || permissions.location == .always
    }

    private var trimmedName: String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if let place = created {
                doneView(place)
            } else {
                formView
            }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: "mappin.and.ellipse")
            OnboardingTitle(title: "Ton premier lieu.",
                            lead: "Ajoute ton taf ou ta fac. Dès que t'y es, je note tes heures tout seul. Tu en ajouteras d'autres après.")

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("C'est quoi comme endroit ?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                Picker("Type de lieu", selection: $type) {
                    Text("Mon taf").tag(PlaceType.taf)
                    Text("Ma fac ou mon lycée").tag(PlaceType.cours)
                }
                .pickerStyle(.segmented)
                Text(type == .taf ? "Ça compte dans tes heures de travail." : "Ça compte dans tes heures de cours.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Son nom")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                TextField("Celui que tu veux, c'est pour toi", text: $name)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minHeight: 44)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    .accessibilityLabel("Nom du lieu")
            }

            if hasLocation {
                Text("Je mets le lieu là où tu es maintenant, avec une zone de 100 m autour. Mets-toi sur place pour ajouter ce lieu, tu pourras ajuster la zone plus tard.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            } else {
                PLTBanner(kind: .info,
                          title: "Je ne peux pas te localiser pour l'instant",
                          message: "Sans localisation, je ne peux pas placer le lieu. Tu pourras l'ajouter plus tard depuis Lieux.")
            }

            if !errorMessage.isEmpty {
                PLTBanner(kind: .error, title: "Le lieu n'a pas pu être ajouté", message: errorMessage)
            }

            VStack(spacing: Theme.Spacing.s) {
                Button(isSaving ? "Je cherche où t'es..." : "Ajouter ce lieu") {
                    save()
                }
                .buttonStyle(.pltPrimary)
                .disabled(!hasLocation || trimmedName.count < 2 || isSaving)
                Button("Je le ferai plus tard", action: onContinue)
                    .buttonStyle(.pltSecondary)
            }
        }
    }

    private func doneView(_ place: OnboardingPlaceSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: "checkmark", kind: .ok)
            OnboardingTitle(title: "Lieu ajouté.",
                            lead: "Je te préviens quand t'y arrives. Tu pourras ajuster la zone sur la carte plus tard.")
            PLTListGroup {
                PLTRow(symbol: place.typeTitle == PlaceType.cours.title ? "graduationcap.fill" : "briefcase.fill",
                       tone: place.typeTitle == PlaceType.cours.title ? .study : .work,
                       title: place.name,
                       subtitle: "\(place.typeTitle), zone de \(Int(place.radius)) m",
                       showsSeparator: false)
            }
            Text("Et si je me trompe ? Je te demande toujours de confirmer avant que ça compte. Tu corriges l'heure en deux taps.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            Button("Continuer", action: onContinue)
                .buttonStyle(.pltPrimary)
        }
    }

    private func save() {
        let cleanName: String = trimmedName
        let chosenType: PlaceType = type
        nameFocused = false
        errorMessage = ""
        isSaving = true
        Task { @MainActor in
            let coordinate: PermissionCoordinate? = await permissions.currentCoordinate()
            guard let coordinate = coordinate else {
                isSaving = false
                errorMessage = "Je n'arrive pas à te localiser. Essaie dehors ou plus tard, ou ajoute le lieu depuis Lieux."
                return
            }
            let place: Place = Place(name: cleanName, type: chosenType,
                                     latitude: coordinate.latitude, longitude: coordinate.longitude)
            context.insert(place)
            do {
                try context.save()
                isSaving = false
                onCreated(OnboardingPlaceSummary(name: cleanName, typeTitle: chosenType.title, radius: place.radius))
            } catch {
                context.delete(place)
                isSaving = false
                errorMessage = "Une erreur est survenue en enregistrant. Réessaie."
            }
        }
    }
}
