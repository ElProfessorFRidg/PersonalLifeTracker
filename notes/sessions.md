# sessions : historique, détail, saisie manuelle, zone de doute

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile).

## Fait
- `App/Core/Logic/SessionRules.swift` (Foundation seulement) : `validate` (erreurs typées `SessionValidationError` : fin avant début, fin dans le futur, plus de 24 h, chevauchement), `overlaps` (bout à bout autorisé), `combine`, `clockWithSeconds`, `durationWithSeconds`, `needsConfirmation`, `filter` (`SessionFilter` : Tout, Taf, Cours, Courses, À confirmer), `groupByDay`, `dayLabel`, `doubtOptions` (les deux heures pleines d'une borne en doute avec la durée normalisée résultante).
- `Tests/UnitTests/SessionRulesTests.swift` : valeurs écrites à la main (06:14, 06:15, 06:45, 06:46, 23:50, minuit, fuseau Paris, 24 h pile, bout à bout).
- `SessionsView` : groupes par jour, filtres, durée dans la base de `AppSettings.calculationBase`, chip "À confirmer", "+" en feuille, états vides (aucune session, filtre vide).
- `SessionDetailView` : entête, bandeau doute, "Les heures" (secondes + heure pleine retenue), "Trois façons de compter", correction début/fin (feuille DatePicker, validation inline, pas de chevauchement), type, note, confirmer, suppression avec dialogue.
- `SessionAjoutView` : lieu (@Query) ou aucun, type, date, début, fin, "finit le lendemain" (minuit), erreurs inline, source manual.
- `DouteView` : une section par borne en doute, deux choix avec durée résultante, enregistre dans `chosenStart` / `chosenEnd`.

## Choix et écarts
- Plafond de durée à 24 h : choix de l'app, la spec 14 ne donne pas de maximum.
- Modifier une borne efface son choix de doute (il ne vaut plus pour une autre heure exacte). `startDate` / `endDate` ne reçoivent que la saisie de l'utilisateur, jamais un arrondi.
- Ligne "Planning" du détail : affiche "Aucun" (la base prévue n'existe pas encore). Les trois bases de 13.1 sont donc heures pleines, exact, planning (vide).
- Une session en cours : seul le début est modifiable.
- Pas de point d'entrée vers SessionsView : à brancher depuis Accueil (fichier hors de ma liste).
- Pas de "garder l'heure exacte" ni de "plus tard" dans DouteView (le prototype en a), pas de case "toujours pareil pour ce lieu".
- Pas de journal des modifications (section 14 non modélisée).

## Risques
- Suppression : `context.delete(session)` puis `dismiss()` ; un drapeau `isDeleted` remplace le contenu pour ne pas lire un modèle supprimé. Comportement SwiftData non vérifié.
- `NavigationLink` dans `PLTListGroup` avec `.buttonStyle(.plain)` : rendu non vérifié.
- Les tests `testDayLabels` supposent la locale fr_FR (comme `testDayTitleInFrench`).
- `@Environment(AppSettings.self)` doit être injecté par RootView (sinon crash à l'ouverture) ; les feuilles en héritent.

## Les 5 lignes les plus susceptibles de ne pas compiler
1. SessionsView : `Dictionary(sessions.map { ($0.uid, $0) }, uniquingKeysWith: { (first: WorkSession, _: WorkSession) -> WorkSession in first })`.
2. SessionsView : `@Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]`.
3. SessionDetailView : `.sheet(item: $editedBound) { (bound: EditedBound) in boundSheet(bound) }` (type `private` utilisé dans une struct internal).
4. SessionDetailView : `TextField("...", text: noteBinding, axis: .vertical)` avec `.lineLimit(1...5)`.
5. SessionAjoutView : `@State private var day: Date` sans valeur par défaut, initialisé via `_day = State(initialValue:)` dans `init()`.
