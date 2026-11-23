# screenshots : captures PNG des vrais écrans (CI)

STATUT : NON COMPILÉ, NON TESTÉ (écrit sans toolchain Swift). Seule la CI macOS compile. Aucune capture n'a encore été vue.

## But
Comparer les écrans SwiftUI réels à la maquette (design/prototype, design/SCREENS.md). La CI rend chaque écran en PNG et les publie.

## Comment
- `Tests/UnitTests/ScreenSnapshotTests.swift` : une méthode de test par écran (un échec n'arrête pas les autres). Rendu avec `ImageRenderer`, échelle 2, largeur 390 pt, hauteur 1700 pt (écrans qui défilent), 844 (fixes), 1200 à 2600 selon l'écran. PNG de 780 px de large.
- `Tests/UnitTests/ScreenSnapshotSeed.swift` : jeu d'exemple de la maquette (Léo, taf Supérette du Canal en cours, cours Fac de lettres, courses Marché du Canal, jours précédents dont une session en zone de doute, employeur + CDD de 13 h par semaine finissant le 9 décembre 2026, taux, créneaux prévus, un congé, journal de détection).
- Environnement : `AppModelContainer.make(inMemory: true)` + `.modelContainer`, `AppSettings` et `ModuleStore` sur un UserDefaults isolé (pas de pollution du simulateur), modules disponibles tous activés, `UndoCenter()`, `GeofenceService` construit avec un `DetectionNotifier` sans appeler `start()` (aucune localisation ni région), `.pltTheme()`, fond de la palette derrière, `NavigationStack` pour les écrans poussés (pas pour les feuilles LieuAjout, SessionAjout, Doute, qui ont la leur).
- Chaque test vérifie : image non nil, 780 px de large, hauteur attendue x 2, PNG écrit. Un écran qui ne se dessine pas est quand même sauvegardé, jamais ignoré.
- Dossier de sortie : `<dépôt>/build/screens` déduit de `#filePath` (le simulateur partage le disque de l'hôte ; les variables d'environnement de xcodebuild ne sont pas transmises au processus de test). `PLT_SCREENSHOT_DIR` l'emporte s'il est présent dans le processus de test, puis repli sur `NSTemporaryDirectory()/screens`.
- Workflow `_build-test.yml` : une étape `Upload screenshots` (artefact `screens`, `if: always()`, `if-no-files-found: ignore`) après les tests.

## Fichiers produits (dans l'artefact `screens`)
`NN-nom-light.png`, `NN-nom-dark.png`, plus `01-accueil-amoled.png`. Un `NN-nom.report.txt` par écran : taille, "image unie (vide)", "rendu sans NavigationStack". Écrans : 01 accueil, 02 lieux, 03 lieu-ajout, 04 lieu-detail, 05 sessions, 06 session-detail (session en cours), 07 session-ajout, 08 doute, 09 planning, 10 stats, 11 fonctionnalites, 12 reglages, 13 onboarding-bienvenue, 14 onboarding-modules, 15 diagnostic, 16 emploi, 17 paie, 18 contrat-heures, 19 conges, 20 instantanes.

## Limites connues (à lire avant de comparer)
- Heure : les écrans lisent `Date()` eux-mêmes, on ne peut pas figer l'horloge. Le jeu d'exemple est donc relatif à l'heure réelle de la CI (taf en cours depuis 1 h 14, cours de 11 h 05 à 7 h 08 avant "maintenant", etc.), pas "lundi 16 novembre 19:10". Si la CI tourne tôt le matin, les sessions "du matin" tombent la veille. Seules la fin du CDD (9 décembre 2026) et sa date de début (1er septembre 2026) sont fixes.
- ImageRenderer ne dessine pas les vues adossées à UIKit/MapKit : les cartes (LieuDetail, LieuAjout, calibration) restent vides ou en pastille grise ; `List`, `Form`, `TextField`, `DatePicker` peuvent apparaître en placeholder. La barre de navigation (titre large, bouton retour) risque de ne pas apparaître non plus. Si une image est entièrement unie avec NavigationStack, le test retente sans et garde le résultat (`report.txt`).
- Feuilles et sélecteurs système (`.sheet`, `Menu`, confirmations) ne s'ouvrent pas : seul l'état initial est capturé.
- Caméra (scanner de planning), permissions, notifications, Live Activity : non capturables. `onAppear` et `.task` ne s'exécutent pas : les données chargées là (Instantanés, état des permissions du Diagnostic) apparaissent vides.
- Onboarding : `OnboardingView` démarre toujours à l'étape Bienvenue (étape en `@State` privé, non pilotable depuis un test). L'étape Modules est rendue seule, sans en-tête ni barre de progression. Les autres étapes ne sont pas capturées.
- `preferredColorScheme` de `.pltTheme()` n'a probablement aucun effet dans ImageRenderer ; le sombre vient de la palette (réglage du thème) et de `\.colorScheme`, forcé à `.dark`.
- Aucune de ces captures ne prouve le comportement sur appareil (AGENTS.md section 3).
