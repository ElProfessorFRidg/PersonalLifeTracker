# PROGRESS : avancement réel (généré par scripts/gen_progress.py, édité à la main avec preuves)

Règles : un statut sans preuve est faux. `python3 scripts/check_progress.py` le vérifie. Statuts : NON COMMENCÉ, EN COURS, CODÉ NON TESTÉ, TESTS AUTO OK, VÉRIFIÉ SIMULATEUR, VÉRIFIÉ SUR APPAREIL, BLOQUÉ.
La colonne Preuve contient un chemin evidence/... ou une URL de run CI. VÉRIFIÉ SUR APPAREIL exige un fichier evidence contenant la ligne `Confirmé par l'utilisateur :`.

## Mise à jour CI/CD du 2026-11-16

Workflows modifiés : pull-request.yml produit aussi l'artefact IPA ; manual-build.yml publie cet IPA dans une pré-release unique build-<run_id>, après réussite des tests. Les tags stables et bêta gardent leur publication existante avec source AltStore. Validation des entrées de build et vérification ZIP sans arrêt anticipé du pipeline. NON TESTÉ sur macOS pour cette modification : environnement Linux ; aucune nouvelle release publiée pendant cette intervention.

## Noms CI/CD du 2026-11-16

Les sept workflows utilisent des noms anglais classiques : CI, PR Checks, Build and Test, Manual Build, Beta Release, Release, Publish AltStore Source. Les libellés des jobs, étapes et champs de saisie sont en anglais. Les identifiants des jobs et les noms techniques des artefacts restent identiques pour conserver les références existantes. Modification limitée aux libellés ; exécution macOS NON TESTÉE pour ce renommage.

## Phases

| ID | Titre | Étape | Statut | Preuve | Note |
|---|---|---|---|---|---|
| phase:P0_ui | Phase 0 : artefact UI + thème validé par l'utilisateur | 0 | TESTS AUTO OK | evidence/P0_ui.md | Validée par l'utilisateur le 2026-11-16. Vue seulement dans Chromium par l'orchestrateur. Devise à ajouter aux Réglages en Phase 2. |
| phase:P1_ci | Phase 1 : CI (build + tests) verte | 1 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43814312689 | Vert sur la PR 1 (détail : evidence/phase1-ci.md). ci.yml sur main jamais exécuté. |
| phase:P1_beta | Phase 1 : pré-release avec IPA | 1 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43836366614 | v0.0.1-beta.1 publiée avec IPA (evidence/phase1-beta.md). Workflows beta.yml et release.yml MODIFIÉS le 2026-11-16 : déclenchement aussi par push de release/BETA_VERSION ou release/STABLE_VERSION. |
| phase:P1_release | Phase 1 : release avec IPA | 1 | NON COMMENCÉ |  | Débloquée (même mécanisme que la bêta) mais jamais exécutée. À lancer quand le noyau compile. |
| phase:P1_altstore | Phase 1 : source AltStore + installation réelle | 1 | EN COURS |  | source-beta.json en ligne et joignable (evidence/phase1-beta.md). Installation réelle sur iPhone : À VÉRIFIER PAR L'UTILISATEUR. Pas d'icône. |

## Noyau

