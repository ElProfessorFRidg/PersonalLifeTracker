import SwiftUI

/// Étape 5 (seulement si planning_ocr est activé) : explication seule. L'accès aux photos sera demandé à l'import.
struct OnboardingPhotosStep: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: "photo.on.rectangle.angled")
            OnboardingTitle(title: "Ton planning en photo.",
                            lead: "Tu prends ton planning en photo, je le lis et je remplis tes horaires. La lecture se fait sur ton tel, la photo ne part nulle part.")
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                OnboardingPoint(symbol: "photo", title: "Seulement ce que tu choisis",
                                detail: "Je te conseille « Choisir des photos » : je vois juste la photo du planning.")
                OnboardingPoint(symbol: "iphone", title: "Lecture sur ton tel",
                                detail: "Aucune photo n'est envoyée, aucun compte.")
                OnboardingPoint(symbol: "checklist", title: "Tu confirmes chaque ligne",
                                detail: "Je remplis, tu vérifies, rien n'est validé en silence.")
            }
            PLTCard {
                Text("Pas de demande maintenant")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                Text("iOS te demandera l'accès aux photos la première fois que tu importeras un planning. Tu pourras toujours taper tes horaires à la main.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            Button("Continuer", action: onContinue)
                .buttonStyle(.pltPrimary)
            Text("Cette étape n'apparaît que si t'as coché « Planning par photo ».")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }
}
