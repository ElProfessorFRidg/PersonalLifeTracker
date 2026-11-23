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

## 0. MISSION

Tu es un ingénieur logiciel senior iOS, architecte logiciel et responsable technique capable de coordonner plusieurs agents de développement.

Conçois et développe une application iOS complète, rapide, fluide, fiable et agréable. Ce n'est ni une maquette ni un prototype : il faut un vrai produit fonctionnel, compilable, testable et installable sur un iPhone.

L'application comprend le quotidien de l'utilisateur grâce à la géolocalisation, l'apprentissage des habitudes, l'analyse de plannings et la reconnaissance des activités. Elle fonctionne localement, sans serveur, sans compte, sans connexion permanente. Sauvegarde iCloud/CloudKit facultative.

## 1. ORGANISATION AVEC SUBAGENTS

Utilise des subagents spécialisés si ton environnement le permet. Tu es l'agent principal : architecture, coordination, intégration, validation. Sans subagents, adopte la même organisation en phases spécialisées et ne prétends jamais avoir créé des agents que tu n'as pas.

Agents :
1. Architecte iOS : analyse du dépôt, architecture, conventions, modèles partagés, registre des modules, interfaces entre modules, conflits.
2. Géolocalisation : CoreLocation, Always, géorepérage, arrivées/départs, changements significatifs, CLVisit, CoreMotion, arrière-plan, restauration, batterie, imprécision GPS, signaux de secours (Wi-Fi, Bluetooth, CarPlay, NFC).
3. Intelligence : habitudes, reconnaissance et découverte de lieux, classification, scores de confiance, anomalies, apprentissage des corrections, détection d'heures manquantes, prédiction d'heure de fin, générateur de disponibilités, détection de motifs de planning (répétitions, cycles, jours fériés), cohérence du trajet, plannings proposés (recherche sous contraintes), comparaison avec le passé, arbitrage cours contre travail, anticipation des périodes creuses, moteur de priorités d'actions, score de fiabilité des données, assistant local Demande-moi tout, phase de rodage, demande de dernière minute, rejouer ma journée, assistant de journée (détection de l'inhabituel).
4. OCR et plannings : import d'images, Vision, reconstruction de tableaux, identification de l'utilisateur, horaires, lecture de contrat et de fiche de paie, validation, rotation de planning, import par la feuille de partage, détecteur de changements de planning, planning par texte, équipe et échanges malins, scanner de planning papier, emploi du temps scolaire, vérificateur de contrat avant signature.
5. UI/UX : design system, SwiftUI, tous les écrans, onboarding, animations, accessibilité, fluidité, équilibre de la semaine, résumé partageable, carte de chaleur, retour de congé, simulateur de semaine en direct, jours fériés de l'année, historique des plannings, aperçu de fin de semaine, préparation de départ en vacances, protection à la capture et mode démo, termes expliqués, carnet de stage ou d'alternance, centre de fiabilité.
6. Données : SwiftData, relations, migrations, CloudKit, sauvegardes, export/restauration, intégrité, recherche indexée, journal infalsifiable (chaînage d'empreintes), annuler partout et instantanés, sauvegarde dans un dossier Fichiers, contrôle de l'horloge, agenda perso comme contrainte (EventKit).
7. Live Activities, widgets, App Intents, Concentration, notifications locales, corrections à la voix, check avant de partir, rappel de badgeuse, compte à rebours de fin de journée, brief du matin, mémos de lieu, trace de retard, notifications qui apprennent, gains en direct, pile intelligente et contrôles.
8. Emploi et paie : employeurs, contrats et fin de contrat, congés payés, moteur de règles de paie, packs de convention, recherche de conventions, primes, date de paie, banque d'heures, seuil fiscal, simulateur, prévu contre réel, rappel d'envoi des heures, historique des taux, suivi des frais, remplacements, journal de contrat, contacts du taf, dossier justificatif, carnet d'échanges, prévisions de primes et de solde, alerte de repos hebdomadaire, vérificateur de fiche de paie, préparation d'entretien, carnet d'expériences, équilibrage des heures du contrat, régularisation des heures payées, alerte de proximité du quota, périodes bloquées, vrai taux horaire, règles selon l'âge, temps annexes, compteurs de contraintes, période de paie personnalisée, déplacements entre sites.
9. Tests, sécurité, performances : XCTest, mémoire, fuites, énergie, confidentialité.
10. CI/CD : GitHub Actions, build, signature, IPA, releases, documentation.

Coordination : avant les développements parallèles, l'agent principal définit l'architecture, les contrats d'interface, les modèles et conventions partagés, et attribue à chaque agent ses fichiers, dépendances, tests et livrables. Deux agents ne modifient jamais les mêmes fichiers en même temps (branches ou espaces séparés si possible).
Intégration : l'agent principal relit le code réellement produit, intègre, résout les conflits, compile régulièrement, exécute les tests et corrige. Les agents contribuent au code, pas seulement à des rapports. Un module n'est pas terminé parce qu'un agent le dit.

## 2. PROFIL ET CONTEXTE D'USAGE

Utilisateur principal : un lycéen qui travaille aussi à temps partiel dans un supermarché. Cours la journée, travail le soir, le week-end ou pendant les vacances. Il fait aussi ses courses dans ce même supermarché. App personnelle, un seul utilisateur, en français uniquement, sans comptes ni partage.
Objectif concret : ne plus jamais noter ses heures à la main. Il ouvre l'app et voit ses heures de travail et de cours, jour par jour, avec les heures réelles d'arrivée et de départ. S'il active les modules correspondants : ce qu'il va toucher, l'écart avec son contrat, ses congés, ses objectifs.
Les horaires de travail changent d'une semaine à l'autre, parfois sans aucune régularité : l'app ne le suppose pas, mais détecte et propose les répétitions quand elles existent (sections 91 et 107).
Version minimale d'iOS : 17.

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

## 4. SCÉNARIOS DE RÉFÉRENCE (base des tests d'intégration)

A. Journée mixte : lycée 08:00 à 17:00, trajet, supermarché 18:00 à 22:00. Deux sessions séparées, activités différentes, un trajet entre les deux.
B. Courses : mardi 18:30 à 18:50 au supermarché, hors créneau habituel. Classé "courses", confiance moyenne, confirmation proposée une seule fois.
C. Travail un samedi : 09:00 à 16:00 au supermarché. Classé "travail" (durée longue, récurrence).
D. Passage rapide : moins de 5 minutes. Classé "passage", non compté dans les statistiques.
E. Pause : sortie de 30 minutes pour manger. Elle ne coupe pas la session si elle reste sous un seuil configurable (défaut 45 minutes) et si l'utilisateur revient. Sinon, deux sessions et question de confirmation.
F. GPS coupé ou téléphone éteint : session "incertaine", jamais supprimée, jamais inventée.
G. Planning photo : capture d'un planning de 10 personnes. L'app retrouve ses lignes par nom ou initiales et n'affiche que ses créneaux.
H. Rattrapage du passé : ajout des dernières semaines à la main ou par import.
I. Oubli de GPS : démarrage ou arrêt manuel en 1 tap (widget, Siri, bouton Action). La session manuelle prime sur la détection.
J. Vacances scolaires : plus de cours ni d'attentes de cours, créneaux de travail adaptés, aucune fausse anomalie d'absence.
K. Fin de mois : l'app compare heures du contrat, heures réelles, estimation de paie, et signale l'écart avec la fiche de paie saisie.
L. Mode examens : période de révisions, rappels réduits, statistiques annotées, rien de culpabilisant.
M. Départ à l'heure : prise de poste à 18:00, trajet estimé 22 minutes, marge 10 minutes : notification "Pars maintenant" à 17:28.
N. Noyau seul : tous les modules optionnels désactivés, l'app détecte, classe et affiche les heures sans rien demander d'autre, sans aucune permission superflue.
O. Deux employeurs : lundi supermarché 18:00 à 22:00, samedi autre employeur 09:00 à 13:00. Sessions rattachées au bon employeur, stats par employeur et cumul.
P. Fin de CDD : le CDD se termine dans 14 jours, alerte, checklist de fin de contrat, archivage ensuite.
Q. Nuit courte : fin de service prévue à 23:00, cours à 08:00 le lendemain, alerte avec le repos disponible.
R. Module activé puis désactivé : les données du module sont conservées, plus aucune interface ni notification, réactivation sans perte.
S. Remplacement : l'utilisateur arrive un mardi hors planning pour remplacer un collègue. L'app propose "Tu remplaces quelqu'un ?", il confirme, la session est comptée à part, sans fausse anomalie.
T. Mode vacances de l'app : une semaine de voyage, aucune détection ni notification, statistiques sans trou signalé, reprise propre à la date de fin.
U. Planning tardif : le planning de la semaine suivante n'est pas importé le vendredi, une seule relance douce, aucune relance en mode vacances.
V. Correction vocale : "J'ai fini à 22h30" dit à Siri ou dicté dans l'app, l'app répond "Je mets ta fin de journée à 22:30, c'est bon ?", applique après confirmation et garde l'heure d'origine.
W. Retard annoncé : le calcul de trajet prévoit une arrivée à 18:06 pour une prise de poste à 18:00, l'app propose "Je suis en retard", prépare un message prérempli pour le responsable, ne l'envoie jamais toute seule.
X. Dossier justificatif : l'utilisateur assemble en un PDF les relevés d'heures et les fiches de paie de l'année scolaire pour une demande de bourse, avec aperçu et sans envoi automatique.
Y. Heures manquantes : un créneau prévu hier soir n'a aucune session. Le lendemain l'app demande "T'as bossé ?", l'utilisateur répond oui, la session est ajoutée avec les horaires prévus et marquée à confirmer. Un jour de congé posé ne déclenche aucune question.
Z. Prévision de fin de mois : le net du mois travaillé et le net reçu ce mois-ci sont distingués à cause du décalage de paie, les hypothèses sont visibles et la fourchette tient compte du planning manquant.
AA. Brief du matin : à 07:00, notification "Aujourd'hui : cours 8 h à 17 h, taf 18 h à 22 h, départ à 17 h 28", ne mentionne que les modules actifs, version minimale pendant le mode examens.
AB. Rotation A/B : deux semaines alternées, l'utilisateur importe le planning de la semaine A, l'app préremplit la semaine B suivante comme "prévue par rotation", un planning réel importé ensuite la remplace.
AC. Jours consécutifs : le planning prévu enchaîne 7 jours de travail, l'app prévient avec la règle du pack comme source, ou dit que la règle est "à renseigner" sans rien affirmer.
AD. Import par partage : l'utilisateur partage une capture de planning depuis une messagerie, l'app s'ouvre sur l'écran de validation ; sans extension de partage, la voie "Ouvrir dans" fonctionne.
AE. Semaines toutes différentes : trois semaines d'affilée avec des créneaux différents. Aucune habitude abusive, aucun horaire inventé, aucune fausse anomalie, aucun brief inventé sans planning, la semaine sans planning est signalée.
AF. Fiche de paie douteuse : la fiche scannée ne contient pas la majoration de dimanche attendue par le pack. L'app signale un écart possible avec sa source, prépare un brouillon de message et ne l'envoie pas.
AG. Planning modifié : le jeudi de la semaine en cours passe de 18 h à 22 h à 14 h à 18 h. L'app affiche le diff, l'utilisateur accepte, les notifications programmées sont mises à jour, aucune question d'heures manquantes n'est posée pour l'ancien créneau.
AH. Intégrité : une session est modifiée directement dans la base ; la vérification d'intégrité détecte l'altération, alors qu'une correction faite par l'app reste valide.
AI. Cycle détecté : les plannings alternent sur 3 semaines. L'app propose "Tes plannings tournent sur 3 semaines (confiance 88 %)", l'utilisateur confirme, la semaine suivante est préremplie comme suggestion, une rupture du cycle baisse la confiance.
AJ. Rééquilibrage du contrat : contrat de 13 h par semaine, planning de 5 h le vendredi, 8 h le samedi et 5 h le dimanche. Vendredi réalisé 4 h : l'app calcule qu'il reste 9 h, que le planning en prévoit 13 et que la projection est de 17 h, soit 4 h de plus. Vendredi non fait mais samedi et dimanche faits : 13 h pile. Semaine à 18 h : classement selon le pack. Semaine à 10 h : options pour les 3 h manquantes.
AK. Jour férié : l'utilisateur a travaillé les deux derniers 11 novembre. L'app propose de prévoir ce créneau pour le prochain, avec la majoration du pack et sa source, et ne l'applique pas sans confirmation.
AL. Retour de congé : après 10 jours de vacances de l'app, un récap affiche les changements de planning, le solde de congés et les éléments à confirmer.
AM. Heures payées en moins : sur trois mois, les fiches de paie paient en moyenne 2 h de moins que les heures réalisées confirmées. L'app prépare un dossier de régularisation et ne l'envoie pas. Cas inverse : des heures payées en trop sont signalées avec le même soin.
AN. Quota proche : à 2 h du quota de 13 h, la notification "Plus que 2 h avant ton quota de la semaine" arrive pendant la session, une seule fois par seuil.
AO. Plannings proposés : trois propositions de semaine respectant les contraintes dures (cours, repos, quota), comparées côte à côte, aucune appliquée sans confirmation.
AP. Simulateur en direct : déplacer un créneau du samedi au dimanche met à jour quota, paie, charge et repos instantanément, sans modifier le réel.
AQ. Jour bloqué : le mercredi 19 est bloqué. L'app affiche l'impact (quota, paie, objectif), signale un créneau déjà prévu ce jour-là, propose message, congé ou échange, et n'annule rien automatiquement.
AR. Semaine bloquée : la semaine du 17 est bloquée. Plus aucune notification de travail, quota "à rattraper ou congé" selon le réglage, objectif d'épargne décalé, mode vacances proposé si c'est un voyage.
AS. Arbitrage : un créneau de travail proposé chevauche un cours de 14 h à 16 h. L'app affiche côte à côte le gain (heures, net, quota) et la perte (heures de cours, absences cumulées, contrôle prévu), propose "garder le cours", "garder le travail" ou "autre créneau", et ne marque aucune absence toute seule.
AT. Fin de semaine adaptée : pour un utilisateur qui travaille le week-end, l'aperçu du jeudi soir affiche samedi 8 h, dimanche 5 h, le reste pour son quota et ses jours de repos en semaine ; pour un utilisateur qui ne travaille pas le week-end, il annonce un week-end libre.
AU. Période creuse : trois semaines avant des vacances scolaires, l'app prévient que le quota risque de ne pas être atteint (heures à rattraper, net estimé en baisse) et propose des options.
AV. Historique : l'utilisateur retrouve la semaine du 3 mars avec le planning prévu, le réel, les versions et l'image d'origine, et la compare à une autre semaine.
AW. Départ en vacances : la checklist guide pas à pas la pose des congés, le blocage, le mode vacances, le message à l'employeur et la vérification de la sauvegarde.
AX. Équipe : à l'import d'un planning, l'utilisateur choisit de retenir son équipe. Pour un créneau qu'il veut céder, l'app liste les collègues sans créneau ce jour-là d'après le planning, prépare un brouillon, crée une entrée du carnet d'échanges et n'envoie rien.
AY. Planning par texte : un SMS "lun repos, mar 14-19, sam 9h-16h" collé avec le bouton de collage natif est compris, affiché en validation avec le texte surligné, sans import silencieux.
AZ. Carte Maintenant : à 17 h 20 la carte propose "Pars maintenant", à 22 h 05 "Confirme ta sortie", et sans urgence "Rien à faire, profites-en".
BA. Notifications qui apprennent : après 5 rappels de pause ignorés, l'app propose de les couper, l'utilisateur accepte en un tap, rien n'est coupé sans son accord.
BB. Gains en direct : un widget affiche une estimation qui avance minute par minute (masquée par défaut) ; la Live Activity ne promet aucun défilement.
BC. Contrôles : depuis le Centre de contrôle (iOS 18) ou le Bouton Action, démarrer ou arrêter une session en un tap ; sous iOS 17, repli par widget interactif et Raccourcis.
BD. Vrai taux horaire : taux net du contrat contre taux net après frais et trajets, hypothèses visibles et modifiables.
BE. Fiabilité : avant l'envoi d'un relevé, "ta semaine est fiable à 92 %, 2 sessions à confirmer", sans blocage.
BF. Annuler : une fin de session modifiée par erreur est annulée en un geste ; "revenir à l'état de ce matin" restaure un instantané après aperçu, en créant d'abord un instantané de l'état actuel.
BG. Délai de prévenance : un changement de planning annoncé 2 jours avant le créneau est comparé à la règle applicable sourcée. L'app signale poliment l'écart avec la source, rappelle que des exceptions existent (accord, urgence, volontariat) et ne conclut rien.
BH. Calibration d'un lieu : les arrivées au taf sont détectées en moyenne 80 m plus loin que le centre du lieu. L'app propose de déplacer le centre ou d'agrandir le rayon, avec aperçu, et n'applique rien sans confirmation.
BI. Batterie vide : le téléphone s'éteint à 21 h 40 avec 4 % de batterie. Au redémarrage, l'app propose une fin de session estimée à 21 h 40, marquée incertaine et bornée par les dernières traces, que l'utilisateur peut corriger.
BJ. Dépannage : une arrivée n'a pas été détectée. "Pourquoi ?" affiche les causes probables classées (autorisation "pendant l'utilisation", Mode économie d'énergie, rayon trop petit) avec un correctif en un tap pour chacune.
BK. Widgets : le widget "Heures et quota" s'affiche dans toutes ses familles, en plein couleur, teinté et clair. Les montants sont masqués sur l'écran verrouillé, un widget d'un module désactivé affiche l'invitation à l'activer, et la famille XL portrait n'est compilée qu'avec le SDK iOS 27.
BL. Live Activity de 9 heures : à l'approche des 8 heures, une notification locale "Relancer l'affichage ?" apparaît, un tap relance une Live Activity avec le même chronomètre. Sans tap, le widget "encore X h" prend le relais et le suivi continue sans interruption.
BM. Bases de calcul : une session de 17:56 à 22:03 donne 4 h 07 sur la base exacte, 4 h 00 sur la base normalisée à la demi-heure et 4 h 00 sur la base prévue 18:00 à 22:00. L'utilisateur voit les trois et la base retenue. Une session de 20:55 à 21:10 coupe la tranche de soirée à 21:00 sur la base exacte.
BN. Cas de doute : arrivée détectée à 17:38. L'app propose 17:00, 17:30, 18:00, l'heure du planning 18:00 ou l'heure exacte 17:38, l'utilisateur choisit 18:00. Les totaux affichent "dont 1 h à choisir" jusqu'au choix, et après 3 choix concordants l'app propose 18:00 par défaut avec confirmation en un tap.
BO. Signal de secours : le GPS ne capte pas dans la réserve. La connexion au Wi-Fi du magasin déclenche une automatisation Raccourcis qui envoie un signal à l'app, laquelle enregistre une arrivée probable à confirmer, avec sa marge d'erreur.
BP. Sauvegarde dans un dossier : l'utilisateur choisit un dossier iCloud Drive, l'app y écrit une sauvegarde chaque semaine avec manifeste d'empreintes. Après suppression de l'app, la restauration depuis ce dossier fonctionne, avec aperçu et instantané préalable.
BQ. Capture et démo : pendant un enregistrement d'écran, montants, lieux et noms sont floutés automatiquement. Le mode démo montre l'app avec des données fictives isolées, sans toucher aux vraies.
BR. Demande-moi tout : "Combien j'ai fait de dimanches en octobre ?" donne une réponse en français dont chaque chiffre vient d'un résultat de fonction vérifiable, avec lien vers les sessions. Sur un appareil sans modèle sur l'appareil, la recherche normale prend le relais.
BS. Scanner papier : trois photos d'un grand tableau mural sont corrigées en perspective, un reflet est signalé avec un conseil de reprise, et les résultats sont fusionnés par recouvrement en un seul planning à valider.
BT. Rodage : pendant les 14 premiers jours, l'app pose au plus 3 questions groupées par jour et affiche une progression, puis annonce la fin du rodage et réduit ses questions.
BU. Horloge : l'heure du téléphone est avancée de 4 minutes à la main. L'app détecte le saut ou la dérive, avertit, marque les sessions concernées "à vérifier" et propose une correction avec confirmation.
BV. Règles selon l'âge : pour un utilisateur qui fête ses 18 ans, les règles changent à la date exacte, avec une notification qui les résume avec leurs sources.
BW. Demande de dernière minute : le message "tu peux venir demain 14h-19h ?" est partagé à l'app. Elle affiche le conflit avec un cours de 14 h à 16 h, l'effet sur le quota, la paie estimée et le repos, propose trois réponses brouillon, n'envoie rien, et n'ajoute le créneau au prévu qu'après confirmation.
BX. Emploi du temps scolaire : un emploi du temps en semaines A/B est importé par photo. Un cours annulé, marqué en un tap, propose le créneau libéré (révision, repos ou disponibilité) sans jamais inciter à manquer un cours.
BY. Temps annexes : un briefing de 10 minutes avant l'ouverture est ajouté en un tap. Il est compté séparément, avec le statut "payé" ou "à renseigner" selon le réglage, et apparaît dans le relevé sans modifier les horodatages de la session.
BZ. Compteurs de contraintes : au 14e dimanche travaillé de l'année, l'app l'affiche avec la limite de la convention si elle existe et est sourcée, sinon "pas de limite renseignée".
CA. Période de paie du 26 au 25 : une session de 23 h 50 le 25 à 00 h 20 le 26 est rattachée aux bonnes périodes sur la base exacte. Un rappel arrive 3 jours avant la clôture pour vérifier les heures.
CB. Contrat avant signature : le scan donne une checklist "présent, absent, à vérifier" avec sources et questions à poser, sans jamais écrire "illégal".
CC. Carnet de stage : une journée avec tâches et compétences est enregistrée, et le récapitulatif hebdomadaire PDF est généré avec une zone de signature vierge, à faire valider par le tuteur.
CD. Rejouer ma journée : la relecture animée montre événements, sources et marges, l'utilisateur corrige un horodatage en un tap, et aucune trace GPS n'est conservée.
CE. Termes expliqués : un tap sur l'icône d'aide à côté de "heures complémentaires" ouvre une explication de deux phrases avec source et date de vérification.
CF. Déplacements entre sites : le départ du magasin A puis l'arrivée au magasin B, même employeur, sont classés déplacement professionnel, comptés selon le réglage, et l'indemnité kilométrique saisie crée une ligne de frais sans doublon.
CG. Agenda comme contrainte : un rendez-vous du calendrier iOS est pris en compte par les disponibilités et les plannings proposés, sans stocker son titre ni l'exporter.
CH. Assistant de journée : une arrivée 1 h 40 plus tard que d'habitude pour ce type de créneau est signalée avec sa raison chiffrée et sans accusation. L'utilisateur répond "C'est normal", et aucun signalement n'est produit quand le planning de la semaine explique l'écart.
CI. Centre de fiabilité : un écran unique affiche le taux de détections confirmées sans correction, les permissions manquantes, les sessions à vérifier, l'état de la sauvegarde, de l'horloge et des lieux, avec un badge discret et trois actions à faire maintenant.
CJ. Questions sans modèle : "Quand suis-je allé pour la dernière fois à tel endroit ?" reçoit une réponse sur un appareil sans modèle de langage, avec la date, la base de calcul et un lien vers la session.
CK. Ta semaine : le dimanche soir, une seule notification ouvre un écran avec d'abord les éléments à confirmer, puis le bilan de la semaine (heures de travail, de cours, de trajets, quota). Sans activité suffisante, aucun bilan n'est produit.

## 5. PERFORMANCE (PRIORITÉ ABSOLUE)

Démarrage : démarrage à froid optimisé, accueil affiché rapidement, jamais d'attente d'une opération GPS, chargement progressif, initialisation différée du secondaire et des modules, aucun calcul lourd sur le thread principal.
Interface : 60 FPS minimum, 120 Hz si disponible, éviter les recalculs SwiftUI inutiles, listes paresseuses, identifiants stables, états globaux limités, animations légères, pas de rechargement d'écran entier pour une modification mineure.
Architecture : Swift Concurrency, async/await, actors pertinents, caches à invalidation ciblée, accès asynchrones aux données, peu d'allocations.
Batterie : pas de GPS haute précision permanent, privilégier géorepérage et changements significatifs, réduire le suivi à l'immobilité (CoreMotion), pas de timers permanents, pas de réveils inutiles, respecter la suspension iOS.
Mesures : Instruments et XCTest (lancement, affichage, statistiques, mémoire, fluidité, énergie, plusieurs milliers de sessions, recherche). Ne pas sacrifier la fiabilité à des benchmarks artificiels.

## 6. TECHNOLOGIES ET CONTRAINTES

Swift, SwiftUI, SwiftData, CoreLocation, CoreMotion, MapKit (dont MKDirections), Vision, ActivityKit, WidgetKit, App Intents, Swift Charts, UserNotifications, EventKit (facultatif), LocalAuthentication, CoreNFC (facultatif), Intents (état de Concentration, facultatif), BackgroundTasks, CryptoKit, Speech (reconnaissance sur l'appareil), PDFKit, NaturalLanguage, ContactsUI (sélecteur de contacts), SwiftUI (PasteButton, ImageRenderer, ShareLink, TimelineView), ControlWidget (iOS 18 ou plus), VisionKit (scanner de documents), Foundation Models (modèle sur l'appareil, iOS 26 ou plus, avec vérification de disponibilité), CloudKit (facultatif), XCTest. Les fonctions récentes (iOS 18, 26, 27) sont toujours derrière une vérification de disponibilité, la version minimale restant iOS 17. Le projet fournit un manifeste de confidentialité (PrivacyInfo.xcprivacy) déclarant les API à raison requise utilisées (UserDefaults, horodatages de fichiers, heure de démarrage du système, espace disque). Pas de React Native, Flutter ni WebView. Peu de dépendances. Vérifier la disponibilité de chaque API dans le SDK utilisé, ne jamais inventer d'API.

Compte Apple Developer gratuit : l'app doit compiler et fonctionner avec. Localisation Always, SwiftData, notifications locales, widgets et Live Activities le permettent. CloudKit/iCloud exigent un compte payant : isoler CloudKit derrière le flag de compilation ENABLE_CLOUDKIT. L'export/import JSON reste la sauvegarde de secours. Viser une app et une seule extension (widgets et Live Activity ensemble), sauf une extension de partage optionnelle derrière le flag ENABLE_SHARE_EXTENSION, non compilée par défaut (section 90). Les widgets lisent les données via un App Group, avec un fallback si l'App Group est indisponible en sideload gratuit.

## 7. ARCHITECTURE

Structure indicative, améliorable :

```
PersonalLifeTracker/
  App/
  Core/ (Models, Persistence, Services, Utilities, ModuleRegistry)
  Features/
    Core/ (Home, Locations, Statistics, ActivityTracking, Settings)
    Modules/ (un dossier par module, liste dans MODULES.md)
  Services/ (LocationService, ActivityDetectionService, HabitLearningService, PlaceDiscoveryService, PlaceCalibrationService, ScheduleOCRService, PlanningTextParser, PayslipOCRService, StatisticsService, PayService, ConventionService, LeaveService, ContractLifecycleService, ContractHoursService, SimulatorService, PatternDetectionService, TravelTimeService, GoalService, RecapService, SearchService, DataTrustService, ActionEngine, NotificationCoordinator, CapabilityService, UndoService, SnapshotService, IntegrityService, CloudSyncService, LiveActivityService, WidgetDataService, SignalService, FolderBackupService, ClockService, AssistantToolService, AgeRulesService, PaperScanService, TimetableService, OfferImpactService, PayPeriodService, ContractCheckService, DayReplayService, GlossaryService, CalendarConstraintsService, DayInsightService, ReliabilityCenterService)
  Widgets/ (extension unique : widgets, Live Activity, contrôles)
  Resources/ (conventions/*.json, reference/*.json, Localizable.xcstrings, PrivacyInfo.xcprivacy)
  Tests/ (UnitTests, IntegrationTests)
```

Pas de logique métier dans les vues, pas d'abstractions inutiles, responsabilités claires. Le code d'un module optionnel ne dépend jamais du noyau dans l'autre sens.

---

# B. NOYAU (TOUJOURS ACTIF)

## 8. GÉOLOCALISATION ET AUTORISATION ALWAYS

Parcours de permission progressif : expliquer l'intérêt, demander l'autorisation initiale, expliquer pourquoi Always est nécessaire, demander Always au moment adapté au processus iOS, détecter refus et restrictions, proposer les Réglages. Ne jamais prétendre imposer une autorisation, ne jamais bloquer l'app en cas de refus (mode réduit).
Surveillance : CLCircularRegion, startMonitoring(for:), startMonitoringSignificantLocationChanges(), CLMonitor si disponible, événements de région, restauration du suivi. API choisies selon l'iOS minimal, pas de surveillance redondante, limite de 20 régions respectée, lieux importants prioritaires.
Arrivées : combiner distance, précision, stabilité, durée de présence, événement de région, habitudes, contexte. Jamais d'arrivée sur une seule position imprécise.
Départs : éviter les faux positifs. Une perte momentanée de GPS n'est pas un départ. Utiliser distance, stabilité, temps hors zone, événements de région, cohérence temporelle.
Arrière-plan : fonctionner écran verrouillé, app en arrière-plan ou suspendue, réactivation par événement système, redémarrage du téléphone. Distinguer suspension système et arrêt forcé par l'utilisateur, ne jamais promettre un suivi garanti après un forçage à quitter.
Récupération : au lancement suivant, reconstituer les événements manqués à partir des événements de région, changements significatifs et visites, et marquer ces sessions "reconstituées".
CoreMotion : activité (immobile, marche, voiture, transport) pour réduire la consommation, détecter les trajets et affiner les départs.

## 9. APPRENTISSAGE DES HABITUDES

Apprentissage local, sans planning requis, sans IA distante. Moteur de règles et de scoring explicable, testable, performant.
Par lieu : coordonnées, rayon estimé, nombre de visites, jours habituels, heures d'arrivée et de départ, durée moyenne/min/max, activités associées, confiance. Apprendre les récurrences quotidiennes et hebdomadaires quand elles existent, sans jamais en supposer : si les horaires varient d'une semaine à l'autre (section 91), la récurrence pèse peu et les habitudes restent des hypothèses. L'app cherche activement les répétitions réelles et les propose avec leur niveau de confiance (section 107). Jamais d'habitude à partir d'une seule visite. Distinguer hypothèses et habitudes confirmées.

## 10. AJOUT ET CONFIGURATION D'UN LIEU

Parcours de moins de 30 secondes :
1. Bouton "Ajouter un lieu" (onglet Lieux ou accueil).
2. Choix : position actuelle, recherche d'adresse (MapKit) ou point sur la carte.
3. Nom, rayon réglable avec aperçu sur la carte (défaut 100 m).
4. Catégorie : Travail, Études, Domicile, Commerce, Autre.
5. Case "J'y travaille aussi" pour un lieu pouvant servir aux courses : active la logique travail contre courses.
6. Horaires habituels optionnels (apprenables ensuite).
7. Si les modules concernés sont actifs : employeur rattaché (18), mode de transport habituel (35).
Le domicile est configuré à part et sert de référence pour les trajets. Plusieurs lieux de travail possibles. Lieux : renommer, fusionner, modifier, supprimer.

## 11. LOGIQUE TRAVAIL CONTRE COURSES

Un supermarché peut être lieu de travail, de courses et de visite. Score de 0 à 100 par visite d'un lieu à double usage, explicable dans l'écran de détail ("Pourquoi cette classification ?").
Facteurs par ordre d'importance :
1. Correction manuelle antérieure dans un contexte similaire (même jour de semaine, plage horaire proche).
2. Correspondance avec un créneau du planning importé de la semaine (si le module est actif). Quand les plannings varient, c'est le facteur le plus fiable après les corrections manuelles.
3. Durée : sous 20 minutes, probablement des courses ; au-dessus de 2 heures, probablement du travail ; entre les deux, ambigu.
4. Récurrence : même jour et même heure d'arrivée que des visites déjà confirmées comme travail (poids réduit quand les plannings varient d'une semaine à l'autre).
5. Heure d'arrivée proche d'une prise de poste habituelle.
6. Contexte : arrivée directe depuis le lycée ou le domicile à une heure de prise de poste.
Analyser aussi les activités précédentes et suivantes.
Seuils : au-dessus de 75, classement automatique sans question. Entre 40 et 75, classement provisoire et confirmation proposée. Sous 40, "inconnu" avec demande de confirmation.
Types : travail, courses, visite personnelle, passage, inconnu, et avec le module multi_site déplacement professionnel (section 151).
Toute confirmation ou correction crée une règle locale limitée à son contexte (lieu, jour, plage horaire). Après 3 confirmations concordantes dans un même contexte, la classification devient automatique pour ce contexte. Jamais de correction appliquée à tous les contextes.

## 12. ÉTUDES

Reconnaître les lieux éducatifs (lycée, collège, université, école, centre de formation). Détecter les cours par horaires, récurrences, lieux et plannings. Statistiques travail, études, déplacements et temps personnel strictement séparées. Plusieurs sessions par jour possibles, qui ne fusionnent jamais. Les cours prévus peuvent venir d'un emploi du temps importé (section 143).

## 13. HORAIRES INTELLIGENTS ET NORMALISATION

Toujours conserver séparément : heure détectée, interprétée, normalisée, confirmée manuellement. Ne jamais écraser l'heure originale. Distinguer temps observé, normalisé et retenu pour les statistiques (voir 13.1).
Arrondis configurables : aucun, heure pleine, 5, 10, 15, 30 minutes. Règle par défaut de la base normalisée : heure pleine avec zone de doute. Hors zone de doute, arrondi automatique à l'heure pleine la plus proche : de :00 à :14 vers l'heure en cours, de :46 à :59 vers l'heure suivante. Zone de doute : de :15 à :45 (quarts d'heure et demi-heure compris) et tout cas incertain (voir ci-dessous). Exemples : 06:02 devient 06:00, 06:14 devient 06:00, 07:12 devient 07:00, 05:47 devient 06:00, 07:46 devient 08:00 ; 06:15, 06:29, 06:31 et 06:45 sont en zone de doute, l'app propose et l'utilisateur choisit. Jamais appliqués aveuglément à toutes les données.
Cas de doute : minutes entre :15 et :45, marge d'erreur de l'horodatage supérieure à 5 minutes, sources contradictoires, confiance faible, session reconstituée, écart important avec le planning, frontière de majoration proche. L'app propose 3 à 5 options en un tap : heure pleine inférieure, demi-heure, heure pleine supérieure, heure du planning (si elle existe), heure exacte. Les propositions arrivent groupées (carte Maintenant, revue de la semaine), pas une notification par cas. Tant que l'utilisateur n'a pas choisi, la valeur provisoire est marquée "à choisir" et les totaux indiquent "dont X h à choisir", jamais présentés comme définitifs. Apprentissage : après 3 choix concordants dans un même contexte (lieu, créneau, type de doute), l'app propose ce choix par défaut avec confirmation en un tap ; il ne devient automatique que si l'utilisateur l'active pour ce contexte.
OCR : distinguer valeur textuelle, interprétée, normalisée et confiance. "6h31" peut devenir 06:30 si le contexte le justifie ; une lecture ambiguë entre 06:30 et 08:30 n'est jamais devinée.
Incertitude : demander confirmation si plusieurs lectures OCR sont possibles, si l'écart est de 15 à 20 minutes ou plus, si l'horaire est incohérent avec le planning, si la détection GPS est tardive, le départ incertain ou la position imprécise. Ne solliciter l'utilisateur que si ça apporte de la valeur.
Apprentissage : une interprétation régulièrement confirmée améliore les estimations dans ce contexte uniquement. Jamais de présence inventée avant l'arrivée réelle.

