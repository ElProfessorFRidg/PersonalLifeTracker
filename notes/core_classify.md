# core_classify : classification travail / études / courses et apprentissage (étape 3)

Statut : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile. Si la CI est rouge, corriger d'abord ici.

## Fichiers
- `App/Core/Classification/VisitClassifier.swift` : pur (Foundation). `VisitContext`, `PlannedShift`, `ClassificationResult` (activité, confiance 0 à 100, niveau, raison en français, `needsConfirmation`), `VisitClassifier.classify(_:habits:now:calendar:)`, `level(forConfidence:)`.
- `App/Core/Classification/HabitModel.swift` : pur. `HabitObservation` (valeurs simples, Codable), `HabitEvidence`, `HabitModel` (`record`, `evidence`, `prune`, `reset`, `exportedValues`).
- `App/Core/Classification/HabitStore.swift` : persistance JSON dans UserDefaults (clé `plt.habits.model`), `HabitStore.shared`, `model`, `record`, `reset`, `exportedObservations`. Aucun nouveau modèle SwiftData, `AppModelContainer` intact.
- `App/Core/Classification/HabitLearning.swift` : `recordFeedback(for: WorkSession, store:)`, ne retient que les sessions d'un lieu à double usage avec une activité travail ou courses.
- Intégration : `DetectionEngine` (nouvelle décision `.visitEnded`), `GeofenceService` (classe au démarrage d'une session taf/cours, et à la fin d'une visite à double usage), `SessionDetailView` (changement de type et bouton "C'est bon, je confirme" alimentent le `HabitStore`).

## Règles implémentées
| Règle | Section | Implémentation |
|---|---|---|
| Taf donne travail, cours donne études, courses donne courses et ne compte jamais comme du travail | 11, 12 | confiance 100, automatique, aucune habitude lue |
| Seul un lieu de courses avec "J'y travaille aussi" reçoit un score travail/courses | 11 ("un supermarché peut être lieu de travail") | `classifyDualUse` |
| Facteur 1 : correction antérieure dans un contexte similaire (lieu, même jour de semaine, heure d'arrivée à +-1 h) | 11 | `HabitModel.evidence` |
| Facteur 2 : créneau du planning | 11 | +40 si l'arrivée est dans un créneau (30 min avant le début jusqu'à la fin), -15 si des créneaux existent mais aucun ne correspond. Liste vide pour l'instant |
| Facteur 3 : moins de 20 min courses, plus de 2 h travail, entre les deux ambigu | 11 | strictement moins de 1200 s : -50 ; strictement plus de 7200 s : +50 ; 1200 s et 7200 s pile : 0 |
| Facteurs 4 et 5 : récurrence et heure de prise de poste | 11 | couverts par les réponses passées du même contexte (indice, voir ci-dessous), pas de calcul séparé |
| Seuils : plus de 75 automatique, 40 à 75 provisoire avec confirmation, sous 40 inconnu avec confirmation | 11 | `level(forConfidence:)` : 76 automatique, 75 et 40 provisoires, 39 inconnu |
| Après 3 confirmations concordantes dans un contexte, la classification est automatique pour ce contexte | 11 | les 3 dernières réponses du contexte (180 jours) identiques : activité apprise, confiance 90 |
| Jamais d'habitude à partir d'une seule visite, jamais appliquée à tous les contextes | 9, 11 | avant 3 réponses : indice de 10 points par réponse nette, plafonné à 20, ne peut pas renverser un signal de durée (50) |
| Visite non sûre : session créée non confirmée | 11 | session `isConfirmed = false` sauf niveau automatique |

