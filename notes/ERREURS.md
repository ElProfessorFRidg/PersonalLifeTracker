# ERREURS et limites connues
(aucune pour l'instant)

## 2026-11-16 : décision de l'utilisateur, étapes enchaînées sans test sur iPhone
La section 60 et phases/PHASE_2_BUILD.md demandent que l'étape N soit utilisable sur un vrai iPhone avant l'étape N+1.
L'utilisateur a écrit : « Enchaîne sans attendre, fais tout avec sub agents Sonnet ». Les étapes 2 et suivantes sont donc
construites sur un noyau qui n'a été vu sur aucun écran. Conséquence : tous les statuts restent au plus TESTS AUTO OK,
rien n'est VÉRIFIÉ SUR APPAREIL, et un défaut du noyau peut se propager.

## 2026-11-16 : échappement CSV des retours CRLF
Le run https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43950545457
échoue sur PayExportTests.testCSVEscaping : le champ contenant CRLF est rendu sans guillemets.
Swift regroupe CRLF dans un seul Character ; contains sur les caractères CR et LF séparés ne le détecte pas.
Correction : inspecter unicodeScalars pour les séparateurs, guillemets, CR et LF.
Le test existant CRLF est conservé et un cas CR seul est ajouté. Aucun oracle modifié.
Validation locale : scripts Python et contrôle du diff ; tests Swift/iOS NON TESTÉS localement (Linux sans Swift/Xcode).
La nouvelle exécution GitHub Actions doit confirmer la correction.

## 2026-11-22 : seuil et activité par défaut dans les tests de lieux

Le [run 50](https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/45068103866) a compilé l’app et exécuté 570 tests. Deux scénarios de découvertes répétées utilisaient un arrêt de 20 minutes, qui est maintenant éligible à lui seul. Les données de test utilisent des arrêts de 15 minutes pour vérifier la répétition et l’expiration indépendamment du seuil d’un arrêt unique. Le troisième test attendait qu’un type de lieu illisible devienne « Taf ». Il vérifie maintenant que ce cas reste personnel et ne peut pas démarrer de session automatique. Le scénario d’un arrêt unique suffisamment long reste couvert séparément.
