## 59. TESTS

Suite XCTest réelle, données déterministes :
- Modularité : noyau seul avec tous les modules désactivés, activation et désactivation, dépendances, aucune permission demandée par un module désactivé, aucune notification d'un module désactivé, données conservées après désactivation.
- Géolocalisation : arrivée, départ, GPS imprécis, perte temporaire, visite courte, récurrente, pause, reconstitution après arrêt.
- Classification : travail, courses, études, visite, passage, inconnu, journée mixte, apprentissage des corrections, seuils 40 et 75.
- OCR : tableau simple, plusieurs personnes, initiales, heures ambiguës, dates manquantes, reconstruction, correction, lecture d'un IDCC et de lignes de fiche de paie, lecture d'un contrat.
- Horaires : arrondis, incertitudes, confirmation, valeurs originales conservées, apprentissage, trois bases de calcul (exacte, normalisée, prévue), horodatages à la seconde avec fuseau, changement d'heure, traversée de minuit, sources et marges d'erreur, frontières de majoration, zone de doute (minutes 15 à 45), propositions groupées, valeur provisoire marquée à choisir, apprentissage après 3 choix concordants.
- Tests des modules : chaque module livre ses tests, listés dans MODULES.md (annexe D). Un module n'est pas terminé sans eux.
- Onboarding complet avec chaque préréglage de modules.
- Données : création, modification, suppression, migration, export, restauration, synchronisation, conflits.
- Capacités : toutes les combinaisons importantes avec un CapabilityProvider simulé.
- Performance : plusieurs milliers de sessions, chargement, navigation, statistiques, recherche, mémoire, thread principal.
- Scénarios A à CK en tests d'intégration.
