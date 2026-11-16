## 136. PROTECTION À LA CAPTURE ET MODE DÉMO (module privacy_shield, proposé et coché par défaut)

- Enregistrement et recopie d'écran : quand iOS indique qu'une capture vidéo ou une recopie est en cours, l'app floute automatiquement montants, lieux, noms de collègues, notes et contenu des mémos, avec un bandeau "Capture en cours, contenu masqué". Disponibilité de l'API à vérifier selon la version d'iOS.
- Captures d'écran : iOS ne permet ni de les empêcher ni de les détecter à l'avance, l'app n'est prévenue qu'après coup. Elle peut alors proposer discrètement "Capture détectée, activer le flou automatique des montants ?". Ne jamais prétendre bloquer les captures.
- Sélecteur d'apps : contenu flouté (voir section 49).
- Mode démo : un bouton dans Réglages (et un App Intent) bascule vers un jeu de données fictives générées localement, dans une base séparée et isolée, avec bandeau permanent "MODE DÉMO", aucune écriture dans les vraies données, aucune vraie notification, sortie en un tap. Permet de montrer l'app sans exposer ses données. Distinct du mode test GPX (section 56). Pendant le mode démo, les widgets affichent aussi les données fictives ou un état neutre, jamais les vraies.
