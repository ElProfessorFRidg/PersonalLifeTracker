## 3. MODULARITÉ : LES FONCTIONS OPTIONNELLES NE SONT JAMAIS OBLIGATOIRES

C'est un principe d'architecture, pas un détail de réglages.

**3.1 Noyau obligatoire (toujours actif, non désactivable)** : lieux, sessions, détection d'arrivée et de départ (dans la limite des permissions accordées), saisie manuelle et démarrage/arrêt manuel, statistiques d'heures de base, réglages, écran "État de l'app", export et import JSON.

**3.2 Tout le reste est un module optionnel.** Chaque module est activable et désactivable à tout moment dans Réglages > Fonctionnalités, avec un titre, une courte explication, son statut, ses dépendances et sa valeur par défaut. Le noyau compile et fonctionne avec tous les modules désactivés (test obligatoire).

**3.3 Règles d'un module désactivé** :
- Aucune interface visible : onglets, cartes, boutons, lignes de réglages, widgets, App Intents et notifications du module sont masqués ou retirés.
- Aucune tâche en arrière-plan, aucun calcul, aucune notification, aucune demande de permission.
- Données conservées : désactiver ne supprime jamais rien, la réactivation retrouve tout.
- Dépendances : activer un module qui en exige un autre propose de l'activer ("Les congés ont besoin du module Emploi, je l'active ?"). Désactiver un module dont d'autres dépendent prévient et propose de désactiver aussi ces derniers. Aucun module n'est requis par le noyau.
- À l'intérieur d'un module, chaque rappel, alerte ou notification reste désactivable individuellement. Aucune saisie (salaire, contrat, congés) n'est obligatoire : l'app fonctionne sans.
- Un module est utilisable seulement si activé ET si la capacité système nécessaire est disponible (voir section 51). Sinon il est grisé avec la raison.

**3.3 bis Implémentation** : un ModuleRegistry unique, source de vérité. Chaque module déclare : identifiant, titre, description, valeur par défaut, dépendances, permissions et capacités requises, points d'entrée UI. Les flags sont des réglages runtime, distincts des flags de compilation (ENABLE_CLOUDKIT). Aucun code d'un module ne s'exécute au lancement tant qu'il est désactivé (initialisation différée).

**3.4 Registre des modules** : la liste complète des modules (identifiant, section, valeur par défaut, dépendances, enrichissements, étape de livraison) est dans MODULES.md, source de vérité. Valeurs par défaut : "coché" = proposé et coché à l'onboarding, "décoché" = proposé et décoché, "inclus" = sous-fonction d'un module existant. Une dépendance "exige" est obligatoire, un "enrichi par" est facultatif. Le principe de la section 91 (planning variable) s'applique à tous les modules qui lisent un planning. Toute nouvelle fonctionnalité ajoute une section ici ET une ligne dans MODULES.md.
