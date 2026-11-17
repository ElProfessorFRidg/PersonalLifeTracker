# core_models : architecture du noyau (Phase 2, étape 1)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI macOS compile. Si la CI rouge, corriger d'abord ici.
Cible : iOS 17.0, SWIFT_VERSION 5.0. Tous les .swift sous App/ sont dans l'app, ceux sous Tests/UnitTests dans les tests (XcodeGen, project.yml non modifié).

## Dossiers
```
App/PersonalLifeTrackerApp.swift   @main : ModelContainer + AppSettings + ModuleStore dans l'environnement
App/RootView.swift                 RootView (onboarding ou onglets, applique .pltTheme()), MainTabView, enum AppTab
App/Core/Models/                   Enums.swift, Place.swift, WorkSession.swift, AppModelContainer.swift (SwiftData)
App/Core/Logic/                    Pur (Foundation seulement) : SessionDurations, DayTimeline, Formatting (+ MoneyFormat)
App/Core/Time/FullHourRounding.swift  règle 13.1 (existant, inchangé)
App/Core/Modules/                  ModuleRegistry.swift (types + ModuleRules), ModuleRegistryData.swift (108 modules), ModuleStore.swift
App/Core/Settings/AppSettings.swift   AppSettings, ThemeChoice, Density, Currency
App/Core/Design/                   Theme.swift (GÉNÉRÉ, ne pas toucher) + composants SwiftUI
App/Core/Services/                 vide (étape 2+)
App/Features/<Feature>/            Accueil, Lieux, Sessions, Fonctionnalites, Reglages, Onboarding, Planning, Stats
Tests/UnitTests/                   un fichier de tests par brique + TestSupport.swift (dates de test)
```

## Types clés (API en une ligne)
Modèles (SwiftData, enums stockés en String brut `xxxRaw`, accesseur typé à côté) :
- `PlaceType { taf, cours, courses }` : `.title`, `.defaultActivity`, `.tone`, `.symbolName`.
- `ActivityType { work, education, shopping, personal, travel, unknown }` : `.title` ("Taf", "Cours", "Courses", "Perso", "Trajet", "Autre"), `.tone`, `.chipKind`, `.symbolName`.
- `SessionSource { gps, manual }`, `CalculationBase { fullHours, exact }` (`.title`).
- `Place(name:type:latitude:longitude:radius:address:alsoWorksHere:)` : `uid, name, type, latitude, longitude, radius (m, défaut 100), address, alsoWorksHere, createdAt, sessions`. Supprimer un lieu garde ses sessions (`place` devient nil).
- `WorkSession(activity:start:end:place:source:isConfirmed:note:)` : `uid, activity, startDate, endDate (nil = en cours), chosenStart, chosenEnd (choix dans la zone de doute, jamais l'arrondi automatique), source, isConfirmed, note, timeZoneID, createdAt, place`. Calculés : `isOngoing, calendar, effectiveEnd(now:), exactSeconds(now:), normalizedMinutes(now:) -> Int?, hasUnresolvedDoubt, timelineInput`. `startDate`/`endDate` ne sont JAMAIS modifiés par l'arrondi.
- `AppModelContainer.make(inMemory: Bool = false) throws -> ModelContainer` (app et tests), `makeForApp()` (disque, repli mémoire).

