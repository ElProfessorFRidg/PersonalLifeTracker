# PHASE 1 : CI/CD GitHub, releases, pré-releases, lien AltStore

Lis docs/CI-CD.md avant. Cette phase peut tourner avec le squelette Swift du kit (App/ et Tests/), c'est le but : prouver la chaîne avant de construire l'app.

## Prérequis côté utilisateur (demande-les, ne les devine pas)
- Dépôt GitHub PUBLIC (source AltStore servie via raw.githubusercontent.com) et `gh auth login` fait.
- Réglages du dépôt : Actions autorisées, workflow permissions "Read and write".
- AltStore installé sur l'iPhone, compte Apple gratuit.

## Étapes
1. `git init`, premier commit, `gh repo create <nom> --public --source . --push`.
2. Renseigne altstore/config.json (nom, bundleIdentifier, URL du dépôt).
3. Vérifie localement ce qui peut l'être : `python3 scripts/validate_altstore_source.py --self-test`, YAML valide, `bash -n scripts/*.sh`.
4. Pousse. Surveille : `gh run watch` puis `gh run view --log-failed | tail -60`. Corrige les vraies causes (pas de désactivation d'étape pour faire passer).
5. Pull request de test : le workflow pull-request.yml doit tourner et être vert (build + tests sur simulateur).
6. Pré-release : tag `v0.0.1-beta.1`. Le workflow beta.yml publie une pré-release avec l'IPA non signé et met à jour source-beta.json sur la branche altstore-source.
7. Release : tag `v0.0.1`. release.yml publie la release avec IPA, notes extraites de CHANGELOG.md, met à jour source.json.
8. Build manuel : `gh workflow run manual-build.yml` doit produire un IPA en artefact.
9. Lien AltStore : `altstore://source?url=https://raw.githubusercontent.com/<user>/<repo>/altstore-source/source.json` (et source-beta.json pour les pré-releases). Génère un QR via le README de la source si tu veux.
10. Vérifie les URLs avec curl : le JSON de la source doit se télécharger, l'URL de l'IPA doit répondre.
11. Demande à l'utilisateur de l'ajouter dans AltStore et d'installer. Statut final seulement après son retour.

## Preuves (evidence/phase1-*.md)
URLs des runs verts, tag publié, taille de l'IPA, contenu de source.json, sortie de validate_altstore_source.py. Les points "installé via AltStore sur iPhone" restent "À VÉRIFIER PAR L'UTILISATEUR" tant qu'il n'a pas confirmé.

## Honnêteté
Le chemin IPA non signé + AltStore (qui resigne) est la voie prévue. Le chemin signé (build_signed_ipa.sh) n'est pas testé : ne le présente pas comme fonctionnel avant preuve. Si ldid ou l'extraction d'entitlements échoue, écris-le.
