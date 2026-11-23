## 123. NOTIFICATIONS QUI APPRENNENT (module smart_notifications, proposé et coché par défaut)

Un coordinateur central de notifications (NotificationCoordinator) pour tous les modules, qui remplace les envois dispersés.
- Priorités (essentielle, utile, informative), budget quotidien réglable, regroupement des rappels proches en un seul, déduplication, respect des contextes de silence et des heures silencieuses. Les notifications essentielles (arrivée ou départ incertain, "Pars maintenant", alerte de suivi interrompu) sont protégées par défaut.
- Apprentissage local par catégorie et plage horaire : notification ouverte, action effectuée, écartée ou restée sans suite. L'app propose, sans jamais imposer : "Tu as ignoré 5 rappels de pause, je les coupe ?", "Tu réagis plutôt vers 18 h, je décale le rappel d'envoi ?" Choix en un tap (couper, déplacer, garder), une proposition par catégorie et par mois, aucune notification coupée sans accord.
- Limite iOS à respecter : l'app ne sait pas si une notification a été simplement vue. "Ignorée" signifie ni ouverte ni action dans un délai donné (défaut 24 h), et la détection des notifications écartées demande une action de fermeture personnalisée sur la catégorie. Le dire dans l'interface plutôt que de prétendre une mesure exacte.
- Données locales, effaçables, aucune télémétrie.
