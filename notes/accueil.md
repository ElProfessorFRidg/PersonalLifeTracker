# accueil : Accueil + démarrage/arrêt manuel

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile).

## Fait
- `App/Core/Logic/DaySummary.swift` (pur) : `DaySessionInput`, `ActivityDayTotal`, `DaySummary.total(...)` (heures pleines ou exact, doute non résolu = exact + provisoire, session en cours = exact, coupe à minuit), `overlapsDay`, `tileValue`, `tileNote`, `NowDecision`, `DaySummary.decideNow(candidates:)` (session en cours > doute à lever > premier jour > calme).
- `App/Core/Services/SessionService.swift` : `start(activity:place:now:)` (refuse une 2e session en cours, `SessionServiceError.alreadyRunning`), `stop(_:now:)` (jamais avant le début, `.notRunning` si déjà finie), `stopRunning`, `runningSession(s)`.
- `App/Features/Accueil/` : `AccueilView` (en-tête date, carte Maintenant, carte session en cours avec `TimelineView`, bouton Démarrer, tuiles Taf/Cours, ruban + liste du jour, "Tout voir" vers `SessionsView()`, "+" vers `SessionAjoutView()` en feuille, doute vers `DouteView(session:)` en feuille, engrenage Réglages conservé), `AccueilCards.swift`, `DemarrerSheet.swift` (Taf ou Cours + lieu facultatif).
- Tests : `DaySummaryTests` (17), `SessionServiceTests` (7). Valeurs écrites à la main.

## Pas fait
- Prénom ("Salut Léo" du prototype) : le texte est "Salut !" faute de réglage prénom.
- "Pourquoi cette carte ?", "Voir les autres", "Pas maintenant", bouton "Détail des heures", bandeau "fiabilité", "prévu jusqu'à" (pas de planning).
- Pas d'état "Ajouter un lieu" dans la carte premier jour (LieuAjoutView n'est pas dans mon périmètre).
- Les lignes de la liste du jour affichent la durée entière de la session (pas seulement la part du jour), seuls les totaux coupent à minuit.
- Les sessions démarrées ici n'ont pas de notification/Live Activity/widget.

## Risques
- La liste est filtrée en mémoire sur toutes les sessions (`@Query` sans prédicat) : à optimiser si beaucoup de sessions.
- `TimelineView` 1 s tant qu'une session tourne (tout le contenu est redessiné), 30 s sinon.
- La base normalisée d'un jour coupe les bornes arrondies : une session 23:50 à 01:10 donne 0 s le premier jour et 1 h le second en heures pleines.
- Le jour affiché utilise `Calendar.current`, les sessions leur propre fuseau pour l'affichage des heures.

## 5 lignes les plus susceptibles de ne pas compiler
1. `AccueilView.swift` : `.sheet(item: $doubtSession) { session in DouteView(session: session) }` (suppose `WorkSession: Identifiable` via @Model).
2. `AccueilView.swift` : `ForEach(Array(today.enumerated()), id: \.element.uid)` avec `item.offset`/`item.element`.
3. `AccueilView.swift` : `body` avec `let` puis `return PLTScreen(...) { TimelineView(...) { content(now:) } }.toolbar...`.
4. `DemarrerSheet.swift` : `.tag(Optional<UUID>.none)` / `.tag(Optional<UUID>.some(place.uid))` dans un `Picker` lié à `UUID?`, et `.onChange(of: activity) { ... }` (forme iOS 17 sans paramètre).
5. `AccueilCards.swift` : `switch decision` dans la closure de `PLTCard` (ViewBuilder) avec `@ViewBuilder private var runningContent` contenant des `let`.
