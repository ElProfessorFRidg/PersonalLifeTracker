import SwiftUI
import SwiftData

/// Feuille « Fusionner deux lieux » : on coche les lieux à réunir, le lieu qui a le plus de sessions est conservé,
/// toutes les sessions sont rattachées à lui. L'action est annulable via UndoCenter.
struct LieuFusionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(GeofenceService.self) private var geofence
    @Environment(UndoCenter.self) private var undoCenter: UndoCenter?
    @Query(sort: \Place.name) private var places: [Place]
    @State private var selected: Set<UUID>

    init(preselected: [UUID] = []) {
        _selected = State(initialValue: Set(preselected))
    }

    private var chosenPlaces: [Place] {
        return places.filter { (p: Place) -> Bool in return selected.contains(p.uid) }
    }

    private var plan: PlaceMergePlan? {
        return PlaceMerge.plan(chosenPlaces.map { (p: Place) -> PlaceSnapshot in return p.snapshot })
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Fusionner des lieux") {
                Text("Coche les lieux qui sont en réalité le même endroit. Je garde le lieu qui a le plus de sessions et je lui rattache toutes les autres.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                PLTListGroup {
                    ForEach(places) { place in
                        PLTRow(symbol: selected.contains(place.uid) ? "checkmark.circle.fill" : place.type.symbolName,
                               tone: place.type.tone,
                               title: place.name,
                               subtitle: "\(place.type.title), \(place.sessions.count) sessions",
                               value: selected.contains(place.uid) ? "Choisi" : nil,
                               showsSeparator: place.id != places.last?.id,
                               action: { toggle(place.uid) })
                    }
                }
                if let plan = plan {
                    let removedNames: [String] = chosenPlaces.filter { (p: Place) -> Bool in
                        return p.uid != plan.keeperID
                    }.map { (p: Place) -> String in return "« \(p.name) »" }
                    PLTCard {
                        Text(PlaceMerge.summary(plan, removedNames: removedNames))
                            .font(.subheadline)
                    }
                }
                Button("Fusionner") { performMerge() }
                    .buttonStyle(.pltPrimary)
                    .disabled(plan == nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ uid: UUID) {
        if selected.contains(uid) { selected.remove(uid) } else { selected.insert(uid) }
    }

    private func performMerge() {
        PlaceFixActions.merge(placeIDs: Array(selected), context: context, undo: undoCenter, geofence: geofence)
        dismiss()
    }
}
