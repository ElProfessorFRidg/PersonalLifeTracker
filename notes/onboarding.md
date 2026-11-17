# onboarding : onboarding de base (7 étapes)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift. Seule la CI compile.

## Fait
- 7 étapes du prototype (00 à 06) : Bienvenue (+ feuille "Et mes données ?"), Modules (préréglages Essentiel / Complet / Je choisis, noyau obligatoire, 16 modules du prototype en interrupteurs via ModuleStore, "Bientôt" pour les non livrés mais présélection permise), Localisation (explication, puis whenInUse puis Always, état toujours / limitée / refusée, bouton réglages iOS), Notifications, Photos (explication seule, seulement si planning_ocr), Premier lieu (Taf ou Cours, position actuelle, Place créée avec rayon par défaut 100 m), Récap (modules, localisation, notifications, lieu, avertissements, bouton `onDone`).
- Barre de progression, Retour, "Plus tard" sur localisation, notifications, photos, lieu. Rien ne bloque.
- `OnboardingFlow` (pur) : étapes, next/previous, position, progression, préréglages, détection de préréglage, avertissements.
- `PermissionRequester` (@MainActor, @Observable, CLLocationManager + UNUserNotificationCenter, `currentCoordinate()`, `openSystemSettings()`).
- Tests : `Tests/UnitTests/OnboardingFlowTests.swift` (valeurs écrites à la main, registre synthétique pour la cascade).

## Pas fait
- Aucune compilation, aucun test lancé, aucun essai sur appareil (les fenêtres iOS ne se testent pas au simulateur de façon fiable).
- Lieux de cours et domicile multiples, adresse saisie (le prototype demande une adresse : ici seule la position actuelle est utilisée, pas de géocodage).
- Prénom dans le titre du récap ("C'est prêt, Léo") : pas de profil.
- Aperçu de notification du prototype, maquettes de fenêtres iOS (inutiles, les vraies fenêtres s'affichent).
- Pas de `#Preview`.

## Choix
- Essentiel = valeurs par défaut du registre moins les 16 modules proposés à l'étape 2 (et tout module qui en dépend, ex. schedule_archive). Dans le prototype, "Essentiel" décoche tout dans la liste : même résultat sur les 16, mais les ~90 autres modules par défaut du registre restent actifs. Complet = tout le registre.
- Les préréglages s'appliquent en désactivant puis activant chaque module via `ModuleStore.setEnabled` (une écriture UserDefaults par module, ~110 : acceptable).
- Le champ "adresse" n'existe pas : `Place.address` reste vide.

## Fichier partagé / project.yml
- Aucune modification. Clés Info.plist suffisantes (When In Use + Always And When In Use). NSMotion non utilisé. Pas de clé photos (aucune demande à cette étape).
- Mode "location" en arrière-plan (UIBackgroundModes) non nécessaire pour l'onboarding, mais le sera pour le géorepérage : à vérifier par l'étape correspondante.

## Risques
- `@State private var permissions: PermissionRequester = PermissionRequester()` : init @MainActor appelé depuis un initialiseur de propriété de View (OK si View est isolée @MainActor, Xcode 16+ ; sinon erreur d'isolation).
- `@MainActor @Observable final class PermissionRequester: NSObject, CLLocationManagerDelegate` avec méthodes `nonisolated` du delegate.
- `withCheckedContinuation` dans un contexte @MainActor avec `Task { @MainActor [weak self] in ... }` dans la fermeture.
- iOS peut ne jamais afficher la seconde fenêtre "Toujours" tout de suite : on n'attend que 2 s, l'état observé se met à jour ensuite.
- Limite de `requestLocation()` : 10 s puis abandon (message d'erreur, l'utilisateur peut passer).

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `OnboardingView.swift` : `@State private var permissions: PermissionRequester = PermissionRequester()`
2. `PermissionRequester.swift` : `@MainActor @Observable final class PermissionRequester: NSObject, CLLocationManagerDelegate`
3. `PermissionRequester.swift` : `let result: PermissionCoordinate? = await withCheckedContinuation { (continuation: CheckedContinuation<PermissionCoordinate?, Never>) in ...`
4. `OnboardingModulesStep.swift` : `@ViewBuilder private func moduleGroup(...)` avec `let defs` suivi d'un `if` (ViewBuilder avec déclaration locale).
5. `OnboardingView.swift` : `let position = OnboardingFlow.position(...)` (tuple étiqueté) dans `header`, puis `if let position = position` avec accès `.number` / `.total`.
