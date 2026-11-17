# core_geofence : détection par géorepérage (étape 2)

Statut : code écrit, NON COMPILÉ localement (pas de Swift ici), NON TESTÉ sur appareil. Seule la CI compile.

## Architecture
- `App/Core/Detection/DetectionEngine.swift` : machine à états pure (Foundation seulement). Entrées : entrée de zone, sortie de zone, tick. Sorties : démarrer à l'heure exacte d'entrée, arrêter à l'heure exacte de sortie, ignorer une visite courte, demander confirmation, noter une visite de courses, ignorer (session déjà en cours, sortie sans entrée), annuler un départ. Aucun arrondi, aucune horloge lue.
- `RegionSelection.swift` : choix des 20 lieux (les plus proches de la dernière position, sinon ordre de création), coordonnées invalides écartées.
- `GeofenceService.swift` : `@MainActor @Observable`, `CLLocationManager`, une `CLCircularRegion` par lieu (identifiant = UUID du lieu), `requestState` à l'enregistrement, significant-location-change si autorisation Toujours, `startUpdatingLocation` seulement pendant un délai en attente (présence minimale ou grâce) pour garder l'app vivante en arrière-plan. Callbacks `nonisolated` qui rendent la main à l'acteur principal. Avant chaque événement le moteur est resynchronisé avec la base (session en cours et son lieu), ce qui rend la relance de l'app sans état possible. Sessions créées via `SessionService`, puis `source = .gps` et `isConfirmed = false`. Chaque étape écrit une ligne `DetectionEvent`.
- `App/Core/Notifications/` : `DetectionNotificationRules` (pur : textes, zone de doute, heures silencieuses, maximum par jour) et `DetectionNotifier` (UNUserNotificationCenter, catégories, delegate, session à corriger dans `PendingCorrectionStore`, clé UserDefaults `plt.pendingCorrectionSessionUID`).
- `PersonalLifeTrackerApp.init` crée notifier et service, appelle `start()`, les garde en vie dans une liste statique et expose le service via `.environment(geofence)`.
- `project.yml` : ajout de `INFOPLIST_KEY_UIBackgroundModes: location`. Si Xcode n'accepte pas cette clé générée (non vérifié), le code reste sûr : `allowsBackgroundLocationUpdates` n'est activé que si le mode est lu dans le Info.plist du bundle.

## Seuils
| Seuil | Valeur | Origine |
|---|---|---|
| Présence minimale avant de compter une arrivée | 5 min | MON CHOIX (la spec dit "durée de présence" sans chiffre, section 8) |
| Délai de grâce avant de confirmer un départ | 3 min | MON CHOIX (section 8 : une perte de GPS n'est pas un départ) |
| Précision de confiance | 100 m (au-delà : arrivée marquée incertaine) | MON CHOIX |
| Max régions | 20 | iOS, section 8 |
| Zone de doute | :15 à :45 | spec section 13, via `FullHourRounding` |
| Notifications par jour | 6 | MON CHOIX (section 45 : "fréquence maximale par jour", sans chiffre) |
| Heures silencieuses | 22:00 à 04:59 | MON CHOIX (section 45 : "heures silencieuses", sans chiffre) |
| Courses | notées, pas de session comptée, même avec "J'y travaille aussi" | consigne de la tâche |

## Pas fait
- Aucun écran : les vues doivent appeler `refreshMonitoredPlaces()` après ajout, modification ou suppression d'un lieu (seul filet : retour au premier plan et changement d'autorisation). Elles doivent lire `PendingCorrectionStore().sessionUID` pour ouvrir la correction.
- État du moteur non persisté : un délai en attente (présence minimale, grâce) est perdu si l'app est tuée. Une session déjà démarrée est retrouvée via la base.
- Pas de CLVisit, pas de CoreMotion, pas de reconstitution des événements manqués ni de sessions "reconstituées" (section 8).
- Lieu de courses avec "J'y travaille aussi" : pas de score travail/courses (section 11), la visite est seulement notée.
- Notifications groupées (carte Maintenant) et coordinateur smart_notifications non faits : une notification par borne.
- Sortie d'un lieu pendant qu'on est dans un autre lieu qui chevauche : pas de reprise d'une entrée ignorée pendant une session.
- Permission notifications : non demandée ici (PermissionRequester s'en charge). Sans elle, rien n'est affiché.
- Une session démarrée à l'état initial "dedans" (lieu ajouté alors qu'on y est, ou relance) commence au moment de la détection, pas avant (jamais de présence inventée).
- Le service ne vérifie pas la position réelle avant d'arrêter une session : il se fie à l'événement de sortie de région.

## Seulement vérifiable sur un vrai iPhone
Le simulateur et les GPX ne prouvent jamais : relance de l'app par un événement de région, délai réel des événements iOS (souvent plusieurs minutes de retard, d'où l'horodatage exact qui peut être tardif), fonctionnement écran verrouillé, effet de l'arrêt forcé, batterie, `startUpdatingLocation` en arrière-plan, affichage des actions de notification, mode Toujours. Les tests unitaires ne couvrent que le moteur, le choix des régions, les textes et les limites.

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `App/PersonalLifeTrackerApp.swift` : `MainActor.assumeIsolated { ... created = service ... }` (capture et mutation d'une variable locale, isolation de `init` de `App`).
2. `GeofenceService.swift` : `@MainActor @Observable final class GeofenceService: NSObject, CLLocationManagerDelegate` avec `private(set) var` et `@ObservationIgnored` (macro Observation avec NSObject).
3. `GeofenceService.swift` : `guard let running = (try? service.runningSession()) ?? nil` (aplatissement de `try?`).
4. `DetectionNotifier.swift` : le `Task { @MainActor in ... completionHandler() }` dans la méthode delegate `nonisolated` (capture d'une closure non Sendable).
5. `GeofenceService.swift` : `Task { [weak self] in ... self?.tick() }` dans `scheduleTick` (héritage de l'acteur principal) et `locationManager(_:monitoringDidFailFor:withError:)` (signature avec `CLRegion?`).