## Seuils et origine
| Seuil | Valeur | Origine |
|---|---|---|
| Courte visite / longue visite | 20 min / 2 h | spec section 11 |
| Automatique / provisoire / inconnu | >75 / 40 à 75 / <40 | spec section 11 |
| Réponses concordantes pour apprendre | 3 | spec section 11 |
| Poids durée, planning (accord, désaccord) | 50, 40, 15 | MON CHOIX (la spec donne l'ordre des facteurs, pas les poids) |
| Tolérance planning avant le début du créneau | 30 min | MON CHOIX |
| Indice avant 3 réponses | 10 par réponse nette, plafond 20 | MON CHOIX |
| Confiance d'une règle apprise | 90 | MON CHOIX |
| Tolérance d'heure du contexte | +-1 h (heure d'arrivée entière) | MON CHOIX ("plage horaire proche") |
| Oubli | réponses de plus de 180 jours ignorées puis supprimées | MON CHOIX (section 9 ne chiffre pas) |
| Maximum de réponses gardées | 500 | MON CHOIX |

## Comportement dans la détection
- Taf et cours : au démarrage d'une session, le classeur donne travail ou études (inchangé, session non confirmée comme avant).
- Courses avec "J'y travaille aussi" : le moteur note toujours l'arrivée sans session (test existant inchangé). À la sortie il émet `.visitEnded(place, entered, exited)` (seulement pour ces lieux). `GeofenceService` classe avec la durée réelle : courses au-dessus de 75 : visite notée, aucune session ; sinon une session terminée est créée (activité provisoire ou "Autre" si inconnu, à confirmer). Travail au-dessus de 75 : session créée déjà confirmée (section 11 : "sans question"). Pas de session créée si une autre tourne.
- Une même session corrigée plusieurs fois ne compte qu'une fois dans l'apprentissage (la dernière réponse remplace).

## Pas fait
- Planning : aucun créneau n'est fourni (liste vide) tant que le module planning n'existe pas.
- Facteur 6 (arrivée directe depuis le lycée ou le domicile) et analyse des activités précédentes et suivantes : non faits.
- Types "visite personnelle", "passage", "déplacement professionnel" : non classés (seulement travail, études, courses, inconnu).
- La raison n'est pas stockée sur la session : l'écran "Pourquoi cette classification ?" n'existe pas, la raison est seulement écrite dans le journal de détection.
- Pas d'écran pour voir ou remettre à zéro les habitudes : `HabitStore.shared.reset()` et `exportedObservations()` existent mais aucun bouton.
- Pas de reclassement d'une visite quand l'utilisateur change le type d'un lieu.
- La classification d'une session taf/cours en cours ne change jamais (pas de score pour ces lieux).
- Rien n'a été testé sur appareil.

## Risques
- La classification d'un supermarché où l'on travaille ne se fait qu'à la sortie (durée connue) : si la sortie n'est jamais détectée, aucune session n'est créée.
- Une arrivée de moins de 5 min est ignorée (seuil du moteur) avant même la classification.
- `Calendar.current` est utilisé à l'exécution pour le jour et l'heure du contexte ; les tests fixent un calendrier UTC explicite.
- Tests : 35 dans `ClassificationTests.swift`, 4 ajoutés à `DetectionEngineTests.swift`, aucun assertion existante modifiée. Mutation légère à la main non faite (changer 20 en 30 minutes ferait échouer `testDurationJustUnderTwentyMinutesIsProbablyShopping`, non vérifié par exécution).

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `HabitModel.swift` : `observations.removeAll { (existing: HabitObservation) -> Bool in ... }` (fermeture trailing avec type explicite sur `removeAll(where:)`).
2. `VisitClassifier.swift` : la raison apprise écrite en deux littéraux concaténés par `+` en début de ligne dans un appel `ClassificationResult(...)`.
3. `HabitStore.swift` : `static let shared: HabitStore = HabitStore()` (variable globale non Sendable, au pire un avertissement) avec valeurs par défaut `UserDefaults.standard`.
4. `GeofenceService.swift` : `let running: WorkSession? = (try? service.runningSession()) ?? nil` dans `classifyDualUseVisit` (même forme que la ligne existante de `feed`).
5. `ClassificationTests.swift` : `XCTAssertEqual(HabitLearning.learnedLabel(for: .work), true)` (comparaison d'un `Bool?` à un littéral) et `habits.observations[0]` après `learn(&habits, ...)` avec paramètre `inout` dans une méthode privée de XCTestCase.
