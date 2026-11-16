# ERREURS et limites connues
(aucune pour l'instant)

## 2026-11-16 : décision de l'utilisateur, étapes enchaînées sans test sur iPhone
La section 60 et phases/PHASE_2_BUILD.md demandent que l'étape N soit utilisable sur un vrai iPhone avant l'étape N+1.
L'utilisateur a écrit : « Enchaîne sans attendre, fais tout avec sub agents Sonnet ». Les étapes 2 et suivantes sont donc
construites sur un noyau qui n'a été vu sur aucun écran. Conséquence : tous les statuts restent au plus TESTS AUTO OK,
rien n'est VÉRIFIÉ SUR APPAREIL, et un défaut du noyau peut se propager.
