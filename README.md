# Personal Life Tracker : kit de construction par IA

Un kit pour qu'une IA de code construise l'app iOS (suivi auto du travail et des études par géolocalisation, 100% local, installée via AltStore) dans le bon ordre, sans mentir sur l'avancée.

## Utiliser le kit
1. Dézippe, ouvre le dossier dans ton IA de code (Claude Code, etc.).
2. Colle le contenu de START_PROMPT.md.
3. Phase 0 : l'IA publie l'UI comme artefact (lien), tu testes, tu demandes des changements, puis tu écris "UI validée". Ensuite elle enchaîne toute seule. Phase 1 : CI/CD (il te demandera un dépôt GitHub public). Phase 2 : l'app, étape par étape.

## Contenu
| Chemin | Rôle |
|---|---|
| AGENTS.md | règles : honnêteté, portes, économie de tokens, sub agents |
| START_PROMPT.md | prompt de démarrage |
| phases/ | PHASE_0_UI, PHASE_1_CICD, PHASE_2_BUILD |
| TESTING_POLICY.md, REAL_WORLD_TEST_PROTOCOL.md | tests honnêtes et tests sur iPhone |
| SUBAGENT_BRIEF.md | modèle de brief court |
| PROGRESS.md | avancement avec preuves (généré, 207 lignes) |
| spec/ | prompt maître, MODULES.md, sections/ découpées, INDEX.md, oracles.json |
| scripts/ | lecture de la spec, vérifications, build IPA, source AltStore, thème |
| design/ | tokens.json, SCREENS.md, prototype/ |
| .github/workflows/ | CI/CD |
| App/, Tests/, project.yml | squelette Swift (XcodeGen) |
| evidence/, notes/ | preuves et notes |

## Garde-fous automatiques
`python3 scripts/check_progress.py` : refuse un statut sans preuve et toute avancée de l'app sans UI validée.
`python3 scripts/check_tests_integrity.py` : détecte skip, assertions triviales, tests sans assertion, détection de XCTest dans l'app, baisse du nombre de tests.
Ils ne remplacent pas la relecture et les tests sur ton iPhone.

## Limites connues
Ce kit a été généré sans Mac : le Swift n'a pas été compilé et les workflows n'ont pas tourné. La phase 1 est faite pour le prouver. Le chemin d'IPA signé est un stub volontaire.

## Télécharger un IPA
- PR : le workflow pull-request produit l'artefact Actions ipa après les tests.
- Build manuel : lance manual-build sur la branche voulue avec une version x.y.z. Après les tests, une pré-release build-<run_id> contient l'IPA ; relancer le même run remplace son fichier.
- Release stable : pousse un tag v1.2.3 ou modifie release/STABLE_VERSION.
- Bêta : pousse un tag v1.2.3-beta.1 ou modifie release/BETA_VERSION. Ces deux canaux mettent aussi à jour la source AltStore.

Les IPA sont non signés et doivent être resignés pour être installés, par exemple avec AltStore. Une PR seule ne publie pas de release.
