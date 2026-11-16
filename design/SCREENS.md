# SCREENS : liste des écrans à livrer (remplie pendant la phase 0)

Un écran = nom | rôle | composants | états (vide, chargement, erreur, hors permission) | module | étape | étiquettes VoiceOver
Cette liste est le contrat visuel de la phase 2. Tout écart doit être noté dans notes/ERREURS.md ou validé par l'utilisateur.
Maquette : design/prototype/index.html (généré par `python3 scripts/build_prototype.py` depuis design/prototype/src/). 33 écrans.

## Accueil et réglages

| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| Accueil (`accueil`) | Voir d'un coup d'œil ce qui se passe et la seule chose à faire | Carte Maintenant, session en cours avec chrono, chiffres du jour, ruban horaire, liste des sessions du jour, bouton d'ajout | En cours, Journée finie, Premier jour (vide) | Noyau, now_card | 1, 10 | "Réglages", "Ajouter", description du ruban horaire |
| Réglages (`reglages`) | Régler l'app et voir les statuts détectés | Statuts (localisation, position exacte, notifications, arrière-plan, économie d'énergie), apparence Auto / Clair / Sombre / Noir pur, densité, animations, base de calcul, suppression en deux temps | Tout est bon, Localisation limitée | Noyau | 1 | Statuts lus avec leur valeur, interrupteurs étiquetés |

## Onboarding

| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| Bienvenue (`onb-bienvenue`) | Dire ce que fait l'app, 100 % local, sans compte | Icône d'accueil, titre, 3 lignes d'argument, bouton "C'est parti", feuille "Où vont tes données ?" | Un seul | Noyau | 1 sur 7 | "Étape 1 sur 7" (progression), "Ce que fait l'app" (liste), "C'est parti", "Et mes données ?" |
| Choix des modules (`onb-modules`) | Choisir les fonctionnalités optionnelles | Préréglages segmentés (Essentiel, Complet, Je choisis), ligne Noyau "Obligatoire", 16 interrupteurs en 4 groupes, compteur vivant, note de dépendance (Employeurs) | Réglage conseillé (11 cochées sur 16) | Noyau (obligatoire), modules du registre | 2 sur 7 | "Étape 2 sur 7", "Un préréglage", un interrupteur par module (libellé du module), "Continuer" |
| Permission localisation (`onb-loc`) | Expliquer la localisation "Toujours" avant iOS, puis traiter la réponse | Icône, "Ce que j'en fais", "Ce qu'iOS va te demander", "Et si tu refuses ?", fausse fenêtre iOS (2 fenêtres), bannière limite, bannière erreur, liste numérotée de réparation | Intro, iOS 1, iOS 2, Toujours, Limitée, Refusée | Noyau | 3 sur 7 | "Étape 3 sur 7", fenêtres `alertdialog` titrées, "Autoriser pendant l'utilisation", "Changer pour Toujours autoriser", "Ouvrir les réglages iOS", "Continuer sans localisation" |
| Permission notifications (`onb-notifs`) | Expliquer les notifications avant iOS | Exemple de notification, "Mes règles" (6 par jour, silence la nuit, par catégorie), fenêtre iOS, bannière refus | Intro, Fenêtre iOS, Accordée, Refusée | Noyau (smart_notifications si cochée) | 4 sur 7 | "Étape 4 sur 7", "Exemple de notification", "Autoriser", "Ne pas autoriser", "Plus tard" |
| Permission photos (`onb-photos`) | Expliquer l'accès aux photos pour le planning | Icône, "Ce que je regarde", fenêtre iOS (limiter, tout, refuser), bannière refus | Intro, Fenêtre iOS, Accordée, Refusée | planning_ocr (étape sautée si non coché) | 5 sur 7 | "Étape 5 sur 7", "Choisir des photos…", "Autoriser l'accès à toutes les photos", "Ne pas autoriser" |
| Premier lieu (`onb-lieu`) | Ajouter son taf ou sa fac, ou passer | Choix unique Taf/Fac, champs nom et adresse, zone de 100 m, carte de confirmation, bouton "Annuler et corriger" | Formulaire, Lieu ajouté | Noyau | 6 sur 7 | "Étape 6 sur 7", "C'est quoi comme endroit ?", "Son nom", "Où ça se trouve ?", "Ajouter ce lieu", "Je le ferai plus tard" |
| C'est prêt (`onb-fin`) | Récapitulatif "Voilà ce que j'ai compris" avec correction par ligne, puis accueil | 4 lignes récap (fonctionnalités, localisation, notifications, lieu) avec statut et "Corriger", bannière si localisation limitée | Tout est bon, Il manque des trucs | Noyau | 7 sur 7 | "Fonctionnalités, corriger", "Localisation, corriger", "Notifications, corriger", "Premier lieu, corriger", "Aller à l'accueil" |

