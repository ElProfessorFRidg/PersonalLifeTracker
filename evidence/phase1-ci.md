# phase:P1_ci : CI (build + tests) verte
Date : 2026-11-16
Appareil / OS / build (tag) : runner GitHub macos-latest, simulateur iPhone 17 Pro iOS 26.5, workflow pull-request sur la PR 1
Ce qui a été fait (étapes exactes) : push de la branche claude/funny-pasteur-a0v12u, PR 1 ouverte, workflow pull-request.yml (garde-fous Python, XcodeGen, xcodebuild test).
Résultat attendu (d'après la spec, section X) : phases/PHASE_1_CICD.md étape 5, workflow vert (build + tests sur simulateur).
Résultat observé (chiffres mesurés) :
- Run 43813341486 : ÉCHEC, `scripts/pick_simulator.sh: Permission denied` (droits d'exécution perdus dans le zip). Corrigé au commit d1bacae.
- Run 43813444736 : ÉCHEC, 3 tests, 1 échec : `oracles.json absent du bundle de tests` (clé `resources` ignorée par XcodeGen). Corrigé au commit bb9d411 dans project.yml.
- Run 43814312689 : SUCCÈS, https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43814312689 (check « build-test / build-test », conclusion success).
Écart : aucun sur le squelette. ci.yml (push sur main) n'a jamais tourné : la branche n'est pas fusionnée.
Verdict : OK pour build + tests en PR
Limites (ce qui n'a pas été testé) : ci.yml sur main, beta.yml, release.yml, manual-build.yml, altstore-source.yml, build de l'IPA. La session de l'orchestrateur ne peut pas pousser de tag (HTTP 403 le 2026-11-16) ni écrire ailleurs que sur sa branche.
Confirmé par l'utilisateur :