13.1 Bases de calcul des heures : horodatage exact, heure normalisée, heure prévue
Chaque session porte trois bases de temps calculées en parallèle, jamais l'une à la place des autres :
- Base exacte : horodatages réels de début et de fin, stockés à la seconde avec le fuseau horaire (date en UTC plus identifiant de fuseau), durées calculées en secondes, sans arrondi.
- Base normalisée : heures arrondies selon la règle ci-dessus (par défaut heures pleines avec zone de doute et choix de l'utilisateur, configurable).
- Base prévue : heures du planning ou du contrat pour le créneau correspondant, quand elles existent.
Origine des horodatages : pour chaque début et chaque fin, l'app garde la source et une marge d'erreur : dates d'arrivée et de départ d'une visite (CLVisit), horodatage de la position qui a déclenché la détection (CLLocation.timestamp), heure de réception d'un événement de région (qui peut arriver en retard sur l'événement réel), saisie manuelle, réponse à une notification, import. Quand plusieurs sources existent, l'heure exacte retenue est la plus fiable, bornée par les traces, avec sa marge affichée ("17:56, à plus ou moins 3 min"). Jamais d'horodatage antérieur à la première preuve de présence.
Base retenue : réglage par usage (statistiques et affichage, quota du contrat, paie estimée, relevé d'heures, comptes à rebours et gains en direct, bilans). Par défaut, la base normalisée en heures pleines (valeurs validées par l'utilisateur dans les cas de doute) sert aux statistiques, au quota, à la paie estimée et au relevé ; la base exacte sert à l'affichage des heures de la journée, aux comptes à rebours et aux gains en direct, et reste toujours affichée à côté. Par employeur, un réglage "payé sur" : heure exacte, heure normalisée, heure du planning, ou heure du planning sauf dépassement de X minutes (puis heure exacte).
Découpage horaire : minuit, dimanche, jours fériés, soirée et nuit (majorations de la section 22) et durées de pause se calculent sur la base retenue avec une précision d'au moins la minute, aux frontières exactes (une session de 20:55 à 21:10 coupe la tranche de soirée à 21:00 sur la base exacte).
Affichage : chaque total (jour, semaine, mois) indique la base retenue et, au tap, montre les trois bases côte à côte avec leurs écarts ("exact 6 h 47, normalisé 7 h, planning 7 h"). Le relevé d'heures donne arrivée et départ exacts et normalisés, les totaux sur chaque base et la base utilisée pour les montants.
Cohérence : changer la base retenue ne modifie aucune donnée, tout est recalculé à partir des sessions d'origine, avec trace dans le journal des modifications. Les changements d'heure d'été et d'hiver et les sessions à cheval sur minuit donnent la durée réelle en secondes.

## 14. SESSIONS

Modèle minimal : identifiant, type d'activité, lieu, employeur (si le module Emploi est actif), début réel, fin réelle (horodatages exacts à la seconde, avec fuseau, source et marge d'erreur de chacun, voir 13.1), durée, source (GPS, manuelle, planning, import, reconstituée), confiance, début et fin normalisés, statut de validation, notes.
Types : work, education, shopping, personal, travel, unknown.
États : en cours, terminée, interrompue, incertaine, corrigée.
Gérer redémarrages, pertes GPS, doublons, anomalies. Jamais de suppression automatique d'une session inhabituelle. Journal des modifications : toute correction conserve valeur d'origine, nouvelle valeur et date.

## 15. SAISIE MANUELLE, IMPORT ET DÉMARRAGE RAPIDE

15.1 Ajout rapide : journée de travail, session de cours, visite, activité personnelle, déplacement, lieu, créneau de planning. Préremplissage intelligent (date, heure, dernier lieu, type habituel, horaires récurrents). Modifier heures, lieu, activité ; fusionner, séparer, supprimer, ajouter des notes.
15.2 Démarrage/arrêt manuel en 1 tap : accueil, widget interactif (si actif), App Intents (Siri, Raccourcis, bouton Action). La session manuelle prime sur la détection.
15.3 Import du passé : images, PDF, CSV, JSON, ICS, avec vérification avant enregistrement. Option "journée type" pour remplir plusieurs jours identiques. Les corrections alimentent l'apprentissage.
15.4 Export : JSON complet, CSV des sessions.
15.5 Tag NFC (module nfc, facultatif) : pointage fiable à l'entrée du lieu de travail, lisible via un raccourci, seulement si la build et l'appareil le permettent.

---

# C. MODULES OPTIONNELS

Rappel (section 3) : chaque module ci-dessous est activable et désactivable, sans effet sur le noyau.

## 16. PLANNING PAR PHOTO (module planning_ocr)

Formats : JPG, JPEG, PNG, HEIC, captures d'écran, PDF si pertinent. Traitement local avec Vision (VNRecognizeTextRequest).
Parcours :
1. Profil unique : prénom, nom, initiales, surnoms, plusieurs variantes possibles.
2. Import depuis Photos, Fichiers ou capture partagée.
3. Analyse locale avec indicateur de progression.
4. Écran de validation : image d'origine en haut, planning reconstruit en bas, créneaux de l'utilisateur surlignés. Si plusieurs lignes ressemblent à son nom, l'app demande de choisir.
5. Chaque créneau est modifiable (date, début, fin, activité, lieu), ajout et suppression possibles.
6. Confirmation : les créneaux deviennent le planning prévu, comparable ensuite au réel.
Extraction : jours, dates, heures, noms, prénoms, initiales, matières, activités, lieux. Reconstruction par la position des textes (colonnes, lignes, en-têtes, cases, créneaux, association personnes/horaires), jamais en lisant le texte dans l'ordre. Gérer : semaine en colonnes, une personne par ligne ou par colonne, "8h-12h / 14h-18h", abréviations de jours, cases vides, repos, congés.
Ne jamais supposer que le premier nom détecté est le bon. Ne jamais enregistrer silencieusement un résultat incertain. Afficher l'écart avec le réel ("prévu 18:00, arrivé 17:56").
Onglet Planning : vues jour, semaine, mois ; distinguer prévu, réel, détecté, corrigé ; détection de conflits (créneau de travail qui chevauche un cours ou un trajet).

## 17. DÉCOUVERTE AUTOMATIQUE DES LIEUX (module place_discovery)

Utiliser CLVisit pour repérer les endroits où l'utilisateur s'arrête régulièrement. Après plusieurs visites cohérentes, proposer "Tu passes souvent ici, c'est quoi ?" avec choix rapides (Travail, Études, Domicile, Commerce, Autre) ou ignorer. Jamais de lieu créé sans confirmation, une seule proposition par lieu sauf demande.

## 18. EMPLOYEURS ET CONTRATS (module employment, puis multi_employer)

