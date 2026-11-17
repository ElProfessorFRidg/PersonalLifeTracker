# REAL_WORLD_TEST_PROTOCOL : tests en conditions réelles (iPhone physique)

Tu prépares, l'utilisateur exécute, tu notes sans embellir. Un cas = un fichier evidence/RW-<id>.md (modèle : evidence/TEMPLATE.md).

## Cas minimum (adapte à l'étape livrée)
RW-01 Installation via AltStore et lancement après redémarrage du téléphone.
RW-02 Permission Toujours accordée, puis refusée : l'app l'explique sans planter (module diagnostic).
RW-03 Arrivée au travail réel : notification de confirmation reçue, délai mesuré (heure de passage de la porte contre heure de notif).
RW-04 Départ réel : fin de session, durée exacte contre ressenti.
RW-05 Courses courtes dans un magasin du même type que le travail : classées "courses" ou "passage", pas "travail".
RW-06 App tuée (balayée) : relance par le système au prochain franchissement de zone ?
RW-07 Mode avion puis retour, batterie faible, économie d'énergie : sessions incertaines, jamais inventées.
RW-08 Journée de travail complète : total exact contre total de ta feuille de pointage.
RW-09 Live Activity lancée par tap sur la notification, limite 8 h et relance.
RW-10 Widgets (écran d'accueil et verrouillé) mis à jour dans le délai annoncé.
RW-11 Photo de planning réelle (10 personnes) : lignes retrouvées, erreurs listées.
RW-12 Changement d'heure, changement de fuseau, horloge modifiée à la main.
RW-13 Consommation batterie sur 24 h (Réglages, Batterie) notée.
RW-14 Installation de la pré-release suivante par-dessus : les données restent.

## Règles
- Écris les chiffres mesurés (heures, délais, %), pas "ça marche".
- Un échec est un résultat valide : il reste dans PROGRESS.md jusqu'à correction et nouveau test.
- Sans confirmation de l'utilisateur, le statut reste "TESTS AUTO OK" ou "VÉRIFIÉ SIMULATEUR".
