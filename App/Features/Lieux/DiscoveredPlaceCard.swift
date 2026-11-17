import SwiftUI
import MapKit

struct DiscoveredPlaceCard: View {
    let candidate: DiscoveredPlace
    let discovery: PlaceDiscovery
    @State private var type: PlaceType = .taf
    @State private var name = ""

    var body: some View {
        PLTCard {
            Text("Tu passes souvent ici.")
                .font(.headline)
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: candidate.latitude, longitude: candidate.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))),
                interactionModes: []) {
                Marker("Lieu repéré", coordinate: CLLocationCoordinate2D(
                    latitude: candidate.latitude, longitude: candidate.longitude))
            }
            .frame(height: 140)
            .accessibilityLabel("Lieu repéré : latitude \(candidate.latitude), longitude \(candidate.longitude)")
            Picker("Type de lieu", selection: $type) {
                Text("Travail").tag(PlaceType.taf)
                Text("Études").tag(PlaceType.cours)
                Text("Domicile").tag(PlaceType.domicile)
                Text("Commerce").tag(PlaceType.courses)
                Text("Autre").tag(PlaceType.autre)
            }
            TextField("Nom (facultatif)", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Ignorer") { discovery.dismiss(candidate.id) }
                    .buttonStyle(.pltSecondary)
                Button("Ajouter") {
                    _ = discovery.confirm(candidate, type: type, name: name)
                }
                .buttonStyle(.pltPrimary)
            }
        }
    }
}
