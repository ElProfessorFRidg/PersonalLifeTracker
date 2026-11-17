# Lieux (étape 3)

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile).

## Fait
- `PlaceRules` (App/Core/Logic) : validation du nom (vide, doublon sans casse ni accents), rayon 50 à 300 m (défaut 100, bornes choisies par l'app : la spec n'en fixe pas), haversine, `isInside`, chevauchement (`Zone`), `PlaceStats.month` (réutilise `SessionDurations.retained`), `PlaceFormat` (dernière visite, libellé de jour).
- `LocationOnce` (App/Core/Services) : position unique, "pendant l'utilisation", états idle/locating/denied/failed/located.
- `LieuxView` : liste (type, rayon, dernière visite), "+" en barre, bandeau si localisation refusée, "Comment ça compte", état vide, push vers le détail.
- `LieuAjoutView` : carte `Map(position:)`, épingle fixe, `MapCircle`, slider, "Ma position", nom, type, "J'y travaille aussi" (courses), avertissement de chevauchement, enregistrement SwiftData.
- `LieuDetailView` : vignette carte, nom/type/rayon éditables (enregistrés à la volée), stats du mois, 5 dernières sessions (push `SessionDetailView`), suppression avec confirmation (sessions gardées).
- Tests : `PlaceRulesTests` (21 tests, valeurs calculées à la main).

## Pas fait
- Fiabilité (Fiable / À vérifier / À l'arrêt) : pas de données de détection dans le modèle.
- Recherche d'adresse, catégories Domicile/Commerce/Autre, horaires habituels, employeur, transport, fusion de lieux (section 10). `address` reste vide.
- "Tout voir" des sessions, annulation ("Remettre ce lieu") après suppression.
- Aucun géorepérage.

## Risques
- Carte dans un ScrollView : le geste de pan de la carte peut entrer en conflit avec le défilement vertical.
- L'épingle fixe est décalée de 14 pt vers le haut à l'œil, à vérifier sur appareil.
- `@MainActor` + delegate `nonisolated` dans LocationOnce : avertissements de concurrence possibles.
- Suppression : `isDeleted` évite de relire un modèle supprimé, comportement SwiftData non vérifié.
- `onChange(of:)` forme sans paramètre (iOS 17).

## Les 5 lignes les plus susceptibles d'échouer à la compilation
1. LieuAjoutView : `MapCircle(center:radius:).foregroundStyle(...).stroke(..., lineWidth:)` (types de retour MapContent).
2. LieuAjoutView : `.onMapCameraChange(frequency: .continuous) { mapContext in center = mapContext.region.center }`.
3. LieuDetailView : `Map(position: $camera, interactionModes: []) { ... Marker(..., coordinate:).tint(...) }`.
4. LieuDetailView : `init(place:)` avec `_nameDraft = State(initialValue:)` et `_camera = State(initialValue:)` en plus de `@Query`/`@Environment`.
5. LocationOnce : `@MainActor final class ... NSObject` avec `override init()` et méthodes `nonisolated` du delegate.
