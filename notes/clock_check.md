# clock_check : contrôle de l'horloge (section 140)

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile). Module encore `isAvailable: false` dans ModuleRegistryData.swift.

## Fait
- `App/Core/Clock/ClockChecker.swift` (pur) : `ClockObservation(wall, uptime, timeZoneID, utcOffsetSeconds)`, `ClockChecker.compare(previous:current:toleranceSeconds:) -> ClockCheckResult(rebootDetected, jump, timeZoneChange)`, `ClockChecker.isAffected(...)`, `ClockChecker.observation(wall:uptime:timeZone:)`.
- `ClockCheckService.swift` : `ClockCheckService.observe(context:)` (indice, comparaison, alerte JSON, marquage `isConfirmed = false` des sessions qui chevauchent la fenêtre du saut), `ClockCheckStore` (clés `plt.clock.observation`, `plt.clock.alert`, `plt.clock.toleranceSeconds`). `SystemMonotonicClock.swift`, `ClockText.swift`.
- RootView : via `LifecycleChecks` (voir notes/battery_recovery.md), observation à l'activation et en arrière-plan.
- Accueil : bandeaux `PLTBanner` (saut en avertissement, fuseau ou heure d'été en info), bouton "Compris" qui masque l'alerte.
- Tests : `Tests/UnitTests/ClockCheckTests.swift` (15).

## Pas fait
- (b) dérive par rapport aux horodatages des positions : à vérifier sur appareil réel, non implémentée.
- Notification unique "Ton horloge semble décalée de 4 min" et ligne d'avertissement dans "État de l'app" : l'alerte est lisible via `ClockCheckStore().loadAlert()` (propriété `isDismissed`), à brancher par le propriétaire de ces écrans.
- Correction des horodatages après confirmation (valeur d'origine, journal des modifications, journal infalsifiable section 98) : NON FAIT. Les horodatages ne sont jamais réécrits, les sessions concernées sont seulement marquées "à vérifier".
- Pas d'écran pour régler le seuil (la clé existe, défaut 30 s).
- Pas de PrivacyInfo.xcprivacy : déclarer l'API d'horloge monotone (SystemBootTime, raison requise).

## Seuils et origine
- Saut : |écart mural - écart monotone| strictement supérieur à 30 s (spec 140 (a), défaut réglable). Exactement 30 s est toléré.
- Redémarrage (monotone qui diminue) : résultat "inconnu" (`rebootDetected`), jamais un saut.
- Fuseau : id différent = `.zone`, même id avec décalage UTC différent = `.daylightSaving` (spec 140 (c)). Informatif : les instants ne bougent pas, aucune session n'est marquée.
- Sessions concernées : celles qui chevauchent la fenêtre entre les deux indices (session en cours : fin = maintenant). CHOIX D'IMPLÉMENTATION.

## Appel pour les autres services
Depuis le thread principal, à chaque événement de détection : `ClockCheckService.observe(context: modelContext)`. Pour lire l'alerte (État de l'app) : `ClockCheckStore().loadAlert()`.

## Risques
- Plus l'intervalle entre deux indices est long, plus la fenêtre marquée est large (sessions marquées à tort si l'utilisateur a changé l'heure puis l'a remise).
- Une resynchronisation automatique réseau après une longue veille peut produire un petit saut légitime au-dessus de 30 s : faux positif possible. NON TESTÉ sur appareil.
- `CLOCK_MONOTONIC_RAW` doit compter pendant la veille : à vérifier sur appareil, sinon faux sauts après chaque veille.
- Les alertes précédentes sont écrasées par la suivante.

## 5 lignes les plus susceptibles de ne pas compiler
1. `SystemMonotonicClock.swift` : `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)`.
2. `ClockCheckService.swift` : paramètre par défaut `uptime: TimeInterval = SystemMonotonicClock.uptime()` dans une fonction `@MainActor static`.
3. `RecoveryCards.swift` : `@ViewBuilder private func clockCards(_:) -> some View` avec deux `if let` consécutifs.
4. `ClockCheckTests.swift` : `XCTAssertEqual(r.timeZoneChange?.kind, .zone)` (comparaison d'optionnel avec membre implicite).
5. `ClockCheckTests.swift` : `XCTAssertEqual(r.jump?.shiftSeconds ?? 0, 31, accuracy: 0.001)`.