18.1 Modèle Employer : nom, couleur, icône, lieux associés, contrat (type, dates, heures, taux), convention, paramètres de pause, rappel d'envoi des heures, statut (actif, archivé). Archiver un employeur ne détruit aucune donnée.
18.2 Contrat : type (CDI, CDD, saisonnier ou job d'été, alternance, intérim, extra ou contrat ponctuel, stage, autre), date de début, date de fin si déterminée, période d'essai, heures par semaine ou par mois, jours et horaires habituels (facultatifs, absents si les semaines sont toutes différentes), rémunération (voir section 20). Écran "Mon contrat" accessible en moins de 3 taps.
18.3 Plusieurs employeurs (module multi_employer) :
- Chaque session de travail est rattachée à un employeur : automatiquement via le lieu, sinon demandé une seule fois et mémorisé pour ce contexte.
- Statistiques, paie, congés, prévu contre réel et relevés d'heures sont calculés par employeur, avec une vue "Tout" qui additionne.
- Contrats chevauchants autorisés. Détection de conflits : deux sessions de travail qui se chevauchent, ou trajet impossible entre deux employeurs, signalés avec demande de confirmation.
- Contrôle du cumul : l'app additionne les heures de tous les employeurs et avertit quand le total approche les durées maximales légales (règle générale à sourcer dans reference/contracts.json, à vérifier), avec la source.
- Live Activity, widgets, notifications et bilans affichent le nom et la couleur de l'employeur concerné. Filtre par employeur dans la recherche.
- Ajout d'un employeur en moins de 2 minutes, depuis l'onboarding ou les réglages. Objectifs d'épargne et simulateur utilisent la somme des employeurs actifs ou un employeur choisi.
Sans le module multi_employer, un seul employeur actif : aucun sélecteur ni champ superflu.

## 19. CYCLE DE VIE DU CONTRAT ET FIN DE CONTRAT (module employment)

Chaque contrat porte : type, date de début, date de fin (si déterminée), période d'essai (durée, date de fin, renouvelable ou non), motif éventuel, nombre de renouvellements.
Les règles générales (durée de la période d'essai, renouvellement, durée maximale d'un CDD, indemnité de fin de contrat et cas où elle ne s'applique pas, par exemple certains contrats saisonniers ou jobs d'étudiant pendant les vacances, délai de carence entre deux CDD, préavis) ne sont JAMAIS codées en dur. Elles vivent dans Resources/reference/contracts.json avec source officielle et date de vérification. L'agent les recherche sur service-public.fr, Légifrance et code.travail.gouv.fr, et marque "à vérifier" ce qu'il ne peut pas confirmer. Le pack de convention prime sur les règles générales quand il est renseigné.
Affichage : carte "Mon contrat" avec statut (en période d'essai, en cours, bientôt terminé, terminé), décompte ("Fin de ton CDD dans 23 jours"), et pour un CDD une estimation indicative de l'indemnité de fin de contrat quand elle s'applique.
Alertes configurables : fin de période d'essai (par exemple 7 et 2 jours avant), fin de CDD ou de saisonnier (14 et 3 jours avant), fin d'alternance ou de stage, anniversaire du contrat.
Checklist de fin de contrat (cases à cocher, chaque ligne explique à quoi ça sert) : certificat de travail, solde de tout compte, attestation pour France Travail, dernière fiche de paie, relevé des congés non pris, restitution du matériel, export du relevé d'heures final.
Un contrat terminé est archivé, jamais supprimé : sessions, stats et bilans restent consultables. Créer le contrat suivant d'un tap (renouvellement, passage en CDI) en reprenant les informations.
Aucun conseil juridique : l'app informe, cite ses sources, invite à vérifier le contrat.

## 20. SALAIRE, PAIE ET ESTIMATIONS (module pay)

Sans ce module, l'app n'affiche aucun montant.

20.1 Saisie ultra simple du salaire
- Bouton rapide "Je suis au SMIC" : remplit le taux avec le SMIC en vigueur lu dans le fichier de référence, avec sa date d'effet. Ou saisie libre du taux horaire ou du salaire mensuel.
- Choix de l'unité saisie : brut ou net. Conversion dans les deux sens avec un ratio net/brut configurable (défaut indicatif autour de 0,79 pour un salarié non cadre, modifiable), affiché comme estimation ("environ"). La fiche de paie fait foi.
- Option abattement jeunes salariés si l'utilisateur est concerné (règle du Code du travail, à sourcer dans le fichier de référence), désactivée par défaut.
- Le SMIC et tous les montants légaux ne sont JAMAIS codés en dur dans le Swift : ils vivent dans Resources/reference/legal.json (valeur, unité, date d'effet, source, date de vérification). L'agent recherche les valeurs en vigueur sur des sources officielles (service-public.fr, Légifrance, info.gouv.fr) en tenant compte des revalorisations en cours d'année, et laisse "à vérifier" tout ce qu'il ne peut pas confirmer. L'app affiche la date de dernière vérification et invite à vérifier quand le fichier date de plus de 6 mois.

20.2 Affichage
Estimation indicative du brut et du net du mois en cours et du précédent, heures par semaine, détail des majorations ("dimanche +X %", "soirée +X %") avec la source de la règle, primes saisies (section 26). Chaque montant précise que c'est indicatif. Sessions incertaines exclues des totaux ou clairement signalées. Les montants se calculent sur la base retenue (section 13.1) et l'écart avec les autres bases reste consultable. Mode discret : masque les montants, tap pour révéler.
Relevé d'heures : export PDF et CSV mensuel (jours, arrivée et départ exacts et normalisés, pauses, total sur chaque base, majorations), avec mention des sessions corrigées ou reconstituées. Les temps annexes (section 144) et la période de paie de l'employeur (section 146) y figurent quand ces modules sont actifs.

20.3 Scan de la fiche de paie (optionnel dans le module)
Photo ou import de la fiche de paie, lecture locale avec Vision. L'app lit, propose et fait confirmer ligne par ligne : période, convention et IDCC, heures payées, brut, net payé, congés acquis, pris et solde, lignes de primes. Elle compare ensuite avec sa propre estimation ("fiche de paie : 41 h payées, tes sessions : 43 h 30, écart 2 h 30, soit environ X €") et peut préremplir le solde de congés et le contrat, après confirmation. Jamais de préremplissage silencieux, jamais de transmission de la fiche.

## 21. CONVENTIONS COLLECTIVES : RECHERCHE ET CHOIX (module pay)

Écran "Ta convention" :
- Barre de recherche tolérante : par mots-clés courants ("supermarché", "alimentaire", "caisse", "vendeur auto", "garage", "resto", "fast-food", "coiffure", "pharmacie", "ménage", "livraison", "bâtiment"), par nom de convention ou par numéro IDCC. Insensible aux accents et aux fautes légères.
- Filtres par grands secteurs : Commerce alimentaire, Commerce non alimentaire, Habillement, Bricolage, Culture et loisirs, Restauration rapide, Hôtels-cafés-restaurants, Restauration collective, Automobile (vente et réparation), Pharmacie, Propreté, Transport routier, Bâtiment, Santé privée, Bureaux d'études et conseil, Sport et animation, Intérim, Commerce de gros, Autre.
- En tête, "Les plus courantes" (voir section 22), avec une phrase simple par convention ("Supermarchés, hypermarchés, supérettes").
- Chemin "Je ne sais pas" : explication ("c'est écrit en haut de ta fiche de paie ou dans ton contrat, avec un numéro à 4 chiffres"), et lecture par OCR de la fiche de paie ou du contrat pour proposer la correspondance à confirmer.
- Option "Je ne trouve pas ma convention" : règles générales du Code du travail et saisie manuelle de ses propres règles (pack Personnalisé).
- La convention choisie affiche ce que l'app en tire (majorations, pauses, durées maximales, repos minimal) et ce qui reste "à renseigner".
Changer de convention ne détruit rien : le calcul est refait à partir des sessions d'origine.

## 22. PACKS DE CONVENTION (module pay)

Chaque pack est un fichier JSON versionné dans Resources/conventions/, lisible et modifiable : nom, IDCC, secteur, mots-clés de recherche, description simple, liens vers sources officielles, date de dernière vérification, et règles : majoration dimanche, jours fériés, soirée et nuit, heures complémentaires et supplémentaires, pauses, durées maximales quotidienne et hebdomadaire, repos minimal entre deux journées, primes usuelles (proposées, jamais appliquées sans confirmation), banque d'heures, remarques.
Priorité : valeurs saisies par l'utilisateur depuis son contrat ou sa fiche de paie, puis pack de convention, puis règles générales du Code du travail. Surcharge manuelle de chaque règle en quelques taps.

Packs à créer en priorité (les plus utilisés ; l'agent valide chaque numéro et chaque nom sur Légifrance ou code.travail.gouv.fr et corrige s'il est inexact) :
- Commerce de détail et de gros à prédominance alimentaire (IDCC 2216)
- Commerce de détail non alimentaire (IDCC 1517)
- Commerce de détail de l'habillement et articles textiles (IDCC 1483)
- Commerces de détail de bricolage (IDCC 1606)
- Commerce de détail de produits culturels et de loisirs (IDCC 1686)
- Commerce de gros (IDCC 573)
- Restauration rapide (IDCC 1501)
- Hôtels, cafés, restaurants (IDCC 1979)
- Restauration de collectivités (IDCC 1266)
- Commerce et réparation de l'automobile, du cycle et du motocycle, vendeurs en concession ou garage (IDCC 1090)
- Pharmacie d'officine (IDCC 1996)
- Propreté et services associés (IDCC 3043)
- Transports routiers et activités auxiliaires (IDCC 16)
- Bureaux d'études techniques, conseil, ingénierie (IDCC 1486)
- Prestataires de services du secteur tertiaire (IDCC 2098)
- Travail temporaire (IDCC 2378)
- Hospitalisation privée (IDCC 2264)
- Sport (IDCC 2511) et animation (IDCC 1518)
- Bâtiment : ouvriers jusqu'à 10 salariés (IDCC 1596) et plus de 10 salariés (IDCC 1597)
- Personnalisée (l'utilisateur saisit tout)
- Règles générales du Code du travail (pack de base utilisé par défaut)
Pas besoin d'être exhaustif : l'architecture permet d'ajouter un pack en déposant un fichier JSON, sans recompiler.

Travail de l'agent : rechercher sur internet, dans des sources officielles (Légifrance, service-public.fr, code.travail.gouv.fr, texte de la convention), les règles de chaque pack, en commençant par le pack supermarché. Remplir chaque pack avec sources et date de vérification. Ne rien inventer : règle introuvable ou ambiguë, la laisser vide, la marquer "à renseigner", la lister dans le rapport final. Beaucoup de règles dépendent de l'entreprise (accords internes) : l'app le dit et invite à vérifier son contrat.
Mise à jour des packs sans serveur obligatoire : import d'un fichier JSON, et en option (désactivée par défaut) téléchargement depuis une URL statique (par exemple un fichier JSON dans le dépôt GitHub), sans aucune donnée personnelle envoyée.
Application automatique : à chaque session, l'app découpe les heures selon les règles (dimanche, férié, soir/nuit, heures complémentaires) et affiche le détail. Alertes avec la source de la règle ("tu approches du plafond", "moins de 11 h de repos entre ces deux journées").

## 23. CONGÉS PAYÉS (module leave, exige employment)

Un compteur de congés par employeur.
Règles : période de référence (défaut proposé après vérification des sources officielles, modifiable car la convention ou l'entreprise peut la fixer autrement), nombre de jours acquis par mois de travail effectif, unité (jours ouvrables ou ouvrés), périodes assimilées à du travail effectif (à renseigner), mode de calcul de l'indemnité (dixième ou maintien du salaire, le plus favorable, indicatif), indemnité compensatrice pour un CDD ou à la sortie. Toutes ces règles viennent de Resources/reference/leave.json avec sources et dates de vérification, rien en dur dans le Swift. L'agent les recherche sur service-public.fr et Légifrance, et marque "à vérifier" ce qui est incertain.
Fonctionnement :
- Solde de départ saisi ou lu sur la fiche de paie (acquis, pris, restant) avec la date du relevé. L'app calcule ensuite l'évolution à partir des mois travaillés.
- Calendrier des congés : poser des jours (pris ou prévus), par jour ou par plage, avec un statut (demandé, accepté, pris). Les jours de congé ne créent aucune fausse anomalie d'absence et sont exclus des attentes de session.
- Affichage : "Il te reste 12,5 jours", acquis, pris, prévus, date d'expiration de la période, projection ("à ce rythme, tu en auras 8 de plus").
- Alertes configurables : "Tes congés expirent le 31 mai, t'en as encore 6".
- Estimation de l'indemnité en euros, indicative, masquable en mode discret. Mode comparaison avec la fiche de paie. Pour un contrat court, indemnité compensatrice estimée à la fin.

## 24. SIMULATEUR "ET SI ?" (module simulator, exige pay)

Travaille sur une copie des données et ne modifie JAMAIS les vraies sessions ni le planning.
Entrées : heures en plus ou en moins (semaine ou mois), travailler un dimanche, un soir, un jour férié, changer le taux horaire, changer de convention, prendre X jours de congés, ajouter un employeur ou un contrat, changer de type de contrat, atteindre un objectif d'épargne à une date précise.
Sorties : brut et net estimés, écart avec la situation actuelle, heures par semaine résultantes, majorations appliquées avec leur source, alertes (plafond d'heures, repos minimal, durée maximale), solde de congés, date d'atteinte d'un objectif, et pour une date cible le nombre d'heures par semaine nécessaire.
Comparaison A contre B côte à côte. Scénarios nommés, enregistrables, supprimables. Même moteur de règles que la paie réelle, mêmes avertissements ("estimation indicative"). Option "Appliquer au planning prévu" qui crée des créneaux prévus modifiables, après confirmation, jamais des sessions réelles.
Phrases du ton de l'app ("Si tu fais 6 h de plus ce mois, ça te fait environ 58 € de plus, tu atteins ton objectif 9 jours plus tôt").
Mode semaine en direct : voir section 111.

## 25. PRÉVU CONTRE RÉEL (module pay)

Compare, par semaine et par mois, le planning prévu et le réel jour par jour : écarts d'horaires, créneaux plus courts ou plus longs. Le suivi du quota du contrat, la projection, le classement en heures complémentaires ou supplémentaires et le rééquilibrage sont décrits en section 106. Bouton "Préparer un relevé pour mon employeur" (PDF ou CSV). Sessions incertaines ou reconstituées signalées.

## 26. PRIMES ET INDEMNITÉS (module pay)

Saisie de primes par employeur : type (panier, transport, 13e mois, objectifs, repas, autre), montant fixe ou pourcentage, fréquence (par session, par jour, mensuelle, annuelle, ponctuelle), brut ou net, soumise ou non à cotisations (case indicative), conditions éventuelles (dimanche, soirée). Option remboursement transport par l'employeur (saisie). Intégrées à l'estimation avec détail ligne par ligne et marquées "saisie par toi". Le pack de convention peut suggérer des primes usuelles "à renseigner", jamais appliquées sans confirmation.

## 27. DATE DE PAIE ATTENDUE (module pay_date, exige pay)

Par employeur : jour de paie habituel (saisi ou lu sur la fiche), estimation de la date du virement avec décalage les week-ends et jours fériés selon réglage (jour ouvré précédent ou suivant). Rappel facultatif "Vérifie ton virement" avec montant estimé masquable. Saisie du montant reçu pour comparer à l'estimation. Aucune connexion bancaire.

## 28. BANQUE D'HEURES (fusionnée dans la section 106.4)

Les heures à récupérer, les heures d'avance et le repos compensateur sont des types de compteur du module contract_hours (section 106.4). Il n'existe plus de module hour_bank séparé.

## 29. SEUIL FISCAL (module tax_threshold, exige pay)

Suit le cumul annuel de revenus estimés et le compare à des seuils saisis ou lus dans Resources/reference/tax.json (plafonds liés à l'exonération et au rattachement fiscal d'un étudiant). L'agent recherche et source ces valeurs (service-public.fr, impots.gouv.fr), marque "à vérifier" ce qui est incertain, et indique la date d'effet. Alertes douces à 80 % et 95 % du seuil. Avertissement visible : information indicative, très dépendante de la situation personnelle, pas un conseil fiscal, renvoi vers impots.gouv.fr. L'app ne fait jamais de déclaration. Désactivé par défaut.

## 30. CALENDRIER SCOLAIRE, VACANCES ET JOURS FÉRIÉS (module school_calendar)

Jours fériés français intégrés (calculés, pas codés en dur par année). Vacances scolaires configurables (plages saisies, import ICS ou lecture du calendrier iOS via EventKit si autorisé). Pendant les vacances, attentes de cours désactivées, logique de créneaux de travail adaptée. Les majorations utilisent les jours fériés. Aucun export vers le calendrier Apple n'est prévu.

## 31. MODE EXAMENS (module exam_mode)

Période définie par l'utilisateur (révisions, bac blanc, bac). Pendant cette période : rappels et notifications réduits au minimum, bouton "Pas aujourd'hui" proéminent, objectifs d'heures de travail suspendus, compte à rebours facultatif jusqu'aux épreuves, période annotée dans les statistiques pour expliquer une baisse d'heures. Suggestion automatique si des épreuves sont détectées dans le calendrier (si autorisé). Aucun message culpabilisant.

## 32. PAUSES (module breaks)

Les pauses ne sont jamais imposées. Réglage : aucune, info seulement, rappel.
- Aucune : l'app ne dit rien.
- Info seulement : les règles de pause du pack sont consultables dans la fiche de la convention, rien n'est envoyé.
- Rappel : notification douce après X heures sans coupure détectée, désactivable, une seule par session, ton non culpabilisant ("Ça fait 6 h que t'enchaînes, une pause si t'as le droit ?").
Pause détectée (sortie temporaire) ou saisie à la main, avec réglage "pause payée ou non" qui détermine si elle est déduite du temps de travail. Le seuil de pause qui coupe une session (défaut 45 minutes) reste configurable dans le noyau. Aucune alerte de non-respect d'une pause si l'utilisateur a choisi "Aucune".

## 33. ALERTE NUIT COURTE (module short_night)

Calcule le repos entre la fin de la dernière session (réelle ou prévue) et le prochain début de cours ou de travail connu : "Tu finis à 23 h, cours à 8 h, ça te fait 7 h 30 max pour dormir." Seuil configurable (défaut proposé 8 h), distinct du repos minimal légal du pack. Notification la veille à un moment utile, désactivable, sans conseil médical, ton cool.

## 34. CRÉNEAUX LIBRES DE RÉVISION (module study_slots)

Repère les trous entre cours, travail, trajets et pauses, avec une durée minimale configurable (défaut 45 minutes), et propose "T'as un créneau d'1 h 30 demain à 17 h". Suivi facultatif des heures de révision (activité personnelle étiquetée "révision", démarrage manuel, jamais de détection du contenu). Objectifs d'heures de révision modifiables, liés au mode examens s'il est actif. Aucune culpabilisation.

## 35. TRAJET ET "PARS MAINTENANT" (module travel_departure)

Pour chaque prise de poste ou de cours connue (planning, contrat, habitudes), l'app calcule le temps de trajet depuis la position probable de départ (position actuelle ou domicile) avec MKDirections (voiture, marche, vélo, transport), en tenant compte du trafic quand l'API le permet.
Réglages : marge de sécurité (défaut 10 minutes), mode de transport par lieu, notification activable par lieu.
Fonctionnement : planifier à l'avance une notification locale basée sur l'estimation, puis la recalculer à l'approche (BackgroundTasks et déclencheurs opportunistes, jamais de polling permanent, requêtes MKDirections limitées et mises en cache). Exemple : "Faut y aller, il est 17:28. T'as 22 min de route et tu prends ton poste à 18:00."
Si le retard est probable, le dire ("Tu vas arriver vers 18:06, prévient ton chef ?"), sans promettre une précision que l'API ne garantit pas. Respecte les heures silencieuses et le mode examens. Rien n'est envoyé si l'utilisateur est déjà sur place.

## 36. COÛT DU TRAJET (module travel_cost, optionnel, désactivé par défaut)

Distance via MapKit, estimation du coût par trajet et par mois selon le mode : voiture (coût au km saisi par l'utilisateur, aucune valeur imposée), transport en commun (prix d'abonnement saisi), vélo et marche (zéro). Affiche le coût mensuel, "net après trajet" et la part du trajet dans le net estimé. Remboursement par l'employeur déductible si saisi. Aucun barème en dur dans le Swift : un éventuel barème indicatif vit dans reference/ avec source et date. Rien n'apparaît tant que le module est désactivé, et le module ne demande aucune donnée en plus de ses propres saisies.

## 37. "JE RENTRE" (module going_home, optionnel, désactivé par défaut)

Bouton, widget ou action Raccourcis qui prépare un message prérempli pour un contact favori choisi par l'utilisateur ("J'ai fini, j'arrive dans 15 min"), l'heure estimée venant du calcul de trajet quand il est actif. Le message est modifiable et n'est JAMAIS envoyé sans action de l'utilisateur (feuille de partage ou composeur de message natif). L'app ne partage jamais la position elle-même en continu : si l'utilisateur veut partager sa position, il passe par les fonctions natives d'iOS, à la main.

## 38. OBJECTIFS D'ÉPARGNE (module savings, exige pay)

Plusieurs objectifs : nom, montant visé, montant déjà mis de côté, date cible facultative, icône. L'app convertit le reste à gagner en heures de travail avec le net estimé ("encore 38 h de taf pour ta console"), affiche la progression, estime la date d'atteinte au rythme actuel ("à ce rythme, c'est bon le 12 mars") et, avec une date cible, le nombre d'heures par semaine nécessaire. Félicitation à l'objectif atteint. Aucune connexion bancaire, tout est saisi à la main. Montants masquables par le mode discret. Estimations indicatives.

## 39. NOTES DE JOURNÉE (module notes)

Une phrase libre par jour, une humeur (emoji), des tags facultatifs ("rush", "client relou", "formation"), modifiables à tout moment, incluses dans l'export, retrouvables par la recherche, visibles dans la chronologie et les bilans.

## 40. BILANS MENSUELS ET ANNUELS, FAÇON WRAPPED (module recaps)

Bilans de fin de mois et de fin d'année, générés localement, présentés en stories plein écran swipeables, animées avec sobriété, style visuel soigné.
Contenu possible : heures de travail et de cours, évolution contre la période précédente, jour le plus long, arrivée la plus tôt, lieu où il passe le plus de temps, série de jours travaillés, meilleur mois, heures de pause, trajets cumulés, objectifs d'épargne avancés, total gagné estimé (si le module paie est actif, masqué en mode discret), moments forts tirés des notes de journée, phrase de conclusion dans le ton de l'app. Seules les cartes dont le module source est actif apparaissent.
Notification à la fin du mois et en décembre, bilan consultable à tout moment pour n'importe quelle période. Chaque carte est exportable en image (ImageRenderer) avec option de masquer montants et lieux précis. Si les données sont insuffisantes ou incertaines, ne pas afficher de statistiques trompeuses.
Bilan hebdomadaire : chaque semaine (dimanche soir par défaut, jour et heure réglables), un résumé court de la semaine écoulée : heures de travail, de cours et de trajets, temps libre si le module weekly_balance est actif, quota du contrat atteint ou non (section 106), jours et lieux marquants, écarts avec le prévu, points à confirmer. Il partage un écran unique "Ta semaine" avec la revue de la semaine (section 46), pour une seule notification au lieu de deux (les éléments à confirmer d'abord, le bilan ensuite). Sans activité suffisante, aucun bilan n'est produit. Mêmes règles que les bilans mensuels : statistiques non trompeuses, sessions incertaines signalées, montants masquables, export en image via le résumé partageable.

## 41. RECHERCHE GLOBALE (module search)

Barre de recherche accessible depuis chaque onglet : sessions, lieux, notes de journée, plannings, objectifs, réglages. Filtres par type d'activité, période, lieu, employeur, statut (incertain, corrigé, reconstitué). Résultats instantanés, indexation locale performante, tolérance aux accents et aux fautes légères. Recherches récentes effaçables. Une requête comme "samedi courses" ou "note rush" doit marcher.
41.1 Questions en langage naturel sans modèle : les questions fréquentes fonctionnent sur tous les appareils, sans modèle de langage, grâce à un analyseur à règles (outils d'analyse de texte de l'appareil) qui reconnaît des formes : "combien de [samedis, dimanches, soirées, jours fériés] ai-je travaillé depuis [date]", "quand suis-je allé pour la dernière fois à [lieu]", "combien de fois à [lieu] en [mois]", "total d'heures [période] [employeur]", "ma plus longue journée". Les réponses viennent de requêtes déterministes sur les données (les mêmes fonctions que les outils de la section 137), avec la base de calcul affichée (section 13.1) et un lien vers les sessions. Question non comprise : suggestions de reformulation puis recherche classique.

## 42. RAPPEL D'ENVOI DES HEURES (module send_hours_reminder, exige employment)

Par employeur, rappel mensuel : jour du mois ou "dernier jour travaillé", heure, canal habituel d'envoi (mail, message, autre).
La notification arrive avec le relevé du mois déjà généré (PDF ou CSV) et les actions : "Ouvrir", "Envoyer" (feuille de partage ou mail prérempli, jamais envoyé automatiquement), "Plus tard" (reporte à demain), "C'est fait" (arrête le rappel du mois).
Avant l'envoi, contrôle rapide : sessions incertaines ou reconstituées à confirmer, jours à compléter. S'il y en a, le rappel le dit et ouvre la revue. L'app garde la date d'envoi dans un historique des relevés. Ton non culpabilisant ("C'est la fin du mois, ton relevé est prêt, t'as juste à l'envoyer").

## 43. CONCENTRATION (module focus)

Contrainte iOS : une app ne peut pas activer un mode Concentration elle-même. Ne jamais prétendre le faire. Ce qui est possible :
1. Action Raccourcis : exposer via App Intents une action "Je suis au travail" (démarre la session, lance la Live Activity). L'app guide pas à pas (captures ou schéma animé) pour créer dans Raccourcis une automatisation "Quand j'arrive à [lieu]" qui active le mode Concentration "Travail" ou "Cours" puis appelle l'action, et l'inverse au départ. Bouton qui ouvre directement Raccourcis.
2. Filtre de Concentration (SetFocusFilterIntent) : quand le mode associé est actif, l'app adapte son comportement (notifications non critiques réduites, bandeau paie masqué, employeur actif affiché).
3. Lecture de l'état (INFocusStatusCenter) uniquement si l'utilisateur l'autorise, pour adapter les notifications, jamais pour deviner où il est.
Une ligne "Concentration" dans "État de l'app" indique ce qui est configuré et ce qui manque, avec un bouton d'aide. Les notifications importantes (confirmation d'arrivée, "Pars maintenant") peuvent être "sensibles au temps" si l'utilisateur le choisit, jamais critiques.

## 44. LIVE ACTIVITY, WIDGETS ET APP INTENTS (module live_activity_widgets)

44.1 Live Activity de travail ou de cours.
Contraintes iOS à respecter (l'agent les vérifie dans la documentation ActivityKit du SDK utilisé) : une Live Activity se démarre quand l'app est au premier plan (ou par notification push distante, que l'app n'utilise pas). Elle peut en revanche être mise à jour et terminée quand l'app est réveillée en arrière-plan (événement de région, par exemple). Sa durée d'activité est limitée à 8 heures, après quoi le système la termine, avec un affichage résiduel limité sur l'écran verrouillé.
Démarrage 100 % local : à l'arrivée détectée ou probable, l'app envoie une notification locale ("T'es arrivé au taf ? Touche pour lancer le suivi"). Le tap ouvre l'app, qui démarre la Live Activity. Autres déclencheurs : Bouton Action ou contrôle (section 125), automatisation Raccourcis qui ouvre l'app, ouverture manuelle de l'app. Ne jamais promettre un démarrage automatique en arrière-plan.
Limite de 8 heures : pour une session plus longue, l'app prévoit une notification locale "Relancer l'affichage ?" juste avant la fin des 8 heures (ou dès que le système termine l'activité). Un tap relance une nouvelle Live Activity avec le même chronomètre de session. Sans tap, le widget "encore X h" (section 44.3) prend le relais, et la reprise se fait aussi à l'ouverture de l'app.
Contenu :
- Écran verrouillé : activité, lieu, heure d'arrivée, chronomètre natif (Text avec timerInterval), heure de fin prévue si connue, ou décompte "encore X h" quand la fin est connue.
- Dynamic Island compacte : icône et durée. Étendue : lieu, début, fin prévue, bouton "Terminer".
- Fin : terminée automatiquement au départ détecté quand l'app est réveillée. Si le départ est incertain, état "À confirmer" au lieu de disparaître.
La Live Activity n'est jamais la source de vérité d'une session : le suivi, les sessions et les statistiques fonctionnent à l'identique sans elle. Pas de timers permanents. Gérer début, mise à jour, fin, interruption, restauration, et respecter les limites d'iOS.
44.2 Widgets : galerie complète, familles, personnalisation et styles décrits en section 133. Bases : petit (activité en cours ou prochaine), moyen (planning du jour avec heures), écran verrouillé (heures travaillées de la semaine), widget interactif (démarrer ou arrêter).
44.3 Widget "encore X h" : pendant une session de travail ou de cours, affiche le temps restant avant la fin de service ("encore 2 h 12") avec un décompte natif (Text(timerInterval:)) pour rester juste sans rafraîchissements permanents. La fin vient, dans l'ordre : du planning importé, de l'horaire du contrat ou de l'habitude du créneau, d'une saisie manuelle. Si aucune n'est connue, il affiche le temps écoulé et ne prétend jamais connaître la fin. Option d'affichage : temps restant, heure de fin, ou les deux. Hors session : prochaine prise de poste ("Prochain taf dans 3 h 40") et, si le module est actif, "Pars maintenant". Plusieurs employeurs : nom et couleur de l'employeur de la session. Boutons App Intents "Terminer" ou "Pause" selon réglages.
44.4 App Intents : démarrer, arrêter, "combien d'heures cette semaine ?", et si les modules sont actifs "combien je vais toucher ce mois ?", "à quelle heure je dois partir ?".
Les widgets et la Live Activity lisent les données via l'App Group, avec le fallback prévu quand il est indisponible.

## 45. NOTIFICATIONS LOCALES

UNUserNotificationCenter, sans serveur ni push distant. Cas du noyau : arrivée ou départ incertain, confirmation d'horaire, "Cette visite correspond-elle à des courses ?", anomalie de suivi. Cas des modules (envoyés seulement si le module est actif) : liste dans MODULES.md (annexe B).
Exemples : "Ton arrivée au travail semble être vers 06:00. Tu confirmes ?" ; "Ton départ du lycée est estimé entre 16:40 et 17:00. Quelle heure retenir ?"
Actions : confirmer, choisir une autre heure, signaler une erreur, ouvrir l'activité. Prévention des doublons, gestion des permissions, préférences par catégorie, heures silencieuses, fréquence maximale par jour. Quand le module smart_notifications est actif, un coordinateur central applique priorités, budget quotidien, regroupement et apprentissage (section 123). Sans réponse, conserver une estimation marquée incertaine. Ne jamais bloquer l'app dans l'attente d'une réponse.

## 46. REVUE DE LA SEMAINE (module weekly_review)

Chaque dimanche (notification), un écran regroupe tous les éléments à confirmer de la semaine (sessions incertaines, classifications provisoires, horaires à valider) pour les valider d'un coup, au lieu de multiplier les notifications. Elle partage son écran avec le bilan hebdomadaire de la section 40 ("Ta semaine").

---

# C BIS. MODULES COMPLÉMENTAIRES

Tous optionnels (section 3), numérotés à la suite pour garder la numérotation stable.

## 67. SUIVI DES FRAIS (module expenses, désactivé par défaut)

Saisie rapide (2 taps) des dépenses liées au travail ou aux études : tenue, chaussures de sécurité, matériel, repas pris sur place, transport, parking, fournitures. Catégories modifiables, montant, date, employeur (si le module Emploi est actif), photo du ticket facultative stockée localement, avec lecture locale du montant et de la date par Vision à confirmer, jamais en silence.
Intérêt : voir ce que le job coûte vraiment. Total par mois et par catégorie, "net moins frais", part des frais dans le net estimé (si le module pay est actif). Marquage "remboursable" et "remboursé par l'employeur" avec le montant remboursé. Relevé de frais exportable en PDF ou CSV pour demander un remboursement. Le coût du trajet (section 36) peut alimenter les frais sur demande, jamais en doublon automatique. Montants masquables par le mode discret. Aucune règle fiscale codée (pas de calcul de déduction), pas de conseil fiscal.

## 68. MODE REMPLACEMENT (module replacements, désactivé par défaut)

Quand l'utilisateur prend le créneau de quelqu'un d'autre ou fait des heures en plus à la demande, il peut marquer une session ou un créneau comme "remplacement" (bouton sur la session, ou à la confirmation d'une arrivée hors planning : "Tu remplaces quelqu'un ?"). Champs facultatifs : pour qui (nom libre), demandé par, motif.
Les remplacements sont comptés à part dans les statistiques (heures de remplacement par mois et cumul), n'écrasent jamais le planning prévu, et sont comparés au contrat comme des heures en plus (complémentaires ou supplémentaires selon le pack, si le module pay est actif). Un écart hors planning marqué remplacement n'est pas signalé comme une anomalie. Option : proposer automatiquement "remplacement ?" lors d'une arrivée hors créneau sur un lieu de travail, une seule fois par contexte, avec apprentissage comme en section 11.

## 69. HISTORIQUE DES TAUX HORAIRES (partie du module pay)

Chaque changement de taux (augmentation, nouveau contrat, revalorisation du SMIC) est enregistré avec sa date d'effet. Le calcul de chaque session utilise le taux en vigueur à sa date : les mois passés ne changent jamais rétroactivement. Une correction d'erreur reste possible avec trace dans le journal des modifications (AuditEntry).
Vue "Mon salaire dans le temps" (Swift Charts) : courbe du taux brut, évolution en pourcentage, comparaison avec le SMIC historique lu dans legal.json (qui contient l'historique des valeurs avec dates d'effet). Quand le SMIC est revalorisé et que l'utilisateur est "au SMIC", l'app propose de mettre à jour son taux à la date d'effet, avec confirmation, jamais en silence. Même logique de versions datées pour les packs de convention et les primes.

## 70. ALERTE PLANNING TARDIF (réglage du module planning_ocr, désactivé par défaut)

L'utilisateur indique quand son planning est habituellement publié pour la semaine suivante (jour et heure), ou l'app l'apprend après 3 semaines et le propose. Si à cette échéance aucun planning n'est importé pour la semaine suivante, notification douce : "Le planning de la semaine prochaine est pas encore là, tu l'as reçu ?" Actions : importer une photo, "Pas encore reçu", "Pas cette semaine" (vacances ou pas de travail), "Ne plus me le rappeler".
Une relance maximum par semaine. Aucune relance pendant les congés, le mode vacances ou le mode examens, ni pendant les heures silencieuses. Jamais culpabilisant. Elle ne suppose aucune régularité des horaires, seulement un rythme de publication du planning.

## 71. STATISTIQUES DE RÉGULARITÉ (module regularity, désactivé par défaut)

Mesures factuelles, sans jugement : écart entre heure prévue et heure réelle d'arrivée (médiane et distribution), heure moyenne d'arrivée et de départ par jour de semaine, régularité des horaires, durée moyenne de session, jours de présence par semaine. Tendances sur 4 et 12 semaines, par lieu et par employeur, avec Swift Charts.
Calcul uniquement sur les sessions confirmées ou non incertaines, avec la taille de l'échantillon affichée et "pas assez de données" sous un seuil (par exemple moins de 5 sessions). Formulations neutres ("tu arrives en moyenne 3 min avant ton créneau"), jamais de mot culpabilisant comme "retard chronique". Pas de score global noté, pas de comparaison avec d'autres personnes. Intégrable aux bilans (section 40) si les deux modules sont actifs.

## 72. JOURNAL DE CONTRAT (module contract_journal, exige employment, désactivé par défaut)

Espace par employeur pour ranger les dates clés et les documents : entretien, signature, début, fin de période d'essai, avenants, changements de taux ou d'horaires, échanges importants avec le responsable, formations, incidents (texte libre), fin de contrat. Chaque entrée : date, type, titre, note, pièces jointes (photos ou PDF du contrat, des avenants, des fiches de paie, scannés avec la caméra ou importés).
Stockage 100 % local, dans le conteneur de l'app avec les protections de données d'iOS, et verrouillage Face ID de l'app si activé. Les pièces jointes ne sont incluses dans la sauvegarde ou iCloud que si l'utilisateur le choisit explicitement. Chronologie par employeur, retrouvable par la recherche (section 41). Les dates clés alimentent les alertes du cycle de vie du contrat (section 19). Lecture locale par Vision d'un document pour préremplir dates et taux, à confirmer. Export PDF du journal sur demande (litige, rendez-vous). Aucune transmission, aucun conseil juridique.

## 73. MODE VACANCES DE L'APP (module vacation_mode, désactivé par défaut)

Différent de "Pas aujourd'hui" (une journée), du calendrier scolaire (section 30) et des périodes bloquées (section 114, qui servent à planifier et à prévenir sans suspendre le suivi). L'utilisateur définit une période (voyage, déplacement, pause), avec dates de début et de fin ou "jusqu'à nouvel ordre".
Pendant la période : suivi automatique suspendu (surveillance de régions et changements significatifs arrêtés pour économiser la batterie), aucune notification d'arrivée ou de départ, aucune alerte d'absence, d'anomalie, de planning tardif ou de pause, attentes de cours et de travail neutralisées, pas de Live Activity. Les statistiques affichent la période comme "vacances de l'app" au lieu d'un trou, et les moyennes et séries ne la comptent pas comme manquante. La saisie manuelle reste possible. Option : poser des congés payés sur la même période en un tap (si le module leave est actif).
Reprise automatique à la date de fin avec une notification ("Re-bienvenue, je relance le suivi"), reprise anticipée en un tap, et vérification de l'état de l'app à la reprise (permissions, précision, suivi).

## 74. CONTACTS DU TAF (module work_contacts, désactivé par défaut)

Contacts par employeur : nom, rôle (responsable, collègue, RH, autre), téléphone, note. Ajout à la main ou avec le sélecteur de contacts natif d'iOS, qui ne copie que le contact choisi et n'exige pas l'accès à tout le carnet d'adresses. Actions rapides : appeler, envoyer un message (composeur natif).
Bouton "Je suis en retard" : proposé sur la carte d'accueil et dans la notification quand le calcul de trajet (section 35) prévoit une arrivée tardive, et disponible en App Intent. Il prépare un message prérempli avec l'heure d'arrivée estimée ("Je vais arriver vers 18:06, désolé"), modifiable, JAMAIS envoyé sans action de l'utilisateur. Action "Appeler mon responsable" disponible dans un widget et par Siri. Contacts stockés localement, exclus d'iCloud sauf choix explicite.

## 75. RAPPEL DE BADGEUSE ET COMPARAISON (module badge_reminder, exige employment, désactivé par défaut)

Par employeur, option "Mon employeur utilise un pointage (badgeuse, appli, feuille)". À l'arrivée détectée ou probable, notification "Pense à badger" (une seule par session, délai configurable, désactivable) et à la fin de session "Pense à badger en partant".
Comparaison : l'utilisateur peut saisir, quand il le souhaite, l'heure de pointage ou le total d'heures de son employeur pour une journée ou une période (ou les lire sur le planning ou la fiche de paie). L'app compare : "selon l'app 6 h 30, selon ton employeur 6 h 15, écart 15 min". Un écart récurrent est signalé doucement et peut figurer dans le relevé d'heures (section 20.2). L'app ne se connecte à aucun système de pointage et ne remplace pas le pointage officiel. Aucune notification pendant le mode vacances ou examens.

## 76. CHECK AVANT DE PARTIR (module departure_checklist, désactivé par défaut)

Listes personnalisables (clés, badge, tenue, sac, carte, chargeur...) par type d'activité (travail, cours) ou par lieu, vides au départ avec des exemples à ajouter. Déclenchement au choix : au départ détecté du domicile, X minutes avant le moment de "Pars maintenant" si ce module est actif, X minutes avant une prise de poste ou de cours connue, ou par bouton. Présentation : notification avec actions puis écran rapide à cases à cocher, "Tout est bon" en un tap.
Contrainte à respecter : la détection du départ du domicile peut arriver avec un léger délai (géorepérage), donc ne jamais promettre un déclenchement instantané, et préférer l'heure de prise de poste comme déclencheur fiable. Un seul rappel par sortie, aucun rappel pendant le mode vacances ou examens, jamais culpabilisant ("Check rapide avant de partir ?").

## 77. CORRECTIONS À LA VOIX (module voice_corrections, désactivé par défaut)

Corriger ou compléter par la voix via Siri (App Intents et App Shortcuts) ou par dictée dans l'app : "J'ai fini à 22h30", "J'ai commencé à 18h", "C'était des courses", "Supprime la pause", "Ajoute une note : rush".
Traitement local : analyseur d'énoncés à règles (avec les outils d'analyse de texte de l'appareil), sans IA distante. Reconnaissance vocale sur l'appareil quand elle est disponible en français (Speech avec reconnaissance locale) ; si elle ne l'est pas, le dire et se rabattre sur la dictée du clavier, sans envoyer l'audio ailleurs sans que l'utilisateur le sache. Permissions micro et reconnaissance vocale demandées seulement à l'activation du module.
Sécurité : toujours une confirmation avant d'appliquer ("Je mets ta fin de journée à 22:30, c'est bon ?"), sauf réglage explicite "appliquer sans demander", désactivé par défaut. L'heure d'origine est conservée dans le journal des modifications. En cas d'ambiguïté (quelle session, 6 h ou 18 h), poser une question courte plutôt que deviner. Respecter les limites de Siri (phrases enregistrées et formulations proches).

## 78. ÉQUILIBRE DE LA SEMAINE (module weekly_balance, désactivé par défaut)

Graphique de la semaine (Swift Charts) répartissant les heures éveillées entre cours, travail, trajets et temps libre. Le temps libre est une ESTIMATION : heures non occupées par une activité détectée, en excluant une plage de sommeil configurable (défaut 23 h à 7 h, modifiable). L'app ne suit pas le sommeil et ne traite aucune donnée de santé, et le dit. Objectifs facultatifs (maximum d'heures de travail par semaine, minimum de temps libre). Comparaison avec la semaine précédente, widget possible. Formulations neutres ("cette semaine 14 h de temps libre, 3 h de moins que la précédente"). Sessions incertaines signalées, vacances et congés pris en compte.

## 79. RÉSUMÉ PARTAGEABLE (module share_summary, désactivé par défaut)

Génère une image (ImageRenderer) ou un PDF simple de la semaine ou du mois : heures de cours, heures de travail, jours travaillés, planning à venir (facultatif), par exemple pour les parents. Avant de générer, l'utilisateur coche le contenu : montants (masqués par défaut), lieux précis (masqués par défaut, affichage "le taf", "le lycée"), notes (exclues par défaut), employeur. Aperçu avant partage, feuille de partage native, jamais d'envoi automatique, ni lien, ni serveur. Réutilise la mise en page des bilans (section 40).

## 80. DOSSIER JUSTIFICATIF (module proof_pack, désactivé par défaut)

Assemble en un seul PDF, pour une période choisie (mois, année civile, année scolaire), les pièces utiles à un dossier de bourse, une demande de location ou de garant, une déclaration d'impôts ou un litige : relevés d'heures, fiches de paie importées (module pay), contrat et avenants (journal de contrat, s'il est actif), notes choisies.
L'utilisateur coche les pièces, l'app génère un sommaire. Les montants lus sur les fiches de paie (source primaire) sont clairement distingués des estimations de l'app, étiquetées "estimation". Outil de caviardage simple (rectangle noir sur une zone d'une pièce) avant export, mot de passe PDF facultatif, aperçu, feuille de partage native, jamais d'envoi automatique. L'app ne remplit pas de formulaires officiels et ne donne aucun conseil juridique, fiscal ou administratif. Aucune dépendance externe pour générer le PDF.

## 81. CARNET D'ÉCHANGES DE CRÉNEAUX (module shift_swaps, désactivé par défaut)

Suivi des échanges de créneaux avec les collègues et de qui doit quoi à qui. Entrée : date du créneau, avec qui (nom libre, ou contact du module work_contacts s'il est actif), sens (j'ai pris son créneau, il a pris le mien, échange croisé), statut (prévu, fait, à rendre, rendu, annulé), échéance de "à rendre", note.
Compteur simple : ce que l'utilisateur doit et ce qu'on lui doit, en créneaux ou en heures. Un remplacement (section 68) peut créer une entrée du carnet en un tap. Quand un échange est confirmé, l'app propose de modifier le planning prévu (copie prévue modifiable, après confirmation, jamais les sessions réelles). Rappel doux avant une échéance "à rendre", désactivable. Le carnet n'a aucune valeur contractuelle ou juridique, n'envoie aucun message et ne parle à personne : c'est un aide-mémoire personnel.

## 82. COMPTE À REBOURS DE FIN DE JOURNÉE (module end_of_day_countdown, désactivé par défaut)

Complète le widget "encore X h" (section 44.3) par des notifications locales douces pendant une session en cours : "Plus qu'une heure", puis 30 minutes, puis 15 minutes avant la fin prévue, seuils configurables, chacun désactivable. Uniquement si la fin est connue (planning, contrat ou habitude du créneau), jamais si elle est inconnue.
Les notifications sont programmées au début de la session, reprogrammées si la fin prévue change (retard, prolongation) et annulées au départ réel. Une notification par seuil, heures silencieuses respectées, réduites pendant le mode examens, aucune pendant le mode vacances. Ton léger ("Plus qu'une heure, tu tiens le bon bout").

## 83. MODE "JOURNÉE DIFFICILE" (module rough_day, désactivé par défaut)

Un tap (carte de session, widget, App Intent) marque la journée comme difficile, avec une humeur et des tags prédéfinis facultatifs (rush, clients, fatigue, stress, conflit) et une note facultative (module notes si actif, sinon une note locale simple). L'app répond par un mot court et chaleureux sans analyse ("Ça arrive. C'est fini pour aujourd'hui, repose-toi.").
L'app ne fait aucun diagnostic, aucune interprétation psychologique du texte de l'utilisateur, aucun calcul de santé. Ce soir-là, les messages de félicitation sont remplacés par un ton plus calme. Compteur facultatif de journées difficiles par mois, désactivé par défaut, jamais inclus dans les bilans ni dans le résumé partageable sans choix explicite.

## 84. PRÉVISION DES PRIMES DE DIMANCHE ET DE FÉRIÉ (module premium_planner, exige pay, désactivé par défaut)

Tableau "Les primes à venir" pour le mois suivant ou une période choisie : liste des dimanches et jours fériés (calculés, section 30) et, pour chacun, le gain supplémentaire estimé si l'utilisateur travaille un créneau type (durée choisie), selon le pack de convention et ses surcharges, avec la majoration appliquée et sa source. L'utilisateur coche les jours où il envisage de travailler et voit le supplément total estimé.
Utilise le même moteur que le simulateur (section 24), avec la même option "Appliquer au planning prévu" (copie prévue, après confirmation). Signale les conditions ou plafonds du pack ("à vérifier") et les alertes de repos ou de durée maximale. Neutre : l'app ne pousse pas à travailler plus. Estimation indicative, la fiche de paie fait foi, certaines entreprises ont des accords différents. Rien codé en dur, montants masquables.

## 85. PRÉVISION DU SOLDE DE FIN DE MOIS (module month_forecast, exige pay, désactivé par défaut)

Jauge simple "Reste estimé en fin de mois" : net estimé du mois (sessions réalisées, planning prévu restant, primes) moins frais saisis (module expenses si actif) moins mises de côté pour les objectifs d'épargne (module savings si actif), avec dépenses prévues ponctuelles facultatives saisies à la main.
Fourchette (basse, probable, haute) qui tient compte de l'incertitude : sessions incertaines, planning non importé (dans ce cas, hypothèse déclarée et modifiable de la section 91, avec une fourchette plus large). Hypothèses visibles et modifiables, détail de chaque composante au tap, comparaison avec le mois précédent. Distinction importante quand le module pay_date est actif : "ce que tu gagnes ce mois" (net du mois travaillé) contre "ce que tu touches ce mois" (net reçu, à cause du décalage de paie). Widget possible. Estimation indicative, masquable en mode discret, aucune connexion bancaire, aucun conseil financier.

## 86. DÉTECTION D'HEURES MANQUANTES (module missing_hours, proposé et coché par défaut)

Repère les journées où un créneau prévu (planning importé en priorité ; horaires du contrat ou habitude confirmée seulement si l'utilisateur déclare des horaires réguliers, section 91) n'a aucune session correspondante, où une session est beaucoup plus courte que prévu, ou où une fin existe sans début. Le lendemain matin (heure réglable) ou dans la revue de la semaine (section 46), une seule question groupée : "Tu devais bosser hier de 18 h à 22 h, je n'ai rien noté. T'as bossé ?"
Actions : "Oui, ajouter" (crée la session avec les horaires prévus, marquée source "planning" et à confirmer ou à corriger), "Non" (avec raison : congé, malade, pas de taf, planning annulé, remplacement ou échange), "Ignorer". Jamais d'ajout silencieux, aucune accusation, pas de relance au-delà de quelques jours.
Éviter les faux positifs : tenir compte des congés posés, du calendrier scolaire, des jours fériés, du mode vacances, des plannings non confirmés. Quand les horaires varient d'une semaine à l'autre et qu'aucun planning n'est importé pour la semaine, ne rien déduire des habitudes. Apprentissage : si l'utilisateur répond souvent "pas de taf" pour un créneau d'habitude, la confiance de cette habitude baisse. Aucune question pendant les vacances ou les congés.

## 87. BRIEF DU MATIN (module morning_brief, désactivé par défaut)

Notification locale et widget qui résument la journée : "Aujourd'hui : cours 8 h à 17 h, taf 18 h à 22 h. Départ conseillé à 17 h 28." Heure réglable, ou automatique : X minutes avant le premier événement du jour, jamais avant une heure minimale réglable.
Contenu modulaire, cases à cocher dans les réglages : activités du jour avec leurs heures, heure de départ conseillée (si travel_departure est actif), éléments à confirmer de la veille, congés ou fin de contrat proche, check avant de partir, total d'heures prévues de la semaine. Seuls les modules actifs fournissent du contenu. S'il n'y a rien, une courte phrase suffit. Version réduite pendant le mode examens, version minimale ou aucune pendant le mode vacances.
Contrainte iOS : le contenu d'une notification locale est fixé à sa programmation. Programmer le brief à l'avance avec le contenu connu du planning, le mettre à jour de façon opportuniste (BackgroundTasks, à l'ouverture de l'app), et ne jamais promettre un contenu temps réel. Ton pote, pas de blague sur les sujets sérieux.

## 88. ROTATION DE PLANNING SEMAINE A/B (module schedule_rotation, exige planning_ocr, désactivé par défaut)

Réservé aux plannings qui se répètent vraiment. La rotation peut être saisie à la main ou détectée par le module pattern_detection (section 107) : quand l'app repère un cycle (2 semaines, 3 semaines, mensuel, autre), elle propose de l'activer. Si les semaines sont toutes différentes, rien n'est proposé.

L'utilisateur définit un cycle (deux semaines A/B, ou N semaines), la semaine de départ, et pour chaque semaine type les créneaux (jour, début, fin, activité, lieu). À l'import d'un planning par photo, l'app demande "C'est la semaine A ou B ?" et peut déduire la rotation après deux plannings consécutifs.
Elle préremplit le planning prévu des semaines suivantes avec des créneaux "prévus par rotation", non confirmés, confirmables en un tap. Un planning réel importé prime toujours sur la rotation. Gérer les exceptions (vacances, fériés, congés, remplacements, échanges) et le décalage de cycle ("On a décalé : cette semaine c'est B"). L'alerte de planning tardif (section 70) et la détection d'heures manquantes (section 86) tiennent compte de ces créneaux prévus.

## 89. ALERTE DE JOURS CONSÉCUTIFS ET DE REPOS HEBDOMADAIRE (module rest_alert, exige employment, désactivé par défaut)

Compte les jours consécutifs travaillés (par employeur, et tous employeurs confondus si multi_employer est actif) et vérifie le repos hebdomadaire, en les comparant aux règles du pack de convention et aux règles générales (Resources/reference/contracts.json, sourcées, "à vérifier" si incertaines). Complète le repos quotidien déjà géré par le pack (section 22), la nuit courte (section 33) et les pauses (section 32).
Alerte douce à l'avance quand le planning prévu ou le réel risque de dépasser : "Tu enchaînes 6 jours, ta convention prévoit un jour de repos par semaine (source : ...)." Seuil d'avertissement personnalisable, désactivable. Les congés posés comptent comme du repos. Sessions incertaines signalées. Si une règle est "à renseigner", l'app le dit et n'affirme rien. Information uniquement, pas un avis juridique.

## 90. IMPORT PAR LA FEUILLE DE PARTAGE (module share_import, désactivé par défaut)

Envoyer une image, un PDF ou une capture depuis WhatsApp, Messages, Mail, Photos ou Fichiers via "Partager" directement vers l'app, avec choix de la destination : planning (section 16), fiche de paie ou contrat (sections 20.3 et 72), ticket de frais (section 67), demande de dernière minute (section 142), contrat à vérifier (section 147). Seules les destinations des modules actifs sont proposées.
Contrainte du compte gratuit (section 6) : une extension de partage s'ajoute à l'extension des widgets et consomme un identifiant d'app. Elle est donc derrière le flag ENABLE_SHARE_EXTENSION, non compilée par défaut. L'extension ne fait que déposer le fichier dans le conteneur partagé (App Group) et ouvrir l'app, sans traitement lourd ni requête réseau. Si l'extension ou l'App Group est indisponible, repli sans extension : l'app déclare les types de documents qu'elle sait ouvrir ("Ouvrir dans" et gestion de l'URL reçue) et propose un sélecteur de photos et de fichiers. L'écran "État de l'app" indique la voie disponible.
Jamais d'import silencieux : tout fichier reçu passe par l'écran de validation correspondant.

## 91. PLANNING VARIABLE : TOUTES LES SEMAINES PEUVENT ÊTRE DIFFÉRENTES (principe transversal)

Hypothèse par défaut : aucune semaine ne ressemble forcément à la précédente. L'app ne suppose pas de régularité hebdomadaire des horaires, mais elle la détecte quand elle existe : elle analyse l'historique, mesure les répétitions et propose (jamais n'impose) un motif avec son niveau de confiance (section 107).
- Unité de planification : la semaine datée (créneaux datés), pas un modèle hebdomadaire. Chaque planning importé ou saisi s'applique à une semaine précise (dates lues, sinon demandées) et reste indépendant des autres. Un modèle de semaine type n'existe que si l'utilisateur active la rotation (section 88).
- Sources du "prévu", par ordre de priorité : planning importé de la semaine, créneaux saisis à la main, rotation si activée et confirmée. Les horaires du contrat ou les habitudes ne servent de prévu que si l'utilisateur déclare que ses horaires sont réguliers ou confirme un motif détecté (section 107).
- Quand aucun planning n'est connu pour une date, les modules qui en dépendent (brief du matin, heures manquantes, nuit courte, trajet, compte à rebours, prévision de solde, disponibilités, prédiction d'heure de fin) n'inventent aucun horaire. Ils disent "pas de planning pour cette semaine" et proposent d'importer ou de saisir, ou de reprendre un motif détecté et confirmable (section 107), toujours présenté comme une hypothèse. La prévision de solde de fin de mois utilise alors une hypothèse déclarée et modifiable (heures du contrat ou moyenne des semaines passées) avec une fourchette plus large.
- Écran de la semaine : "Semaine du 17 au 23 novembre : planning importé" ou "pas de planning", avec boutons Importer et Saisir. Bandeau discret pour la semaine suivante sans planning.
- Saisie rapide d'une semaine à la main : grille de 7 jours avec créneaux, "copier la semaine précédente" comme simple point de départ modifiable (jamais confirmé automatiquement), "semaine vide", "congé".
- Statistiques : moyennes par semaine avec dispersion, jamais comparées à une semaine type.
- Les habitudes de lieu (section 9) et la classification (section 11) tiennent compte de cette variabilité : le planning de la semaine pèse plus que la récurrence.

## 92. VÉRIFICATEUR DE FICHE DE PAIE (module payslip_check, exige pay, désactivé par défaut)

Après le scan de la fiche de paie (section 20.3), l'app lance une série de contrôles factuels et présente chaque constat avec la règle source et un niveau de confiance ("écart probable", "possible", "à vérifier") :
- heures payées contre heures réellement confirmées, au-dessus d'un seuil d'écart réglable ;
- majorations attendues par le pack de convention mais absentes (dimanche, jour férié, soirée ou nuit) ;
- taux horaire inférieur au minimum du pack ou au SMIC en vigueur à la date (historique de legal.json, section 69) ;
- congés acquis incohérents avec les règles de la section 23 ;
- heures complémentaires ou supplémentaires sans majoration ;
- primes saisies par l'utilisateur absentes de la fiche ;
- lignes inhabituelles que l'app ne sait pas évaluer, signalées "à comprendre" et jamais comme des fautes.
Ton neutre : "Possible écart à vérifier avec ton employeur", jamais d'accusation. L'app rappelle que la fiche peut intégrer des règles d'entreprise qu'elle ne connaît pas. Brouillon de message poli et factuel à l'employeur, modifiable, avec le relevé d'heures en pièce jointe, JAMAIS envoyé sans action de l'utilisateur. Aucun conseil juridique ; renvoi vers les sources officielles citées.

## 93. PRÉPARATION D'ENTRETIEN (module interview_prep, exige employment et pay, désactivé par défaut)

Prépare, avec des faits tirés des données réelles, un entretien avec le responsable. Trois modèles au choix, sections cochables, sortie en fiche PDF, trame d'entretien et brouillon de message modifiables, jamais envoyés automatiquement.
- Modèle "Augmentation" : ancienneté, taux actuel et son historique (section 69), écart avec le minimum du pack de convention et avec le SMIC, heures en plus et remplacements pris (section 68), régularité (section 71), expériences et compétences (section 96), responsabilités saisies par l'utilisateur.
- Modèle "Changement d'heures (avenant)" : quota du contrat, distribution réelle des heures (section 106.6), dépassements ou manques récurrents, remplacements, contraintes de l'utilisateur (cours, révisions, périodes bloquées), proposition chiffrée modifiable ("passer de 13 h à 16 h par semaine", ou "de 13 h à 10 h"). Aucun cadre légal codé en dur, et l'app rappelle qu'un changement d'heures passe par un accord entre les deux parties, à vérifier dans le contrat.
- Modèle "Fin de période d'essai" : heures faites, régularité, remplacements, notes de journée choisies, formations, points à demander au responsable, questions à poser, échéance de la période d'essai (section 19).
Ton posé, sans pression, aucune promesse de résultat ni affirmation qu'une demande serait due. Aucune donnée externe obligatoire, l'utilisateur peut saisir ses propres repères. Rien n'est envoyé automatiquement.

## 94. GÉNÉRATEUR DE DISPONIBILITÉS (module availability_planner, désactivé par défaut)

Pour une semaine donnée, calcule les créneaux où l'utilisateur peut travailler à partir de ses cours et événements connus de cette semaine, des trajets, des créneaux de révision (module study_slots), de la nuit courte (module short_night) et du repos (module rest_alert) quand ils sont actifs. Pensé pour des semaines toutes différentes (section 91).
Grille de la semaine : pour chaque créneau, "dispo", "plutôt" ou "pas dispo" (modifiable), jours exclus (congés, examens, vacances de l'app, périodes bloquées), objectif d'heures facultatif (lié à l'épargne si le module savings est actif, sans pousser à travailler plus). Sortie en texte, image ou PDF, partage via la feuille de partage native, jamais envoyée automatiquement. Aucune promesse que l'employeur tiendra compte des disponibilités.

## 95. PRÉDICTION D'HEURE DE FIN (module end_prediction, désactivé par défaut)

À partir de l'historique des écarts entre fin prévue et fin réelle, estime une "fin probable" : "prévu 22:00, fin probable 22:15". Calcul par contexte (employeur, lieu, type et durée du créneau, jour de la semaine), jamais par semaine type (section 91), avec un échantillon minimal réglable (défaut 8 sessions comparables) et un niveau de confiance affiché. Sous le seuil : "pas assez de données", aucune prédiction.
Utilisée pour affiner, avec une mention claire "probable", le widget "encore X h" (option), la nuit courte, le trajet retour, le brief du matin et le compte à rebours. Elle ne remplace jamais silencieusement l'heure prévue : "prévu" et "probable" restent distincts partout. Sessions incertaines exclues de l'apprentissage.

## 96. CARNET D'EXPÉRIENCES (module experience_log, désactivé par défaut)

Registre des expériences (job, stage, projet, bénévolat) avec poste, employeur ou structure, période, missions (étiquettes : caisse, mise en rayon, accueil, service, livraison...), compétences, outils, résultats chiffrés facultatifs. L'utilisateur peut y ajouter à la main des expériences passées hors de l'app (stage, job d'été).
Heures cumulées calculées depuis les sessions confirmées ("312 h en caisse sur 8 mois"). Pour un cumul par mission, une étiquette de tâche facultative peut être posée en un tap sur une session ; sans étiquette, le cumul se fait par employeur. Les sessions incertaines sont exclues ou le total est présenté comme "environ".
Génère des phrases factuelles prêtes à adapter pour un CV, un dossier de candidature (par exemple la rubrique d'activités et de centres d'intérêt) ou une lettre de motivation. Chaque phrase est rattachée à une donnée réelle, ne gonfle rien, et reste modifiable. Export texte ou PDF, tout en local.

## 97. DÉTECTEUR DE CHANGEMENTS DE PLANNING (module planning_diff, exige planning_ocr, désactivé par défaut)

Compare les versions d'UNE MÊME semaine (planning réimporté, modification manuelle, changement en cours de semaine), jamais deux semaines différentes entre elles (section 91). La comparaison porte sur les créneaux structurés et validés, pas sur le texte OCR brut, pour éviter les faux changements dus à la lecture.
Affiche un diff lisible : créneau ajouté, supprimé, déplacé. Notification quand un changement touche les 48 prochaines heures ou à l'import : "Ton planning a changé : jeudi 18 h à 22 h est devenu 14 h à 18 h." Actions : "Accepter" (met à jour le prévu et conserve l'ancienne version), "Garder l'ancien", "Voir les détails". Historique des versions consultable (ScheduleVersion).
Un changement accepté met à jour les notifications déjà programmées (brief, compte à rebours, trajet, check avant de partir) et n'entraîne aucune question d'heures manquantes pour un créneau supprimé officiellement.

## 98. JOURNAL INFALSIFIABLE (module tamper_log, désactivé par défaut)

Chaque session, correction et entrée du journal des modifications est chaînée : empreinte SHA-256 (CryptoKit) du contenu canonique plus l'empreinte de l'entrée précédente. Une correction légitime est une nouvelle entrée qui référence l'ancienne, jamais une réécriture.
Points de contrôle périodiques (par exemple chaque semaine), éventuellement signés avec une clé du Secure Enclave quand l'appareil le permet. L'utilisateur peut exporter l'empreinte d'un point de contrôle (texte ou QR) et la faire dater en la gardant ailleurs (mail à soi-même, note partagée), ce qui fixe une date vérifiable par un tiers.
Écran "Vérifier l'intégrité" : détecte toute altération de la chaîne. Attestation d'intégrité en PDF (période, nombre d'entrées, empreinte racine). Honnêteté obligatoire dans l'interface et dans l'attestation : le journal prouve la non-modification locale depuis un point de contrôle, il ne prouve ni que les heures sont exactes, ni la date réelle sans ancrage externe, et n'a pas de valeur juridique garantie. Calcul hors du thread principal, par lots. Compatible avec la sauvegarde JSON et iCloud : la chaîne est exportée avec les données et vérifiée à la restauration.

## 99. PRÉVISION DE CHARGE DE LA SEMAINE (module load_forecast, désactivé par défaut)

Calcule une charge hebdomadaire et quotidienne à partir du planning connu : heures de cours, de travail, de trajets, de révision planifiée et d'objectifs. Elle la compare à des repères personnels (par défaut la moyenne des semaines passées, ou un maximum d'heures occupées fixé par l'utilisateur, par semaine et par jour).
Alerte douce quand une semaine s'annonce chargée : "Semaine chargée : 46 h occupées contre 34 h en moyenne, jeudi est le plus rempli." Détail par jour, avec repérage des jours sans pause. L'app propose des options d'allègement (décaler un créneau de révision, utiliser un créneau libre de la section 34, ne pas accepter un remplacement), sans jamais décider à la place de l'utilisateur. Sans planning connu pour la semaine, elle le dit et ne calcule rien. Vocabulaire neutre : pas de diagnostic, pas de termes de santé. S'articule avec l'équilibre de la semaine (section 78), le mode examens (section 31) et les disponibilités (section 94).

## 100. MODE "BAC EN APPROCHE" (module exam_budget, exige exam_mode, désactivé par défaut)

À l'approche des épreuves, calcule un budget d'heures de travail rémunéré à ne pas dépasser, à partir des objectifs de révision saisis par l'utilisateur (heures par semaine, éventuellement par matière), des cours, des trajets et du repos : heures disponibles moins cours, révision cible et repos égale marge pour le travail. Affichage : "Tu peux bosser jusqu'à 8 h cette semaine sans casser ton planning de révision."
Suivi des heures de révision (module study_slots) contre l'objectif, alertes douces si le budget est dépassé. Si le contrat (section 106) prévoit plus d'heures que le budget, l'app le signale factuellement ("Ton contrat prévoit 13 h, ton budget en autorise 8") et peut préparer un brouillon de message pour demander un aménagement, JAMAIS envoyé sans action de l'utilisateur, sans aucun conseil juridique. Dates d'épreuves reprises du mode examens.

## 101. ASSISTANT DE RETOUR DE CONGÉ (module return_recap, désactivé par défaut)

Après une absence longue (mode vacances de l'app, période de congés payés, ou toute absence de plus de N jours, défaut 7), un récap à la reprise : planning des prochains jours, changements de planning survenus pendant l'absence (module planning_diff), solde de congés mis à jour, échéances proches (fin de contrat, période d'essai), éléments à confirmer, règles ou valeurs de référence mises à jour (SMIC, packs de convention) et état de l'app (permissions, suivi). Contenu modulaire : seulement ce que fournissent les modules actifs. Notification de reprise et carte sur l'accueil, qui disparaît après lecture. Ton léger et cool.

## 102. CARTE DE CHALEUR ANNUELLE (module heatmap, désactivé par défaut)

Grille façon contributions GitHub : une colonne par semaine, une case par jour, intensité selon les heures de travail, de cours, ou des deux (choix), couleurs par type d'activité. Périodes : année civile, année scolaire, 12 derniers mois. Tap sur un jour pour le détail, filtres par employeur et par activité, vacances, congés et mode vacances marqués, jours incertains hachurés. Jamais de statistique trompeuse sur des données incomplètes.
Accessibilité : résumé par semaine pour VoiceOver, aucune information portée par la couleur seule. Rendu performant (365 cases, dessin direct ou Canvas, calcul hors du thread principal). Exportable en image via le résumé partageable (section 79) si ce module est actif.

## 103. MÉMOS DE CONTEXTE PAR LIEU (module place_memos, désactivé par défaut)

Notes écrites par l'utilisateur pour un lieu : consigne du jour, code du vestiaire, chose à ramener. Deux modes : permanent (affiché à chaque arrivée) ou "une seule fois" (affiché une fois puis archivé), avec date d'expiration facultative. Déclenchement à l'arrivée détectée ou probable : notification discrète et carte sur l'accueil, une seule fois par session.
Confidentialité : par défaut la notification ne montre pas le contenu ("Tu as un mémo pour ce lieu"), le contenu s'affiche à l'ouverture, après Face ID si le verrouillage est actif. Stockage local, exclu d'iCloud et de l'export sauf choix explicite. Une ligne d'avertissement dans l'écran de saisie : ne pas y mettre de mots de passe importants.

## 104. COHÉRENCE DU TRAJET (module travel_calibration, exige travel_departure, désactivé par défaut)

Compare les durées de trajet réellement observées (du départ de la zone à l'arrivée au lieu) avec l'estimation MKDirections, par trajet, mode de transport, créneau horaire et jour. Calcule l'écart médian et propose d'ajuster la marge de "Pars maintenant" : "Ton trajet dure en moyenne 6 min de plus que prévu, je prends une marge de 16 min." L'utilisateur accepte, refuse ou règle à la main.
Échantillon minimal réglable (défaut 8 trajets comparables). Exclure les trajets avec arrêt (courses détectées, pause). Confidentialité : seules les durées et horodatages sont conservés, jamais de trace GPS détaillée.

## 105. TRACE DE RETARD (module delay_log, désactivé par défaut)

En cas de retard imprévu, l'utilisateur peut enregistrer en un tap une trace datée : heure, cause facultative (transport, trafic, panne), heure d'arrivée estimée (si le module de trajet est actif), position approximative, photo facultative (par exemple un panneau d'information transport), stockées localement. Pour la confidentialité, la position est arrondie à un quartier (rayon d'environ 500 m) par défaut, et précise seulement si l'utilisateur le choisit.
Message prérempli au responsable via le module work_contacts, jamais envoyé automatiquement. Entrée optionnelle dans le journal de contrat (section 72), chaînée par le journal infalsifiable (section 98) si actif, protégée par Face ID si le verrouillage est actif. La trace ne prouve pas la cause du retard, c'est une information personnelle datée. Aucune transmission.

## 106. ÉQUILIBRAGE DES HEURES DU CONTRAT (module contract_hours, exige employment, proposé et coché par défaut)

Le contrat fixe un quota d'heures sur une période de référence, mais la réalité varie : le planning annonce des créneaux, certains sont plus courts, plus longs ou sautés, et certaines semaines dépassent le quota. L'app suit le quota, projette la fin de période et rééquilibre en permanence. Cette section complète la section 25.

106.1 Paramètres : quota d'heures du contrat par employeur, historisé avec date d'effet comme les taux (section 69) pour gérer les avenants ; période de référence (semaine par défaut, quinzaine, mois, trimestre, annualisation ou modulation, ou "heures variables sans quota") ; premier jour de la période ; période de contrat distincte de la période de paie si nécessaire.
106.2 Suivi et projection : pour la période en cours, quota, heures planifiées (créneaux datés), heures réalisées (sessions confirmées et en cours, sur la base retenue pour le quota, section 13.1), reste à faire (quota moins réalisé), projection (réalisé plus planifié restant) et écart projeté. Carte "Ta semaine : 13 h au contrat, 9 h faites, 8 h prévues, projection 17 h, soit 4 h de plus." Barres jour par jour (prévu contre réalisé). États : dans le contrat, il te manque X h, tu dépasses de X h, à confirmer.
106.3 Rééquilibrage intelligent : recalcul à chaque changement (créneau plus court, plus long ou non fait, changement de planning, remplacement, absence), avec des phrases claires. Cas à couvrir, par exemple pour un contrat de 13 h avec un planning de 5 h le vendredi, 8 h le samedi et 5 h le dimanche (18 h prévues) :
- Vendredi réalisé 4 h : "Il te reste 9 h pour tes 13 h, ton planning en prévoit 13, tu finiras à 17 h, soit 4 h de plus que ton contrat."
- Vendredi non fait (0 h), samedi 8 h et dimanche 5 h faits : "13 h au total, ton contrat est atteint pile."
- Semaine à 18 h réalisées : "5 h au-dessus de ton contrat", avec le classement selon le pack (106.5).
- Semaine à 10 h réalisées : "Il te manque 3 h pour tes 13 h", avec les options de 106.4.
L'app informe et propose des options, elle ne décide jamais à la place de l'utilisateur et ne propose jamais de contourner le contrat.
106.4 Heures en trop ou en moins et repos compensateur : compteurs "heures à rattraper", "heures d'avance" et "repos compensateur" (heures supplémentaires converties en repos selon la convention, avec récupérations prises, date d'expiration éventuelle et alerte douce avant expiration, règles lues dans le pack et "à renseigner" si absentes) par employeur, avec un réglage de ce qui se passe réellement dans la situation de l'utilisateur : reportées sur la période suivante, lissées sur le mois, payées en heures complémentaires ou supplémentaires, non reportées, ou "à renseigner" si inconnu. Par défaut l'app ne présume rien. Réglage "comment compter un créneau prévu non travaillé (congé, absence, créneau annulé)" : à rattraper, quota réduit, maintenu payé, ou demander à chaque fois (défaut).
106.5 Heures complémentaires et supplémentaires : quand la projection dépasse le quota, classement selon le pack de convention et les règles générales (Resources/reference/contracts.json, sourcé, "à vérifier"), avec la majoration applicable, le plafond d'heures complémentaires et la durée minimale d'une séance de travail si le pack les précise. Alertes douces : "Tu approches du plafond d'heures complémentaires de ton contrat (source : ...)". Rien codé en dur.
106.6 Quotas qui varient : si les semaines réelles s'éloignent souvent du contrat (13 h au contrat, parfois 18 h), l'app affiche la distribution réelle (moyenne, minimum, maximum, par mois) et signale doucement un dépassement récurrent ("Tu dépasses ton quota 5 semaines sur 8, un avenant a peut-être été prévu, à vérifier dans ton journal de contrat"), sans jamais accuser.
106.7 Aide à la répartition : "pour atteindre tes 13 h il te faut X h sur les jours restants", avec des répartitions possibles s'appuyant sur le planning, les disponibilités (section 94), le repos (section 89) et les motifs détectés (section 107) quand ces modules sont actifs.
106.8 Interactions : la paie (section 20) utilise les heures réalisées ou les heures du contrat selon un réglage ("payé sur la base du réalisé" ou "du contrat", à renseigner), et la prévision de solde (section 85), le simulateur (section 24) et le rappel d'envoi (section 42) reprennent ces mêmes projections. Aucune alerte pendant les congés, les vacances de l'app ou les absences justifiées marquées.

## 107. DÉTECTION DE MOTIFS DE PLANNING ET SUGGESTIONS INTELLIGENTES (module pattern_detection, proposé et coché par défaut)

L'app n'impose aucune régularité, mais la cherche. Elle analyse l'historique des plannings et des sessions, mesure les répétitions et propose un motif avec son niveau de confiance et son nombre d'occurrences. L'utilisateur confirme, ajuste ou rejette. Un motif confirmé devient une règle modifiable ; un motif rejeté n'est pas reproposé, sauf nouvelle donnée forte.
107.1 Motifs recherchés : semaine identique à la précédente (tolérance horaire réglable, par exemple plus ou moins 30 minutes), cycles de 2, 3 ou 4 semaines, rythme mensuel ("premier week-end du mois"), semaines paires et impaires, jours fixes avec horaires variables, durées récurrentes ("toujours 4 h le vendredi"), enchaînements ("après un week-end long, semaine courte").
107.2 Méthode : calcul local, explicable et testable, sans IA distante. Mesure de similarité entre semaines (créneaux comparés par jour, début, fin, lieu), recherche de périodicité à pas de N semaines, taux de correspondance sur un nombre minimal de répétitions du cycle (défaut 3), score de confiance, explication lisible ("Tes 6 dernières semaines alternent entre 2 plannings, la correspondance est de 5 sur 6").
107.3 Suggestions : pour une semaine sans planning, proposer "Même planning que la semaine du 10 (confiance 85 %)" ou "Suite de ton cycle de 3 semaines", avec aperçu, validation en un tap et modification possible. Jamais appliqué sans confirmation. Si le motif se casse, l'app baisse la confiance et le dit. Quand un cycle est détecté et confirmé, elle active le module de rotation (section 88) avec confirmation.
107.4 Jours fériés : l'app apprend comment l'utilisateur fonctionne autour d'un jour férié : travaille-t-il ce jour, avec quels horaires, compense-t-il la veille ou le lendemain ? Exemple : "Le 11 novembre tombe un mardi : les deux dernières années tu as travaillé de 9 h à 13 h, je le prévois ?" Échantillon minimal (au moins 2 occurrences du même jour férié, ou assez de jours fériés tous types confondus), sinon "pas assez de données". Les majorations du pack sont affichées avec leur source.
107.5 Intégrations : les suggestions respectent le quota du contrat (section 106), les disponibilités (section 94) et le repos (section 89) quand ces modules sont actifs. Un motif confirmé peut servir de prévu à faible priorité pour les heures manquantes (section 86), avec une question formulée comme une hypothèse. Écran "Mes habitudes de planning" pour consulter, corriger ou effacer les motifs.
107.6 Réglages : sensibilité (stricte, normale, souple), nombre minimal de répétitions, tolérance horaire, désactivation des suggestions, effacement des motifs appris. Tout reste local.

## 108. RÉGULARISATION DES HEURES PAYÉES (module pay_reconciliation, exige pay et contract_hours, désactivé par défaut)

Suivi cumulé sur plusieurs mois de l'écart entre trois chiffres : heures du contrat (quota), heures réalisées confirmées, heures payées (lues sur les fiches de paie scannées ou saisies). Pour chaque mois et en cumul : écart en heures et en euros estimés, en tenant compte des règles de report, de lissage et de comptage choisies en section 106.4 et des majorations du pack.
Si un écart persiste dans le même sens sur plusieurs mois (seuil et nombre de mois réglables), l'app prépare un dossier de régularisation : tableau mensuel, relevés d'heures, extraits du planning, entrées du journal infalsifiable (section 98) si actif, brouillon de message poli et factuel. Tout est modifiable et JAMAIS envoyé sans action de l'utilisateur.
Honnêteté : l'app signale avec le même soin les heures payées EN TROP (trop-perçu probable) et n'affirme jamais que l'employeur a tort, car il peut exister des règles ou accords qu'elle ne connaît pas. Distinct du vérificateur de fiche de paie (section 92), qui contrôle une fiche à la fois. Aucun conseil juridique, renvoi vers les sources officielles.

## 109. ALERTE DE PROXIMITÉ DU QUOTA (réglage du module contract_hours, désactivé par défaut)

Prévient quand l'utilisateur approche d'une limite : "Plus que 2 h avant ton quota de la semaine." Limites au choix : quota du contrat, plafond personnel fixé par l'utilisateur, plafond d'heures complémentaires du contrat, durée maximale légale ou conventionnelle (règles sourcées, "à vérifier"). Seuils réglables (par exemple 2 h, 1 h, 0 h restant), un rappel par seuil, par employeur. Le calcul inclut la session en cours et les heures déjà réalisées. Affichage possible dans la Live Activity (section 44) en option.
Ton neutre : l'app donne l'information pour que l'utilisateur choisisse en connaissance de cause, sans pousser à en faire plus ou moins. Aucune alerte pendant les congés, le mode vacances ou une période bloquée, heures silencieuses respectées.

## 110. PLANNINGS PROPOSÉS (module plan_proposals, exige employment, désactivé par défaut)

Pour une semaine donnée, génère 2 à 3 plannings possibles à comparer. Entrées : quota (section 106), cours et événements connus, objectifs de révision, préférences (jours préférés ou à éviter, durée minimale et maximale d'un créneau, horaires exclus), repos (section 89), nuit courte (section 33), charge (section 99), disponibilités (section 94), motifs détectés (section 107), périodes bloquées (section 114) et objectifs d'épargne (section 38) quand ces modules sont actifs.
Contraintes dures jamais violées : cours, repos du pack, périodes bloquées de niveau "je ne peux pas", quota maximal si réglé. Contraintes souples optimisées : préférences, équilibre, charge.
Méthode locale, déterministe et explicable : recherche sous contraintes avec un score visible par critère (heures contre quota, paie estimée, charge, repos, préférences) et un bouton "Pourquoi cette proposition ?". Pas d'IA distante, calcul hors du thread principal, résultat rapide.
Chaque proposition affiche créneaux, total d'heures, écart au quota, paie estimée et charge. L'utilisateur compare, ajuste, puis exporte comme proposition (texte, image ou PDF via la feuille de partage), jamais envoyée automatiquement. Un planning n'entre dans le "prévu" qu'après confirmation. L'app rappelle que l'employeur décide. Sans données minimales (quota, cours connus), elle le dit et ne propose rien.

## 111. SIMULATEUR DE SEMAINE EN DIRECT (mode du module simulator, section 24)

Grille de la semaine où l'utilisateur glisse, allonge ou supprime des créneaux. Les indicateurs se mettent à jour instantanément dans une barre fixe : quota du contrat (section 106), paie estimée (sections 20 et 24), charge (section 99), repos (section 89), nuit courte (section 33), trajet (section 35), objectif d'épargne (section 38), seulement pour les modules actifs.
Annuler et rétablir, enregistrement comme scénario, "Appliquer au planning prévu" après confirmation (jamais les sessions réelles). Travaille sur une copie isolée. Calcul incrémental hors du thread principal, visé sous 16 ms par interaction. Alternative accessible au glisser-déposer (boutons, champs d'heure, VoiceOver).

## 112. JOURS FÉRIÉS DE L'ANNÉE (module holiday_outlook, désactivé par défaut)

Récap en début d'année et à la demande : jours fériés de l'année (calculés, section 30) avec leur jour de semaine, ceux qui tombent un jour habituellement travaillé (d'après le planning ou un motif confirmé, jamais supposé), ce que l'utilisateur a fait ce jour-là les années précédentes (travaillé, horaires, durée, d'après l'historique), majoration du pack avec sa source, ponts possibles. Rappel doux avant chaque férié proche. Sans planning ni historique, l'app le dit ("pas encore de planning pour ce jour"). S'appuie sur la détection de motifs (section 107.4).

## 113. COMPARAISON AVEC TON PROPRE PASSÉ (module self_compare, désactivé par défaut)

Compare la période en cours avec la moyenne des périodes précédentes : "Ce mois-ci tu as travaillé 12 % de plus que ta moyenne, surtout le samedi." Indicateurs : heures de travail et de cours, jours travaillés, heures de soirée et de week-end, trajets, durée moyenne de session, remplacements. Décomposition par jour, lieu et employeur pour expliquer l'écart.
N'affiche une comparaison que si l'écart est significatif et l'échantillon suffisant. Sessions incertaines exclues. Compare vacances à vacances et période scolaire à période scolaire quand le calendrier est actif. Vocabulaire neutre, aucun jugement, jamais de comparaison avec d'autres personnes. Peut alimenter les bilans (section 40) et une notification mensuelle facultative.

## 114. PÉRIODES BLOQUÉES : JOUR, SEMAINE OU PLAGE (module blocked_periods, désactivé par défaut)

L'utilisateur bloque un jour, une semaine ou une plage de dates où il ne peut pas ou ne veut pas travailler (voyage, anniversaire, événement, repos). Niveaux : "je ne peux pas" (contrainte dure) ou "je préférerais éviter" (contrainte souple). Journée entière ou plage horaire (par exemple la soirée), ponctuel ou récurrent (tous les mercredis après-midi jusqu'à une date). S'applique au travail par défaut, et peut s'étendre à d'autres activités (par exemple la révision).
Écran d'impact avant confirmation, calculé avec les modules actifs : "Si tu bloques la semaine du 17 : ton quota de 13 h ne sera pas atteint (13 h à rattraper ou à poser en congé selon ton réglage), paie estimée en baisse d'environ X € net, ton objectif décalé de 6 jours."
Effets : quota et compteurs (section 106), paie et prévision de solde (sections 20 et 85), objectifs d'épargne (section 38), congés (section 23, avec proposition de poser un congé), disponibilités (section 94), plannings proposés (section 110, contrainte dure), et aucun rappel de travail, brief de travail, question d'heures manquantes, compte à rebours ou alerte de quota pendant la période.
Conflit avec un créneau déjà prévu : l'app le signale et propose des options (prévenir l'employeur avec un brouillon, poser un congé, chercher un échange dans le carnet d'échanges de la section 81, ou garder le créneau). Elle n'annule JAMAIS un créneau prévu automatiquement. Brouillon "Je ne suis pas disponible le [date]" avec motif facultatif, jamais envoyé automatiquement. Périodes affichées hachurées dans le planning et les widgets, aucune Live Activity pendant la période.
Différence avec le mode vacances de l'app (section 73) : une période bloquée sert à planifier et à prévenir, elle ne suspend pas le suivi automatique. Pour un voyage, l'app propose d'activer aussi le mode vacances.

## 115. ARBITRAGE COURS CONTRE TRAVAIL (module class_work_tradeoff, désactivé par défaut)

Quand un créneau de travail chevauche un cours (planning reçu, créneau ou remplacement proposé, changement de planning), l'app affiche côte à côte, sans décider :
- ce que l'utilisateur gagne en travaillant : heures, net estimé, effet sur le quota (section 106) et sur ses objectifs ;
- ce qu'il perd en manquant le cours : heures de cours manquées, matière si elle est connue, absences déjà cumulées (compteur personnel facultatif, jamais transmis à l'établissement), contrôle ou épreuve prévus ce jour-là s'il les a saisis.
Options présentées dans un ordre neutre : garder le cours, garder le travail, chercher un autre créneau (disponibilités, échange du carnet de la section 81), prévenir l'employeur (brouillon). L'app ne conseille jamais de manquer un cours et ne marque jamais une absence toute seule. Les cours restent une contrainte dure par défaut dans les plannings proposés et les périodes bloquées. Point d'entrée : la détection de conflits de l'onglet Planning (section 16).

## 116. APERÇU DE TA FIN DE SEMAINE (module weekend_preview, désactivé par défaut)

Récap des jours à venir, adapté à la vraie vie de l'utilisateur : l'app ne présume pas que le week-end est un temps de repos. L'utilisateur définit "ma fin de semaine" (par exemple vendredi à dimanche, samedi et dimanche, ou ses jours de travail et de repos propres, déduits du planning ou d'un motif confirmé) et le moment du récap (jour et heure, par défaut la veille du premier jour du bloc).
Contenu : créneaux prévus, heures déjà faites sur la période, reste pour atteindre le quota (section 106) et projection, jours de repos, révisions, événements, jours fériés, périodes bloquées. Phrases adaptées : pour quelqu'un qui travaille le week-end, "Ce week-end : samedi 8 h, dimanche 5 h. Il te reste 9 h pour tes 13 h, ton planning couvre 13 h, tu as lundi et mardi de repos." ; pour quelqu'un qui ne travaille pas le week-end, "Week-end libre, il te reste 4 h à faire lundi." Sans planning connu, l'app le dit. Seuls les modules actifs fournissent du contenu.

## 117. ANTICIPATION DES PÉRIODES CREUSES (module low_period_alert, exige employment, désactivé par défaut)

Repère à l'avance les semaines ou les mois où le quota ou le revenu risque de ne pas être atteint : jours bloqués, vacances scolaires, congés posés, jours fériés, absence de planning, fin de contrat proche, période d'examens, périodes creuses constatées les années précédentes. Projette le quota (section 106) et le net estimé (section 85) sur un horizon réglable (défaut 4 à 8 semaines), avec une fourchette.
Alerte douce, hebdomadaire ou à la détection : "Dans 3 semaines (vacances), ton quota risque de ne pas être atteint : environ 18 h à rattraper, soit environ X € net en moins." Options proposées : demander des heures, poser des congés, décaler un objectif d'épargne, ajuster un blocage. Basé sur les données déclarées et l'historique, "pas assez de données" sinon. Estimation, jamais une certitude.

## 118. HISTORIQUE DES PLANNINGS CONSULTABLE (module schedule_archive, exige planning_ocr, proposé et coché par défaut)

Navigation par semaine, mois et année dans tous les plannings passés : planning prévu (avec ses versions, section 97), réel, écarts, changements, notes, et image d'origine du planning importé si l'utilisateur choisit de la conserver. Retrouvable par la recherche (section 41, "semaine du 3 mars"). Comparaison de deux semaines côte à côte. Une semaine passée peut être proposée comme point de départ d'un prévu (suggestion, jamais confirmée automatiquement). Export PDF d'une semaine ou d'un mois.
Stockage : conservation des images désactivée ou activée au choix, compression, taille occupée affichée, purge par période, protection des données d'iOS, Face ID si le verrouillage est actif. Hors ligne, aucune transmission.

## 119. PRÊT À PARTIR EN VACANCES (module vacation_prep, désactivé par défaut)

Checklist guidée avant un long départ (durée minimale réglable, ou à la demande). Chaque étape ouvre l'écran concerné en un tap et se coche une fois faite, avec seulement les étapes des modules actifs :
1. poser les congés payés (section 23) ;
2. bloquer la période (section 114) et voir l'écran d'impact ;
3. activer le mode vacances de l'app (section 73) ;
4. prévenir l'employeur (brouillon, jamais envoyé automatiquement) ;
5. vérifier le planning des semaines avant et après ;
6. vérifier la dernière sauvegarde et lancer un export JSON ;
7. vérifier quotas, paie estimée et objectifs d'épargne sur la période ;
8. régler les notifications à garder ou à couper ;
9. contrôler permissions et état de l'app.
Checklist modifiable, état mémorisé, rappel quelques jours avant la date de départ si elle est saisie. Au retour, le récap de la section 101 prend le relais.

## 120. ÉQUIPE ET ÉCHANGES MALINS (module team_swaps, exige planning_ocr, désactivé par défaut)

Les plannings importés (section 16) contiennent aussi les créneaux des collègues. Ce module les exploite, avec leur accord implicite d'usage strictement personnel et local.
- Collecte : à l'import, l'utilisateur choisit de retenir ou non les noms et créneaux des collègues. Par défaut rien n'est conservé hors de ses propres créneaux. Avec le choix "retenir mon équipe", l'app garde localement les prénoms ou initiales et leurs créneaux datés. Les initiales ambiguës sont confirmées par l'utilisateur, la liste "Mon équipe" est modifiable et chaque personne peut être effacée.
- "Avec qui je bosse" : pour un créneau, affichage des collègues présents en même temps (chevauchement des horaires).
- "Qui pourrait me remplacer ou échanger" : pour un créneau que l'utilisateur veut céder ou obtenir, liste des collègues sans créneau ce jour-là d'après le planning. L'app précise qu'elle ne connaît pas leurs contraintes réelles ("pas prévu ce jour-là d'après le planning, à confirmer avec la personne"). Elle prépare un brouillon de message (contact du module work_contacts s'il existe), jamais envoyé automatiquement, et crée une entrée dans le carnet d'échanges (section 81).
- Vie privée : données de tiers minimisées, jamais partagées, jamais exportées par défaut, exclues des résumés et dossiers, aucune statistique ni classement sur les collègues.

## 121. PLANNING PAR TEXTE (module planning_text, exige planning_ocr, désactivé par défaut)

Beaucoup d'employeurs envoient le planning en texte (SMS, WhatsApp, mail). L'utilisateur le colle ou le partage, et l'app le comprend sans photo.
- Entrées : bouton de collage natif (qui évite l'alerte système de presse-papiers), partage d'un texte via la feuille de partage (nouveau type de contenu pour le module share_import), saisie directe.
- Analyse locale, déterministe et explicable (règles avec les outils d'analyse de texte de l'appareil, sans IA distante) : jours (lundi, lun., 17/11), plages ("14-19", "14h-19h", "de 14h à 19h", "14h00/19h00"), deux plages dans un jour ("8-12 / 14-18"), repos et congés ("repos", "OFF", "R", "congé"), jours fériés, lieux, plusieurs semaines, listes, tableaux copiés, dates relatives ("semaine du 17"). Si le texte contient plusieurs personnes, même identification par nom ou initiales que pour une photo (section 16).
- Les ambiguïtés ne sont jamais devinées ("14-19" est lu 14 h à 19 h, "6-2" demande confirmation).
- Écran de validation comme en section 16 : texte d'origine avec les passages reconnus surlignés, créneaux reconstruits et modifiables. Jamais d'import silencieux.
- Apprentissage local du gabarit de l'employeur après validation, pour mieux lire le message suivant. Rien ne quitte l'appareil.

## 122. MAINTENANT : UNE SEULE CHOSE À FAIRE (module now_card, proposé et coché par défaut)

Carte unique en haut de l'accueil qui montre l'action la plus utile du moment, pour éviter de noyer l'utilisateur sous les bandeaux et notifications.
- Moteur d'actions (ActionEngine, service du noyau) : chaque module actif déclare des candidats d'action avec titre, urgence (heure limite), importance, durée estimée, coût d'ignorer et action associée en un tap (partir, confirmer une arrivée ou une sortie, importer le planning, répondre "T'as bossé ?", envoyer les heures, badger, confirmer des sessions avant un relevé). Le moteur classe par score (importance fois urgence), filtre selon les contextes de silence (mode vacances, examens, périodes bloquées, "Pas aujourd'hui", heures silencieuses) et renvoie le meilleur candidat.
- Carte : titre court, bouton principal d'un tap, "Pas maintenant" (report) et lien "Voir les autres (3)". Avec ce module, la carte remplace le bandeau "À confirmer" de la section 47 en regroupant les éléments incertains ("3 trucs à confirmer"). Sans ce module, le bandeau reste.
- Règles : jamais plus d'une carte, état calme quand rien n'est urgent ("Rien à faire, profites-en"), stabilité (réévaluation sur événement, pas à la seconde), une action ignorée plusieurs fois voit sa priorité baisser, bouton "Pourquoi cette carte ?", accessibilité complète, calcul local déterministe et testable.
- Le coordinateur de notifications (section 123) s'appuie sur le même moteur.

## 123. NOTIFICATIONS QUI APPRENNENT (module smart_notifications, proposé et coché par défaut)

Un coordinateur central de notifications (NotificationCoordinator) pour tous les modules, qui remplace les envois dispersés.
- Priorités (essentielle, utile, informative), budget quotidien réglable, regroupement des rappels proches en un seul, déduplication, respect des contextes de silence et des heures silencieuses. Les notifications essentielles (arrivée ou départ incertain, "Pars maintenant", alerte de suivi interrompu) sont protégées par défaut.
- Apprentissage local par catégorie et plage horaire : notification ouverte, action effectuée, écartée ou restée sans suite. L'app propose, sans jamais imposer : "Tu as ignoré 5 rappels de pause, je les coupe ?", "Tu réagis plutôt vers 18 h, je décale le rappel d'envoi ?" Choix en un tap (couper, déplacer, garder), une proposition par catégorie et par mois, aucune notification coupée sans accord.
- Limite iOS à respecter : l'app ne sait pas si une notification a été simplement vue. "Ignorée" signifie ni ouverte ni action dans un délai donné (défaut 24 h), et la détection des notifications écartées demande une action de fermeture personnalisée sur la catégorie. Le dire dans l'interface plutôt que de prétendre une mesure exacte.
- Données locales, effaçables, aucune télémétrie.

## 124. COMPTEUR DE GAINS EN DIRECT (module live_earnings, exige pay, désactivé par défaut)

Estimation du gain depuis le début de la session : taux fois temps écoulé, avec les majorations applicables à l'instant (soirée, dimanche) selon le pack, en net ou en brut au choix, affiché "environ +14 € net". Utilise l'horodatage exact du début de session, ou l'heure normalisée si la base retenue pour la paie de l'employeur l'impose (section 13.1).
Contrainte technique à respecter honnêtement : une Live Activity ne se met pas à jour toute seule sans que l'app s'exécute ou sans notification push, donc l'app ne promet jamais un défilement en direct dans la Live Activity. Réalisation : (a) widget d'écran verrouillé ou d'accueil avec une timeline précalculée (une entrée par minute ou par 5 minutes sur la durée prévue de la session, recalculée à chaque changement), (b) compteur fluide dans l'app (TimelineView), (c) dans la Live Activity, seulement une valeur statique mise à jour quand l'app tourne. Sans fin prévue connue, la timeline couvre une durée maximale réglable (défaut 10 h).
Masqué par défaut grâce au mode discret, tap pour révéler, désactivable, sans gamification excessive ni notification. Estimation indicative, sessions incertaines exclues.

## 125. PILE INTELLIGENTE ET CONTRÔLES (réglage du module live_activity_widgets, activé avec lui)

- Pile intelligente : les widgets fournissent des informations de pertinence pour remonter au bon moment (avant la prise de poste, pendant la session, à l'approche de la fin) quand l'API de pertinence de WidgetKit est disponible dans le SDK utilisé. L'app donne aussi ses App Intents ("Démarrer ma session") au bon moment pour que le système puisse les suggérer.
- Contrôles : boutons "Démarrer ma session", "Arrêter", "Pause" et, si work_contacts est actif, "Je suis en retard", disponibles dans le Centre de contrôle, l'écran verrouillé et le Bouton Action. Les contrôles du Centre de contrôle demandent iOS 18 : ils sont protégés par une vérification de disponibilité. Sous iOS 17, repli par widgets interactifs, App Intents et Bouton Action assigné via Raccourcis.
- Aucune cible supplémentaire : les contrôles font partie de l'extension de widgets existante. La capacité est signalée dans "État de l'app" (section 51).

## 126. TON VRAI TAUX HORAIRE (module true_hourly_rate, exige pay, désactivé par défaut)

Calcule ce que rapporte vraiment une heure : (net estimé moins frais directs) divisé par (heures travaillées plus temps de trajet plus temps de préparation ou d'attente).
- Entrées : net du module pay sur la période choisie (semaine, mois, trois mois, depuis le début), frais du module expenses et coût du trajet (section 36) s'ils sont actifs, remboursements déduits, heures confirmées, temps de trajet réel observé ou estimé (aller-retour), temps de préparation saisi (par exemple 10 minutes par session, facultatif), temps de présence non payé.
- Affichage : "Taux net du contrat 9,50 € de l'heure, vrai taux 7,80 € de l'heure (trajets et frais)", avec décomposition en barres. Hypothèses visibles et modifiables, "pas assez de données" sinon, sessions incertaines exclues, montants masquables en mode discret.
- Aucun jugement : l'app donne des faits, jamais un avis sur le fait de travailler ou non. Peut alimenter le simulateur (section 24) pour comparer, par exemple, deux modes de transport.

## 127. SCORE DE FIABILITÉ DES DONNÉES (module data_trust, proposé et coché par défaut)

Pour une période (semaine, mois), mesure la qualité des données et non le comportement de l'utilisateur : "Ta semaine est fiable à 92 %". Formule transparente : part des heures confirmées ou détectées avec forte confiance, pénalisée par les sessions incertaines ou reconstituées, les jours attendus sans session, les chevauchements, les horaires incohérents, un planning non importé et des modifications récentes non vérifiées. Bouton "Pourquoi ce score ?" avec la liste des points à régler et une correction en un tap.
Intégrations : affichée avant la génération ou l'envoi d'un relevé d'heures (section 42), d'un dossier justificatif (section 80) et d'une régularisation (section 108), avec un seuil réglable sous lequel l'app recommande de confirmer d'abord, sans jamais bloquer. Alimente la carte Maintenant (section 122) : "2 sessions à confirmer avant d'envoyer tes heures".

## 128. ANNULER PARTOUT ET INSTANTANÉS (module undo_safety, proposé et coché par défaut)

Filet de sécurité contre les erreurs de saisie et de correction.
- Annuler et rétablir : chaque modification de l'utilisateur (session, lieu, planning prévu, contrat, congés, notes, classification) est enregistrée comme opération réversible. Annulation par le geste système (secouer l'iPhone ou le menu Édition), par un bouton, ou depuis la liste "Modifications récentes" (20 dernières sur 7 jours) avec annulation sélective quand il n'y a pas de conflit. Message clair : "Annulé : fin de session de 22:30 remise à 22:00".
- Instantanés automatiques : copie locale de l'état de la base à la fin de chaque journée et avant les opérations risquées (import, restauration, suppression par période, changement de convention, migration), conservés N jours (défaut 14) avec limite d'espace et indicateur de taille. "Revenir à l'état de ce matin" : aperçu des différences puis restauration complète ou sélective. Toute restauration crée d'abord un instantané de l'état actuel, donc elle est elle-même réversible.
- Cohérence : une annulation est une nouvelle entrée du journal des modifications (et du journal infalsifiable, section 98, s'il est actif), jamais une réécriture. Instantanés protégés par les protections de données d'iOS, exclus d'iCloud sauf choix.
- Limite : annuler ne défait pas les effets externes (message déjà envoyé, notification déjà reçue).

## 129. DÉLAI DE PRÉVENANCE (module notice_check, exige planning_ocr et employment, désactivé par défaut)

Quand un planning ou un changement de planning (section 97) est reçu, l'app compare le préavis reçu avec la règle de délai de prévenance applicable. Date de réception : celle de l'import ou de la validation, ou une saisie "reçu le" modifiable.
La règle est recherchée et sourcée par l'agent (Légifrance, service-public.fr, pack de convention), stockée dans Resources/reference/contracts.json avec sa date de vérification, marquée "à vérifier" si elle est incertaine, jamais codée en dur, et appliquée seulement aux types de contrat concernés (par exemple le temps partiel) quand le contrat le permet.
Message neutre : "Ce changement t'a été annoncé 2 jours avant ; ta convention prévoit 3 jours (source : ...)." L'app rappelle que des exceptions existent (accord entre les parties, urgence, volontariat) et propose "J'ai accepté volontairement" pour éviter les fausses alertes. Options : brouillon de message poli, entrée dans le journal de contrat (section 72), marquage "remplacement demandé" (section 68), ouverture d'un échange (section 81). Aucun conseil juridique, jamais d'accusation, rien d'envoyé automatiquement.

## 130. AUTO-CALIBRATION DES LIEUX (module place_calibration, proposé et coché par défaut)

Analyse, pour chaque lieu, les écarts constatés lors des arrivées et départs confirmés : décalage systématique entre la position de détection et le centre du lieu, dispersion (bruit GPS), délai de détection. Après un échantillon minimal (défaut 6 arrivées), propose : "Tes arrivées au taf sont détectées en moyenne 80 m plus loin que le lieu, j'ajuste ?" avec aperçu sur la carte (déplacer le centre, changer le rayon, ou diviser en deux zones).
Détecte aussi les lieux qui se chevauchent et l'usage de la limite de 20 régions surveillées, et propose des priorités. Jamais appliqué sans confirmation. Seules des mesures agrégées (distance, direction, bruit) sont conservées, jamais de traces GPS. Indicateur de qualité par lieu (vert, orange). Liée à l'assistant de dépannage (section 132).

## 131. RÉCUPÉRATION APRÈS BATTERIE VIDE OU EXTINCTION (module battery_recovery, proposé et coché par défaut)

iOS ne prévient pas l'app d'une extinction. L'app garde donc de simples indices datés, enregistrés quand elle est réveillée par un événement (région, changement significatif, notification) : heure, niveau de batterie, Mode économie d'énergie, dernière activité détectée. Aucun timer, aucun polling.
Au prochain lancement, si une session était en cours, qu'un redémarrage est détecté entre les derniers indices et le premier événement suivant, et que le dernier niveau de batterie était très bas, l'app propose : "Ton tel s'est peut-être éteint vers 21:40 (batterie 4 %). Fin de session estimée à 21:40, tu confirmes ou tu corriges ?" La fin est une estimation bornée entre le dernier indice et le premier événement après redémarrage, marquée incertaine et reconstituée, jamais inventée au-delà des traces. Confirmation possible aussi dans la revue de la semaine (section 46). La détection du redémarrage passe par l'heure de démarrage du système : API à raison requise, à déclarer dans le manifeste de confidentialité (section 6).
Optionnel : notification unique "Batterie basse pendant ta session, tes heures peuvent être incertaines, tu peux arrêter ou démarrer à la main" quand elle est détectée à un réveil, et activité réduite en Mode économie d'énergie.

## 132. ASSISTANT DE DÉPANNAGE : "POURQUOI L'APP A RATÉ ÇA ?" (module detection_help, proposé et coché par défaut)

Depuis une session ou une journée avec une arrivée ou un départ manqué, tardif ou décalé, un bouton "Pourquoi ?" analyse le journal des événements de détection (section 52) et l'historique daté des capacités du système (autorisation de localisation et précision, Mode économie d'énergie, actualisation en arrière-plan, batterie basse, réseau, modes actifs : vacances, "Pas aujourd'hui", période bloquée). Il propose des causes probables classées, avec une explication en français et un correctif en un tap : "Passer sur Toujours", "Agrandir le rayon de 40 m", "Autoriser l'actualisation en arrière-plan", "Relancer le suivi".
L'app ne peut pas être certaine (par exemple d'un forçage à quitter) : elle parle de causes probables avec un niveau de confiance. Journal compact et local des changements de capacités (date, ancien état, nouvel état), purgé après N jours (défaut 30). S'articule avec l'auto-calibration (section 130) et la récupération après batterie vide (section 131).

## 133. GALERIE DE WIDGETS : FORMATS, STYLES ET PERSONNALISATION (extension du module live_activity_widgets)

133.1 Familles à supporter (WidgetKit, à vérifier dans le SDK utilisé) :
- iPhone, écran d'accueil et vue Aujourd'hui : systemSmall (2×2), systemMedium (4×2), systemLarge (4×4) et, avec iOS 27, systemExtraLargePortrait (4×6, portrait uniquement).
- Écran verrouillé : accessoryCircular, accessoryRectangular, accessoryInline.
- StandBy : les widgets de taille small s'y affichent, avec une version adaptée (gros chiffres, teinte nocturne).
- iPad et Mac : systemExtraLarge, seulement si l'app devient universelle plus tard. Apple Watch (accessoryCorner et autres) et visionOS : hors périmètre tant qu'aucune cible dédiée n'existe. CarPlay : les widgets introduits avec iOS 26 et étendus avec iOS 27 sont à étudier seulement s'ils sont accessibles sans autorisation spéciale, sinon hors périmètre.
Chaque widget déclare ses familles avec supportedFamilies et réutilise le même fournisseur de timeline avec une vue adaptée à chaque famille.
Contrainte de compilation : systemExtraLargePortrait n'existe que dans le SDK Xcode 27 (Swift 6.4) et sur iOS 27 ou plus. L'ajouter derrière une vérification de compilation ET de disponibilité (#if compiler(>=6.4) et #available(iOS 27.0, *)) pour que le projet compile encore avec un Xcode plus ancien. Dans le CI (section 57), prévoir un runner avec Xcode 27 pour compiler ce chemin et documenter le comportement quand il n'est pas disponible.

133.2 Widgets proposés. Pour ne pas multiplier les widgets, un nombre limité de widgets très configurables (AppIntentConfiguration), chacun avec plusieurs affichages. Le groupe de widgets (WidgetBundle) est fixé à la compilation et ne peut pas masquer un widget selon les modules actifs : un widget d'un module désactivé affiche un état d'invitation ("Active le module X dans l'app") au lieu de disparaître.
1. Maintenant (activité en cours, prochaine, ou "rien à faire", avec actions rapides) : small, medium, large, XL portrait, accessoryRectangular.
2. Ma journée (frise avec trait "maintenant", cours et travail) : medium, large, XL portrait.
3. Ma semaine (grille de 7 jours, couleur par activité, barre de quota) : large, XL portrait, version compacte en medium.
4. Heures et quota (anneau, barre ou chiffre : heures de la semaine ou du mois, quota, projection) : small, medium, accessoryCircular, accessoryRectangular, accessoryInline.
5. Compte à rebours (au choix : fin de service "encore X h", prochaine prise de poste, paie dans X jours, fin de contrat, fin de période d'essai, congés restants, examens, objectif d'épargne) : small, accessoryCircular, accessoryRectangular, accessoryInline, StandBy.
6. Argent (net estimé du mois, reste de fin de mois, épargne, gains en direct) : small, medium, accessoryCircular, masqué par défaut.
7. Carte de chaleur (section 102) : large, XL portrait, version compacte en medium.
8. Actions rapides (démarrer, arrêter, pause, "je suis en retard", appeler le responsable) : small, medium, boutons interactifs.
9. Aperçu (aperçu de fin de semaine, brief du matin, charge de la semaine, périodes bloquées à venir, disponibilités) : medium, large, XL portrait.
10. Fiabilité et suivi (score de fiabilité, état du suivi, éléments à confirmer) : small, accessoryCircular, accessoryRectangular.
11. Mot de pote (phrase courte, drôle ou encourageante, dans le ton de l'app, jamais sur un sujet sérieux) : small, medium, accessoryInline.
Chaque widget a, dans la galerie du système, une description tutoyée et un aperçu réaliste.

133.3 Personnalisation (intents) : employeur (si multi_employer), période (jour, semaine, mois, année), affichage (anneau, barre, chiffre, graphique), unité (net ou brut), contenu du compte à rebours, objectif d'épargne choisi, densité (compacte ou confortable), masquer les montants, masquer les lieux, style. Valeurs par défaut sobres, paramètres dynamiques (liste des employeurs, des objectifs) alimentés par les données de l'app.
133.4 Styles visuels : un style global choisi dans l'app, surchargeable par widget : Épuré clair, Sombre profond (OLED), Verre (matériaux du système), Cartes colorées (couleur d'activité), Monochrome accent, Gros chiffres, Graphique d'abord, Contraste élevé. Palette d'accent de 8 à 10 couleurs identique à l'app, option police arrondie, aucune couleur codée en dur hors palette.
133.5 Modes d'apparence du système : plein couleur, teinté et clair. Utiliser les marqueurs d'accentuation de WidgetKit (widgetAccentable), le mode de rendu du widget et le fond de conteneur système (containerBackground), sans images en couleur qui se dégradent en mode teinté. Tester chaque widget dans les trois modes, en clair et en sombre.
133.6 Confidentialité : sur l'écran verrouillé, montants, lieux et notes sont marqués sensibles (privacySensitive et contenu masqué) et cachés tant que l'appareil est verrouillé, par défaut. Réglage pour les afficher quand même.
133.7 Données et mises à jour : timelines précalculées (heures, comptes à rebours, gains en direct par entrées minute par minute), Text(timerInterval:) pour les décomptes, rechargement ciblé (WidgetCenter) au démarrage ou à la fin d'une session et à chaque changement de planning, sans épuiser le budget de rechargements. Données via l'App Group avec le repli de la section 44 : sans App Group, les widgets affichent un contenu générique et un lien pour ouvrir l'app, et "État de l'app" l'indique. Un tap ouvre l'écran concerné (liens profonds), les actions passent par des App Intents.
133.8 Tests et qualité : aperçus SwiftUI par famille et par style, tests d'instantanés des tailles, des trois modes d'apparence, du texte agrandi, de l'état d'invitation d'un module désactivé et de l'absence d'App Group. Mode développeur de WidgetKit pour lever les limites de rechargement pendant les tests. Chaque widget reste lisible d'un coup d'œil.


## 134. SIGNAUX DE SECOURS (module backup_signals, désactivé par défaut)

En plus du GPS, d'autres signaux locaux servent de preuves d'arrivée ou de départ : connexion ou déconnexion d'un Wi-Fi précis (celui du magasin), d'un accessoire Bluetooth (casque, voiture), CarPlay, mise en charge, tag NFC, mode Concentration, heure. Utile quand le GPS échoue (réserve en sous-sol, centre commercial).
Réalisation honnête : une app ne peut ni lister les Wi-Fi alentour ni créer d'automatisations elle-même. Elle expose via App Intents une action "Signal de secours" (paramètres : type et libellé) et guide l'utilisateur pas à pas pour créer dans Raccourcis les automatisations personnelles correspondantes (comme en section 43) : quand je me connecte à ce Wi-Fi, quand je le quitte, quand je connecte cet accessoire, etc. Les automatisations disponibles et la possibilité de les exécuter sans confirmation dépendent de la version d'iOS : l'agent le vérifie, et "État de l'app" indique ce qui est configuré.
Utilisation : chaque signal reçu est une preuve datée (source, horodatage d'exécution, marge d'erreur) liée à un lieu choisi par l'utilisateur. Le moteur de détection (sections 8 et 13.1) la combine avec le GPS : elle confirme ou précise un horodatage, ou, sans GPS, crée une arrivée ou un départ probable marqué "à confirmer". Une exécution de raccourci pouvant être retardée, la marge d'erreur reste affichée.
Confidentialité : aucun scan de réseaux, l'app ne lit jamais le nom du Wi-Fi (c'est le raccourci qui le gère), seul un libellé choisi par l'utilisateur est stocké.

## 135. SAUVEGARDE AUTOMATIQUE DANS UN DOSSIER FICHIERS (module folder_backup, proposé et coché par défaut)

L'utilisateur choisit une fois un dossier dans l'app Fichiers (iCloud Drive, "Sur mon iPhone", ou un disque accessible) via le sélecteur de dossier ; l'app garde un accès durable (signet sécurisé) et y écrit des sauvegardes. Ça fonctionne avec un compte Apple gratuit et survit à la suppression de l'app, ce que ne font pas les instantanés internes de la section 128.
- Contenu : un dossier daté avec les données en JSON et un manifeste d'empreintes SHA-256 (CryptoKit), sans dépendance externe. Chiffrement facultatif par mot de passe (à réaliser avec un mécanisme standard du SDK, l'agent vérifie lequel). Choix des éléments sensibles (contacts, mémos, pièces du journal de contrat), exclus par défaut.
- Quand : chaque semaine (tâche de fond opportuniste), à la demande, et avant les opérations risquées. Conservation des N dernières sauvegardes (défaut 8), vérification d'intégrité à l'écriture.
- Restauration depuis un dossier : aperçu des différences, instantané automatique de l'état actuel avant d'appliquer, restauration complète ou sélective.
- Suivi : "Dernière sauvegarde : il y a 3 jours" dans "État de l'app". Si le dossier devient inaccessible (signet périmé), alerte douce et re-sélection en un tap. Si aucun dossier n'est choisi, le module rappelle une fois, puis se tait.

## 136. PROTECTION À LA CAPTURE ET MODE DÉMO (module privacy_shield, proposé et coché par défaut)

- Enregistrement et recopie d'écran : quand iOS indique qu'une capture vidéo ou une recopie est en cours, l'app floute automatiquement montants, lieux, noms de collègues, notes et contenu des mémos, avec un bandeau "Capture en cours, contenu masqué". Disponibilité de l'API à vérifier selon la version d'iOS.
- Captures d'écran : iOS ne permet ni de les empêcher ni de les détecter à l'avance, l'app n'est prévenue qu'après coup. Elle peut alors proposer discrètement "Capture détectée, activer le flou automatique des montants ?". Ne jamais prétendre bloquer les captures.
- Sélecteur d'apps : contenu flouté (voir section 49).
- Mode démo : un bouton dans Réglages (et un App Intent) bascule vers un jeu de données fictives générées localement, dans une base séparée et isolée, avec bandeau permanent "MODE DÉMO", aucune écriture dans les vraies données, aucune vraie notification, sortie en un tap. Permet de montrer l'app sans exposer ses données. Distinct du mode test GPX (section 56). Pendant le mode démo, les widgets affichent aussi les données fictives ou un état neutre, jamais les vraies.

## 137. DEMANDE-MOI TOUT (module ask_assistant, désactivé par défaut)

L'utilisateur pose une question en français, au clavier ou à la voix ("combien j'ai fait de dimanches en octobre ?", "il me reste combien de congés ?", "quand je finis samedi ?") et un assistant local répond.
- Moteur : le framework Foundation Models (modèle sur l'appareil, iOS 26 ou plus), avec vérification de disponibilité à l'exécution (appareil compatible, fonction activée, langue prise en charge). Aucune donnée ne quitte l'appareil.
- Principe de fiabilité : le modèle ne calcule rien. Il appelle des fonctions de l'app (outils) qui interrogent les données de façon déterministe (heures sur une période et des filtres, nombre de sessions, nombre de jours par catégorie comme les samedis ou les dimanches depuis une date, dernière visite d'un lieu, plus longue journée, solde de congés, état du quota, prochains créneaux, montants estimés). Il rédige ensuite la réponse à partir des résultats. Garde-fou : tout nombre affiché dans la réponse doit provenir d'un résultat d'outil ; sinon la réponse est remplacée par le résultat structuré brut.
- Transparence : chaque réponse indique sa base ("calculé sur 12 sessions du 1er au 31 octobre, en heures pleines") avec un lien "Voir les sessions", et la base de calcul retenue (section 13.1).
- Limites : lecture seule (une action proposée passe par une confirmation), aucun conseil juridique ou financier, pas de mémoire de conversation au-delà de la session, réponse "je ne sais pas" quand les données manquent. Si le modèle est indisponible, repli sur les questions sans modèle de la section 41.1 puis sur la recherche globale, avec un message clair. La capacité est signalée dans "État de l'app".

## 138. SCANNER DE PLANNING PAPIER (sous-fonction du module planning_ocr, activée avec lui)

Pour un planning affiché au mur ou imprimé : scanner de documents du système (VisionKit) avec détection des bords et correction de perspective, plusieurs pages ou photos possibles.
- Contrôles de qualité avant l'analyse : flou (reprise suggérée), reflets ou zones surexposées (conseil "incline un peu le téléphone"), lumière faible (suggestion d'éclairage), résolution insuffisante.
- Grand tableau en plusieurs photos : l'assemblage se fait au niveau des résultats de lecture, pas des pixels. Les tableaux reconstruits de chaque photo sont fusionnés grâce aux en-têtes et aux noms de lignes ou colonnes communs, avec contrôle des recouvrements. Les doublons et les conflits sont signalés.
- Écriture manuscrite : lecture possible mais moins fiable, toujours soumise à l'écran de validation de la section 16, jamais devinée.
- L'image d'origine et l'image corrigée sont conservées selon le réglage de la section 118. Tout reste local.

## 139. PHASE DE RODAGE (module break_in, proposé et coché par défaut)

Pendant les premiers jours (défaut 14 jours, ou jusqu'à un nombre de confirmations atteint), l'app pose un peu plus de questions rapides pour apprendre plus vite : confirmer les premières arrivées et départs, classer les premières visites, vérifier le rayon des lieux. Les questions sont regroupées sur la carte Maintenant (section 122) et dans la revue de la semaine, au maximum 3 par jour, sans notifications en rafale (budget de la section 123).
Une barre de progression ("Rodage : 6 sur 10 confirmations") et un indicateur honnête de précision ("9 détections sur 10 confirmées sans correction") montrent où en est l'app. Quand les seuils sont atteints, l'app annonce "Rodage terminé, je te pose moins de questions" et réduit ses sollicitations. Si l'utilisateur corrige beaucoup, le rodage se prolonge. Bouton "Passer le rodage". S'articule avec l'auto-calibration des lieux (section 130) et le score de fiabilité (section 127).

## 140. CONTRÔLE DE L'HORLOGE (module clock_check, proposé et coché par défaut)

Les calculs reposent sur des horodatages exacts : si l'heure du téléphone est fausse ou modifiée, des sessions peuvent être décalées.
- Mesures locales : pour chaque indice daté, l'app enregistre l'heure murale ET une horloge monotone (temps de fonctionnement depuis le démarrage) avec un identifiant de session de démarrage. (a) Saut d'horloge : dans une même session de démarrage, la différence d'heure murale entre deux indices doit correspondre à la différence monotone, sinon l'heure a été modifiée ou resynchronisée (seuil réglable, défaut 30 secondes). (b) Dérive : comparaison de l'heure du téléphone avec l'horodatage des positions fournies par le système de localisation, une divergence durable signalant une horloge fausse (à vérifier sur appareil réel). (c) Changements de fuseau ou d'heure d'été détectés et notés.
- Actions : avertissement dans "État de l'app" et notification unique ("Ton horloge semble décalée de 4 min") avec explication du réglage automatique de la date et de l'heure (l'app ne peut pas régler l'heure elle-même). Sessions concernées marquées "à vérifier". Correction des horodatages exacts proposée seulement après confirmation, avec valeur d'origine conservée, trace dans le journal des modifications et dans le journal infalsifiable (section 98) s'il est actif.
- Honnêteté : l'app détecte des incohérences, elle ne peut pas prouver l'heure vraie sans source externe, et n'utilise aucun serveur de temps. L'API d'heure de démarrage du système est à raison requise, à déclarer dans le manifeste de confidentialité (section 6).

## 141. RÈGLES SELON L'ÂGE (module age_rules, désactivé par défaut)

Optionnel. L'utilisateur saisit sa date de naissance, stockée localement, exclue des exports, résumés et dossiers sauf choix explicite. Les règles de travail qui dépendent de l'âge s'appliquent alors automatiquement et changent à la date exacte de l'anniversaire (16 ans, 18 ans), avec une notification qui résume ce qui change et cite ses sources.
Règles concernées, toutes recherchées et sourcées par l'agent (Légifrance, service-public.fr, code.travail.gouv.fr), stockées dans Resources/reference/contracts.json par profil d'âge avec date de vérification, marquées "à vérifier" si incertaines, jamais codées en dur : durées maximales quotidienne et hebdomadaire, repos quotidien et hebdomadaire, pauses, travail de nuit, travail le dimanche et les jours fériés, abattement jeunes salariés sur le SMIC (section 20.1, proposé automatiquement quand la date de naissance est connue), autres limites propres aux jeunes travailleurs.
Elles alimentent les alertes de repos (section 89), la nuit courte (section 33), les pauses (section 32), le classement des heures (section 106.5), les contraintes dures des plannings proposés (section 110), les disponibilités (section 94) et le simulateur (section 24). Formulation neutre ("À ton âge, la règle prévoit ..., source : ..."). Information uniquement, aucun conseil juridique, renvoi vers le contrat et les sources officielles.


## 142. DEMANDE DE DERNIÈRE MINUTE (module last_minute_offer, exige planning_text, désactivé par défaut)

Quand l'employeur propose un créneau par message ("tu peux venir demain 14h-19h ?"), l'utilisateur partage le texte à l'app (feuille de partage, collage natif ou saisie) et voit en un écran l'effet de ce créneau.
- Lecture : même analyseur de texte que la section 121, avec écran de validation de ce qui a été compris (date, début, fin, lieu), jamais deviné.
- Impact calculé avec les modules actifs : conflit avec un cours ou un événement de l'agenda (sections 143 et 152), repos et jours consécutifs (section 89), nuit courte (section 33), quota et heures complémentaires (section 106), paie estimée (différence de net), charge (section 99), périodes bloquées (section 114), faisabilité du trajet (section 35), échange ou remplacement possible (sections 81 et 68), délai de prévenance (section 129, la demande reçue est datée).
- Trois réponses brouillon, modifiables : accepter, refuser poliment, faire une contre-proposition ("je peux à partir de 16 h", calculée avec le premier moment libre des disponibilités de la section 94). Jamais envoyées toutes seules.
- Si l'utilisateur accepte, l'app propose d'ajouter le créneau au planning prévu (copie prévue, après confirmation, jamais une session réelle) et, le cas échéant, de le marquer comme remplacement.
- L'app n'encourage ni ne décourage : elle affiche les faits côte à côte, comme l'arbitrage de la section 115.

## 143. EMPLOI DU TEMPS SCOLAIRE (module school_timetable, proposé et coché par défaut)

Import de l'emploi du temps des cours : photo (même lecture que la section 16), PDF, fichier de calendrier ICS ou saisie à la main. Semaines A/B (ou autre alternance) gérées avec la semaine de départ, en tenant compte des vacances (section 30). Les cours deviennent le "prévu" côté études, comparable au réel détecté ("prévu 8 h, arrivé 7 h 52").
Quand un cours est annulé ou change (l'utilisateur le marque en un tap, ou réimporte l'emploi du temps et le même moteur de différences que la section 97 montre le changement), l'app propose le créneau libéré : révision (section 34), repos, ou disponibilité à marquer (section 94) si l'utilisateur le souhaite. Jamais de suggestion de manquer un cours, jamais de transmission d'absence à l'établissement, aucune connexion à un système de l'école. Le compteur d'absences facultatif reste celui de la section 115.

## 144. TEMPS ANNEXES (module extra_time, exige employment, désactivé par défaut)

Briefing avant l'ouverture, habillage, formation obligatoire, rangement après la fermeture, attente imposée : ajout en un tap (bouton sur la session, modèles par employeur comme "briefing 10 min", ou question optionnelle à l'arrivée). Chaque temps annexe est un segment à part, avec ses propres horodatages exacts et sa durée, rattaché à une session sans jamais modifier les horodatages de celle-ci.
Par employeur et par type : "payé", "non payé" ou "à renseigner" (défaut), et "compte dans le quota : oui ou non". Les règles de rémunération de ces temps varient selon l'entreprise et la convention : l'agent les recherche et les source ("à vérifier"), sans conseil juridique. Ils apparaissent séparément dans le relevé d'heures (section 20.2), alimentent le vrai taux horaire (section 126, temps de préparation) et le vérificateur de fiche de paie (section 92).

## 145. COMPTEURS DE CONTRAINTES (module constraint_counters, exige employment, désactivé par défaut)

Compte, sur l'année civile ou la période de référence de la convention : dimanches travaillés, jours fériés travaillés, soirées, nuits, week-ends travaillés, maximum de jours consécutifs atteint. Les frontières (début de soirée, de nuit, dimanche, férié) sont évaluées sur la base retenue (section 13.1).
Comparaison avec les limites ou compensations du pack de convention quand elles existent (sourcées par l'agent dans Resources/reference/contracts.json, "à vérifier") : "Tu as travaillé 14 dimanches cette année, ta convention prévoit ... (source : ...)" ou "pas de limite renseignée". Alertes douces à l'approche d'une limite, compensations liées aux compteurs de la section 106.4. Aucune limite non sourcée n'est affirmée.

## 146. PÉRIODE DE PAIE PERSONNALISÉE (module pay_period, exige pay, désactivé par défaut)

Par employeur : jour de clôture de la paie (par exemple le 25, ou "dernier jour du mois"), jour de versement (section 27) et décalage éventuel ("les heures variables sont payées le mois suivant"). Les vues "mois" et les estimations de paie suivent alors "du 26 au 25" au lieu du mois civil, au choix.
Chaque session est rattachée à une période de paie, donc à une fiche de paie (les sessions à cheval sur minuit à la clôture sont gérées avec la base exacte). Rappel doux avant la clôture : "Clôture dans 3 jours, vérifie tes heures", avec le score de fiabilité (section 127) et le rappel d'envoi des heures (section 42) alignés sur cette date. Les congés (section 23) gardent leur propre période de référence.

## 147. VÉRIFICATEUR DE CONTRAT AVANT SIGNATURE (module contract_check, exige pay, désactivé par défaut)

Scan local du contrat (Vision). L'app présente une checklist "présent", "absent" ou "à vérifier" pour chaque point, avec la règle de référence et sa source : taux horaire face au minimum du pack et au SMIC à la date, période d'essai, heures et leur répartition, pauses, délai de prévenance (section 129), préavis, indemnité de fin de CDD, durée maximale, mention de la convention et de l'IDCC, congés, majorations.
Ton neutre : l'app ne dit jamais "illégal" ni "ne signe pas". Elle propose des questions à poser à l'employeur et un brouillon de message, jamais envoyé automatiquement. Rien n'est conservé sauf si l'utilisateur enregistre le rapport dans le journal de contrat (section 72). Aucun conseil juridique, renvoi vers les sources officielles. Distinct du scan d'onboarding de la section 48, qui ne fait que préremplir.

## 148. CARNET DE STAGE OU D'ALTERNANCE (module internship_log, désactivé par défaut)

Journal de bord quotidien structuré : date, durée (reprise des sessions), tâches (étiquettes), compétences mobilisées, outils, difficultés, apprentissages, photos facultatives stockées localement. Les entrées alimentent le carnet d'expériences (section 96) et les notes de journée (section 39).
Sorties : fiche d'activités hebdomadaire et récapitulatif d'heures en PDF avec une zone de signature vierge à faire valider par le tuteur, par exemple sur papier. Statut "à faire valider" puis "validé", que l'utilisateur coche lui-même après la validation : l'app ne vérifie rien et n'envoie rien au tuteur ni à l'établissement. Export du carnet complet pour le rapport de stage. Tout reste local. Pensé aussi pour les projets et stages de filières techniques.

## 149. REJOUER MA JOURNÉE (module day_replay, désactivé par défaut)

Relecture animée d'une journée, avec carte et frise, qui montre ce que l'app a détecté : chaque événement (arrivée, départ, signal de secours, réponse à une notification, saisie, correction) avec son heure, sa source et sa marge d'erreur, et les étapes de décision (exacte, normalisée, doute et choix, section 13).
Aucune trace GPS continue n'est conservée (section 130) : la carte affiche des repères (lieux, transitions) et non un tracé. Sources : journal des événements de détection (section 52), limité dans le temps (défaut 30 jours), historique des capacités (section 132) et indices d'horloge (section 140). Curseur de lecture, pause, avance pas à pas ; un tap sur un événement permet de corriger son heure en un geste. Sert à comprendre un doute ou à vérifier un total.

## 150. TERMES EXPLIQUÉS (module glossary, proposé et coché par défaut)

Chaque terme technique de l'app (IDCC, heures complémentaires, avenant, période d'essai, repos compensateur, solde de tout compte...) porte une petite icône d'aide qui ouvre une explication de deux phrases en français simple, avec lien vers la source et date de vérification. Écran "Lexique" consultable et recherchable (section 41). Définitions stockées localement (Resources/reference/glossary.json), rédigées par l'agent à partir de sources officielles, "à vérifier" si incertaines. L'icône reste discrète et masquable dans les réglages, sans soulignement envahissant.

## 151. DÉPLACEMENTS ENTRE SITES (module multi_site, exige employment, désactivé par défaut)

Pour un employeur qui a plusieurs sites, un trajet entre deux sites le même jour (départ d'un site puis arrivée à l'autre dans un délai raisonnable) est classé "déplacement professionnel" et non trajet personnel (section 11). Réglage "compté comme temps de travail : oui, non, à renseigner" (la règle applicable est recherchée et sourcée par l'agent, "à vérifier"). Journée continue possible entre les deux sites, sans couper la session en deux fausses journées.
Indemnité kilométrique facultative : montant au kilomètre saisi par l'utilisateur (aucune valeur imposée), distance par MapKit, création d'une ligne de frais remboursable si le module expenses est actif, jamais en doublon.

## 152. AGENDA PERSO COMME CONTRAINTE (module calendar_constraints, désactivé par défaut)

Lecture seule du calendrier iOS (EventKit, autorisation demandée à l'activation) pour que les disponibilités (section 94), les plannings proposés (section 110), les demandes de dernière minute (section 142) et la charge (section 99) évitent les rendez-vous de l'utilisateur. L'utilisateur choisit les calendriers inclus, le niveau par calendrier ou par mot-clé (contrainte dure ou souple) et si les événements sur la journée entière comptent. Les anniversaires sont ignorés par défaut.
Confidentialité : seules les plages horaires et l'identifiant du calendrier sont gardés, les titres ne sont jamais stockés ni exportés, ils ne s'affichent qu'en direct. L'app n'écrit rien dans le calendrier (aucun export vers le calendrier Apple n'est prévu). Peut proposer de bloquer un rendez-vous comme période bloquée (section 114), avec confirmation.


## 153. ASSISTANT DE JOURNÉE (module day_assistant, proposé et coché par défaut)

Comprend la journée de l'utilisateur et signale ce qui est inhabituel, sans jamais juger.
- Compréhension : à la fin de la journée et à la demande, l'assistant assemble les événements (sessions, trajets, courses, passages, signaux, corrections) en un récit court : "Cours 8 h à 17 h, trajet, taf 18 h à 22 h 05 (5 min de plus que prévu)."
- Inhabituel, mesuré et expliqué : chaque fait est comparé (a) au prévu du jour quand il existe (planning importé, emploi du temps) et (b) à l'historique du MÊME contexte (lieu, type de créneau, jour, employeur), jamais à une semaine type (section 91). Exemples : arrivée ou départ très éloigné du prévu, session beaucoup plus longue ou plus courte que d'habitude pour ce contexte, lieu jamais vu hors d'une zone connue, trajet nettement plus long que la normale, créneau prévu sans session (renvoi à la section 86), double session, journée sans cours alors que le prévu en annonçait, activité de travail détectée un jour de congé.
- Méthode : statistiques robustes (médiane et écart absolu médian) sur un échantillon minimal par contexte (défaut 8), seuils réglables (sensibilité faible, normale, forte), "pas assez de données" sinon, aucun modèle distant. Chaque signalement donne sa raison chiffrée et sa base ("d'habitude 4 h pour ce créneau, aujourd'hui 6 h 10").
- Présentation discrète : un seul récap par jour, intégré à la carte Maintenant (section 122), à "Ta semaine" (sections 40 et 46) et à rejouer ma journée (section 149). Pas de notification par défaut. Actions en un tap : "C'est normal" (alimente l'apprentissage du contexte), "Corriger", "Ignorer".
- Limites : n'accuse jamais, ne tire aucune conclusion sur l'utilisateur, tient compte des congés, vacances, jours fériés, périodes bloquées et du mode vacances. Pendant le rodage (section 139), la sensibilité est réduite.

## 154. CENTRE DE FIABILITÉ (module reliability_center, proposé et coché par défaut)

Écran unique Réglages > Fiabilité qui AGRÈGE, sans les dupliquer, des éléments déjà décrits ailleurs :
- Détection : taux de détections confirmées sans correction (global et par lieu), délai moyen de détection et marge d'erreur typique (sections 130 et 139), lieux à calibrer.
- Permissions et capacités manquantes ou limitées (section 51), avec les boutons d'action existants.
- Sessions à vérifier : incertaines, reconstituées, heures à choisir (sections 13 et 127), avec accès direct à la revue.
- Données : score de fiabilité de la période (section 127), horloge (section 140), batterie et extinctions récentes (section 131), dernière sauvegarde et espace disponible (sections 128 et 135).
- Outils : assistant de dépannage (section 132), diagnostic (section 52) et rejouer ma journée (section 149) si ces modules sont actifs.
Un indicateur global en haut ("Fiabilité : très bonne, à surveiller, à régler") calculé avec une règle transparente et consultable, un badge discret sur Réglages quand un point critique apparaît (il remplace celui de la section 51), et une liste "Ce que tu peux faire maintenant" limitée à 3 actions classées par la même logique que la carte Maintenant. Les écrans d'origine restent accessibles directement. Données lues uniquement, aucune nouvelle collecte.

---

# D. INTERFACE ET RÉGLAGES

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

## 48. ONBOARDING

Parcours de moins de 3 minutes, chaque étape passable ("Plus tard") et modifiable ensuite. Ton tutoyé et décontracté (section 50).
1. Prénom et petit mot d'accueil.
2. Profil : lycéen, étudiant, salarié, ou plusieurs (détermine les écrans proposés).
3. "Qu'est-ce qui t'intéresse ?" : choix des modules avec trois préréglages ("Essentiel" = noyau seul, "Complet", "Je choisis") et la liste cochable issue de MODULES.md. Tout reste modifiable dans Réglages > Fonctionnalités. Les étapes suivantes n'apparaissent que si leur module est choisi.
4. (employment) "Tu bosses où ?" : premier employeur, nom, couleur, type de contrat (CDI, CDD, saisonnier ou job d'été, alternance, intérim, extra, stage, autre), dates de début et de fin selon le type, période d'essai si applicable, heures du contrat, et horaires : "toujours les mêmes", "un cycle" ou "ça change toutes les semaines" (défaut, aucune hypothèse d'horaires habituels, section 91).
5. (pay) Rémunération : "Je suis au SMIC" ou saisie libre, brut ou net. Convention : recherche, ou "Je sais pas" avec lecture de la fiche de paie ou du contrat. Option "Scanner mon contrat" : Vision lit le contrat en local et préremplit type, dates, heures, taux et convention, que l'utilisateur confirme ligne par ligne, jamais en silence.
6. Lieux : lieu de travail avec "J'y travaille aussi", lieu de cours ou lycée, domicile.
7. (leave) Solde de congés de départ s'il le connaît.
8. (planning_ocr) Importer une photo de planning maintenant ou plus tard.
9. Permissions, une par une, au moment utile : localisation (puis Always avec explication), notifications, photos. Seulement pour les modules choisis.
10. Récap "Voilà ce que j'ai compris" avec un bouton de correction par ligne, puis accueil.
(multi_employer) Possibilité d'ajouter un deuxième employeur à la fin ("T'as un autre job ?").

## 49. RÉGLAGES ET PERSONNALISATION

Stockés localement, inclus dans l'export JSON, bouton "Réinitialiser les réglages" sans toucher aux données.
Fonctionnalités : liste des modules avec interrupteur, description, statut, dépendances (section 3).
Apparence : thème automatique, clair, sombre, "noir pur" OLED ; couleur d'accent (8 à 10 couleurs) ; couleurs par type d'activité modifiables ; icône d'app alternative (au moins 3) ; densité confortable ou compacte ; texte dynamique respecté partout.
Animations et sensations : animations normales, réduites, aucune (défaut : suivre le réglage système) ; retours haptiques et intensité ; sons ; effets de célébration.
Suivi : rayon par défaut, seuil de pause, base de calcul des heures (exacte, normalisée en heures pleines ou prévue, par usage, section 13.1), arrondi (heure pleine par défaut), délai avant de valider un départ, mode économie (normal, économe, auto selon le Mode économie d'énergie iOS et la batterie), "Pas aujourd'hui" (suspend la détection jusqu'à demain ou une heure choisie).
Notifications : par catégorie, heures silencieuses, fréquence maximale par jour.
Modules (visibles seulement si actifs) : chaque module expose ses réglages dans Réglages > Fonctionnalités, listés dans MODULES.md (annexe A).
Affichage : 24 h ou 12 h, premier jour de la semaine, format des durées (7h30 ou 7,5 h), onglet de démarrage, mode discret (masque les montants).
Sécurité : verrouillage Face ID/Touch ID (désactivé, au lancement, après X minutes), flou dans le sélecteur d'apps.
Données : export/import JSON, suppression par période, suppression totale avec double confirmation.
Chaque réglage a un libellé tutoyé et une courte explication.

## 50. VOIX ET TON DE L'APPLICATION

L'app tutoie toujours et parle comme un pote : détendue, directe, chaleureuse, jamais corporate. Français uniquement. Pas de jargon ("session de géolocalisation initiée" est interdit, "t'es arrivé au taf" est bon).
Exemples : "T'es arrivé au taf à 17:56, c'est bon ?" ; "Bien joué, 6h30 de taf aujourd'hui." ; "Tu fais juste tes courses là, non ?" ; "Rien pour l'instant, profites-en." ; "J'ai besoin de savoir où t'es pour noter tes heures tout seul. Rien ne sort de ton tel." ; "Oups, ça a pas marché. Réessaie ?"
Un peu d'humour léger dans l'accueil, les états vides, les félicitations et les bilans, mais zéro blague sur les sujets sérieux (erreurs d'heures, paie, permissions, sauvegardes, fin de contrat, impôts) : ton cool mais clair et précis. Pas d'emojis en excès. Toutes les chaînes sont centralisées dans un String Catalog, en forme tutoyée partout (notifications, widgets, Live Activity, App Intents, bilans compris).

## 51. DÉTECTION DES CAPACITÉS ET ÉCRAN "ÉTAT DE L'APP"

CapabilityService unique, source de vérité de ce qui est possible sur ce téléphone avec cette build. Chaque capacité a un statut (disponible, limité, indisponible), une raison en français et, si possible, une action corrective ("Ouvrir les Réglages", "Activer", "Réessayer"). Combiné avec le ModuleRegistry : un module est utilisable s'il est activé ET si ses capacités sont disponibles.
À détecter à l'exécution, sans jamais crasher : localisation (autorisation, précision complète ou approximative, services activés), notifications (autorisées, provisoires, refusées), Live Activities, widgets et App Group, iCloud (section 54), CoreMotion, NFC, Face ID/Touch ID, Photos et Calendrier, actualisation en arrière-plan, mode économie d'énergie (réaction en direct), réseau, stockage, retours haptiques, accessibilité système (réduction des animations, texte agrandi, VoiceOver), Siri et Raccourcis, Concentration (App Intents enregistrés, filtre actif), reconnaissance vocale (sur l'appareil, en français), extension de partage (compilée ou non), contrôles du Centre de contrôle (iOS 18 ou plus), modèle de langage sur l'appareil, accès au dossier de sauvegarde, état de capture ou de recopie d'écran, dérive de l'horloge, disponibilité du calcul de trajet, version d'iOS et type d'appareil.
Écran Réglages > "État de l'app" : lignes avec pastille verte, orange ou rouge, titre court, raison en clair, bouton d'action. Résumé en haut ("Tout est bon" ou "2 trucs à régler"), badge discret sur Réglages quand un point critique cloche. Avec le module reliability_center, ce résumé et ce badge sont fournis par le centre de fiabilité (section 154). Revérifier à chaque retour au premier plan et à chaque changement système observable. Les fonctions indisponibles sont grisées avec la raison, jamais cachées. Les capacités d'un module désactivé ne sont pas signalées comme des problèmes.

## 52. FIABILITÉ ET DIAGNOSTIC

Écran de diagnostic : état du suivi, autorisation, précision, régions surveillées, dernier événement reçu, mode économie d'énergie, actualisation en arrière-plan, bouton "Relancer le suivi". Si le suivi semble interrompu (forçage à quitter, permission retirée), l'app le dit clairement et propose de corriger. Journal des événements de détection consultable pour comprendre une arrivée ou un départ raté ou décalé.

---

# E. DONNÉES

## 53. DONNÉES ET PERSISTANCE

SwiftData. Modèles du noyau : UserProfile, ActivitySession, Place, Habit, ActivityCorrection, DetectionEvent, AuditEntry, ModuleState, SyncMetadata.
Modèles des modules : liste dans MODULES.md (annexe C), un modèle par besoin de module, créés seulement quand le module est livré.
Identifiants stables, relations cohérentes, dates normalisées, migrations, gestion des suppressions, intégrité, accès asynchrones, gestion des erreurs. Les données locales sont la source de vérité, l'app reste utilisable hors ligne. Les données d'un module désactivé sont conservées (section 3).

## 54. ICLOUD ET CLOUDKIT (module icloud, facultatif)

Derrière le flag ENABLE_CLOUDKIT. Détection automatique de la disponibilité, sans jamais crasher :
1. Vérifier à l'exécution que l'entitlement iCloud est présent dans la build AVANT d'instancier CKContainer (ne jamais appeler CKContainer.default() sans cette vérification).
2. Si présent, vérifier CKContainer.accountStatus (connecté, non connecté, restreint, indéterminé) et le réseau.
3. Ne pas prétendre détecter "compte gratuit ou payant" : détecter si la sauvegarde est possible ou non.
Réglages : ligne "Sauvegarde iCloud", possible (connecté, dernière sauvegarde, bouton "Sauvegarder maintenant") ou impossible avec la raison en français ("cette version de l'app n'a pas iCloud", "tu n'es pas connecté à iCloud", "iCloud est restreint", "pas de réseau"). Dans tous les cas impossibles, proposer l'export JSON de secours.
Synchronisation incrémentale, sans doublons, gestion des conflits, reprise après perte de réseau, jamais bloquante, jamais de téléchargement complet à chaque modification, regroupement des écritures, sauvegardes différées, nouvelles tentatives, vérification d'intégrité, versionnement. Jamais de suppression locale à cause d'un échec cloud.
Export/import JSON, sauvegarde complète, restauration, migration entre versions, suppression des données cloud. Documenter le format.

## 55. CONFIDENTIALITÉ ET SÉCURITÉ

Fonctionnement local par défaut. Ni serveur, ni API externe, ni compte, ni abonnement obligatoires. Aucune position transmise à un tiers, aucune publicité, aucune analytique sans consentement explicite. OCR local (planning, contrat, fiche de paie). Verrouillage optionnel Face ID/Touch ID (module biometric_lock). Export et suppression complète. Mise à jour des packs de convention : simple téléchargement, aucune donnée envoyée. Onboarding progressif : chaque permission est demandée au moment utile, et seulement pour les modules activés.

---

# F. LIVRAISON

## 56. MODE TEST GPX

Fichiers GPX et simulateur de scénarios (section 4, A à CK) pour tester sans se déplacer. Données fictives réservées à ce mode de test et au mode démo isolé de la section 136, jamais mélangées aux vraies données. Les tests d'intégration rejouent les scénarios de façon déterministe.

## 57. CI/CD ET GITHUB ACTIONS

Workflows : ci.yml, beta.yml, release.yml, pull-request.yml, manual-build.yml.
Pull requests : compilation, tests, rapports, aucun déploiement, aucun secret exposé. Branche dev : compilation, tests, artefacts, logs. Branche main : compilation, tests, artefacts, prerelease beta, notes de version. Tags SemVer : vérification, build Release, tests, signature si configurée, IPA, checksums SHA-256, release stable, changelog.
Signature : secrets APPLE_TEAM_ID, APPLE_CERTIFICATE_BASE64, APPLE_CERTIFICATE_PASSWORD, APPLE_PROVISIONING_PROFILE_BASE64, APPLE_BUNDLE_IDENTIFIER. Le workflow installe le certificat, crée un keychain temporaire, installe le profil, signe, exporte, vérifie l'IPA et nettoie. Sans secrets, il produit automatiquement une IPA non signée. Ne jamais prétendre qu'une IPA non signée est installable directement.
Deux voies documentées dans docs/CI-CD.md :
- Voie gratuite : IPA non signée en artefact, installable avec Sideloadly ou AltStore, certificat qui expire tous les 7 jours (réinstallation nécessaire), procédure pas à pas.
- Voie payante : signature automatique par secrets GitHub, release et TestFlight facultatif via l'API App Store Connect.
Sécurité : permissions minimales, secrets protégés, pas de secrets dans les PR non fiables, actions maîtrisées et épinglées, pas de releases en double, workflows idempotents.
Documentation : README.md, CONTRIBUTING.md, docs/CI-CD.md.

## 58. QUALITÉ DU CODE

Code propre, noms explicites, fonctions courtes, types cohérents, faible duplication, gestion des erreurs, responsabilités séparées. Commentaires rares et utiles. Pas de try? systématique, pas de code mort, pas de TODO sur les fonctionnalités principales, pas de boutons décoratifs, pas de données fictives dans la version finale (hors mode démo isolé, section 136), pas de dépendances sans raison.

## 59. TESTS

Suite XCTest réelle, données déterministes :
- Modularité : noyau seul avec tous les modules désactivés, activation et désactivation, dépendances, aucune permission demandée par un module désactivé, aucune notification d'un module désactivé, données conservées après désactivation.
- Géolocalisation : arrivée, départ, GPS imprécis, perte temporaire, visite courte, récurrente, pause, reconstitution après arrêt.
- Classification : travail, courses, études, visite, passage, inconnu, journée mixte, apprentissage des corrections, seuils 40 et 75.
- OCR : tableau simple, plusieurs personnes, initiales, heures ambiguës, dates manquantes, reconstruction, correction, lecture d'un IDCC et de lignes de fiche de paie, lecture d'un contrat.
- Horaires : arrondis, incertitudes, confirmation, valeurs originales conservées, apprentissage, trois bases de calcul (exacte, normalisée, prévue), horodatages à la seconde avec fuseau, changement d'heure, traversée de minuit, sources et marges d'erreur, frontières de majoration, zone de doute (minutes 15 à 45), propositions groupées, valeur provisoire marquée à choisir, apprentissage après 3 choix concordants.
- Tests des modules : chaque module livre ses tests, listés dans MODULES.md (annexe D). Un module n'est pas terminé sans eux.
- Onboarding complet avec chaque préréglage de modules.
- Données : création, modification, suppression, migration, export, restauration, synchronisation, conflits.
- Capacités : toutes les combinaisons importantes avec un CapabilityProvider simulé.
- Performance : plusieurs milliers de sessions, chargement, navigation, statistiques, recherche, mémoire, thread principal.
- Scénarios A à CK en tests d'intégration.

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

## 61. RÈGLES DE TRAVAIL DANS LE DÉPÔT

Travailler dans le dépôt GitHub existant s'il est accessible. Avant de modifier : examiner les fichiers, lire le code existant, identifier fonctionnalités, dépendances et conventions, vérifier la configuration Xcode. Ne pas réécrire inutilement, ne pas supprimer de code fonctionnel sans justification, ne pas simuler une fonctionnalité réelle, ne pas remplacer une implémentation par une maquette. Compiler régulièrement.

## 62. CRITÈRES D'ACCEPTATION

Terminé uniquement si : app native iOS qui compile ; noyau fonctionnel avec tous les modules désactivés ; modules activables et désactivables sans perte de données ; quatre onglets ; données persistées ; Always pris en charge ; arrivées et départs détectés ; suivi en arrière-plan exploitant iOS ; habitudes apprises ; travail et courses distingués ; études séparées du travail ; démarrage/arrêt manuel ; plannings importables avec OCR qui reconstruit les tableaux et retrouve l'utilisateur ; horaires interprétés avec arrondis configurables et incertitudes confirmables ; trois bases de calcul des heures (exacte, normalisée, prévue) avec base retenue réglable et heures pleines proposées en cas de doute ; onboarding complet avec choix des modules ; chaque module activé satisfait ses critères listés dans MODULES.md (annexe E) ; notifications locales ; Live Activities et widgets ; écran "État de l'app" fiable ; réglages complets ; hors ligne possible ; iCloud facultatif avec détection ; export et restauration ; interface fluide ; batterie préservée ; tests principaux verts ; CI/CD fonctionnel ; IPA générée (signée si secrets présents) ; aucune fonctionnalité principale fictive.

## 63. LIVRABLES

Projet Xcode complet, code source, architecture documentée, modèles SwiftData, ModuleRegistry, services (géolocalisation, classification, habitudes, OCR, paie, conventions, congés, simulateur, trajet, objectifs, bilans, recherche, capacités), packs de convention et fichiers de référence (legal.json, contracts.json, leave.json, tax.json) avec sources et dates de vérification, notifications, Live Activities et widgets, interface SwiftUI, statistiques, sauvegarde CloudKit, export et restauration, tests, GitHub Actions, documentation, instructions de compilation et de signature, IPA signée si certificats disponibles.
Créer aussi PROJECT_SPEC.md (spécifications fonctionnelles et techniques) et AGENTS.md (conventions, architecture, responsabilités des modules, instructions pour futurs agents), pour reprendre le projet dans une nouvelle conversation sans recopier ce prompt. MODULES.md accompagne ce fichier : il est copié dans le dépôt et tenu à jour avec chaque module.

## 64. RAPPORT FINAL

Indiquer précisément : ce qui a été développé, ce qui fonctionne réellement, les modules des subagents et leur intégration, les tests exécutés, les résultats de compilation, les performances mesurées, les packs de convention créés et leurs règles "à renseigner", les valeurs légales (SMIC, congés, contrats, seuils fiscaux) à revérifier, les fonctionnalités incomplètes, les limites d'iOS, les secrets Apple manquants, les étapes restantes pour installer l'app. Ne jamais déclarer une fonctionnalité terminée sans l'avoir vérifiée.

## 65. CE QUE L'APP NE DOIT PAS FAIRE

Pas de compte, de serveur, d'analytique ni de publicité. Pas de suivi GPS continu haute précision. Pas d'enregistrement silencieux d'une donnée incertaine. Pas de modification des heures d'origine. Pas de statistiques incluant des sessions incertaines sans le signaler. Pas de lieu créé sans confirmation. Pas de promesse de suivi garanti après un forçage à quitter.
Pas de fonctionnalité optionnelle imposée : aucun module hors noyau n'est requis, aucune saisie financière n'est obligatoire. Pas de permission demandée, de notification envoyée ni de calcul lancé par un module désactivé.
Pas de montant légal, de règle de convention, de règle de contrat, de congés ou de seuil fiscal codé en dur dans le Swift. Pas d'estimation de paie présentée comme définitive. Pas de conseil juridique ou fiscal. Pas de pause présentée comme obligatoire si l'utilisateur ne l'a pas choisi. Pas de message culpabilisant.
Ne jamais prétendre activer un mode Concentration automatiquement. Ne jamais envoyer un relevé ou un message ("Je rentre") sans action de l'utilisateur. Le simulateur ne modifie jamais les données réelles. Pas d'export vers le calendrier Apple. Pas de jugement ni de score noté dans les statistiques de régularité. Les documents du journal de contrat et les tickets de frais ne quittent jamais l'appareil sans choix explicite de l'utilisateur. Pas de changement de taux appliqué rétroactivement en silence. Aucune correction vocale appliquée sans confirmation, sauf réglage explicite de l'utilisateur. Aucun message, résumé ou dossier envoyé sans action de l'utilisateur. Le temps libre et l'équilibre de la semaine ne sont jamais présentés comme des données de santé ou de sommeil. Aucune connexion à un système de pointage de l'employeur. Aucune session ajoutée automatiquement par la détection d'heures manquantes sans réponse de l'utilisateur. Le mode journée difficile ne fait ni analyse psychologique ni diagnostic. Les prévisions de primes et de solde ne sont jamais présentées comme garanties ni comme conseil financier. Le carnet d'échanges n'a aucune valeur contractuelle. Le brief du matin ne promet pas un contenu mis à jour en temps réel. L'alerte de repos n'est pas un avis juridique. L'import par partage n'importe jamais rien sans écran de validation, et l'extension de partage ne fait ni traitement lourd ni requête réseau. Aucune hypothèse d'horaires réguliers imposée : sans planning connu ni motif confirmé par l'utilisateur, l'app n'invente aucun horaire, et un motif détecté n'est qu'une proposition. Le vérificateur de fiche de paie n'accuse jamais l'employeur : il signale des écarts possibles avec leur source. La préparation d'entretien ne contient que des faits tirés des données réelles et ne promet aucun résultat. Le carnet d'expériences n'invente ni n'exagère aucune compétence. Le journal infalsifiable ne prouve pas l'exactitude des heures, seulement leur non-modification, et n'a aucune valeur juridique garantie. Aucun brouillon de message n'est envoyé sans action de l'utilisateur. La régularisation des heures payées n'affirme jamais que l'employeur a tort et signale aussi les heures payées en trop. Les plannings proposés ne contournent jamais les contraintes dures (repos, cours, quota maximal, périodes bloquées) et ne sont jamais appliqués sans confirmation. Une période bloquée n'annule jamais un créneau de travail déjà prévu : l'app informe et propose des options. La comparaison avec le passé ne compare jamais l'utilisateur à d'autres personnes. L'arbitrage cours contre travail ne décide jamais à la place de l'utilisateur, ne conseille jamais de manquer un cours et ne marque aucune absence automatiquement. L'aperçu de fin de semaine ne présume pas que le week-end est un temps de repos. Les prévisions de périodes creuses restent des estimations avec fourchette. L'historique des plannings ne conserve les images d'origine que si l'utilisateur l'a choisi. Les noms des collègues ne sont conservés que si l'utilisateur l'a choisi, jamais partagés, jamais analysés. Le planning par texte n'importe jamais rien sans validation. La carte Maintenant n'affiche qu'une action à la fois et ne culpabilise jamais. Aucune notification n'est coupée sans l'accord de l'utilisateur. Le compteur de gains est masqué par défaut et reste une estimation, et la Live Activity ne promet pas de défilement en direct. Le vrai taux horaire ne juge jamais le choix de travailler. Le score de fiabilité mesure les données, jamais l'utilisateur. Annuler ne défait pas les effets externes (messages déjà envoyés). Le délai de prévenance n'accuse jamais l'employeur, rappelle que des exceptions existent et n'a aucune règle codée en dur. L'auto-calibration ne modifie jamais un lieu sans confirmation et ne conserve pas de traces GPS détaillées. La récupération après batterie vide n'invente jamais une présence : toute fin estimée est bornée par des traces réelles et marquée incertaine. L'assistant de dépannage présente des causes probables, jamais des certitudes. Les widgets masquent montants, lieux et notes sur l'écran verrouillé par défaut. La Live Activity n'est jamais la source de vérité d'une session et ne démarre jamais seule en arrière-plan. Aucune base de calcul n'écrase les autres : l'horodatage exact est toujours conservé. Un arrondi ne s'applique jamais en silence dans un cas de doute : l'app propose et l'utilisateur choisit. L'app ne prétend jamais bloquer les captures d'écran, créer elle-même une automatisation Raccourcis ni prouver l'heure vraie. L'assistant local ne calcule rien lui-même, n'affiche aucun chiffre qui ne provienne d'un résultat de fonction, et ne modifie aucune donnée sans confirmation. Le mode démo n'écrit jamais dans les vraies données. La date de naissance reste locale et exclue des exports par défaut. La demande de dernière minute ne répond jamais seule et n'encourage ni ne décourage. L'emploi du temps scolaire n'incite jamais à manquer un cours et ne transmet aucune absence. Les temps annexes ne modifient jamais les horodatages d'une session. Les compteurs de contraintes n'affirment aucune limite non sourcée. Le vérificateur de contrat ne dit jamais "illégal" ni "ne signe pas". Le carnet de stage n'envoie rien au tuteur : la validation reste un acte de l'utilisateur. Le replay ne conserve aucune trace GPS. L'agenda est lu en lecture seule et ses titres ne sont ni stockés ni exportés. L'assistant de journée ne signale que des écarts mesurés par rapport au prévu ou à l'historique du même contexte, avec leur raison, jamais un jugement ni une accusation. Le centre de fiabilité agrège les écrans existants sans les dupliquer et ne collecte rien de nouveau. Aucun bilan hebdomadaire n'est produit sans activité suffisante.

## 66. INSTRUCTION FINALE

Commence par examiner le dépôt GitHub existant. Puis : organise les subagents, lis MODULES.md, définis l'architecture et le ModuleRegistry, répartis les tâches, lance les développements en parallèle si possible, intègre, compile régulièrement, exécute les tests, corrige, optimise, livre. Ne te contente pas d'un plan ou d'une maquette : développe réellement le produit dans le dépôt, en suivant l'ordre de livraison de la section 60.
Priorités absolues : 1. fiabilité de la détection, 2. rapidité et fluidité, 3. excellente UX, 4. intelligence de classification, 5. précision des horaires et des corrections, 6. fonctionnement local sans serveur, 7. sauvegardes fiables, 8. architecture propre et évolutive, 9. noyau léger, modules optionnels.
