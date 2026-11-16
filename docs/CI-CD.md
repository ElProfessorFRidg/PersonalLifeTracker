# CI/CD : comment ça marche

## Workflows
| Fichier | Déclencheur | Rôle |
|---|---|---|
| _build-test.yml | appelé | garde-fous Python, XcodeGen, tests simulateur, IPA non signé (option) |
| ci.yml | push sur main | build + tests |
| pull-request.yml | PR | build + tests |
| beta.yml | tag `v1.2.0-beta.1` | build, pré-release GitHub avec IPA, mise à jour de source-beta.json |
| release.yml | tag `v1.2.0` | build, release GitHub avec IPA, mise à jour de source.json |
| manual-build.yml | à la main | IPA en artefact (sans release) |
| altstore-source.yml | appelé par beta/release, ou à la main | écrit la source AltStore sur la branche `altstore-source` |

Pourquoi `workflow_call` : une release créée avec GITHUB_TOKEN ne déclenche pas d'autres workflows. On enchaîne donc dans le même run.

## Liens AltStore (remplace OWNER/REPO)
- Stable : `altstore://source?url=https://raw.githubusercontent.com/OWNER/REPO/altstore-source/source.json`
- Bêta : `altstore://source?url=https://raw.githubusercontent.com/OWNER/REPO/altstore-source/source-beta.json`
Le dépôt doit être public pour que raw.githubusercontent.com réponde sans authentification.

## IPA non signé
AltStore resigne l'IPA avec ton compte Apple gratuit à l'installation. Les entitlements (App Group...) sont limités par le compte gratuit : voir section 54 et ENABLE_CLOUDKIT. `ldid` n'est utilisé que si présent et si App/PersonalLifeTracker.entitlements existe (effet à vérifier sur appareil).

## Publier
```
git tag v0.0.1-beta.1 && git push origin v0.0.1-beta.1   # pré-release
git tag v0.0.1 && git push origin v0.0.1                  # release
```
Notes de version : section du tag dans CHANGELOG.md (extract_changelog.py), sinon Unreleased.

## État de vérification de ce kit (honnête)
Vérifié dans l'environnement de génération (Linux) : syntaxe YAML des workflows, `bash -n` des scripts, scripts Python (exécutés), génération de source AltStore et sa validation, oracles contre une mutation.
NON vérifié : compilation Swift/XcodeGen, exécution des workflows sur GitHub, noms exacts des simulateurs, runner `macos-latest`, `xcresulttool` (la sous-commande peut varier selon Xcode), ldid, format de source accepté par la version d'AltStore installée, installation sur iPhone. La phase 1 sert à les prouver pour de vrai.
