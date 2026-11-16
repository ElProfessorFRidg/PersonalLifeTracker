import SwiftUI

/// Réglages. Version minimale mais fonctionnelle : apparence, devise, base de calcul, accès aux Fonctionnalités.
/// Poussé depuis Accueil. À compléter (statuts détectés, suppression des données...) par l'agent qui possède ce fichier.
struct ReglagesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Apparence") {
                Picker("Thème", selection: $settings.themeChoice) {
                    ForEach(ThemeChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Picker("Densité", selection: $settings.density) {
                    ForEach(Density.allCases) { d in
                        Text(d.title).tag(d)
                    }
                }
                Toggle("Réduire les animations", isOn: $settings.reduceAnimations)
            }
            .listRowBackground(palette.surface)

            Section("Argent") {
                Picker("Devise", selection: $settings.currencyCode) {
                    ForEach(Currency.all) { c in
                        Text("\(c.name) (\(c.symbol))").tag(c.code)
                    }
                }
            }
            .listRowBackground(palette.surface)

            Section("Calcul des heures") {
                Picker("Base de calcul", selection: $settings.calculationBase) {
                    ForEach(CalculationBase.allCases) { b in
                        Text(b.title).tag(b)
                    }
                }
            }
            .listRowBackground(palette.surface)

            Section {
                NavigationLink("Fonctionnalités") {
                    FonctionnalitesView()
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Réglages")
    }
}
