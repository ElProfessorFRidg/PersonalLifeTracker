# phase:P1_beta et phase:P1_altstore : pré-release avec IPA, source AltStore bêta
Date : 2026-11-16
Appareil / OS / build (tag) : GitHub Actions, tag v0.0.1-beta.1 sur le commit ad69610 (squelette technique)
Ce qui a été fait (étapes exactes) : push de release/BETA_VERSION contenant `v0.0.1-beta.1` sur la branche claude/funny-pasteur-a0v12u ; beta.yml (modifié ce jour pour ce déclencheur) a enchaîné prep, build-test + IPA, publish, altstore-source.
Résultat attendu (d'après la spec, section X) : phases/PHASE_1_CICD.md étapes 6, 9, 10.
Résultat observé (chiffres mesurés) :
- Run https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43836366614 : 4 jobs en succès (prep, build / build-test, publish, altstore / source).
- Pré-release https://github.com/ElProfessorFRidg/PersonalLifeTracker/releases/tag/v0.0.1-beta.1, prerelease=true, asset PersonalLifeTracker-0.0.1-beta.1.ipa, 8597 octets.
- IPA téléchargé et listé par l'orchestrateur : Payload/PersonalLifeTracker.app/{PersonalLifeTracker 73688 octets, Info.plist, PkgInfo}.
- `curl https://raw.githubusercontent.com/ElProfessorFRidg/PersonalLifeTracker/altstore-source/source-beta.json` : HTTP 200, une version 0.0.1-beta.1, downloadURL vers l'asset ci-dessus, bundleIdentifier io.github.elprofessorfridg.personallifetracker.
- Lien : altstore://source?url=https://raw.githubusercontent.com/ElProfessorFRidg/PersonalLifeTracker/altstore-source/source-beta.json
Écart : pas d'icône (altstore/icon.png absent, iconURL de la source pointe vers un fichier qui n'existe pas). Release stable (release.yml, source.json) et manual-build.yml jamais exécutés.
Verdict : PARTIEL (chaîne bêta prouvée côté GitHub, installation non prouvée)
Limites (ce qui n'a pas été testé) : ajout de la source dans AltStore, installation et lancement sur iPhone, resignature de l'IPA non signé par AltStore. À VÉRIFIER PAR L'UTILISATEUR.
Confirmé par l'utilisateur :
