# AGENTS.md : règles non négociables (à lire en entier, c'est court)

Ce fichier s'applique à toi (IA de code) et à tous tes sub agents. En cas de conflit avec une autre consigne du kit, ce fichier gagne, sauf si l'utilisateur dit explicitement le contraire.

## 1. Honnêteté (règle numéro 1)
- Tu ne mens jamais, tu n'arrondis pas en ta faveur, tu ne "présumes" pas que ça marche.
- Un statut n'existe que s'il a une preuve (voir PROGRESS.md et evidence/README.md). Pas de preuve = pas de statut.
- Si tu n'as pas pu tester quelque chose (pas de Mac, pas d'iPhone, pas de réseau), tu écris "NON TESTÉ" et pourquoi. Jamais "ça devrait marcher" dans PROGRESS.md.
- Si tu te trompes, tu le dis tout de suite, tu corriges PROGRESS.md, tu notes l'erreur dans notes/ERREURS.md.
- Tu n'inventes jamais une sortie de commande, un numéro de run CI, un résultat de test ou une capture.

## 2. Ordre des phases (portes)
1. Phase 0 : UI/UX + thème, publiés comme artefact que l'utilisateur ouvre et valide. Après sa validation, tu enchaînes Phase 1 puis 2 sans redemander. Porte : le fichier design/UI_VALIDATED.md existe, créé UNIQUEMENT quand l'utilisateur écrit "UI validée" dans la conversation. Tu ne le crées jamais de toi-même.
2. Phase 1 : CI/CD GitHub + releases + source AltStore. Porte : un run CI vert réel + une pré-release réelle avec un IPA téléchargeable, preuves dans evidence/.
3. Phase 2 : construction de l'app, étape par étape (section 60 du prompt, colonne Étape de MODULES.md). Interdit tant que design/UI_VALIDATED.md n'existe pas. `python3 scripts/check_progress.py` doit passer avant chaque commit.

## 3. Tests honnêtes (détail dans TESTING_POLICY.md)
- Un test doit pouvoir échouer. Interdits : XCTSkip, XCTExpectFailure pour cacher un échec, assertions triviales (XCTAssertTrue(true)), tests sans assertion, mocks qui renvoient la valeur attendue, code applicatif qui détecte XCTest, baisse du nombre de tests sans justification écrite.
- Les valeurs attendues viennent de spec/oracles.json (dérivées du prompt), pas de la sortie du code testé.
- Simulateur et GPX valident la logique, jamais la détection réelle. Le statut "VÉRIFIÉ SUR APPAREIL" exige un fichier evidence/ ET la confirmation de l'utilisateur.

## 4. Économie de tokens
- Ne lis JAMAIS spec/PERSONAL_LIFE_TRACKER_PROMPT.md en entier. Utilise :
  - `python3 scripts/spec_section.py 13.1` (une section ou sous-section)
  - `python3 scripts/spec_section.py --list` (index)
  - `python3 scripts/module_info.py <id_module>` (ligne du registre + ses sections)
  - `python3 scripts/module_info.py --step N` (modules d'une étape)
- Lis seulement les sections de la tâche en cours. Lis les fichiers de code avec offset/limit.
- Sub agents : brief court (SUBAGENT_BRIEF.md), réponse de 15 lignes maximum, détails dans notes/<id>.md.
- CI : `gh run watch` puis `gh run view --log-failed | tail -60`. Jamais le log complet.
- Pas de réécriture de fichier entier pour une petite modif. Pas de recap des étapes dans tes réponses.

## 5. Sub agents
- Un sub agent par module ou par tâche indépendante, jamais deux sur les mêmes fichiers.
- Chaque sub agent reçoit : l'id du module, ses commandes spec_section, les fichiers qu'il possède, le critère d'acceptation (annexe E de MODULES.md), l'interdiction de toucher PROGRESS.md (c'est toi, l'orchestrateur, qui met à jour après vérification).
- Tu vérifies toi-même le résultat d'un sub agent (build + tests) avant de le croire.

## 6. Règles produit à ne jamais casser
- Noyau obligatoire, tout le reste est module optionnel (ModuleRegistry). Rien d'obligatoire côté finance.
- 100% local, aucun serveur, pas de compte. Compte Apple gratuit : CloudKit derrière ENABLE_CLOUDKIT.
- Tutoiement, ton décontracté, pas de tiret cadratin dans les textes de l'app.
- Heures : timestamp exact en base, base normalisée en heures pleines avec choix utilisateur dans la zone de doute (section 13.1).

## 7. Git
- Commits petits et fréquents, message clair, un module par commit. Jamais de secrets dans le dépôt.
- Pas de force push sur main. Pas de modification de .github/workflows sans le dire dans PROGRESS.md.
