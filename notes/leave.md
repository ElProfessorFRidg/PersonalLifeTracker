# leave : congés payés (section 23)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile.

## Fait
- `LeaveRules` (pur, Foundation, Calendar explicite) : période de référence, jours acquis, jours décomptés (ouvrables lundi au samedi, ouvrés lundi au vendredi), solde (acquis, pris, prévus, reste), jours à risque avec alerte, validation (fin avant début, chevauchement, hors contrat, pas de contrat), paramètres `LeaveParameters` surchargeables dans UserDefaults (clés `plt.leave.*`).
- Solde jamais ramené à zéro en silence : `remaining` peut être négatif, `isOverdrawn` et `overdrawnBy` l'expriment, l'écran affiche un bandeau.
- Écran `CongesView()` (poussé, PLTScreen), `CongesEditSheet` (ajout, modification, suppression), `CongesParamsSheet` (unité, début de période, jours par mois, plafond, alerte), `CongesFormat`. États module désactivé et pas de contrat. Annulation via `UndoCenter` (ajout, modification, suppression).
- `leave` passé en `isAvailable: true`.
- Tests : Tests/UnitTests/LeaveRulesTests.swift (valeurs à la main : 30 sur période pleine, 7 pour sept. au 17 nov., 7 pour 15 janv. au 31 mars, week-end 3 ou 2, frontière de mois 4 ou 3, changement d'heure Paris, chevauchement, solde négatif -5, alerte à 60 et 61 jours).

## Pas fait
- Resources/reference/leave.json n'existe pas : valeurs par défaut en Swift (LeaveParameters), contraire à "rien en dur" de la spec. À migrer vers le JSON quand il existera.
- Solde de départ saisi ou lu sur la fiche de paie avec date du relevé (LeaveEntry n'a pas de champ, modèle figé).
- Statuts demandé, accepté, pris (déduits de la date : pris jusqu'à aujourd'hui, prévus après).
- Jours fériés (non retirés du décompte), périodes assimilées à du travail effectif, report des jours, fractionnement, congés supplémentaires d'ancienneté ou de convention.
- Estimation de l'indemnité en euros (dixième, maintien du salaire), indemnité compensatrice de fin de CDD, mode comparaison, projection ("à ce rythme"), alertes sous forme de notifications, exclusion des congés des anomalies d'absence et des attentes de session (autres modules).
- Un congé n'appartient qu'à un employeur via `employerUID`; sans employeur renseigné il compte pour l'employeur unique.

## Valeurs légales et statut (toutes À VÉRIFIER, aucune source consultée en ligne, mémoire du Code du travail)
- 2,5 jours ouvrables par mois, plafond 30 (art. L3141-3) : à vérifier.
- Équivalent ouvrés 25 / 12 par mois, plafond 25 : à vérifier.
- Période de référence du 1er juin au 31 mai (art. L3141-4 et dispositions d'ordre public ou conventionnelles) : à vérifier, modifiable.
- Arrondi du total au jour entier supérieur (art. L3141-7) : à vérifier, désactivable (`roundUpToWholeDay`, pas encore dans l'écran).
- Mois acquis au prorata des jours couverts (le droit parle de 4 semaines ou 24 jours de travail effectif par mois) : approximation maison, à vérifier.
- Alerte 60 jours avant la fin de période : choix produit, pas une règle.

## 5 lignes les plus risquées pour la compilation
1. CongesView.swift : `@Query(sort: \LeaveEntry.startDay, order: .reverse)` sur un modèle créé par un autre agent (noms et types à confirmer).
2. CongesView.swift : `@ViewBuilder func activeContent` avec `let` locaux puis `if` et vues.
3. CongesEditSheet.swift : `.onChange(of: startDay) { (_: Date, newValue: Date) in ... }` (forme iOS 17 à deux paramètres).
4. CongesView.swift : `.sheet(item: $route)` avec un type privé `CongesRoute` et `editSheet(for:)` en `@ViewBuilder`.
5. LeaveRules.swift : `for (index, count) in covered` sur `[Int: Int]` et `min`/`max` globaux sur `Date` dans un enum à méthodes statiques.
