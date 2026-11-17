# SUBAGENT_BRIEF : modèle de brief (court, c'est voulu)

```
Module : <id>
Lis uniquement : python3 scripts/module_info.py <id> (puis les sections qu'il affiche)
Fichiers que tu possèdes : <chemins> (ne touche à aucun autre)
Dépendances déjà livrées : <ids>
À faire : <1 à 3 lignes>
Critère d'acceptation : annexe E du module (module_info le montre)
Tests : écris-les d'après l'annexe D et spec/oracles.json. Lis TESTING_POLICY.md (pas de test truqué).
Vérifie : xcodegen generate && xcodebuild test (si dispo), sinon dis "NON COMPILÉ" clairement.
Ne touche pas à PROGRESS.md. Écris le détail dans notes/<id>.md.
Réponse finale : 15 lignes max : fait / pas fait / NON TESTÉ / fichiers modifiés / risques.
Ne mens pas : si ça ne compile pas ou si un test échoue, dis-le.
```

Contrôle de l'orchestrateur après retour : build + tests relancés, diff des tests relu, résultat réel noté dans PROGRESS.md.
