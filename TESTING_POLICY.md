# TESTING_POLICY : des tests qui prouvent quelque chose

But : savoir si l'app marche, pas faire passer la CI.

## Interdits (check_tests_integrity.py en détecte une partie, le reste c'est ta responsabilité)
- XCTSkip, XCTSkipIf, XCTSkipUnless, XCTExpectFailure, `.disabled`, `throw XCTSkip`
- Assertions triviales : XCTAssertTrue(true), XCTAssertEqual(x, x), tests sans assertion
- Attendre la valeur calculée par le code testé (circulaire) : les oracles viennent de spec/oracles.json
- Mocks qui renvoient directement la bonne réponse de la fonction testée
- Du code applicatif qui détecte XCTest / ProcessInfo environment pour changer de comportement
- Supprimer ou affaiblir un test qui échoue au lieu de corriger le code. Si le test est faux, explique pourquoi dans notes/ERREURS.md et corrige-le avec l'oracle de la spec.
- Baisser le nombre de tests sans justification (le script compare à evidence/test_count.json)
- Seuils de couverture contournés par des tests vides

## Obligatoire
- Chaque règle métier a des tests avec cas limites : 06:14, 06:15, 06:45, 06:46, minuit, changement d'heure, fuseau, session à cheval sur deux jours.
- Chaque test de bug : écrire d'abord le test qui échoue, le voir échouer (note la sortie), puis corriger.
- Tests de mutation légère à la main sur les règles clés : changer 14 en 15 dans la règle d'arrondi doit faire échouer un test. Note-le dans notes/.
- Scénarios A à CK de la section 4 : rejoués par fichiers GPX en test d'intégration, valeurs attendues écrites à la main depuis la spec.

## Niveaux de preuve
1. Tests unitaires (logique pure) : CI.
2. Tests d'intégration simulateur (GPX, scénarios) : CI ou local, preuve = log.
3. Appareil réel : seulement l'utilisateur peut confirmer. Voir REAL_WORLD_TEST_PROTOCOL.md.
Le simulateur ne prouve jamais : géorepérage en arrière-plan, relance après kill, batterie, Live Activity depuis une notification, widgets réels, caméra, notifications réelles.