| ID | Titre | Étape | Statut | Preuve | Note |
|---|---|---|---|---|---|
| core:core_models | Noyau : modèles SwiftData, ModuleRegistry, écran Fonctionnalités | 1 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43877060132 | Modèles, registre (108 modules, tous encore « bientôt »), écran Fonctionnalités, Réglages (thème, devise, base de calcul, export JSON). Build + tests + archive verts en CI. Jamais lancé sur simulateur ni iPhone par quiconque : aucun écran vu. |
| core:core_places | Noyau : lieux, sessions, saisie manuelle, onglets Accueil et Lieux | 1 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43877060132 | Lieux (carte, rayon), sessions, saisie manuelle, démarrage et arrêt manuel, Accueil, onboarding de base. Logique testée en CI. Écrans jamais vus à l'écran ; permissions et carte NON TESTÉES sur appareil. |
| core:core_geofence | Géorepérage, arrivée/départ, notifications, diagnostic, annuler partout | 2 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43889057891 | Moteur de détection (logique pure) et règles de notification testés en CI. Géorepérage réel, relance en arrière-plan, notifications et leurs actions : NON TESTÉS, seulement vérifiables sur iPhone. Seuils choisis par l'agent (5 min, 3 min, 6 notifs par jour, silence 22:00 à 04:59), voir notes/core_geofence.md. État du moteur non persisté. |
| core:core_classify | Classification travail/études/courses, apprentissage, récupération | 3 | NON COMMENCÉ |  |  |
| core:core_time_rounding | Heures : timestamp exact + base normalisée + zone de doute (13.1) | 1 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43877060132 | Arrondi, zone de doute, durées, choix utilisateur stocké à part de l'heure exacte : testés en CI. Écran de choix jamais vu à l'écran. Mutation à la main (14 en 15) non faite. |

## Modules (registre MODULES.md)