Logique pure (aucun import SwiftUI/SwiftData) :
- `SessionDurations.exactSeconds(start:end:)`, `.normalizedBound(_:calendar:) -> Bound(.rounded(Date)|.doubt)`, `.doubtChoices(for:calendar:) -> DoubtChoices?(floor, ceil)`, `.resolvedBound(exact:chosen:calendar:)`, `.hasUnresolvedDoubt(...)`, `.normalizedSeconds/Minutes(start:end:chosenStart:chosenEnd:calendar:) -> Int?` (nil si doute sans choix), `.retained(base:start:end:chosenStart:chosenEnd:calendar:) -> (seconds, isProvisional)`. Un choix est ignoré si la borne n'est pas en zone de doute. Les durées sont des écarts d'instants réels (minuit et changement d'heure corrects).
- `DayTimeline.segments(day:inputs:now:calendar:) -> [DaySegment]` (heures décimales 0 à 24, coupe à minuit, fin nil = en cours/`isLive`), `.visibleRange(segments:) -> HourRange`, `.nowHour(day:now:calendar:)`, `.summary(segments:)` (phrase VoiceOver). Entrée : `DayTimelineInput(start:end:activity:isDoubt:)`.
- `Formatting.duration(minutes:)` "3 h 04" / "25 min", `.duration(seconds:)` (tronque), `.clock(_ date, calendar:)` "17:56", `.clock(minutesFromMidnight:)`, `.clock(hour:)`, `.timer(seconds:)` "1:14:07", `.margin(minutes:)`, `.dayTitle(_:calendar:)` "lundi 16 novembre".
- `MoneyFormat.format(amount:symbol:fractionDigits:)` : "1 234,50 €" (espace fine U+202F pour les milliers, U+00A0 avant le symbole).

Modules :
- `ModuleDefinition(id,title,summary,step,defaultOn,requires,isAvailable,isMandatory)`. `ModuleRegistry.all` (noyau `core` d'abord, puis les 108 lignes de spec/MODULES.md), `.definition(for:)`, `.defaultEnabledIDs`, `.mandatoryIDs`, `.modules(step:)`.
- `ModuleRules.enabling/disabling(_:in:registry:)`, `.requirements(of:)`, `.dependents(of:)`, `.missingRequirements(for:enabled:)`, `.activeDependents(of:enabled:)` : fonctions pures, transitives, noyau jamais retiré.
- `ModuleStore` (@Observable, UserDefaults clé `plt.modules.enabled`) : `enabledIDs`, `isEnabled(id)`, `isActive(id)` (activé ET `isAvailable`), `setEnabled(id, on)` (applique les dépendances), `resetToDefaults()`.
- Livrer un module : passer `isAvailable: true` dans ModuleRegistryData.swift (une ligne). Les `summary` de la plupart des modules sont encore égaux au titre (seuls ~45 ont une vraie phrase) : à réécrire.

Réglages : `AppSettings` (@Observable, propriétés calculées sur UserDefaults) : `themeChoice (ThemeChoice: auto, light, dark, amoled "Noir pur")`, `currencyCode`, `currency: Currency` (code, symbol, name, fractionDigits ; EUR CHF CAD USD GBP XOF MAD TND), `calculationBase`, `density (Density)`, `reduceAnimations`, `hasCompletedOnboarding`, `formatMoney(_ amount: Double) -> String`, `resetToDefaults()` (ne touche pas l'onboarding). `ThemeChoice.themeMode(systemIsDark:) -> ThemeMode`.

## Lire réglages, palette, modules depuis une vue
```swift
@Environment(AppSettings.self) private var settings      // @Bindable var settings = settings  puis $settings.themeChoice
@Environment(ModuleStore.self) private var modules       // modules.isActive("notes")
@Environment(\.palette) private var palette              // Palette générée (palette.accent, .surface, ...)
@Environment(\.pltDensity) private var density           // Density
@Environment(\.pltReduceAnimations) private var reduceAnimations
@Environment(\.modelContext) private var context         // SwiftData ; @Query var places: [Place]
```
La palette est posée par `.pltTheme()` (dans RootView), les feuilles en héritent. Ne jamais mettre de couleur en dur : `palette.x` ou `PLTTone`.
Dans les `#Preview`, il faut `.environment(AppSettings())` avant `.pltTheme()`... soit : `View().pltTheme().environment(AppSettings())`.

## Composants (App/Core/Design)
- `PLTScreen(title:) { ... }` fond + scroll + marges + titre de navigation. `PLTCard(isNow:) { }`, `PLTListGroup { PLTRow(...) }`, `PLTSectionHeader(title:actionTitle:action:)`.
- `PLTRow(symbol:tone:title:subtitle:value:showsChevron:showsSeparator:action:)` (bouton si `action`, 44 pt min, valeur en chiffres mono).
- `PLTChip("Taf", kind: .work|.study|.errand|.doubt|.neutral)`, `PLTTone` (`color(palette)`, `soft(palette)`).
- Styles : `.buttonStyle(.pltPrimary)`, `.pltSecondary`, `.pltDestructive` (44 pt, pleine largeur).
- `PLTEmptyState(symbol:title:message:actionTitle:action:)`, `PLTBanner(kind: .error|.warning|.info, title:message:actionTitle:action:)`, `ReliabilityBadge(.high|.mid|.low)`.
- `HourRibbon(segments:range:nowHour:summary:)`, `StatTile(label:value:note:tone:)`.
- Chiffres, heures, durées, montants : `.font(.body.monospacedDigit())`. Textes en styles système (Dynamic Type), jamais de taille fixe.

## Ajouter un écran
1. Un fichier dans `App/Features/<Feature>/` (le fichier existe déjà pour les stubs : le remplir, garder le nom du type et l'init).
2. Écrans poussés (détails, Sessions, Réglages, Fonctionnalités) : pas de NavigationStack propre, `PLTScreen`, ouverts avec `NavigationLink`. Feuilles (`LieuAjoutView`, `SessionAjoutView`, `DouteView`) : portent leur NavigationStack et un bouton Fermer (`dismiss`), présentées avec `.sheet`. Onglets : RootView.swift met chaque racine dans sa NavigationStack.
3. Données : `@Query` (SwiftData) ou `@Environment(\.modelContext)`. Pas de logique métier dans les vues : la mettre dans `App/Core/Logic` (pur) et la tester.
4. Textes en français, tutoiement, jamais de tiret cadratin, pas d'emoji. Cibles 44 pt, `accessibilityLabel` sur tout bouton icône.
5. Un module optionnel : n'afficher ses entrées que si `modules.isActive("id")`.
Navigation actuelle : Accueil (bouton engrenage `Réglages` à garder) > ReglagesView > FonctionnalitesView. SessionsView n'a pas encore de point d'entrée (à brancher depuis Accueil). ReglagesView est déjà fonctionnelle pour thème, densité, animations, devise, base de calcul (demande utilisateur).

## Conventions
Enums stockés en String brut dans SwiftData (jamais de Codable enum direct, pour les prédicats). Heures 24 h `17:56`, durées `3 h 04`. Pas de force unwrap hors tests. Aucun code applicatif ne détecte XCTest. Tests : valeurs écrites à la main depuis la spec, pas de XCTSkip.

## Pas fait
Écrans réels (tous des stubs sauf Réglages minimal), CapabilityService, démarrage/arrêt manuel, géorepérage, export JSON, écran État de l'app, couleur d'accent et couleurs d'activité personnalisables, formats 12 h, icône alternative. Le réglage "base de calcul" est stocké mais rien ne le lit encore. Pas de PrivacyInfo.xcprivacy. Journal des modifications (section 14) non modélisé. Source de session limitée à gps/manual. `Place` n'a ni catégorie Domicile/Commerce ni horaires habituels.

## Risques connus (tout est NON COMPILÉ)
- `@Relationship(deleteRule:.nullify, inverse:)` déclaré d'un seul côté (Place.sessions) : comportement SwiftData de l'inverse jamais vérifié, test `testDeletingAPlaceKeepsItsSessions` à surveiller.
- `AppSettings` utilise `access(keyPath:)` / `withMutation(keyPath:_:)` générés par `@Observable` dans des propriétés calculées.
- `@Bindable var settings = settings` dans le `body` de ReglagesView.
- Styles de bouton avec `@Environment` et extensions `ButtonStyle where Self == ...` (`.pltPrimary`).
- Le test `testDayTitleInFrench` suppose que la locale fr_FR est disponible dans le simulateur.
- Modèles @Model non insérés dans un contexte utilisés dans les tests (WorkSession(...) seul).
- Mutation légère à la main (changer 14 en 15 dans FullHourRounding) : non faite ici, à noter quand un build sera possible.
