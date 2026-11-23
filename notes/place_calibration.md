# place_calibration : auto-calibration des lieux (étape 3, section 130)

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile). Module non activé : l'orchestrateur doit passer `isAvailable: true` dans ModuleRegistryData.swift.

## Fait
- `PlaceSample` (@Model, App/Core/Models) : uid, placeUID, date, latitude, longitude, horizontalAccuracy, kindRaw (`PlaceSampleKind` : arrival, departure, manualConfirm). Ajouté au schéma (`AppModelContainer.schema`).
- `PlaceCalibrator` (App/Core/Calibration, Foundation seulement, plus `PlaceRules`) : médiane des écarts est/nord pour le centre, 90e centile (rang le plus proche) pour le rayon, marge, arrondi, bornes `PlaceRules`, explication française, empreinte (`signature`) de la proposition.
- `PlaceSampleRecorder.record(...)`, `.prune`, `.removeSamples`, `.calibrationSamples` ; `CalibrationDismissals` (UserDefaults, "Ignorer").
- `CalibrationCard` (App/Features/Lieux) : texte, aperçu carte (zone actuelle grise, proposée en accent), lignes Actuelle / Proposée, "Appliquer" (enregistre dans `UndoCenter` si présent, rafraîchit le géorepérage), "Ignorer". Rien d'affiché sans proposition. Insérée dans `LieuDetailView` sous "Réglage", seulement si `modules.isActive("place_calibration")`.
- Tests : `Tests/UnitTests/PlaceCalibrationTests.swift` (26 tests, valeurs calculées à la main).

## Pas fait (de la section 130)
- Délai de détection (non mesuré), séparation en deux zones, déplacement par glisser sur la carte.
- Détection des lieux qui se chevauchent et de l'usage des 20 régions, priorités (le chevauchement existe déjà dans LieuDetailView via PlaceRules, sans lien avec ce module).
- Indicateur de qualité par lieu (vert, orange).
- Lien avec l'assistant de dépannage (section 132).
- Aucun appel de `PlaceSampleRecorder.record` n'est branché : le service de détection n'est pas modifié ici, donc la carte reste vide tant que personne n'enregistre de mesure.
- Pas de nettoyage des mesures à la suppression d'un lieu (appeler `removeSamples`).
- Longitudes à cheval sur l'antiméridien non gérées.

## Seuils
| Seuil | Valeur | Origine |
|---|---|---|
| Mesures minimales | 6 | Spec section 130 ("défaut 6 arrivées"), compté sur toutes les mesures exploitables (arrivées, départs, confirmations), pas seulement les arrivées : MON CHOIX |
| Précision maximale d'une mesure | 50 m (zéro ou négatif : ignoré) | MON CHOIX |
| Mesures récentes utilisées | 30 | MON CHOIX |
| Mesures gardées par lieu | 40 | MON CHOIX (la spec impose seulement "jamais de traces GPS") |
| Centre déplacé si écart | 30 m ou plus | MON CHOIX |
| Rayon changé si écart | 20 m ou plus | MON CHOIX |
| Couverture du rayon | 90 % (rang le plus proche) | MON CHOIX |
| Marge sur le rayon | +10 m, arrondi à 10 m | MON CHOIX |
| Bornes du rayon | 50 à 300 m | `PlaceRules` (déjà existant) |
Si seul le centre bouge, le rayon actuel est gardé (et inversement). Le rayon est calculé autour du centre retenu.

## Vie privée
La spec dit "seules des mesures agrégées, jamais de traces GPS". Le modèle demandé garde une position par arrivée/départ (pas de suite continue), limitée à 40 par lieu. C'est plus fin qu'un simple agrégat : à valider avec l'utilisateur.

## Appel à faire par le service de détection (GeofenceService, non modifié)
Quand une arrivée ou un départ est confirmé et qu'une position récente est connue, seulement si le module est actif :
```swift
if modules.isActive("place_calibration") {   // ModuleStore, ou un booléen passé au service
    PlaceSampleRecorder.record(placeUID: place.uid,
                               latitude: location.coordinate.latitude,
                               longitude: location.coordinate.longitude,
                               horizontalAccuracy: location.horizontalAccuracy,
                               kind: .arrival,          // .departure ou .manualConfirm
                               date: location.timestamp,
                               in: context)           // le ModelContext du service
}
```
Retourne `Bool` (`@discardableResult`) : faux si la position ou la précision est invalide. À la suppression d'un lieu : `PlaceSampleRecorder.removeSamples(placeUID:in:)`.
Remarque : la position de l'événement de région est près du bord de la zone, ce qui tire le rayon proposé vers le rayon actuel plus la précision. Il vaut mieux enregistrer la meilleure position reçue juste après l'événement.

## Risques
- Qualité des données : un échantillon pris au bord du cercle donne un centre moyen proche du centre si les arrivées viennent de directions variées, mais biaisé si tout le monde arrive du même côté (cas fréquent : la médiane proposera alors de déplacer le centre vers ce côté). C'est le comportement voulu ("décalage systématique"), mais il peut surprendre.
- "Ignorer" retient l'empreinte exacte (centre à 11 m, rayon) : une proposition légèrement différente réapparaît.
- La carte d'aperçu utilise `Map(initialPosition:)` : l'appareil photo n'est pas recalculé si la proposition change pendant l'affichage.
- `@Query` avec `#Predicate` sur un UUID capturé dans `init`.
- Environnement optionnel `GeofenceService?` (même schéma que `UndoCenter?` déjà utilisé).

## Les 5 lignes les plus susceptibles d'échouer à la compilation
1. CalibrationCard : `_samples = Query(filter: #Predicate<PlaceSample> { $0.placeUID == uid }, sort: [SortDescriptor(\PlaceSample.date, order: .reverse)])`.
2. CalibrationCard : `@Environment(GeofenceService.self) private var geofence: GeofenceService?`.
3. CalibrationCard : `Map(initialPosition: position, interactionModes: []) { MapCircle(...).foregroundStyle(...).stroke(...) ... }`.
4. PlaceSampleRecorder : `FetchDescriptor<PlaceSample>(predicate: #Predicate<PlaceSample> { $0.placeUID == uid }, sortBy: [SortDescriptor(\PlaceSample.date, order: .reverse)])`.
5. CalibrationCard : appel de `service?.refreshMonitoredPlaces()` depuis une fonction `static` (isolation MainActor) appelée dans la fermeture d'annulation.