| ID | Titre | Étape | Statut | Preuve | Note |
|---|---|---|---|---|---|
| module:planning_ocr | Planning par photo, alerte de planning tardif | 7 | NON COMMENCÉ |  |  |
| module:place_discovery | Découverte automatique des lieux | 10 | NON COMMENCÉ |  |  |
| module:employment | Employeurs, contrats, fin de contrat | 5 | NON COMMENCÉ |  |  |
| module:pay | Salaire, paie, conventions, primes, historique des taux | 5 (base), 6 (conventions, primes) | NON COMMENCÉ |  |  |
| module:school_calendar | Calendrier scolaire, vacances, jours fériés | 9 | NON COMMENCÉ |  |  |
| module:notes | Notes de journée | 9 | NON COMMENCÉ |  |  |
| module:search | Recherche globale | 10 | NON COMMENCÉ |  |  |
| module:weekly_review | Revue de la semaine | 10 | NON COMMENCÉ |  |  |
| module:recaps | Bilans mensuels et annuels | 10 | NON COMMENCÉ |  |  |
| module:live_activity_widgets | Live Activity, widgets, App Intents, contrôles, galerie de widgets | 8 (base, contrôles), 10 (galerie) | NON COMMENCÉ |  |  |
| module:missing_hours | Détection d'heures manquantes | 10 | NON COMMENCÉ |  |  |
| module:contract_hours | Équilibrage des heures du contrat, compteurs, repos compensateur, alerte de quota | 6 | NON COMMENCÉ |  |  |
| module:pattern_detection | Détection de motifs de planning | 10 | NON COMMENCÉ |  |  |
| module:schedule_archive | Historique des plannings | 10 | NON COMMENCÉ |  |  |
| module:now_card | Carte Maintenant (ActionEngine) | 10 | NON COMMENCÉ |  |  |
| module:smart_notifications | Notifications qui apprennent (coordinateur) | 10 | NON COMMENCÉ |  |  |
| module:data_trust | Score de fiabilité des données | 10 | NON COMMENCÉ |  |  |
| module:undo_safety | Annuler partout et instantanés | 2 | TESTS AUTO OK | https://github.com/ElProfessorFRidg/PersonalLifeTracker/actions/runs/43889057891 | Toast Annuler, instantanés quotidiens, restauration : logique testée en CI. Écrans jamais vus. Pas fait : secousse, annulation des modifications d'heure, restauration sélective. |
| module:place_calibration | Auto-calibration des lieux | 3 | NON COMMENCÉ |  |  |
| module:battery_recovery | Récupération après batterie vide | 3 | NON COMMENCÉ |  |  |
| module:detection_help | Assistant de dépannage de la détection | 3 | NON COMMENCÉ |  |  |
| module:multi_employer | Plusieurs employeurs | 10 | NON COMMENCÉ |  |  |
| module:leave | Congés payés | 6 | NON COMMENCÉ |  |  |
| module:simulator | Simulateur et semaine en direct | 10 (simulateur), 11 (semaine en direct) | NON COMMENCÉ |  |  |
| module:pay_date | Date de paie attendue | 10 | NON COMMENCÉ |  |  |
| module:tax_threshold | Seuil fiscal | 11 | NON COMMENCÉ |  |  |
| module:exam_mode | Mode examens | 9 | NON COMMENCÉ |  |  |
| module:breaks | Pauses | 9 | NON COMMENCÉ |  |  |
| module:short_night | Alerte nuit courte | 9 | NON COMMENCÉ |  |  |
| module:study_slots | Créneaux libres de révision | 9 | NON COMMENCÉ |  |  |
| module:travel_departure | Trajet et Pars maintenant | 9 | NON COMMENCÉ |  |  |
| module:travel_cost | Coût du trajet | 11 | NON COMMENCÉ |  |  |
| module:going_home | Je rentre | 11 | NON COMMENCÉ |  |  |
| module:savings | Objectifs d'épargne | 10 | NON COMMENCÉ |  |  |
| module:send_hours_reminder | Rappel d'envoi des heures | 10 | NON COMMENCÉ |  |  |
| module:focus | Concentration | 11 | NON COMMENCÉ |  |  |
| module:nfc | Tag NFC | 11 | NON COMMENCÉ |  |  |
| module:biometric_lock | Verrouillage Face ID | 11 | NON COMMENCÉ |  |  |
| module:icloud | Sauvegarde iCloud | 11 | NON COMMENCÉ |  |  |
| module:expenses | Suivi des frais | 11 | NON COMMENCÉ |  |  |
| module:replacements | Remplacements | 10 | NON COMMENCÉ |  |  |
| module:regularity | Statistiques de régularité | 10 | NON COMMENCÉ |  |  |
| module:contract_journal | Journal de contrat | 11 | NON COMMENCÉ |  |  |
| module:vacation_mode | Mode vacances de l'app | 10 | NON COMMENCÉ |  |  |
| module:work_contacts | Contacts du taf | 11 | NON COMMENCÉ |  |  |
| module:badge_reminder | Rappel de badgeuse | 11 | NON COMMENCÉ |  |  |
| module:departure_checklist | Check avant de partir | 11 | NON COMMENCÉ |  |  |
| module:voice_corrections | Corrections à la voix | 11 | NON COMMENCÉ |  |  |
| module:weekly_balance | Équilibre de la semaine | 11 | NON COMMENCÉ |  |  |
| module:share_summary | Résumé partageable | 11 | NON COMMENCÉ |  |  |
| module:proof_pack | Dossier justificatif | 11 | NON COMMENCÉ |  |  |
| module:shift_swaps | Carnet d'échanges de créneaux | 11 | NON COMMENCÉ |  |  |
| module:end_of_day_countdown | Compte à rebours de fin de journée | 11 | NON COMMENCÉ |  |  |
| module:rough_day | Journée difficile | 11 | NON COMMENCÉ |  |  |
| module:premium_planner | Primes de dimanche et de férié à venir | 11 | NON COMMENCÉ |  |  |
| module:month_forecast | Prévision du solde de fin de mois | 11 | NON COMMENCÉ |  |  |
| module:morning_brief | Brief du matin | 10 | NON COMMENCÉ |  |  |
| module:schedule_rotation | Rotation de planning A/B | 10 | NON COMMENCÉ |  |  |
| module:rest_alert | Alerte de jours consécutifs et de repos | 11 | NON COMMENCÉ |  |  |
| module:share_import | Import par la feuille de partage (et planning par texte) | 11 | NON COMMENCÉ |  |  |
| module:payslip_check | Vérificateur de fiche de paie | 11 | NON COMMENCÉ |  |  |
| module:interview_prep | Préparation d'entretien | 11 | NON COMMENCÉ |  |  |
| module:availability_planner | Générateur de disponibilités | 11 | NON COMMENCÉ |  |  |
| module:end_prediction | Prédiction d'heure de fin | 11 | NON COMMENCÉ |  |  |
| module:experience_log | Carnet d'expériences | 11 | NON COMMENCÉ |  |  |
| module:planning_diff | Détecteur de changements de planning | 10 | NON COMMENCÉ |  |  |
| module:tamper_log | Journal infalsifiable | 11 | NON COMMENCÉ |  |  |
| module:load_forecast | Prévision de charge | 11 | NON COMMENCÉ |  |  |
| module:exam_budget | Mode bac en approche | 11 | NON COMMENCÉ |  |  |
| module:return_recap | Retour de congé | 11 | NON COMMENCÉ |  |  |
| module:heatmap | Carte de chaleur annuelle | 11 | NON COMMENCÉ |  |  |
| module:place_memos | Mémos de lieu | 11 | NON COMMENCÉ |  |  |
| module:travel_calibration | Cohérence du trajet | 11 | NON COMMENCÉ |  |  |
| module:delay_log | Trace de retard | 11 | NON COMMENCÉ |  |  |
| module:pay_reconciliation | Régularisation des heures payées | 11 | NON COMMENCÉ |  |  |
| module:plan_proposals | Plannings proposés | 11 | NON COMMENCÉ |  |  |
| module:holiday_outlook | Jours fériés de l'année | 11 | NON COMMENCÉ |  |  |
| module:self_compare | Comparaison avec ton passé | 11 | NON COMMENCÉ |  |  |
| module:blocked_periods | Périodes bloquées | 10 | NON COMMENCÉ |  |  |
| module:class_work_tradeoff | Arbitrage cours contre travail | 11 | NON COMMENCÉ |  |  |
| module:weekend_preview | Aperçu de ta fin de semaine | 11 | NON COMMENCÉ |  |  |
| module:low_period_alert | Anticipation des périodes creuses | 11 | NON COMMENCÉ |  |  |
| module:vacation_prep | Prêt à partir en vacances | 11 | NON COMMENCÉ |  |  |
| module:team_swaps | Équipe et échanges malins | 11 | NON COMMENCÉ |  |  |
| module:planning_text | Planning par texte | 10 | NON COMMENCÉ |  |  |
| module:live_earnings | Compteur de gains en direct | 11 | NON COMMENCÉ |  |  |
| module:true_hourly_rate | Vrai taux horaire | 11 | NON COMMENCÉ |  |  |
| module:notice_check | Délai de prévenance | 11 | NON COMMENCÉ |  |  |
| module:backup_signals | Signaux de secours (Wi-Fi, Bluetooth, CarPlay, charge, NFC) | 10 | NON COMMENCÉ |  |  |
| module:folder_backup | Sauvegarde automatique dans un dossier Fichiers | 10 | NON COMMENCÉ |  |  |
| module:privacy_shield | Protection à la capture et mode démo | 10 | NON COMMENCÉ |  |  |
| module:ask_assistant | Demande-moi tout (assistant local) | 11 | NON COMMENCÉ |  |  |
| module:break_in | Phase de rodage | 10 | NON COMMENCÉ |  |  |
| module:clock_check | Contrôle de l'horloge | 3 | NON COMMENCÉ |  |  |
| module:age_rules | Règles selon l'âge | 11 | NON COMMENCÉ |  |  |
| module:last_minute_offer | Demande de dernière minute | 11 | NON COMMENCÉ |  |  |
| module:school_timetable | Emploi du temps scolaire | 9 | NON COMMENCÉ |  |  |
| module:extra_time | Temps annexes | 11 | NON COMMENCÉ |  |  |
| module:constraint_counters | Compteurs de contraintes | 11 | NON COMMENCÉ |  |  |
| module:pay_period | Période de paie personnalisée | 10 | NON COMMENCÉ |  |  |
| module:contract_check | Vérificateur de contrat avant signature | 11 | NON COMMENCÉ |  |  |
| module:internship_log | Carnet de stage ou d'alternance | 11 | NON COMMENCÉ |  |  |
| module:day_replay | Rejouer ma journée | 11 | NON COMMENCÉ |  |  |
| module:glossary | Termes expliqués | 10 | NON COMMENCÉ |  |  |
| module:multi_site | Déplacements entre sites | 11 | NON COMMENCÉ |  |  |
| module:calendar_constraints | Agenda perso comme contrainte | 11 | NON COMMENCÉ |  |  |
| module:day_assistant | Assistant de journée (détection de l'inhabituel) | 10 | NON COMMENCÉ |  |  |
| module:reliability_center | Centre de fiabilité | 10 | NON COMMENCÉ |  |  |

## Scénarios de référence (section 4)

| ID | Titre | Étape | Statut | Preuve | Note |
|---|---|---|---|---|---|
| scenario:A | Journée mixte | - | NON COMMENCÉ |  |  |
| scenario:B | Courses | - | NON COMMENCÉ |  |  |
| scenario:C | Travail un samedi | - | NON COMMENCÉ |  |  |
| scenario:D | Passage rapide | - | NON COMMENCÉ |  |  |
| scenario:E | Pause | - | NON COMMENCÉ |  |  |
| scenario:F | GPS coupé ou téléphone éteint | - | NON COMMENCÉ |  |  |
| scenario:G | Planning photo | - | NON COMMENCÉ |  |  |
| scenario:H | Rattrapage du passé | - | NON COMMENCÉ |  |  |
| scenario:I | Oubli de GPS | - | NON COMMENCÉ |  |  |
| scenario:J | Vacances scolaires | - | NON COMMENCÉ |  |  |
| scenario:K | Fin de mois | - | NON COMMENCÉ |  |  |
| scenario:L | Mode examens | - | NON COMMENCÉ |  |  |
| scenario:M | Départ à l'heure | - | NON COMMENCÉ |  |  |
| scenario:N | Noyau seul | - | NON COMMENCÉ |  |  |
| scenario:O | Deux employeurs | - | NON COMMENCÉ |  |  |
| scenario:P | Fin de CDD | - | NON COMMENCÉ |  |  |
| scenario:Q | Nuit courte | - | NON COMMENCÉ |  |  |
| scenario:R | Module activé puis désactivé | - | NON COMMENCÉ |  |  |
| scenario:S | Remplacement | - | NON COMMENCÉ |  |  |
| scenario:T | Mode vacances de l'app | - | NON COMMENCÉ |  |  |
| scenario:U | Planning tardif | - | NON COMMENCÉ |  |  |
| scenario:V | Correction vocale | - | NON COMMENCÉ |  |  |
| scenario:W | Retard annoncé | - | NON COMMENCÉ |  |  |
| scenario:X | Dossier justificatif | - | NON COMMENCÉ |  |  |
| scenario:Y | Heures manquantes | - | NON COMMENCÉ |  |  |
| scenario:Z | Prévision de fin de mois | - | NON COMMENCÉ |  |  |
| scenario:AA | Brief du matin | - | NON COMMENCÉ |  |  |
| scenario:AB | Rotation A/B | - | NON COMMENCÉ |  |  |
| scenario:AC | Jours consécutifs | - | NON COMMENCÉ |  |  |
| scenario:AD | Import par partage | - | NON COMMENCÉ |  |  |
| scenario:AE | Semaines toutes différentes | - | NON COMMENCÉ |  |  |
| scenario:AF | Fiche de paie douteuse | - | NON COMMENCÉ |  |  |
| scenario:AG | Planning modifié | - | NON COMMENCÉ |  |  |
| scenario:AH | Intégrité | - | NON COMMENCÉ |  |  |
| scenario:AI | Cycle détecté | - | NON COMMENCÉ |  |  |
| scenario:AJ | Rééquilibrage du contrat | - | NON COMMENCÉ |  |  |
| scenario:AK | Jour férié | - | NON COMMENCÉ |  |  |
| scenario:AL | Retour de congé | - | NON COMMENCÉ |  |  |
| scenario:AM | Heures payées en moins | - | NON COMMENCÉ |  |  |
| scenario:AN | Quota proche | - | NON COMMENCÉ |  |  |
| scenario:AO | Plannings proposés | - | NON COMMENCÉ |  |  |
| scenario:AP | Simulateur en direct | - | NON COMMENCÉ |  |  |
| scenario:AQ | Jour bloqué | - | NON COMMENCÉ |  |  |
| scenario:AR | Semaine bloquée | - | NON COMMENCÉ |  |  |
| scenario:AS | Arbitrage | - | NON COMMENCÉ |  |  |
| scenario:AT | Fin de semaine adaptée | - | NON COMMENCÉ |  |  |
| scenario:AU | Période creuse | - | NON COMMENCÉ |  |  |
| scenario:AV | Historique | - | NON COMMENCÉ |  |  |
| scenario:AW | Départ en vacances | - | NON COMMENCÉ |  |  |
| scenario:AX | Équipe | - | NON COMMENCÉ |  |  |
| scenario:AY | Planning par texte | - | NON COMMENCÉ |  |  |
| scenario:AZ | Carte Maintenant | - | NON COMMENCÉ |  |  |
| scenario:BA | Notifications qui apprennent | - | NON COMMENCÉ |  |  |
| scenario:BB | Gains en direct | - | NON COMMENCÉ |  |  |
| scenario:BC | Contrôles | - | NON COMMENCÉ |  |  |
| scenario:BD | Vrai taux horaire | - | NON COMMENCÉ |  |  |
| scenario:BE | Fiabilité | - | NON COMMENCÉ |  |  |
| scenario:BF | Annuler | - | NON COMMENCÉ |  |  |
| scenario:BG | Délai de prévenance | - | NON COMMENCÉ |  |  |
| scenario:BH | Calibration d'un lieu | - | NON COMMENCÉ |  |  |
| scenario:BI | Batterie vide | - | NON COMMENCÉ |  |  |
| scenario:BJ | Dépannage | - | NON COMMENCÉ |  |  |
| scenario:BK | Widgets | - | NON COMMENCÉ |  |  |
| scenario:BL | Live Activity de 9 heures | - | NON COMMENCÉ |  |  |
| scenario:BM | Bases de calcul | - | NON COMMENCÉ |  |  |
| scenario:BN | Cas de doute | - | NON COMMENCÉ |  |  |
| scenario:BO | Signal de secours | - | NON COMMENCÉ |  |  |
| scenario:BP | Sauvegarde dans un dossier | - | NON COMMENCÉ |  |  |
| scenario:BQ | Capture et démo | - | NON COMMENCÉ |  |  |
| scenario:BR | Demande-moi tout | - | NON COMMENCÉ |  |  |
| scenario:BS | Scanner papier | - | NON COMMENCÉ |  |  |
| scenario:BT | Rodage | - | NON COMMENCÉ |  |  |
| scenario:BU | Horloge | - | NON COMMENCÉ |  |  |
| scenario:BV | Règles selon l'âge | - | NON COMMENCÉ |  |  |
| scenario:BW | Demande de dernière minute | - | NON COMMENCÉ |  |  |
| scenario:BX | Emploi du temps scolaire | - | NON COMMENCÉ |  |  |
| scenario:BY | Temps annexes | - | NON COMMENCÉ |  |  |
| scenario:BZ | Compteurs de contraintes | - | NON COMMENCÉ |  |  |
| scenario:CA | Période de paie du 26 au 25 | - | NON COMMENCÉ |  |  |
| scenario:CB | Contrat avant signature | - | NON COMMENCÉ |  |  |
| scenario:CC | Carnet de stage | - | NON COMMENCÉ |  |  |
| scenario:CD | Rejouer ma journée | - | NON COMMENCÉ |  |  |
| scenario:CE | Termes expliqués | - | NON COMMENCÉ |  |  |
| scenario:CF | Déplacements entre sites | - | NON COMMENCÉ |  |  |
| scenario:CG | Agenda comme contrainte | - | NON COMMENCÉ |  |  |
| scenario:CH | Assistant de journée | - | NON COMMENCÉ |  |  |
| scenario:CI | Centre de fiabilité | - | NON COMMENCÉ |  |  |
| scenario:CJ | Questions sans modèle | - | NON COMMENCÉ |  |  |
| scenario:CK | Ta semaine | - | NON COMMENCÉ |  |  |

## Journal des erreurs et limites connues

(voir notes/ERREURS.md)