## Lieux et sessions

| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| `lieux` | Liste des lieux avec type, rayon, fiabilité, dernière visite (onglet Lieux) | `list`/`row`, `rel`, `banner--error`, `empty`, carte d'explication taf/cours/courses | liste, vide, refuse (localisation refusée) | core (lieux, section 10) | Étape 3 (lieux) | « Ajouter un lieu », « Ouvrir les réglages iOS », fiabilité lue en texte (Fiable, À vérifier, À l'arrêt) |
| `lieu-ajout` | Ajouter un lieu : carte SVG, épingle, cercle de rayon réglable, nom, type taf/cours/courses, « J'y travaille aussi » | carte SVG (`role="img"`), `input type=range`, `field`, `radiogroup`, `switch`, toast avec Annuler | carte, erreur (nom manquant) | core (lieux, sections 10 et 11) | Étape 3 (lieux) | « Carte du quartier avec une épingle et un cercle de 100 mètres autour », « Rayon : N m » (aria-valuetext), « Type de lieu », « J'y travaille aussi », « Ma position » |
| `lieu` | Détail d'un lieu : carte, rayon, type, fiabilité, stats du mois, dernières sessions, suppression | carte SVG, `list`, `rel`, `stat-grid`, `row--destructive`, toast Annuler | taf, courses | core (lieux) | Étape 3 (lieux) | « Aperçu de la carte : [lieu], zone de N mètres », « Modifier le lieu », « Supprimer ce lieu » |
| `sessions` | Historique groupé par jour, filtres tout/taf/cours/courses, pastille « À confirmer » | `segmented`, chip bouton `aria-pressed`, `list`/`row`, `chip--doubt`, `skeleton`, `empty` | liste, vide, chargement | core (sessions, section 14) | Étape 4 (sessions) | « Filtrer par type », « À confirmer (2) » (pressed), « Ajouter une session », compteur `aria-live`, chargement en `role="status"` |
| `session` | Détail et correction : horodatages exacts, base heures pleines, trois bases, marge, source, changement de type, suppression | `card`, `rel`, `banner--warning`, `list`, 2 feuilles (heures, type), `radiogroup`, toast Annuler | terminee, incertaine | core (sessions, section 13.1) | Étape 4 (sessions) | « Durée retenue », « Durée provisoire », « Type de session », champs Arrivée et Départ (labels), « Choisir l'heure pleine » |
| `session-ajout` | Saisie manuelle : lieu, type, date, début, fin, durée calculée, erreur de cohérence | `radiogroup`, `segmented`, `input` date et time, `field is-invalid`, `banner--error` | formulaire, erreur (fin avant début) | core (saisie manuelle, section 15) | Étape 4 (sessions) | « Lieu », « Type », Date, Début, Fin (labels), `aria-invalid` sur la fin, bandeau `role="alert"` |
| `doute` | Zone de doute 13.1 : choisir l'heure pleine, deux options avec durée résultante, heure exacte gardée, « Appliquer toujours ce choix pour ce lieu », rappel de la règle :00-:14 / :15-:45 / :46-:59 | `card--now`, `radiogroup`, `switch`, `chip`, boutons Compter / Garder l'heure exacte / Plus tard, toast Annuler | depart (20:38), arrivee (17:32) | core (normalisation, section 13.1) | Étape 4 (sessions) | « Heure pleine de départ », « Heure pleine d'arrivée », « Appliquer toujours ce choix pour ce lieu » (switch), bouton « Compter 21:00 (3 h) » |

## Planning, emploi et paie

| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| `planning` (onglet Planning) | Semaine en cours jour par jour, prévu contre fait, navigation de semaine, rappel de planning tardif | `largetitle`, navigation de semaine (`iconbtn`), `stat-grid`, `list` de lignes jour (scoped `pl-day`), `chip`, `banner--warning`, `btn-row`, `empty`, 2 feuilles (légende, réglage de l'alerte) | `semaine`, `vide`, `tardif` | planning_ocr (alerte tardif : réglage optionnel), contract_hours (lien contrat) | 7 | « Importer un planning depuis une photo », « Semaine précédente », « Semaine suivante », libellé complet par jour (« Lundi 16 novembre, aujourd'hui. Cours de 8:00 à 12:00, fait en 3 h 57... ») |
| `planning-photo` | Import d'un planning papier : photo, créneaux lus avec fiabilité, correction en ligne, validation | Photo dessinée en SVG (`pp-paper`), `meter` + `skeleton`, `banner--info/error`, lignes créneau (scoped `pp-item`) avec `rel--high/mid/low`, éditeur en ligne, feuilles (choix de ligne, jeter la lecture) | `resultat`, `analyse`, `rate` | planning_ocr | 7 | « Photo d'un planning papier. La ligne de Léo est surlignée... », « Analyse de la photo » (progressbar), « Corriger le lundi 23 novembre », « Retirer le ... », « C'est bon pour le samedi 28 novembre », « Ligne du planning » |
| `planning-jour` | Détail d'un jour, ruban prévu contre réel, écarts | `navbar`, 2 `timeline` (prévu pointillé, réel), `timeline-legend`, `list` d'écarts, `chip--doubt`, `stat-grid`, feuille d'édition du prévu | `aujourdhui`, `passe` | planning_ocr | 7 | « Prévu : cours de 8:00 à 12:00, taf de 18:00 à 21:00. », « Réel : cours de 8:05 à 12:02, ... », « Ajouter un créneau prévu » |
| `emploi` | Employeur, contrat (type, heures, dates), compte à rebours de fin, checklist de fin de contrat | `card`, `meter` (avancement du contrat), `list`, `switch` du module, feuilles (checklist avec cases `role="checkbox"`, indemnité), `empty` | `actif`, `desactive` | employment (optionnel, désactivable) | 5 | « Fin de ton CDD » (groupe), « Avancement du contrat » (progressbar), switch « Emploi et contrat », cases « Certificat de travail »... |
| `contrat` | Contrat de 13 h : quota, fait, prévu, projection, rééquilibrage, compteurs, 8 dernières semaines, alerte de quota | Jauge scoped (`ct-meter` : fait, prévu, repère du quota), `stat-grid`, barres jour par jour (JS), histogramme des semaines, `banner--info`, feuilles (règle de report, classement, répartition, alerte) | `semaine`, `quota`, `depasse`, `manque` | contract_hours (exige employment) | 6 | « 13 h au contrat, 1 h 14 faites, 11 h 46 prévues, projection 13 h. », « Heures par jour, prévu contre fait : ... », « Heures réalisées par semaine, de la 39 à la 46 : ... », « Ce qui se passe » (radiogroup) |
| `paie` | Estimation du mois (heures, taux, primes, brut et net), historique, relevé | `banner--warning` « Ce sont des estimations », `segmented` mois, `stat-grid` (valeurs précédées de ≈), `list` détail, `chip` « Saisie par toi », bouton mode discret, feuilles (détail du calcul, saisie du taux), `empty` | `estimation`, `vide`, `desactive` | pay (exige employment, optionnel) | 5 | « Masquer les montants » / « Afficher les montants » (aria-pressed), « Mois », « Tu saisis » (Brut ou Net) |

## Statistiques, fonctionnalités, états

| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| `stats` (Statistiques) | Totaux taf et cours, graphique par jour, moyennes, évolution, base heures pleines ou exacte | Contrôle segmenté Période et Base, `stat-grid`, graphique en barres CSS à l'échelle (0 à 8 h, valeurs sous chaque jour), `list`, `rel`, bannière info | `semaine`, `mois`, `vide` | noyau (stats d'heures), `data_trust` pour la ligne fiabilité | 1 (noyau), 10 (fiabilité) | "Période", "Base de calcul", "Heures par jour, heures pleines. mar 10 : taf 3 h, cours 4 h ; ..." (résumé du graphique), "Réglages" |
| `fonctionnalites` (Fonctionnalités) | Registre des modules : noyau toujours actif, modules par thème avec interrupteurs, recherche, dépendances | Champ de recherche, `list` + `row` + `switch`, feuille de dépendance (activer ou couper en cascade), `status` verrou, bannière "Tout est désactivé", `empty` recherche vide, toast Annuler | `liste`, `recherche`, `minimal` | `ModuleRegistry` (noyau) | 1 | "Chercher une fonctionnalité", "<Nom du module>" (interrupteur), "<Nom du module>, détails" (ouvre le détail), "Toujours actif" |
| `module` (Détail d'une fonctionnalité) | Détail d'un module : ce qu'il fait, données, autorisations iOS, dépendances, effet de la désactivation | Carte + interrupteur, `list` de lignes, `status` par autorisation, bannière dépendance manquante, carte `card--outline` "Si tu la désactives" | `planning_ocr` (activé), `leave` (coupé), `focus` (coupé), `data_trust` (activé) | tous (affiche le module choisi) | 1 | "Activer cette fonction" (interrupteur), "Fonctionnalités" (retour) |
| `fiabilite` (Fiabilité des données) | Score de la semaine, fiabilité par jour, causes de baisse, actions pour remonter, agrégat du centre de fiabilité | Score en grand + `meter`, `rel` (3 barres + libellé + %), `list` des jours, causes avec points perdus, 3 actions max, bannières, feuille "Pourquoi ce score ?" | `bonne` (92 %), `moyenne` (74 %), `faible` (48 %) | `data_trust`, `reliability_center` | 10 | "Score de fiabilité, 92 pour cent", "Pourquoi ce score ?", "Réglages" |
| `etats` (États de l'app) | Galerie des états système d'une app 100 % locale, chacun avec son lieu d'apparition | `empty` (4 cas), `banner` error, warning, info (localisation refusée ou approximative, notifications refusées, stockage plein, import raté, horloge modifiée, dossier de sauvegarde introuvable, batterie vide), `skeleton` (3 cas), toasts avec Annuler | `tout`, `vides`, `erreurs`, `chargement`, `toasts` | noyau, `clock_check`, `folder_backup`, `battery_recovery` | 1 à 3 | "Chargement des statistiques", "Chargement des sessions", "Réglages" |
| `diagnostic` (Dépannage de la détection) | Assistant "Pourquoi l'app a raté ça" : vérifications pas à pas avec statut et correctif en un tap | Carte de contexte, bannière verdict (cause probable + confiance), 7 lignes `status` ok, warn, error avec bouton de correction, journal du jour, bouton "Relancer le suivi", skeletons | `causes`, `riendutout`, `analyse` | `detection_help` | 3 | "Relancer le suivi", "Corriger la session", "Fiabilité" (retour) |

## Système iOS

| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| `ecran-verrouille` (80) | Maquette de l'écran verrouillé iOS : Live Activity de la session, widgets d'écran verrouillé, contrôles du bas | Heure, widget en ligne, widget rectangulaire, 2 circulaires (anneau), carte Live Activity (chrono `data-timer`, jauge, arrivée, fin prévue, Pause / Terminer ou Reprendre / Terminer), encart « pas de Live Activity », 2 boutons ronds (contrôle + photo) | `encours`, `pause`, `rien` | live_activity_widgets (+ section 125 pour les contrôles) | Phase 0 maquette, ensuite extension de widgets | « Widget en ligne : taf, encore 1 h 50 », « Widget rectangulaire : taf, encore 1 h 50, fin à 21:00 », « Widget circulaire : 40 pour cent de la session faite, reste 1:50 », « Live Activity : taf en cours », « Durée de la session en cours », « Contrôle : arrêter la session » |
| `ile-dynamique` (82) | Maquette de la Dynamic Island : les trois présentations de la même Live Activity | Pilule compacte (icône + durée), minimale (rond), étendue (lieu, chrono, jauge, début, fin prévue, boutons) | `encours`, `pause`, `confirmer` (départ incertain, « À confirmer ») | live_activity_widgets | Phase 0 maquette, ensuite extension de widgets | « Dynamic Island compacte : taf en cours depuis 1 h 14 », « Dynamic Island minimale : taf en cours », « Dynamic Island étendue : taf en cours », « Durée de la session en cours » |
| `widgets` (84) | Maquette de l'écran d'accueil iOS : widgets petit 2x2, moyen 4x2, grand 4x4 à l'échelle | Widget Maintenant (petit), Ma journée (moyen, ruban horaire), grand (Maintenant, semaine 7 jours, ruban, prochain), cases d'icônes factices, squelettes | `encours`, `calme`, `vide` (sans données, « Ouvre l'app ») | live_activity_widgets (section 133) | Phase 0 maquette, ensuite extension de widgets | « Widget petit, Maintenant », « Widget moyen, Ma journée », « Widget grand, Maintenant, ma journée et ma semaine », « Journée : cours de 8:05 à 12:02... », « Semaine : lundi cours et taf, mardi... » |
| `controles` (86) | Maquette du Centre de contrôle (iOS 18), des contrôles d'écran verrouillé et du Bouton Action, plus comportement de la pile intelligente | Tuiles Démarrer ma session / Arrêter / Pause / En retard, case « Ajouter un contrôle », bandeau iOS 17 et 3 chemins de repli, widget de pile avec points, liste « quand elle remonte » | `rien`, `encours`, `ios17` | live_activity_widgets (section 125), work_contacts pour « En retard » | Phase 0 maquette, ensuite extension de widgets | « Démarrer ma session », « Arrêter », « Pause », « En retard », « Pile intelligente : widget Maintenant », « Contrôle démarrer ma session » |
| `notifications` (88) | Préférences de notifications dans l'app, et bannières d'exemple avec leurs boutons d'action | Interrupteurs par type (8), heures silencieuses, maximum par jour (contrôle segmenté), apprentissage + carte de proposition, bandeau d'erreur iOS refusé, 9 bannières (arrivée détectée, arrivée probable, départ, zone de doute, Pars maintenant, relancer l'affichage, planning tardif, nuit courte, plus qu'une heure) | `reglages` (préférences), `exemples`, `refus` | smart_notifications, notifications locales du noyau, planning_ocr, short_night, travel_departure, end_of_day_countdown | Phase 0 maquette, ensuite notifications locales | « Arrivée et départ à confirmer », « Maximum par jour », « Exemple : arrivée détectée », « Exemple : zone de doute », « Exemple : planning tardif », « Ouvrir les réglages iOS » |

## Non maquetté (dit honnêtement)

### Onboarding


- Prénom et petit mot d'accueil (étape 1 de la spec), profil lycéen, étudiant, salarié (étape 2) : non demandés pour cette passe, "Léo" est écrit en dur dans l'écran final.
- Étapes conditionnelles par module : employeur et contrat (4), rémunération et convention, scan du contrat (5), solde de congés (7), import d'une photo de planning (8), deuxième employeur (multi_employer).
- Lieux de cours et domicile à l'onboarding (étape 6) : seul le premier lieu (taf ou fac) est maquetté.
- Permission "mouvement" : la spec 48 n'en cite pas (localisation, notifications, photos), donc absente.
- Rien de persistant : les choix passent par `PLT.store` (`onb.modules`, `onb.loc`, `onb.notif`, `onb.lieu`) pour la maquette seulement.
- Le contenu du noyau (section 3.1) est résumé en une ligne, non relu dans la spec complète.
- La carte et la recherche d'adresse du premier lieu : deux champs texte simples.
- Les fenêtres iOS sont des imitations (texte et boutons d'esprit iOS), pas les libellés exacts d'iOS.

### Lieux et sessions


- Recherche d'adresse (MapKit) et choix « position actuelle » réels : la carte est un dessin SVG, le rayon seul est interactif.
- Catégories Domicile, Commerce, Autre, horaires habituels, employeur rattaché, mode de transport (section 10).
- Fusion et séparation de sessions, notes, journal des modifications, démarrage manuel (en dehors de l'accueil).
- Options de doute 3 à 5 (demi-heure, heure du planning) : seules heure pleine avant, heure pleine après et heure exacte sont montrées.
- Détail « Pourquoi cette classification ? » (score 0 à 100, section 11) et renommer, fusionner un lieu.
- Pagination et défilement infini de l'historique, recherche globale.
- Dates et heures : champs natifs du navigateur, pas les sélecteurs iOS.

### Planning, emploi et paie


- Vue jour et vue mois de l'onglet Planning (spec section 16), seule la vue semaine existe. Les flèches de semaine ne bascule qu'entre la semaine 47 et la 48.
- Détection de conflits (créneau de taf qui chevauche un cours ou un trajet) et choix d'activité et de lieu par créneau dans la correction en ligne.
- Scanner de documents VisionKit et contrôles de qualité de la photo (section 138), assemblage de plusieurs photos, écriture manuscrite.
- Ajout d'un employeur, multi-employeurs, période d'essai, renouvellement et passage en CDI (juste un toast), journal de contrat.
- Écran « Ta convention » (recherche, packs, IDCC), saisie détaillée des primes, majorations par règle, scan de la fiche de paie, vérificateur de fiche.
- Historique des taux horaires, abattement jeunes salariés, ratio net sur brut modifiable (affiché, pas éditable).
- Détail d'un mois passé dans l'historique de paie (toast), export PDF et CSV du relevé (toast).
- Réglage fin de l'alerte de quota (seuils par employeur) et affichage dans la Live Activity.
- Les montants, taux (12,02 €) et dates de vérification sont des données d'exemple de la maquette, jamais des valeurs légales à reprendre dans l'app.

### Statistiques, fonctionnalités, états


- Les ~130 modules du registre : seulement 42 listés (représentatifs, un par thème utile). Les autres suivent le même gabarit de ligne.
- Détails complets (données, autorisations, effet de la coupure) écrits à la main pour 4 modules seulement (`planning_ocr`, `leave`, `focus`, `data_trust`). Les autres utilisent un texte générique.
- Statistiques : pas d'onglet Année, pas de sections paie, congés, objectifs, bilans, pas de répartition domicile ou déplacements ni de graphique Swift Charts réel (barres CSS).
- Bascule exact ou heures pleines : seule la base exacte et la base normalisée sont montrées, pas la base prévue ni la comparaison des trois bases au tap.
- Fiabilité : pas de réglage du seuil sous lequel l'app recommande de confirmer, pas de fiabilité par lieu ni de délai moyen de détection.
- Diagnostic : pas de journal complet des événements de détection, pas de purge du journal, pas de "Rejouer ma journée".
- États : pas de synchronisation iCloud (module facultatif), pas de première utilisation (couverte par l'onboarding), pas de feuille de confirmation destructive.

### Système iOS


- Widgets d'écran verrouillé et d'accueil autres que Maintenant, Ma journée, Ma semaine : Heures et quota, Compte à rebours, Argent, Carte de chaleur, Actions rapides, Aperçu, Fiabilité, Mot de pote (section 133.2).
- Format extra-large portrait 4x6 (iOS 27), StandBy, iPad, Mac, Apple Watch, CarPlay.
- Modes d'apparence des widgets (plein couleur, teinté, clair), styles visuels (Verre, Gros chiffres, etc.), masquage des montants et des lieux : seul le thème de l'app change, pas ces modes.
- État d'invitation d'un module désactivé (« Active le module X dans l'app ») et état sans App Group distinct de « sans données ».
- Widget « encore X h » avec option « temps restant, heure de fin ou les deux », plusieurs employeurs (nom et couleur).
- Live Activity : plusieurs activités simultanées dans l'îlot, fin automatique, restauration après 8 h. Le décompte « encore 1 h 50 » est un texte fixe, seul le temps écoulé est vivant.
- Notifications groupées (regroupement de rappels proches), notification de relance « Rappel d'envoi des heures » et autres rappels de modules, choix de l'heure exacte (sélecteur d'heure) après « Autre heure » ou « Corriger ».
- Mode examens, vacances et « Pas aujourd'hui » : effet sur les notifications non montré.
- Les heures de la semaine à venir dans le widget grand sont des exemples inventés, pas des données du jeu commun.

