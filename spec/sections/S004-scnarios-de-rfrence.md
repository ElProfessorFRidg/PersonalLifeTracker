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
