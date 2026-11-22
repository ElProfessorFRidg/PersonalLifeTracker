import SwiftUI

/// Étape 1 : ce que fait l'app, historique local et feuille "Et mes données ?".
struct OnboardingWelcomeStep: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void
    @State private var showsData: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            OnboardingHero(symbol: "clock.badge.checkmark")
            OnboardingTitle(title: "Tes heures, notées toutes seules.",
                            lead: "Je repère quand t'arrives au taf ou en cours et quand tu pars. Toi, tu fais rien. Deux minutes de réglages et c'est parti.")
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                OnboardingPoint(symbol: "location.fill", title: "Je sens tes arrivées et tes départs",
                                detail: "Au taf, en cours, aux courses, sans que tu ouvres l'app.")
                OnboardingPoint(symbol: "chart.bar.fill", title: "Tu vois où passe ton temps",
                                detail: "Ta journée, ta semaine, tes heures de taf et de cours.")
                OnboardingPoint(symbol: "lock.fill", title: "Ton historique reste sur ton iPhone",
                                detail: "Life Tracker fonctionne sans compte.")
            }
            VStack(spacing: Theme.Spacing.s) {
                Button("C'est parti", action: onContinue)
                    .buttonStyle(.pltPrimary)
                Button("Et mes données ?") { showsData = true }
                    .buttonStyle(.pltSecondary)
            }
        }
        .sheet(isPresented: $showsData) {
            OnboardingDataSheet()
        }
    }
}

private struct OnboardingDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    OnboardingTitle(title: "Où vont tes données ?",
                                    lead: "Ton historique et tes heures restent enregistrés sur ton iPhone.")
                    OnboardingPoint(symbol: "person.crop.circle.badge.xmark", title: "Pas de compte",
                                    detail: "Tu n'as ni mail ni mot de passe à donner.")
                    OnboardingPoint(symbol: "map", title: "Recherche d’une adresse",
                                    detail: "Quand tu consultes une suggestion dans Plans, Apple reçoit la position de l’arrêt recherché.")
                    OnboardingPoint(symbol: "hand.raised.fill", title: "Tu gardes la main",
                                    detail: "Tu peux tout exporter ou tout effacer depuis Réglages.")
                    Button("OK, compris") { dismiss() }
                        .buttonStyle(.pltPrimary)
                }
                .padding(Theme.Spacing.m)
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
