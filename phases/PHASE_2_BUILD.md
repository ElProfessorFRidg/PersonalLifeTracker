# PHASE 2 : construction de l'app (seulement si design/UI_VALIDATED.md existe)

Vérifie d'abord : `python3 scripts/check_progress.py` (il refuse si la porte UI manque).

## Boucle par étape N (1 à 11, ordre de la section 60)
1. `python3 scripts/module_info.py --step N` : liste des modules. `python3 scripts/spec_section.py 60` : rappel de l'ordre.
2. Découpe en tâches indépendantes (1 module = 1 tâche). Lance un sub agent par tâche indépendante, en parallèle quand les fichiers ne se recoupent pas. Utilise SUBAGENT_BRIEF.md comme modèle de brief.
3. Chaque sub agent : lit ses sections via spec_section.py, écrit le code + les tests (scénarios et critères d'acceptation de l'annexe D et E : `python3 scripts/module_info.py <id>`), compile, lance les tests, écrit notes/<id>.md, répond en 15 lignes.
4. Toi, l'orchestrateur : tu relances build et tests toi-même, tu relis le diff des tests (pas truqués), tu pousses, tu attends la CI verte, tu mets à jour PROGRESS.md avec la preuve.
5. UI : l'app doit correspondre à design/SCREENS.md et au thème généré. Tout écart est noté.
6. Fin d'étape : pré-release automatique (tag beta), puis protocole REAL_WORLD_TEST_PROTOCOL.md pour les modules concernés. Tu demandes à l'utilisateur de tester sur son iPhone et tu notes ses retours. Pas d'étape N+1 si le noyau de l'étape N n'est pas utilisable (règle de la section 60).

## Statuts autorisés dans PROGRESS.md
- `NON COMMENCÉ`
- `EN COURS`
- `CODÉ, NON TESTÉ`
- `TESTS AUTO OK` (CI verte, preuve : lien du run)
- `VÉRIFIÉ SIMULATEUR` (scénario GPX rejoué, preuve : fichier evidence)
- `VÉRIFIÉ SUR APPAREIL` (preuve evidence + confirmation de l'utilisateur)
- `BLOQUÉ` (raison écrite)
Un module n'est "terminé" qu'à `VÉRIFIÉ SUR APPAREIL` s'il touche à la localisation, aux notifications, à la Live Activity, aux widgets ou à la caméra. Sinon `TESTS AUTO OK` suffit pour la logique pure, et c'est écrit comme tel.

## Économie de tokens
Pas de lecture de la spec entière, sub agents à brief court, logs CI en tail, pas de recap. Si le contexte gonfle, écris l'état dans notes/ et PROGRESS.md puis continue dans une session fraîche.
