import SwiftUI

/// Lignes de Réglages vers les écrans des modules Notes, Pauses, Trajet et Heures manquantes.
/// Chaque ligne n'apparaît que si son module est actif. Ne montre rien sinon.
struct JournalModuleLinks: View {
    @Environment(ModuleStore.self) private var modules

    var body: some View {
        Group {
            if modules.isActive("notes") {
                link(symbol: "note.text", title: "Notes de journée", subtitle: "Une phrase par jour, avec des tags") {
                    NotesView()
                }
            }
            if modules.isActive("breaks") {
                link(symbol: "pause.circle", title: "Pauses", subtitle: "Aucune, info ou rappel, jamais imposées") {
                    PausesView()
                }
            }
            if modules.isActive("travel_departure") {
                link(symbol: "arrow.triangle.turn.up.right.diamond", title: "Trajet et Pars maintenant",
                     subtitle: "Mode de transport, marge, notifications") {
                    TrajetView()
                }
            }
            if modules.isActive("missing_hours") {
                link(symbol: "clock.badge.questionmark", title: "Heures manquantes",
                     subtitle: "Les créneaux prévus sans session") {
                    HeuresManquantesView()
                }
            }
        }
    }

    private func link<Destination: View>(symbol: String, title: String, subtitle: String,
                                         @ViewBuilder destination: () -> Destination) -> some View {
        let target: Destination = destination()
        return NavigationLink {
            target
        } label: {
            PLTListGroup {
                PLTRow(symbol: symbol,
                       title: title,
                       subtitle: subtitle,
                       showsChevron: true,
                       showsSeparator: false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
