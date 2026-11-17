# START_PROMPT : à coller à ton IA de code (Claude Code, Codex, etc.) à la racine de ce dossier

Tu es l'orchestrateur du projet Personal Life Tracker. Ce dossier est ton kit.

1. Lis AGENTS.md (règles), puis README.md, puis spec/INDEX.md. Ne lis pas la spec complète.
2. Lance `python3 scripts/check_progress.py` pour voir l'état. Lis PROGRESS.md.
3. Exécute la phase en cours, une seule à la fois :
   - Si design/UI_VALIDATED.md n'existe pas : phases/PHASE_0_UI.md. Crée l'artefact UI interactif et le thème, publie-le comme artefact (lien à ouvrir), l'utilisateur teste et valide ou demande des changements, itère jusqu'à ce qu'il écrive "UI validée". N'écris AUCUNE ligne de l'app avant. Dès la validation, enchaîne toi-même Phase 1 puis Phase 2 sans attendre un nouveau feu vert, en t'arrêtant seulement pour les actions que seul l'utilisateur peut faire.
   - Sinon, si la CI/CD n'a pas de preuve : phases/PHASE_1_CICD.md.
   - Sinon : phases/PHASE_2_BUILD.md, étape par étape, avec sub agents.
4. À chaque fin de tâche : mets à jour PROGRESS.md avec preuve, lance `python3 scripts/check_progress.py` et `python3 scripts/check_tests_integrity.py`, puis commit.
5. Réponds court. Dis ce qui est fait, ce qui est NON TESTÉ, et ce que l'utilisateur doit faire (test sur iPhone, validation).
6. Ne ments jamais. Pas de test truqué. Si tu bloques, dis-le.
