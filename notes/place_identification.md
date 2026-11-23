# place_identification : lieux voisins, taf contre école, corrections, audit

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile). Aucun nouveau modèle SwiftData : JSON dans UserDefaults.

## Ce qui a changé
- `App/Core/Discovery/PlaceSuggestionMerge.swift` (pur) : regroupe les arrêts voisins en UNE suggestion, détecte les recouvrements avec les lieux enregistrés.
- `App/Core/Classification/PlaceKindClassifier.swift` (pur) : score taf / école / courses / domicile (sport, sortie via Plans), raison française par signal, question quand ce n'est pas sûr.
- `App/Core/Classification/PlaceKindLearning.swift` : `PlaceKindMemory` (leçons, écarts de fusion), `PlaceKindStore` (UserDefaults, clé `plt.placekind.memory`, partage les `defaults` de `PlaceDiscovery`).
- `App/Core/Discovery/PlaceSuggestionAudit.swift` (pur) : liste des problèmes avec correctif en un geste.
- `App/Core/Logic/PlaceMerge.swift` (pur) : plan de fusion de lieux. `PlaceRules` : `enclosingZone`, `roundedUpRadius`.
- UI : `DiscoveredPlaceCard` (affirmation ou question à 3 boutons), `LieuxView` (suggestions regroupées, "Agrandir", bandeau "À vérifier", "Fusionner deux lieux"), `LieuFusionView`, `PlaceFixActions` (applique et enregistre l'annulation dans `UndoCenter`), `LieuDetailView` (fusion, apprentissage du changement de type).
- Anciens contextes : `DiscoveredPlaceContext.poi` (catégorie Plans brute) et `DiscoveredPlace.mergedIDs` sont optionnels, l'historique existant se relit tel quel. `PlaceDiscoveryRules.recommendation` (ancienne logique) est gardée pour le tri "domicile en dernier" et les anciens tests ; l'interface utilise le nouveau classeur.

## 1. Regroupement
| Règle | Valeur | Pourquoi |
|---|---|---|
| Distance de fusion | `max(150, 100 + précisionA + précisionB)`, plafond 250 m | deux bâtiments d'une même rue ; GPS bruité = plus de tolérance ; au-delà de 250 m ce sont deux lieux |
| Même bâtiment | moins de 60 m : fusion quel que soit le type | le bruit GPS d'un seul bâtiment |
| Compatibilité | même type probable, ou l'un inconnu | une boulangerie à 100 m de l'école reste à part |
| Centre | moyenne pondérée par le nombre de passages | le bâtiment le plus fréquenté pèse plus |
| Rayon | plus grande distance au centre + 40 m (demi-emprise), au moins 50 m, par 10 m, max 300 m | couvre les deux bâtiments |
| Groupes | du plus fréquenté au moins fréquenté, centre recalculé | pas d'effet de chaîne A-B-C |
| Arrêt refusé | un groupe qui contient un arrêt ignoré est ignoré | un refus vaut pour le voisin |
| Passages et jours | additionnés (deux arrêts d'un jour chacun font une suggestion) | la preuve se cumule |
| Lieu enregistré couvre | `distance + rayon suggestion <= rayon lieu + 30` : jamais proposé | marge de bruit 30 m |
| Chevauchement partiel | zones qui se touchent (+30 m) ou lieu du même type à moins de la distance de fusion : proposer d'agrandir/déplacer (cercle englobant) ; si l'englobant dépasse 300 m : masqué | pas de doublon |
| Distance apprise | écart max fusionné à la main + 20 m, plafonné à 250 | l'utilisateur a dit "ces deux-là sont pareils" |
Le regroupement est fait à l'affichage ; `consolidateDuplicates` le rend permanent (bouton "Regrouper" du bandeau). `confirm` crée UN lieu et ignore tous les arrêts du groupe.

## 2. Identification
Chaque signal ajoute des points à un type avec une raison ; score par type 0 à 100.
- Horaires (plafonnés à 69 au total par type, sauf domicile) : école = du lundi au vendredi (samedi matin toléré) 25, heure d'arrivée régulière 20, séjours de 1 à 9 h 15, sortie de midi 15, 4 jours différents 10, semaine entière absente 8. Taf = soirs 25, week-end 25, heures irrégulières 15, durées variables 10, plus de 2 h sur 3 jours 15. Courses = 70 % de passages sous 45 min : 45, +10 si 3 jours. Domicile = 3 nuits 75 (2 nuits 45). Motifs d'horaires seulement à partir de 4 passages sur 4 jours.
- Nom (accents et casse ignorés, mots entiers pour les mots courts) : lycée, collège, école, université, fac, IUT, BTS, campus, CFA : 50 ; institut, formation : 25 ; société, agence, hôpital, bureau... : taf 40 ; magasin, boulangerie, pharmacie, enseignes : courses 40 ; restaurant, café : sortie 30.
- Catégorie Plans : école ou université 45, bibliothèque 20, commerce ou service 30, hôpital 30, sortie 30, sport 40. Si le nom dit autre chose (40 ou plus), la catégorie compte moitié : le nom l'emporte.
- Ce que l'utilisateur sait : lieu de contrat (`Contract.placeUIDs`) à moins de 400 m +35 taf ; lieu taf ou école du même type à moins de 400 m +25.
- Corrections (leçons à moins de 400 m) : une réponse +45 pour le type choisi, -35 pour le type corrigé ou refusé (2 fois max) ; DEUX réponses concordantes et nettes : type imposé, score 100, les autres ramenés à 35 : elles écrasent toute heuristique. Mêmes horaires ailleurs : +20 après 2 réponses.
- Décision : confiance = meilleur score x (0,5 + 0,5 x min(1, avance/40)). Confiant à 70 ou plus : type présélectionné et "Je pense que c'est ton école, parce que ...". Sinon la carte pose "C'est ton taf, ton école ou autre chose ?" (Mon taf / Mon école / Autre) avec le pourquoi. "Pencher" : 40 points et 15 d'avance (sert au texte de la question et au regroupement). Désaccord franc entre nom/Plans (40+) et horaires (50+) : confiance plafonnée à 60 et le conflit est expliqué.
Pourquoi 69 pour les horaires seuls : un 9 h 17 h du lundi au vendredi avec pause midi est aussi un bureau. Sans nom, Plans, voisin ou réponse passée, l'app demande plutôt que de se tromper. Une seule question par lieu, et la réponse est retenue.

## 3. Apprentissage
Confirmer une suggestion, changer le type d'un lieu (`LieuDetailView`, correctif d'audit), corriger ou confirmer une session (`HabitLearning.recordFeedback` appelle `recordPlaceKind`, une session compte une fois), refuser une suggestion (`dismissSuggestion` retient ce qu'on proposait), fusionner (écart retenu). Une leçon : position, type choisi, type proposé, empreinte d'horaires, clé de remplacement ; 200 max, 365 jours.

## 4. Audit ("À vérifier")
Lieux du même type voisins (taf, cours, courses, sport) : Fusionner. Arrêts en double : Regrouper. Suggestion qui touche un lieu : Agrandir. Zones de types différents qui se chevauchent : Réduire (si les deux restent à 50 m ou plus). Type invraisemblable (nom 50 points pour un autre type, 20 ou moins pour le type enregistré, moins de 5 sessions, jamais pour un commerce où l'on travaille) : Passer en X. Le bandeau montre le plus important, "Ignorer ce point" retient l'identifiant (`plt.placeaudit.ignored`). Les correctifs enregistrent une annulation.

## Pas fait
- `Detection/*` et `GeofenceService` non modifiés : une visite détectée dans un lieu enregistré n'est pas reclassée, seules les suggestions le sont. Pas de reclassement automatique des sessions passées.
- Pas de lecture du calendrier scolaire : "vacances" = une semaine sans passage.
- Plans ne fournit qu'une catégorie par établissement ; une école avec un commerce au même point reste ambiguë.
- Fusion de lieux : les mesures de calibration (`PlaceSample`) des lieux absorbés ne sont pas reportées. L'annulation recrée les lieux absorbés avec leurs sessions, contrats et passages détectés, pas les mesures.
- Pas d'écran pour voir ou effacer les leçons (`PlaceKindStore.shared.reset()` existe).
- Tests : aucun n'a tourné (pas de toolchain). Mutation légère non faite (changer 150 en 250 doit casser `testAccuracyWidensTheMergeDistance`).
- Un test existant a été modifié : `testLargeSavedZoneDoesNotSuppressAnotherBuildingAndClearingRemovesSuggestions` (bâtiment à 61 m dans la zone de 200 m = couvert, donc le test utilise maintenant un bâtiment à 389 m ; commentaire dans le test).

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `PlaceKindClassifier.swift` : types `fileprivate` (`PlaceKindTally`) dans les signatures de `fileprivate static func` et variables locales d'un `enum` internal.
2. `PlaceKindClassifier.swift` : `ranked.sort { (a: (index: Int, type: PlaceType, score: Double), b: ...) -> Bool in ... }` et dictionnaire `[PlaceType: (weight: Double, display: String)]`.
3. `PlaceSuggestionMerge.swift` : `plan(... leaning: (DiscoveredPlace) -> PlaceType?)` passe une fermeture non échappante à `group` et appelle `leaning(...)` dans des boucles, et le tri de tuples à 4 champs étiquetés dans `plan`.
4. `PlaceFixActions.swift` : fermetures d'annulation capturant `ModelContext` et `GeofenceService` (isolation MainActor), `try? UndoSnapshots.restorePlace(...)`.
5. `DiscoveredPlaceCard.swift` / `LieuxView.swift` : `.accessibilityAddTraits(isOn ? .isSelected : [])`, `ForEach(enlargements, id: \.shape.placeID)`, `@Query private var places: [Place]` ajouté à la carte.
