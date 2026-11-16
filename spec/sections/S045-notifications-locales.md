## 45. NOTIFICATIONS LOCALES

UNUserNotificationCenter, sans serveur ni push distant. Cas du noyau : arrivée ou départ incertain, confirmation d'horaire, "Cette visite correspond-elle à des courses ?", anomalie de suivi. Cas des modules (envoyés seulement si le module est actif) : liste dans MODULES.md (annexe B).
Exemples : "Ton arrivée au travail semble être vers 06:00. Tu confirmes ?" ; "Ton départ du lycée est estimé entre 16:40 et 17:00. Quelle heure retenir ?"
Actions : confirmer, choisir une autre heure, signaler une erreur, ouvrir l'activité. Prévention des doublons, gestion des permissions, préférences par catégorie, heures silencieuses, fréquence maximale par jour. Quand le module smart_notifications est actif, un coordinateur central applique priorités, budget quotidien, regroupement et apprentissage (section 123). Sans réponse, conserver une estimation marquée incertaine. Ne jamais bloquer l'app dans l'attente d'une réponse.
