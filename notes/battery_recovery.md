# battery_recovery : récupération après batterie vide (section 131)

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile). Module encore `isAvailable: false` dans ModuleRegistryData.swift (à basculer par l'orchestrateur).

## Fait
- `App/Core/Recovery/RecoveryPlanner.swift` (pur) : `RecoveryHeartbeat`, `RecoveryPlanner.evaluate(last:now:nowUptime:running:...) -> RecoveryDecision (.nothing(raison) | .propose(RecoveryPlan))`, `RecoveryPlanner.endDate(for:plan:customDate:)`.
- `RecoveryStore.swift` (UserDefaults JSON, clés `plt.recovery.heartbeat` et `plt.recovery.pending`), `RecoveryText.swift`, `RecoveryService.swift` (`recordHeartbeat`, `evaluateAtWake`, `RecoveryApplier.apply` avec annulation via UndoCenter), `LifecycleChecks.swift` (point d'entrée de RootView, commun avec clock_check).
- RootView : un second `.onChange(of: scenePhase, initial: true)` appelle `LifecycleChecks` (actif : évalue puis écrit l'indice ; arrière-plan : écrit l'indice). Gate par `modules.isActive`.
- Accueil : `RecoveryCardsSection(now:calendar:running:)` (RecoveryCards.swift), inséré avant la carte Maintenant. Choix : "Fin à HH:MM", "J'étais encore là", "Choisir une autre heure" (feuille bornée).
- Tests : `Tests/UnitTests/BatteryRecoveryTests.swift` (16).

## Pas fait
- Notification unique "Batterie basse pendant ta session" et activité réduite en Mode économie d'énergie (optionnels dans la spec). Le Mode économie est enregistré mais non exploité.
- Confirmation dans la revue de la semaine (section 46) : la session reste `isConfirmed = false`, c'est à l'écran de revue de la lire.
- Pas de PrivacyInfo.xcprivacy (hors périmètre) : l'API d'horloge monotone (`clock_gettime_nsec_np`, catégorie SystemBootTime, raison à déclarer) doit y figurer.
- Aucun appel depuis la détection (région, changement significatif) : voir ci-dessous.

## Seuils et origine
- Redémarrage : horloge monotone actuelle strictement inférieure à celle du dernier indice (spec 131 : redémarrage entre les indices et le premier événement). Certain, pas d'heuristique.
- Batterie "très bas" : 10 % (`RecoveryPlanner.defaultLowBatteryThreshold`). La spec ne donne pas de chiffre (exemple 4 %). CHOIX D'IMPLÉMENTATION. Batterie inconnue : pas de proposition.
- Trou minimal : 5 min (`defaultMinimumGap`). Pas dans la spec. CHOIX D'IMPLÉMENTATION, évite le bruit.
- Fin estimée = dernier indice, jamais avant le début de la session, jamais après le réveil. Heure libre acceptée seulement dans [dernier indice, réveil].

## Appels pour les autres services
Depuis le thread principal, à chaque réveil par événement (région, changement significatif, notification) :
`RecoveryService.recordHeartbeat(lastActivity: Date())`
Depuis un contexte non isolé : `Task { @MainActor in RecoveryService.recordHeartbeat(lastActivity: Date()) }`.
Ne PAS appeler `evaluateAtWake` ailleurs que dans `LifecycleChecks.sceneBecameActive` (il doit passer avant l'écriture d'un nouvel indice). Si le réveil par événement se fait sans passer l'app au premier plan, appeler `RecoveryService.evaluateAtWake(context:)` avant `recordHeartbeat`.

## Risques
- Une session qui tourne sans indice depuis son démarrage : estimation bornée au début de la session (visible dans le test).
- Le premier `UIDevice.batteryLevel` après activation du suivi peut valoir -1 (nil stocké) : l'indice d'arrière-plan corrige. NON TESTÉ sur appareil.
- `CLOCK_MONOTONIC_RAW` doit continuer de compter pendant la veille (doc Apple) : à vérifier sur appareil.
- Un redémarrage dont l'uptime dépasse l'ancien avant le premier réveil n'est pas détecté (cas rare).
- Le test d'annulation compte sur le fait que `WorkSession` non inséré ou inséré se comporte comme dans SessionServiceTests.

## 5 lignes les plus susceptibles de ne pas compiler
1. `RecoveryService.swift` : `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)` (dans SystemMonotonicClock.swift) et `UIDevice.current.batteryLevel` (isolation MainActor).
2. `RecoveryCards.swift` : `@Environment(UndoCenter.self) private var undoCenter: UndoCenter?` (même forme que SessionDetailView).
3. `RecoveryCards.swift` : closure `RecoveryCustomTimeSheet(plan:calendar:initial:) { (picked: Date) in ... }` appelant un `@MainActor` depuis un `.sheet`.
4. `RecoveryCards.swift` : `DatePicker(..., in: plan.customLower...plan.customUpper, ...)` avec `.environment(\.calendar, calendar)`.
5. `BatteryRecoveryTests.swift` : `guard case .propose(let plan) = RecoveryPlanner.evaluate(...) else` dans une expression à une ligne, et classe `@MainActor` avec `UndoCenter`.
