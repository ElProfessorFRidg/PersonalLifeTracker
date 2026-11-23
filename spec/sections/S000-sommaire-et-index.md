# MASTER PROMPT : PERSONAL LIFE TRACKER

Application iOS native intelligente de suivi automatique du travail, des études et des activités personnelles.

> Mode d'emploi de ce fichier : c'est la source de vérité du prompt. Une section = un sujet, numérotation stable. Pour le faire évoluer, éditer la section concernée ou ajouter une section à la fin de sa partie. Toute fonctionnalité hors noyau doit rester un module optionnel (section 3). Le registre des modules et les listes associées (défauts, dépendances, étapes, réglages, notifications, modèles, tests par module, critères d'acceptation) sont dans MODULES.md : une nouvelle fonctionnalité ajoute une section ici ET une ligne là-bas.

## SOMMAIRE

**A. Cadre** : 0 Mission, 1 Subagents, 2 Profil, 3 Modularité et fonctions optionnelles, 4 Scénarios, 5 Performance, 6 Technologies, 7 Architecture
**B. Noyau (toujours actif)** : 8 Géolocalisation, 9 Habitudes, 10 Lieux, 11 Travail contre courses, 12 Études, 13 Horaires intelligents, 14 Sessions, 15 Saisie manuelle et import
**C. Modules optionnels** : 16 Planning par photo, 17 Découverte de lieux, 18 Employeurs et contrats, 19 Fin de contrat, 20 Salaire et paie, 21 Conventions collectives, 22 Packs de convention, 23 Congés payés, 24 Simulateur, 25 Prévu contre réel, 26 Primes, 27 Date de paie, 28 Banque d'heures, 29 Seuil fiscal, 30 Calendrier scolaire, 31 Mode examens, 32 Pauses, 33 Alerte nuit courte, 34 Créneaux de révision, 35 Trajet et "Pars maintenant", 36 Coût du trajet, 37 "Je rentre", 38 Épargne, 39 Notes de journée, 40 Bilans, 41 Recherche, 42 Rappel d'envoi des heures, 43 Concentration, 44 Live Activity et widgets, 45 Notifications, 46 Revue de la semaine
**C bis. Modules complémentaires** : 67 Suivi des frais, 68 Remplacements, 69 Historique des taux, 70 Alerte planning tardif, 71 Régularité, 72 Journal de contrat, 73 Mode vacances de l'app, 74 Contacts du taf, 75 Rappel de badgeuse, 76 Check avant de partir, 77 Corrections à la voix, 78 Équilibre de la semaine, 79 Résumé partageable, 80 Dossier justificatif, 81 Carnet d'échanges de créneaux, 82 Compte à rebours de fin de journée, 83 Journée difficile, 84 Prévision des primes de dimanche et de férié, 85 Prévision du solde de fin de mois, 86 Heures manquantes, 87 Brief du matin, 88 Rotation de planning A/B, 89 Alerte de repos, 90 Import par la feuille de partage, 91 Planning variable (principe), 92 Vérificateur de fiche de paie, 93 Préparation d'entretien, 94 Générateur de disponibilités, 95 Prédiction d'heure de fin, 96 Carnet d'expériences, 97 Détecteur de changements de planning, 98 Journal infalsifiable, 99 Prévision de charge, 100 Mode bac en approche, 101 Retour de congé, 102 Carte de chaleur annuelle, 103 Mémos par lieu, 104 Cohérence du trajet, 105 Trace de retard, 106 Équilibrage des heures du contrat, 107 Détection de motifs de planning, 108 Régularisation des heures payées, 109 Alerte de proximité du quota, 110 Plannings proposés, 111 Simulateur de semaine en direct, 112 Jours fériés de l'année, 113 Comparaison avec ton passé, 114 Périodes bloquées, 115 Arbitrage cours contre travail, 116 Aperçu de ta fin de semaine, 117 Périodes creuses, 118 Historique des plannings, 119 Départ en vacances, 120 Équipe et échanges malins, 121 Planning par texte, 122 Maintenant (carte d'action), 123 Notifications qui apprennent, 124 Gains en direct, 125 Pile intelligente et contrôles, 126 Vrai taux horaire, 127 Fiabilité des données, 128 Annuler partout et instantanés, 129 Délai de prévenance, 130 Auto-calibration des lieux, 131 Batterie vide ou extinction, 132 Dépannage de la détection, 133 Galerie de widgets, 134 Signaux de secours, 135 Sauvegarde dans un dossier, 136 Protection à la capture et mode démo, 137 Demande-moi tout, 138 Scanner de planning papier, 139 Phase de rodage, 140 Contrôle de l'horloge, 141 Règles selon l'âge, 142 Demande de dernière minute, 143 Emploi du temps scolaire, 144 Temps annexes, 145 Compteurs de contraintes, 146 Période de paie personnalisée, 147 Contrat avant signature, 148 Carnet de stage ou d'alternance, 149 Rejouer ma journée, 150 Termes expliqués, 151 Déplacements entre sites, 152 Agenda perso comme contrainte, 153 Assistant de journée, 154 Centre de fiabilité
**D. Interface et réglages** : 47 UX, 48 Onboarding, 49 Réglages, 50 Voix et ton, 51 Capacités et état de l'app, 52 Fiabilité et diagnostic
**E. Données** : 53 Persistance, 54 iCloud, 55 Confidentialité
**F. Livraison** : 56 Mode test GPX, 57 CI/CD, 58 Qualité du code, 59 Tests, 60 Ordre de livraison, 61 Règles du dépôt, 62 Critères d'acceptation, 63 Livrables, 64 Rapport final, 65 Interdits, 66 Instruction finale

## INDEX PAR THÈME

- Planning : 16, 70, 88, 91, 97, 107, 110, 111, 116, 118, 121, 142, 143, 152
- Contrat et emploi : 18, 19, 72, 93, 106, 109, 129, 145, 147, 151
- Paie et argent : 20 à 22, 25 à 27, 29, 36, 38, 67, 69, 84, 85, 92, 108, 124, 126, 144, 146
- Absences et périodes : 23, 30, 31, 73, 100, 101, 114, 117, 119
- Trajet et lieux : 10, 17, 35, 36, 103, 104, 105, 130
- Détection et fiabilité : 8 à 14, 52, 127, 128, 130, 131, 132, 134, 139, 140, 149, 153, 154
- Notifications, widgets et cartes : 43, 44, 45, 82, 87, 122, 123, 124, 125, 133
- Analyses et bilans : 40 (dont bilan hebdomadaire), 71, 78, 99, 102, 113, 153
- Équipe et communication : 37, 74, 75, 79, 81, 120
- Données et sécurité : 53, 54, 55, 98, 128, 135, 136, 140
- Études : 12, 31, 34, 100, 115, 143, 148
- Assistant, scan et âge : 137, 138, 141, 150

---

# A. CADRE
