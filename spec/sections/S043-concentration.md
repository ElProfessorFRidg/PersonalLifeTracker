## 43. CONCENTRATION (module focus)

Contrainte iOS : une app ne peut pas activer un mode Concentration elle-même. Ne jamais prétendre le faire. Ce qui est possible :
1. Action Raccourcis : exposer via App Intents une action "Je suis au travail" (démarre la session, lance la Live Activity). L'app guide pas à pas (captures ou schéma animé) pour créer dans Raccourcis une automatisation "Quand j'arrive à [lieu]" qui active le mode Concentration "Travail" ou "Cours" puis appelle l'action, et l'inverse au départ. Bouton qui ouvre directement Raccourcis.
2. Filtre de Concentration (SetFocusFilterIntent) : quand le mode associé est actif, l'app adapte son comportement (notifications non critiques réduites, bandeau paie masqué, employeur actif affiché).
3. Lecture de l'état (INFocusStatusCenter) uniquement si l'utilisateur l'autorise, pour adapter les notifications, jamais pour deviner où il est.
Une ligne "Concentration" dans "État de l'app" indique ce qui est configuré et ce qui manque, avec un bouton d'aide. Les notifications importantes (confirmation d'arrivée, "Pars maintenant") peuvent être "sensibles au temps" si l'utilisateur le choisit, jamais critiques.
