## 60. ORDRE DE LIVRAISON (MVP D'ABORD)

Livrer et valider dans cet ordre, en vérifiant compilation et tests à chaque étape, sans commencer une étape avant que la précédente soit utilisable sur un vrai iPhone :
1. Noyau : modèles SwiftData, ModuleRegistry et écran Fonctionnalités, ajout de lieux, sessions, saisie manuelle, démarrage/arrêt manuel, onglets Accueil et Lieux, CapabilityService de base, onboarding de base.
2. Géorepérage, détection d'arrivée et de départ, notifications locales de confirmation, écran de diagnostic, annuler partout et instantanés quotidiens (section 128).
3. Classification travail, études, courses, apprentissage des corrections, auto-calibration des lieux, récupération après batterie vide, assistant de dépannage (sections 130 à 132), contrôle de l'horloge (section 140).
4. CI GitHub Actions qui build et produit l'IPA.
5. Module emploi (employeurs, contrat, cycle de vie, fin de contrat) et module paie de base (SMIC en un tap, brut/net, heures, statistiques, export JSON/CSV, historique des taux).
6. Conventions et règles de paie, primes, relevé d'heures, équilibrage des heures du contrat (avec alerte de proximité du quota), congés payés.
7. Planning : semaines datées indépendantes (section 91), onglet Planning, import et OCR de planning photo, scan de contrat et de fiche de paie.
8. Live Activity (démarrage par notification, section 44.1), widgets de base, App Intents, pile intelligente et contrôles.
9. Trajet et "Pars maintenant", notes de journée, pauses, mode examens, calendrier scolaire et fériés, nuit courte, créneaux de révision.
10. Modules marqués étape 10 dans MODULES.md (planning avancé, bilans, recherche, motifs de planning, carte Maintenant, notifications qui apprennent, fiabilité des données, galerie de widgets, etc.).
11. Modules marqués étape 11 dans MODULES.md, puis optimisations.
La colonne "Étape" de MODULES.md fait foi : un module n'est livré qu'à son étape.
