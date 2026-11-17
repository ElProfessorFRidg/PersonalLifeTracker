# diagnostic : écran "Fiabilité et diagnostic" (section 52, étape 2)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile.

## Fait
- `App/Core/Logic/DiagnosticRules.swift` (Foundation seulement) : `DiagInput` -> `DiagnosticRules.checks` (9 points dans un ordre fixe) et `summary` (cause = premier bloquant, sinon premier "à régler"), phrases par type d'événement (valeur brute String), familles de filtre, texte de précision.
- `App/Features/Diagnostic/DiagnosticView.swift` : `DiagnosticView()` : bandeau de synthèse, "Ce que j'ai vérifié" avec bouton de correction, "Relancer la surveillance", journal groupé par jour (heure avec secondes, précision), filtre segmenté, vidage avec confirmation, état vide.
- `ReglagesView.swift` : section avec deux NavigationLink (Diagnostic de la détection, Instantanés).
- `Tests/UnitTests/DiagnosticRulesTests.swift` : 16 tests, attendus écrits à la main.

## Pas fait
- Aucune compilation ni exécution. Aucun test d'interface.
- Pas de "Corriger la session" ni d'analyse d'un jour précis (prototype 97 : analyse par session). Ici : état actuel + journal global.
- Pas de score de fiabilité (prototype 95), hors périmètre demandé.
- Limite iOS de 20 : la règle compare le nombre de lieux enregistrés, pas ce que iOS a réellement accepté.
- "Dernier événement" sans aucun événement est classé OK (installation neuve), pas un avertissement.
- Statut "bloquant" pour : localisation différente de Toujours, aucun lieu, surveillance arrêtée ou en erreur. Le reste est "à régler".

## Risques
- `@Environment(GeofenceService.self)` plante à l'exécution si l'environnement ne l'injecte pas : l'agent géorepérage doit l'injecter à la racine (App ou RootView).
- Le contrat `DetectionEvent` (kindRaw = nom du cas Swift) est supposé : les phrases comparent à "regionEntered", etc.
- `context.delete(model:)` utilisé comme dans ReglagesView.

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `@Environment(GeofenceService.self) private var geofence` (DiagnosticView) : dépend de `@Observable` côté autre agent.
2. `@Query(sort: \DetectionEvent.date, order: .reverse)` : dépend du modèle d'un autre agent.
3. `ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in ... }` dans un PLTListGroup.
4. `try context.delete(model: DetectionEvent.self)`.
5. `InstantanesView()` dans ReglagesView (type d'un autre agent) et `PLTBannerKind` renvoyé par `bannerKind(for:)`.
