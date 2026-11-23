# Assistant de configuration (setup_assistant)

Retour d'usage : rien n'aide à configurer l'app, rien ne se configure tout seul. L'assistant lit l'état réel et propose des actions en un tap.

## Fichiers
- `App/Core/Logic/SetupChecklist.swift` : règles pures (faits en valeurs simples, 7 étapes, statuts done / todo / blocked / notApplicable, progression, règle d'affichage de la carte).
- `App/Core/Services/SetupAutomation.swift` : `SetupFactsBuilder` (état réel vers faits), `SetupDismissal` (« Plus tard » dans UserDefaults), `SetupAutomation` (actions en un tap).
- `App/Features/Setup/SetupAssistantView.swift` (écran poussé, sans argument) et `SetupCard.swift` (carte de l'Accueil).
- Accueil : `SetupCard()` sous les cartes de récupération. Réglages : ligne « Assistant de configuration » en tête.

## Étapes (dans l'ordre)
1 Localisation « Toujours » (bloquée si « Pendant l'utilisation » ou refusée, action : réglages iOS). 2 Notifications. 3 Premier lieu de type taf. 4 Employeur et contrat (emploi actif). 5 Taux horaire (paie active, bloqué sans contrat). 6 Planning (planning_ocr actif). 7 Heures du contrat (contract_hours actif, bloqué sans contrat, fait quand un contrat a des heures par semaine > 0).

## Automatique (« Tout configurer pour moi »)
Active les modules recommandés livrés (employment, pay, contract_hours, planning_ocr, place_discovery) via `ModuleStore.setEnabled`, demande localisation puis notifications via `PermissionRequester`, crée un lieu taf « Mon taf » à la position actuelle (`currentCoordinate`, rayon `PlaceRules.defaultRadius`), crée « Mon employeur » + contrat CDI à 0 h. Rien de légal n'est inventé : type (CDI/CDD) et heures sont saisis dans le compte rendu, le nom du lieu aussi. Le taux horaire et le planning restent manuels.
Annulation : un seul `UndoCenter.register` supprime lieux et employeurs créés et éteint les modules allumés.

## « Plus tard »
`SetupDismissal` garde le drapeau et les étapes de permission bloquées à ce moment. La carte revient si une autre permission se bloque (règle `shouldShowCard`, testée).

## Limites connues
- Brouillons (nom du lieu, contrat) gardés en mémoire : si tu quittes l'écran avant de confirmer, le lieu garde « Mon taf » et le contrat reste à 0 h (l'étape Heures du contrat le rappelle).
- Un contrat à 0 h est un brouillon en base : non vérifié que tous les écrans le gèrent. NON TESTÉ (pas de compilateur ici).
