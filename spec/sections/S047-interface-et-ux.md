## 47. INTERFACE ET UX

Direction artistique : minimaliste, premium, native iOS, typographie SF, SF Symbols, mode clair et sombre, espacements cohérents, animations discrètes, hiérarchie claire, accessibilité (Dynamic Type, VoiceOver, contrastes). S'inspirer d'Apple Santé, Plans et Calendrier sans les copier. Pas de surcharge, pas de dégradés excessifs, pas de cartes partout.
Navigation : 4 onglets (Accueil, Planning, Lieux, Statistiques). Réglages, profil, recherche, bilans, objectifs accessibles clairement. L'onglet Planning n'affiche que ce que les modules actifs fournissent (sinon un état simple qui propose d'activer le module). Aucun écran ne demande plus de 2 taps pour corriger une session.
Accueil, de haut en bas :
1. Carte de l'activité en cours ou prochaine : type, lieu, heure de début, durée en direct, et "Pars maintenant" si le module est actif et pertinent.
2. Résumé du jour en deux blocs : heures de cours, heures de travail.
3. Bandeau "À confirmer", visible seulement s'il y a des éléments incertains, avec boutons rapides. Avec le module now_card, la carte "Maintenant" (section 122) prend sa place et regroupe ces éléments.
4. Chronologie du jour avec la note du jour si le module est actif.
5. Bouton flottant "+" pour l'ajout rapide et le démarrage/arrêt manuel.
Lieux : nom, adresse, coordonnées, visites, temps total, durée moyenne, dernière visite, activités, habitudes, confiance ; MapKit.
Statistiques (Swift Charts) : travail et études séparés, avec aujourd'hui, semaine, mois, année, nombre de journées, moyenne journalière, évolution ; autres : domicile, déplacements, visites, répartition des activités ; sections paie, congés, objectifs et accès aux bilans seulement si leurs modules sont actifs. Jamais de statistiques trompeuses si les données sont incomplètes.
États soignés : première utilisation, aucune donnée, localisation refusée ou limitée, hors ligne, synchronisation en cours ou échouée, détection incertaine, historique vide, module désactivé.
