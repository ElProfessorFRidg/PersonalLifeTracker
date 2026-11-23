import SwiftUI
import SwiftData

/// Carte compacte de l'Accueil : nombre de créneaux à vérifier. N'affiche rien sans module actif ou sans élément.
struct HeuresManquantesCard: View {
    @Environment(ModuleStore.self) private var modules
    @Query(sort: \PlannedShift.start) private var shifts: [PlannedShift]
    @Query private var sessions: [WorkSession]
    @Query private var leaves: [LeaveEntry]
    @Query private var contracts: [Contract]

    private let ignoreStore: MissingHoursIgnoreStore = MissingHoursIgnoreStore.shared

    var body: some View {
        Group {
            if modules.isActive("missing_hours") && !modules.isActive("vacation_mode") {
                cardContent
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        let now: Date = Date()
        let items: [MissingItem] = MissingHoursSupport.items(shifts: shifts, sessions: sessions, leaves: leaves,
                                                             contracts: contracts,
                                                             ignored: ignoreStore.activeIDs(now: now),
                                                             now: now, calendar: Calendar.current)
        if !items.isEmpty {
            NavigationLink {
                HeuresManquantesView()
            } label: {
                PLTListGroup {
                    PLTRow(symbol: "clock.badge.questionmark",
                           title: "Heures manquantes ?",
                           subtitle: MissingHoursRules.countText(items.count),
                           showsChevron: true,
                           showsSeparator: false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Heures manquantes, \(MissingHoursRules.countText(items.count))")
        }
    }
}
