## 5. PERFORMANCE (PRIORITÉ ABSOLUE)

Démarrage : démarrage à froid optimisé, accueil affiché rapidement, jamais d'attente d'une opération GPS, chargement progressif, initialisation différée du secondaire et des modules, aucun calcul lourd sur le thread principal.
Interface : 60 FPS minimum, 120 Hz si disponible, éviter les recalculs SwiftUI inutiles, listes paresseuses, identifiants stables, états globaux limités, animations légères, pas de rechargement d'écran entier pour une modification mineure.
Architecture : Swift Concurrency, async/await, actors pertinents, caches à invalidation ciblée, accès asynchrones aux données, peu d'allocations.
Batterie : pas de GPS haute précision permanent, privilégier géorepérage et changements significatifs, réduire le suivi à l'immobilité (CoreMotion), pas de timers permanents, pas de réveils inutiles, respecter la suspension iOS.
Mesures : Instruments et XCTest (lancement, affichage, statistiques, mémoire, fluidité, énergie, plusieurs milliers de sessions, recherche). Ne pas sacrifier la fiabilité à des benchmarks artificiels.
