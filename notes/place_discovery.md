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
