## 35. TRAJET ET "PARS MAINTENANT" (module travel_departure)

Pour chaque prise de poste ou de cours connue (planning, contrat, habitudes), l'app calcule le temps de trajet depuis la position probable de départ (position actuelle ou domicile) avec MKDirections (voiture, marche, vélo, transport), en tenant compte du trafic quand l'API le permet.
Réglages : marge de sécurité (défaut 10 minutes), mode de transport par lieu, notification activable par lieu.
Fonctionnement : planifier à l'avance une notification locale basée sur l'estimation, puis la recalculer à l'approche (BackgroundTasks et déclencheurs opportunistes, jamais de polling permanent, requêtes MKDirections limitées et mises en cache). Exemple : "Faut y aller, il est 17:28. T'as 22 min de route et tu prends ton poste à 18:00."
Si le retard est probable, le dire ("Tu vas arriver vers 18:06, prévient ton chef ?"), sans promettre une précision que l'API ne garantit pas. Respecte les heures silencieuses et le mode examens. Rien n'est envoyé si l'utilisateur est déjà sur place.
