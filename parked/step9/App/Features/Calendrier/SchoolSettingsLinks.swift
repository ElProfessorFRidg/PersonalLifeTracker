import SwiftUI

/// Lignes de Réglages des quatre modules scolaires (calendrier scolaire, mode examens, créneaux de révision, nuit courte).
/// Chaque ligne n'existe que si son module est actif. Le groupe est vide (rien ne s'affiche) si aucun n'est actif.
struct SchoolSettingsLinks: View {
    @Environment(ModuleStore.self) private var modules

    private var activeIDs: [String] {
        var result: [String] = []
        for id in ["school_calendar", "exam_mode", "study_slots", "short_night"] where modules.isActive(id) {
            result.append(id)
        }
        return result
    }

    var body: some View {
        let ids: [String] = activeIDs
        Group {
            if !ids.isEmpty {
                PLTListGroup {
                    ForEach(Array(ids.enumerated()), id: \.element) { (index: Int, id: String) in
                        link(id: id, showsSeparator: index < ids.count - 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func link(id: String, showsSeparator: Bool) -> some View {
        switch id {
        case "school_calendar":
            NavigationLink {
                CalendrierScolaireView()
            } label: {
                PLTRow(symbol: "calendar", title: "Calendrier scolaire",
                       subtitle: "Vacances, jours fériés et tes propres pauses",
                       showsChevron: true, showsSeparator: showsSeparator)
            }
            .buttonStyle(.plain)
        case "exam_mode":
            NavigationLink {
                ExamModeView()
            } label: {
                PLTRow(symbol: "graduationcap", title: "Mode examens",
                       subtitle: "Ta période d'examens et tes épreuves",
                       showsChevron: true, showsSeparator: showsSeparator)
            }
            .buttonStyle(.plain)
        case "study_slots":
            NavigationLink {
                CreneauxRevisionView()
            } label: {
                PLTRow(symbol: "book", title: "Créneaux de révision",
                       subtitle: "Les trous libres où réviser",
                       showsChevron: true, showsSeparator: showsSeparator)
            }
            .buttonStyle(.plain)
        default:
            NavigationLink {
                NuitCourteView()
            } label: {
                PLTRow(symbol: "moon.zzz", title: "Alerte nuit courte",
                       subtitle: "Seuil de repos et notification la veille",
                       showsChevron: true, showsSeparator: showsSeparator)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Cartes de l'Accueil des modules scolaires : nuit courte et compte à rebours d'examens.
struct SchoolHomeCards: View {
    let now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    var body: some View {
        Group {
            NuitCourteCard(now: now)
            ExamCountdownCard(now: now)
        }
    }
}
