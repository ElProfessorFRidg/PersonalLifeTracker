# Découverte automatique des lieux

Implémentation anticipée à la demande explicite de l'utilisateur (2026-11-16).
Section 17 : CLVisit, confirmation obligatoire, choix Travail / Études / Domicile / Commerce / Autre, ignorer et revoir volontairement les lieux ignorés.

Choix techniques : trois arrêts terminés d'au moins dix minutes, précision au plus 100 m, regroupés à 100 m ; arrivées espacées de quatre heures. Fenêtre glissante de trente jours. Ces seuils sont des choix d'implémentation, pas des exigences chiffrées de la spec. Coordonnées fixes du premier arrêt pour éviter une dérive du groupe.
Les doublons de callbacks et les séjours incomplets sont exclus. Les lieux déjà enregistrés sont exclus selon leur rayon. Pas de trajet continu, de géocodage distant, de notification supplémentaire ni de création rétroactive de sessions.
Persistance locale des candidats et exclusions ; maximum 100 groupes actifs et 20 dates par groupe. Les exclusions sont conservées pour ne pas reproposer un lieu ignoré.
Le module est disponible et activé par défaut ; sa désactivation arrête CLVisit et bloque l'enregistrement des callbacks. Autorisation Toujours nécessaire pour la collecte en arrière-plan.
Les types domicile et autre ne créent pas de sessions automatiques et sont classés personnels, jamais en travail.
UI courte dans Lieux : carte, type, nom facultatif, Ajouter / Ignorer. L'étape de premier lieu de l'onboarding peut être passée.

Validation : check_progress.py, check_tests_integrity.py et git diff --check exécutés localement. Dix tests de découverte ajoutés, dont création uniquement après confirmation, déduplication, persistance des exclusions et désactivation.
NON TESTÉ localement : compilation Swift, XCTest et cartes (environnement Linux sans Xcode).
NON TESTÉ sur iPhone : callbacks CLVisit, relance en arrière-plan, précision et délai des propositions. iOS décide du moment de livraison ; aucun délai de découverte garanti.

Priorités majeures encore indisponibles dans le registre : emploi du temps scolaire, planning texte/photo, sauvegarde automatique avec restauration, détection d'heures manquantes, revue hebdomadaire. Les statuts PROGRESS de certains autres modules sont anciens : leur présence dans le code ne suffit pas à prouver leur livraison.

## Mise à jour du 22 novembre 2026

- Les événements d’arrivée peuvent être rapprochés d’un départ seul après relance. Les doublons, trajets courts et positions insuffisamment précises restent exclus. Les anciennes dates gardent leur place dans l’historique sans durée inventée. Les arrêts rapprochés sont regroupés selon la précision et un grand rayon de surveillance ne masque plus systématiquement les bâtiments voisins.
- Une suggestion est éligible après deux jours distincts de visite, ou après un arrêt récent d’au moins 20 minutes et suffisamment précis. Historique de 45 jours. Les longues nuits répétées donnent un indice de domicile et passent derrière les autres propositions. Trois présences d’au moins deux heures sur trois jours distincts peuvent indiquer un emploi, quel que soit le jour ou l’heure. Les catégories reconnues dans Plans (hors commerces) et les indices de domicile sont examinés en premier.
- Recherche du nom, de l’adresse et de la catégorie dans Apple Plans à l’ouverture de la fiche. Recherche multiple facultative depuis la liste. Confirmation manuelle requise dans tous les cas. Sport et Sortie restent des activités personnelles. Le choix Courses avec « J’y travaille aussi » s’appuie sur la durée et le planning daté lorsqu’il est disponible.
- Les régressions couvrent le vendredi matin et le week-end, le domicile, une école identifiée dans Plans, deux bâtiments proches, les anciens arrêts, les départs seuls après relance, la suppression des suggestions et la classification d’un commerce où l’on travaille aussi.

L’accueil donne accès aux suggestions en attente. L’onboarding et Lieux expliquent les permissions et la recherche d’adresse. Une course courte pendant un horaire habituel de travail et un long service prévu contredisant une habitude de courses repassent par les règles de classification.

Validation locale : contrôles du dépôt et des diffs. Compilation SwiftUI et tests XCTest NON TESTÉS localement (Linux, sans Xcode). Détection réelle en arrière-plan, délais iOS et résultats Plans NON TESTÉS sur iPhone.

## Utilisation de l’ancien historique

La clé de stockage des suggestions et le format historique des dates d’arrivée restent lisibles. Les anciens et nouveaux passages se combinent sur la même fiche dans la fenêtre de 45 jours. Les anciens départs absents sont affichés comme inconnus. Si iOS renvoie un passage déjà connu avec un départ, la fiche se complète et le nombre de passages reste identique. Aucun arrêt ou horaire absent des données enregistrées n’est reconstruit.

## Visites récurrentes avec des relevés GPS inégaux

Le regroupement tient compte de la précision des deux relevés, dans un rayon maximal de 85 m. Deux positions précises gardent un rayon plus étroit, et une attribution ambiguë entre deux lieux est écartée. Un départ moins précis peut compléter une arrivée précise si les horaires et lieux désignent un seul passage connu. La fiche se base alors sur la position de l’arrivée. L’écran Lieux indique aussi quand iOS a livré une arrivée récente et que le départ est encore absent.

Les anciens passages de journée sans départ peuvent compléter les jours de visite connus pour atteindre trois jours distincts et suggérer « Taf possible ». Seules les durées réellement connues peuvent justifier la mention de deux heures. Un passage récent de durée connue inférieure à deux heures ne complète pas ce seuil.

## Première utilisation et mouvements à l’intérieur

L’écran Lieux peut préremplir un nouveau lieu de travail avec la position actuelle après une action explicite. Le nom, la position et la catégorie restent à enregistrer. Un lieu confirmé fonctionne sans historique. Un créneau de travail daté de la semaine affichée peut ouvrir une saisie manuelle préremplie s’il est terminé depuis la veille, récent et sans session qui se chevauche. Les congés saisis et jours fériés sont exclus. Ce contrôle en Planning ne met pas en œuvre les notifications, le suivi des créneaux partiellement renseignés ou l’apprentissage de la section 86.

Les commerces à double usage ont maintenant le même délai de grâce de trois minutes que les lieux de travail. Une nouvelle position précise clairement à l’intérieur de la zone peut annuler le départ en attente, même sans deuxième événement de région. Une réelle sortie conserve son horodatage initial. Les positions intermédiaires et le mouvement à pied ne sont pas enregistrés comme historique. Aucune permission de mouvement n’est demandée.
