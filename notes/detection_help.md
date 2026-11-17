# detection_help : assistant "Pourquoi l'app a raté ça ?" (section 132, étape 3)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile. `isAvailable` du module est encore à false dans ModuleRegistryData.swift (à basculer par l'orchestrateur).

## Fait
- `App/Core/Logic/MissAnalysis.swift` (Foundation seulement) : entrées en valeurs simples (`MissInput` : question, fenêtre, événements `MissEvent`, capacités au moment `atTime` (optionnel) et actuelles `now`, rayon, session). Sorties : `MissResult` avec verdict (causes, rien d'anormal, je ne sais pas, session manuelle), causes classées (confiance, explication en français, correctif), 7 points vérifiés (ok / à régler / bloquant / inconnu) et texte du bandeau.
- `App/Features/Diagnostic/DepannageView.swift` : `DepannageView(session: WorkSession?)`. Étape 1 (4 questions, sélecteur de session récente ou jour + lieu quand session nil, bouton Analyser), étape 2 (carte contexte, "Ce que je pense", "Autres pistes", "Ce que j'ai vérifié" avec boutons de correctif, "Relancer le suivi", "Corriger la session" vers `SessionDetailView`). Correctifs réels : ouvrir les réglages iOS, agrandir le rayon du lieu (puis `refreshMonitoredPlaces`), relancer le suivi. Aussi `DepannageEntryRow`.
- `DiagnosticView.swift` : ajout de `@Environment(ModuleStore.self)` et de l'entrée "Pourquoi j'ai raté ça ?" sous condition `modules.isActive("detection_help")`.
- `Tests/UnitTests/MissAnalysisTests.swift` : 23 tests, attendus écrits à la main (scores et ordres du tableau ci-dessous).

## Pas fait (honnête)
- Pas d'historique daté des capacités (spec 132 : journal des changements, purge à 30 jours). Il faudrait un nouveau modèle SwiftData (fichier hors de mon périmètre). La vue passe donc `atTime = nil` : les réglages cités sont ceux d'aujourd'hui, la confiance baisse d'un cran et le texte le dit. Le moteur sait déjà exploiter `atTime` (testé).
- Pas d'analyse des modes actifs (vacances, "Pas aujourd'hui", période bloquée), du réseau ni de la batterie basse : pas de données.
- Pas de détection d'un forçage à quitter (aucune preuve disponible dans le journal).
- Pas d'écran d'analyse animé (squelette du prototype) : l'analyse est instantanée, un état de chargement serait trompeur.
- Pas de lien vers l'auto-calibration (130) ni la récupération batterie (131).
- Aucun test d'interface. Rien vérifié sur appareil.

## Seuils et origine (tous MON CHOIX, la spec ne donne aucun chiffre)
| Seuil | Valeur |
|---|---|
| Fenêtre étudiée | 1 h avant le début, 1 h 30 après la fin (ou maintenant si en cours) ; jour entier sans session |
| Rayon serré | moins de 80 m |
| Rayon large (session pour rien) | 200 m et plus |
| GPS imprécis | pire précision >= max(50 m, 75 % du rayon) ; sans rayon connu : > 100 m |
| Retard d'événement | 5 min et plus (événement reçu après l'heure de la session) |
| Simple passage | session de moins de 10 min |
| Agrandissement proposé | 40 m, plafonné au rayon max 300 m (PlaceRules) |
| Confiance | base par cause (forte : localisation, arrière-plan, erreur de surveillance ; moyenne : économie d'énergie, position exacte, GPS imprécis, retard, passage ; faible : rayon) ; un cran de moins si le réglage vient d'aujourd'hui |

Scores (départ manqué / arrivée manquée / heure décalée / pour rien) : localisation refusée 95/95/80/0, Pendant l'utilisation 90/90/60/0, erreur de surveillance 88/88/45/0, arrière-plan coupé 85/80/55/0, économie d'énergie 55/50/65/0, GPS imprécis 60/60/60/70, position exacte 58/58/50/60, retard iOS 0/0/75/0, passage 0/0/0/65, rayon serré 50/45/40/0, rayon large 0/0/0/45, signal faible (seul, quand rien d'anormal) 20. Égalité : ordre de déclaration de `MissCauseID`. Une session `manual` n'est jamais reprochée à la détection.

## Risques
- Le contrat `DetectionEvent.kindRaw` (nom du cas Swift) est supposé : `MissAnalysis` compare à "regionEntered", "monitoringFailed", etc.
- `@Environment(GeofenceService.self)` et `@Environment(ModuleStore.self)` plantent à l'exécution s'ils ne sont pas injectés (comme DiagnosticView).
- Le filtre des événements par `placeName` ignore deux lieux de même nom.
- Une session GPS sans événement dans le journal (journal vidé) donne "je ne sais pas" même si un réglage actuel est mauvais : voulu, les points restent affichés.

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `ForEach(Array(MissQuestion.allCases.enumerated()), id: \.element) { index, item in ... }` (DepannageView, avec `action:` dans PLTRow).
2. `Picker("Lieu concerné", selection: $dayPlaceUID)` avec `.tag(UUID?.none)` / `.tag(UUID?.some(item.uid))`.
3. `@ViewBuilder private var analysisSections: some View` contenant des `let` puis des appels de fonctions de vue.
4. `NavigationLink { SessionDetailView(session: s) } label: { Text(...).background(palette.accentSoft, in: RoundedRectangle(...)) }`.
5. `MissAnalysis.window(...)` renvoyant un tuple nommé `(start: Date, end: Date)` et `fix.kind != .none` sur l'enum `MissFixKind` à valeur associée (Equatable synthétisé).
