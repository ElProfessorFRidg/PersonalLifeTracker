# MODULES.md : registre des modules de Personal Life Tracker

Source de vérité des listes liées aux modules. Le prompt principal (PERSONAL_LIFE_TRACKER_PROMPT.md) décrit chaque fonctionnalité dans sa section ; ce fichier regroupe ce qu'il faut tenir à jour pour ne rien oublier.

**Pour ajouter une fonctionnalité** : écrire sa section dans le prompt principal, ajouter UNE ligne dans le tableau ci-dessous, puis ajouter ses réglages (annexe A), notifications (B), modèles (C), tests (D) et critères d'acceptation (E) si elle en a.

**Légende** : défaut "coché" = proposé et coché à l'onboarding, "décoché" = proposé et décoché. "Exige" = dépendance obligatoire. "Enrichi par" = facultatif. Étape = étape de la section 60 du prompt principal (un module n'est livré qu'à son étape). Le noyau (section 3.1) n'est pas un module.

## 1. Registre

| Module | Sections | Titre | Défaut | Exige | Enrichi par | Étape |
|---|---|---|---|---|---|---|
| planning_ocr | 16, 70, 138 | Planning par photo, alerte de planning tardif | coché | - | - | 7 |
| place_discovery | 17 | Découverte automatique des lieux | coché | - | - | 10 |
| employment | 18, 19 | Employeurs, contrats, fin de contrat | coché | - | - | 5 |
| pay | 20 à 22, 25, 26, 69 | Salaire, paie, conventions, primes, historique des taux | coché | employment | - | 5 (base), 6 (conventions, primes) |
| school_calendar | 30 | Calendrier scolaire, vacances, jours fériés | coché | - | - | 9 |
| notes | 39 | Notes de journée | coché | - | - | 9 |
| search | 41 | Recherche globale | coché | - | - | 10 |
| weekly_review | 46 | Revue de la semaine | coché | - | - | 10 |
| recaps | 40 | Bilans mensuels et annuels | coché | - | - | 10 |
| live_activity_widgets | 44, 125, 133 | Live Activity, widgets, App Intents, contrôles, galerie de widgets | coché | - | - | 8 (base, contrôles), 10 (galerie) |
| missing_hours | 86 | Détection d'heures manquantes | coché | - | planning_ocr, leave, vacation_mode | 10 |
| contract_hours | 28, 106, 109 | Équilibrage des heures du contrat, compteurs, repos compensateur, alerte de quota | coché | employment | pay, leave, availability_planner | 6 |
| pattern_detection | 107 | Détection de motifs de planning | coché | - | planning_ocr, employment, school_calendar | 10 |
| schedule_archive | 118 | Historique des plannings | coché | planning_ocr | - | 10 |
| now_card | 122 | Carte Maintenant (ActionEngine) | coché | - | candidats de tous les modules actifs | 10 |
| smart_notifications | 123, 45 | Notifications qui apprennent (coordinateur) | coché | - | toutes les notifications de tous les modules | 10 |
| data_trust | 127 | Score de fiabilité des données | coché | - | planning_ocr, pay, missing_hours | 10 |
| undo_safety | 128 | Annuler partout et instantanés | coché | - | tous les modules | 2 |
| place_calibration | 130 | Auto-calibration des lieux | coché | - | place_discovery, detection_help | 3 |
| battery_recovery | 131 | Récupération après batterie vide | coché | - | - | 3 |
| detection_help | 132 | Assistant de dépannage de la détection | coché | - | place_calibration, battery_recovery | 3 |
| multi_employer | 18.3 | Plusieurs employeurs | décoché | employment | - | 10 |
| leave | 23 | Congés payés | décoché | employment | - | 6 |
| simulator | 24, 111 | Simulateur et semaine en direct | décoché | pay | - | 10 (simulateur), 11 (semaine en direct) |
| pay_date | 27 | Date de paie attendue | décoché | pay | - | 10 |
| tax_threshold | 29 | Seuil fiscal | décoché | pay | - | 11 |
| exam_mode | 31 | Mode examens | décoché | - | - | 9 |
| breaks | 32 | Pauses | décoché | - | - | 9 |
| short_night | 33 | Alerte nuit courte | décoché | - | - | 9 |
| study_slots | 34 | Créneaux libres de révision | décoché | - | school_calendar | 9 |
| travel_departure | 35 | Trajet et Pars maintenant | décoché | - | - | 9 |
| travel_cost | 36 | Coût du trajet | décoché | travel_departure, ou au moins un lieu avec adresse | - | 11 |
| going_home | 37 | Je rentre | décoché | - | - | 11 |
| savings | 38 | Objectifs d'épargne | décoché | pay | - | 10 |
| send_hours_reminder | 42 | Rappel d'envoi des heures | décoché | employment | - | 10 |
| focus | 43 | Concentration | décoché | - | - | 11 |
| nfc | 15.5 | Tag NFC | décoché | - | - | 11 |
| biometric_lock | 55 | Verrouillage Face ID | décoché | - | - | 11 |
| icloud | 54 | Sauvegarde iCloud | décoché | - | - | 11 |
| expenses | 67 | Suivi des frais | décoché | - | - | 11 |
| replacements | 68 | Remplacements | décoché | - | - | 10 |
| regularity | 71 | Statistiques de régularité | décoché | - | - | 10 |
| contract_journal | 72 | Journal de contrat | décoché | employment | - | 11 |
| vacation_mode | 73 | Mode vacances de l'app | décoché | - | - | 10 |
| work_contacts | 74 | Contacts du taf | décoché | - | employment, pay, recaps, contract_journal | 11 |
| badge_reminder | 75 | Rappel de badgeuse | décoché | employment | - | 11 |
| departure_checklist | 76 | Check avant de partir | décoché | - | - | 11 |
| voice_corrections | 77 | Corrections à la voix | décoché | - | - | 11 |
| weekly_balance | 78 | Équilibre de la semaine | décoché | - | - | 11 |
| share_summary | 79 | Résumé partageable | décoché | - | employment, pay, recaps, contract_journal | 11 |
| proof_pack | 80 | Dossier justificatif | décoché | - | employment, pay, recaps, contract_journal | 11 |
| shift_swaps | 81 | Carnet d'échanges de créneaux | décoché | - | work_contacts, replacements | 11 |
| end_of_day_countdown | 82 | Compte à rebours de fin de journée | décoché | - | - | 11 |
| rough_day | 83 | Journée difficile | décoché | - | - | 11 |
| premium_planner | 84 | Primes de dimanche et de férié à venir | décoché | pay | - | 11 |
| month_forecast | 85 | Prévision du solde de fin de mois | décoché | pay | expenses, savings, pay_date | 11 |
| morning_brief | 87 | Brief du matin | décoché | - | contenu des modules actifs | 10 |
| schedule_rotation | 88 | Rotation de planning A/B | décoché | planning_ocr | - | 10 |
| rest_alert | 89 | Alerte de jours consécutifs et de repos | décoché | employment | - | 11 |
| share_import | 90, 121 | Import par la feuille de partage (et planning par texte) | décoché | - | destinations des modules actifs (planning_ocr, pay, contract_journal, expenses) | 11 |
| payslip_check | 92 | Vérificateur de fiche de paie | décoché | pay | - | 11 |
| interview_prep | 93 | Préparation d'entretien | décoché | employment, pay | - | 11 |
| availability_planner | 94 | Générateur de disponibilités | décoché | - | study_slots, rest_alert, short_night, savings | 11 |
| end_prediction | 95 | Prédiction d'heure de fin | décoché | - | planning_ocr, short_night | 11 |
| experience_log | 96 | Carnet d'expériences | décoché | - | employment | 11 |
| planning_diff | 97 | Détecteur de changements de planning | décoché | planning_ocr | - | 10 |
| tamper_log | 98 | Journal infalsifiable | décoché | - | tous les modules actifs | 11 |
| load_forecast | 99 | Prévision de charge | décoché | - | planning_ocr, weekly_balance, study_slots, exam_mode | 11 |
| exam_budget | 100 | Mode bac en approche | décoché | exam_mode | - | 11 |
| return_recap | 101 | Retour de congé | décoché | - | contenu des modules actifs | 11 |
| heatmap | 102 | Carte de chaleur annuelle | décoché | - | - | 11 |
| place_memos | 103 | Mémos de lieu | décoché | - | - | 11 |
| travel_calibration | 104 | Cohérence du trajet | décoché | travel_departure | - | 11 |
| delay_log | 105 | Trace de retard | décoché | - | travel_departure, work_contacts, contract_journal, tamper_log | 11 |
| pay_reconciliation | 108 | Régularisation des heures payées | décoché | pay, contract_hours | - | 11 |
| plan_proposals | 110 | Plannings proposés | décoché | employment | pattern_detection, availability_planner, contract_hours, rest_alert, short_night, study_slots, savings | 11 |
| holiday_outlook | 112 | Jours fériés de l'année | décoché | - | school_calendar, pattern_detection, pay | 11 |
| self_compare | 113 | Comparaison avec ton passé | décoché | - | employment | 11 |
| blocked_periods | 114 | Périodes bloquées | décoché | - | contract_hours, pay, savings, leave, availability_planner, plan_proposals, vacation_mode | 10 |
| class_work_tradeoff | 115 | Arbitrage cours contre travail | décoché | - | planning_ocr, pay, contract_hours, exam_mode | 11 |
| weekend_preview | 116 | Aperçu de ta fin de semaine | décoché | - | contract_hours, blocked_periods, school_calendar, study_slots | 11 |
| low_period_alert | 117 | Anticipation des périodes creuses | décoché | employment | pay, savings, contract_hours, blocked_periods, school_calendar, pattern_detection | 11 |
| vacation_prep | 119 | Prêt à partir en vacances | décoché | - | vacation_mode, blocked_periods, leave, return_recap, icloud | 11 |
| team_swaps | 120 | Équipe et échanges malins | décoché | planning_ocr | shift_swaps, work_contacts | 11 |
| planning_text | 121 | Planning par texte | décoché | planning_ocr | share_import | 10 |
| live_earnings | 124 | Compteur de gains en direct | décoché | pay | - | 11 |
| true_hourly_rate | 126 | Vrai taux horaire | décoché | pay | expenses, travel_cost, travel_departure, travel_calibration | 11 |
| notice_check | 129 | Délai de prévenance | décoché | planning_ocr, employment | planning_diff, contract_journal | 11 |
| backup_signals | 134 | Signaux de secours (Wi-Fi, Bluetooth, CarPlay, charge, NFC) | décoché | - | detection_help, place_calibration | 10 |
| folder_backup | 135 | Sauvegarde automatique dans un dossier Fichiers | coché | - | tamper_log, undo_safety | 10 |
| privacy_shield | 136 | Protection à la capture et mode démo | coché | - | - | 10 |
| ask_assistant | 137 | Demande-moi tout (assistant local) | décoché | - | search, données de tous les modules actifs | 11 |
| break_in | 139 | Phase de rodage | coché | - | now_card, smart_notifications, data_trust, place_calibration | 10 |
| clock_check | 140 | Contrôle de l'horloge | coché | - | tamper_log, detection_help | 3 |
| age_rules | 141 | Règles selon l'âge | décoché | - | rest_alert, short_night, breaks, contract_hours, plan_proposals, availability_planner, simulator | 11 |
| last_minute_offer | 142 | Demande de dernière minute | décoché | planning_text | availability_planner, blocked_periods, contract_hours, pay, rest_alert, short_night, travel_departure, shift_swaps, replacements, notice_check, calendar_constraints, school_timetable | 11 |
| school_timetable | 143 | Emploi du temps scolaire | coché | - | school_calendar, planning_ocr, study_slots, availability_planner, class_work_tradeoff | 9 |
| extra_time | 144 | Temps annexes | décoché | employment | pay, contract_hours, true_hourly_rate, payslip_check | 11 |
| constraint_counters | 145 | Compteurs de contraintes | décoché | employment | pay, contract_hours, rest_alert | 11 |
| pay_period | 146 | Période de paie personnalisée | décoché | pay | pay_date, month_forecast, send_hours_reminder, data_trust | 10 |
| contract_check | 147 | Vérificateur de contrat avant signature | décoché | pay | employment, contract_journal | 11 |
| internship_log | 148 | Carnet de stage ou d'alternance | décoché | - | notes, experience_log, employment, proof_pack | 11 |
| day_replay | 149 | Rejouer ma journée | décoché | - | detection_help, backup_signals, clock_check, place_calibration | 11 |
| glossary | 150 | Termes expliqués | coché | - | - | 10 |
| multi_site | 151 | Déplacements entre sites | décoché | employment | expenses, multi_employer, travel_departure | 11 |
| calendar_constraints | 152 | Agenda perso comme contrainte | décoché | - | availability_planner, plan_proposals, last_minute_offer, blocked_periods, load_forecast | 11 |
| day_assistant | 153 | Assistant de journée (détection de l'inhabituel) | coché | - | pattern_detection, planning_ocr, school_timetable, data_trust, now_card, break_in | 10 |
| reliability_center | 154 | Centre de fiabilité | coché | - | data_trust, detection_help, place_calibration, battery_recovery, clock_check, folder_backup, break_in, undo_safety | 10 |

**Sous-fonctions (pas de module séparé)** : rate_history (69, partie de pay, actif avec lui) ; late_planning_alert (70, réglage de planning_ocr, décoché) ; quota_alert (109, réglage de contract_hours, décoché) ; live_week_sim (111, mode du simulateur) ; smart_stack_controls (125, réglage de live_activity_widgets, activé avec lui) ; widget_gallery (133, extension de live_activity_widgets, activée avec lui) ; paper_scan (138, scanner de planning papier, inclus dans planning_ocr) ; weekly_summary (40 et 46, bilan hebdomadaire "Ta semaine", fait partie de recaps et weekly_review) ; natural_queries (41.1, questions en langage naturel sans modèle, fait partie de search).

**Fusionnés ou renommés** : hour_bank (ancienne section 28) est fusionné dans contract_hours (106.4) ; raise_dossier est renommé interview_prep (93).

## Annexe A. Réglages des modules (visibles seulement si le module est actif)

- trajet (marge, transport par lieu)
- argent (contrat, convention, règles surchargées, ratio net/brut, devise, plafond d'heures)
- congés (période, unité, alertes)
- contrat (alertes de fin)
- simulateur
- employeurs
- rappel d'envoi
- pauses (aucune, info, rappel)
- nuit courte (seuil)
- créneaux de révision
- coût du trajet
- "Je rentre" (contact favori, message type)
- widget "encore X h" (temps restant, heure de fin, les deux)
- Concentration (aide à la configuration)
- frais (catégories)
- remplacements (proposition automatique ou non)
- alerte planning tardif (jour de publication)
- régularité
- journal de contrat
- mode vacances (période)
- contacts du taf
- badgeuse (délai du rappel)
- check avant de partir (listes)
- corrections à la voix (confirmation obligatoire par défaut)
- équilibre (plage de sommeil exclue, objectifs facultatifs)
- résumé partageable (contenu par défaut)
- dossier justificatif
- carnet d'échanges (rappel avant échéance)
- compte à rebours (seuils)
- journée difficile (tags)
- primes à venir (durée type du créneau)
- prévision de fin de mois (hypothèses)
- heures manquantes (heure de la question du matin)
- brief du matin (heure, contenu)
- rotation de planning (cycle, semaine de départ)
- alerte de repos (seuils)
- import par partage (voie disponible)
- vérificateur de fiche de paie (seuils d'écart)
- préparation d'entretien (sections)
- disponibilités (créneaux types, jours exclus)
- prédiction d'heure de fin (échantillon minimal)
- carnet d'expériences (étiquettes de tâche)
- changements de planning (notifications)
- journal infalsifiable (signature, ancrage)
- horaires (toujours les mêmes, cycle, ou variables)
- équilibrage des heures (période de référence, comment compter un créneau non travaillé, report des heures)
- motifs de planning (sensibilité, nombre minimal de répétitions, tolérance horaire)
- charge de la semaine (seuils)
- bac en approche (objectifs de révision)
- retour de congé (durée minimale d'absence)
- carte de chaleur (activité affichée)
- mémos de lieu
- cohérence du trajet (marge automatique ou non)
- trace de retard (précision de la position)
- régularisation (seuil d'écart, nombre de mois)
- alerte de quota (seuils et limites)
- plannings proposés (contraintes dures et souples, jours préférés ou à éviter)
- simulateur en direct
- jours fériés (récap annuel)
- comparaison avec le passé (périodes de référence)
- périodes bloquées (niveaux, récurrence, message type)
- arbitrage cours contre travail (compteur d'absences facultatif)
- aperçu de fin de semaine (mes jours à moi, jour et heure du récap)
- périodes creuses (horizon, sensibilité)
- historique des plannings (conservation des images, limite de stockage)
- départ en vacances (checklist)
- équipe (conservation des noms)
- planning par texte
- carte Maintenant (priorités)
- notifications qui apprennent (budget, propositions)
- gains en direct (net ou brut, durée de la timeline)
- pile intelligente et contrôles
- vrai taux horaire (temps de préparation, période)
- fiabilité des données (seuil)
- annuler et instantanés (durée de conservation, espace)
- délai de prévenance (règle applicable, date de réception)
- calibration des lieux (échantillon minimal)
- batterie vide (seuil de batterie basse)
- dépannage (durée de conservation du journal)
- widgets (style global, masquage sur l'écran verrouillé, familles)
- préparation d'entretien (modèles)

- base de paie par employeur (payé sur l'heure exacte, normalisée, du planning, ou du planning sauf dépassement de X minutes)

- signaux de secours (signaux par lieu, libellés, automatisations à créer)
- sauvegarde dans un dossier (dossier, fréquence, nombre de sauvegardes conservées, chiffrement, éléments sensibles)
- protection à la capture (flou automatique, rappel après capture d'écran), mode démo
- Demande-moi tout (activation, saisie vocale)
- scanner papier (guidage, assemblage de plusieurs photos)
- rodage (durée, questions par jour, passer le rodage)
- horloge (seuil de dérive, alerte)
- règles selon l'âge (date de naissance, profil)
- heures pleines (zone de doute, apprentissage des choix par contexte)

- demande de dernière minute (réponses types, ton)
- emploi du temps scolaire (cycle A/B, import, semaine de départ)
- temps annexes (types, payé ou non, compté dans le quota, modèles par employeur)
- compteurs de contraintes (période de référence, limites sourcées)
- période de paie (jour de clôture, décalage, jour de versement)
- contrat avant signature (points contrôlés)
- carnet de stage (modèles, nom du tuteur, statut de validation)
- rejouer ma journée (durée de conservation des événements)
- termes expliqués (icônes d'aide visibles ou masquées)
- déplacements entre sites (compté comme temps de travail, indemnité au kilomètre)
- agenda (calendriers inclus, niveau dur ou souple, événements sur la journée entière)

- assistant de journée (sensibilité, types de signalements, notification ou non)
- centre de fiabilité (cartes affichées, badge)
- bilan hebdomadaire (jour et heure)
- questions en langage naturel (suggestions de reformulation)

## Annexe B. Notifications des modules (envoyées seulement si le module est actif)

Toutes passent par le coordinateur central quand smart_notifications est actif (section 123).

- planning du lendemain
- "Pars maintenant"
- rappel de pause
- alerte de plafond
- nuit courte
- fin de contrat
- congés qui expirent
- date de paie
- rappel d'envoi des heures
- planning tardif
- remplacement possible
- rappel de badgeuse
- check avant de partir
- compte à rebours de fin de journée
- heures manquantes
- échange à rendre
- brief du matin
- alerte de repos
- changement de planning
- suggestion de planning
- charge de la semaine
- mémo de lieu
- retour de congé
- alerte de proximité du quota
- jours fériés à venir
- conflit avec une période bloquée
- période creuse à venir
- aperçu de fin de semaine
- rappel de préparation de départ
- reprise après le mode vacances
- bilans
- revue de la semaine
- délai de prévenance
- batterie basse pendant une session
- relance de la Live Activity avant la limite de 8 heures
- lancement du suivi à l'arrivée (touche pour démarrer la Live Activity)

- sauvegarde de dossier échouée ou dossier inaccessible
- horloge du téléphone décalée ou modifiée
- passage à un nouveau profil d'âge (par exemple 18 ans)
- fin du rodage
- propositions d'heures à choisir (groupées, pas de notification par cas)

- rappel de clôture de paie
- limite de contrainte proche (dimanches, nuits, jours consécutifs)
- rappel de validation du tuteur (carnet de stage)
- question optionnelle sur un temps annexe à l'arrivée (briefing du jour)

- signalement d'inhabituel (désactivé par défaut, sinon regroupé dans la carte Maintenant)
- Ta semaine (bilan hebdomadaire et revue de la semaine en une seule notification)

## Annexe C. Modèles de données des modules

- Schedule et ScheduleEntry
- Employer
- ContractLifecycle
- ConventionSelection
- PayRuleOverride
- Bonus
- LeaveBalance et LeaveEntry
- Scenario
- SentReportRecord
- PayslipRecord
- HourBankEntry
- Holiday
- DayNote
- SavingsGoal
- ExamPeriod
- Recap
- Expense
- ReplacementTag
- RateHistoryEntry
- ContractJournalEntry et ContractDocument
- VacationPeriod
- WorkContact
- ChecklistItem
- BadgePunch
- ProofPack
- ShiftSwap
- CountdownRule
- RoughDayMark
- MissingHoursPrompt
- ForecastAssumption
- RotationCycle
- RestRuleCheck
- SharedInboxItem
- WeekPlan
- ScheduleVersion
- PayslipFinding
- ExperienceEntry
- AvailabilityGrid
- EndPredictionSample
- IntegrityCheckpoint
- ContractHoursPeriod
- HoursProjection
- HoursCarryOver
- PatternCandidate
- HolidayPattern
- PlaceMemo
- TravelSample
- DelayRecord
- LoadSnapshot
- PayGapEntry
- QuotaAlertRule
- PlanProposal
- SimulationDraft
- HolidayOutlook
- ComparisonSnapshot
- BlockedPeriod
- AbsenceCount
- WeekendPreviewConfig
- LowPeriodForecast
- ScheduleArchiveItem
- VacationChecklist
- TeamMember
- TeamSlot
- PlanningTextTemplate
- ActionCandidateLog
- NotificationStat
- EarningsTimeline
- RateBreakdown
- TrustSnapshot
- UndoRecord
- DataSnapshot
- NoticeRecord
- PlaceCalibrationSample
- BatteryEvidence
- CapabilityLogEntry
- WidgetStylePreference

- SignalEvidence
- BackupJob
- BackupFolderBookmark
- ClockEvidence
- AgeProfile
- BreakInProgress
- PaperScanSession
- TimeChoice (choix d'heure en cas de doute)

- OfferAnalysis
- TimetableEntry et TimetableCycle
- ExtraTimeEntry
- ConstraintCounterSnapshot
- PayPeriodConfig
- ContractCheckReport
- InternshipEntry
- SiteTravel
- CalendarConstraintRule

- DayInsight
- ReliabilitySnapshot
- WeeklyRecap

## Annexe D. Tests par module

- Paie : conversion brut/net, SMIC lu depuis le fichier de référence avec date d'effet (y compris changement en cours d'année), majorations, plafonds, jours fériés, heures complémentaires et supplémentaires, primes, exclusion des sessions incertaines, changement de convention, date de paie, compteurs de repos compensateur (section 106.4), seuil fiscal.
- Conventions : recherche (mots-clés, accents, fautes, IDCC), chargement d'un pack, surcharge manuelle, pack incomplet marqué "à renseigner".
- Contrats : périodes d'essai, terme, renouvellement, alertes, checklist, archivage, création du contrat suivant.
- Congés : acquisition sur plusieurs mois, changement de période de référence, mois incomplet, congés à cheval sur deux périodes, CDD de quelques semaines.
- Simulateur : copie isolée, aucune modification des données réelles, comparaison A contre B, cohérence avec le moteur de paie réel.
- Multi-employeurs : rattachement, conflits, cumul d'heures, statistiques par employeur et totales.
- Trajet et coût : calcul de l'heure de départ, marge, retard probable, pas de requête superflue, coût mensuel avec saisies de l'utilisateur.
- Nuit courte, créneaux de révision, pauses (aucune, info, rappel), mode examens, "Je rentre" (aucun envoi automatique), Concentration (App Intents, filtre, ligne d'état), rappel d'envoi, widget "encore X h" (fin connue ou inconnue), objectifs, bilans, recherche, notes.
- Frais (saisie, catégories, remboursement, relevé), remplacements (proposition, comptage à part, aucune fausse anomalie), historique des taux (session avant et après un changement, SMIC qui change en cours de mois, aucune rétroactivité silencieuse), alerte planning tardif (une seule relance, aucune en mode vacances), régularité (seuil minimal de données, sessions incertaines exclues), journal de contrat (pièces jointes locales, alimentation des alertes), mode vacances (aucune détection ni notification, reprise, statistiques non faussées).
- Contacts du taf (aucun envoi automatique, message de retard prérempli), badgeuse (une notification par session, comparaison avec le pointage saisi), check avant de partir (déclenchement, une fois par sortie, aucun en mode vacances), corrections vocales (corpus d'énoncés, confirmation avant application, ambiguïtés, valeur d'origine conservée, reconnaissance sur l'appareil indisponible), équilibre de la semaine (plage de sommeil exclue, sessions incertaines signalées), résumé partageable (contenu masqué par défaut, aperçu), dossier justificatif (sélection, sommaire, estimations distinguées des montants lus, mot de passe PDF).
- Carnet d'échanges (sens, statuts, compteur de dettes, lien avec les remplacements, aucune modification des sessions réelles), compte à rebours (seuils, fin inconnue donc aucune notification, fin modifiée donc reprogrammation, annulation au départ réel), journée difficile (un tap, aucune analyse, aucune absence des bilans sauf choix), primes à venir (dimanches et fériés calculés, moteur de paie partagé avec le simulateur, aucune valeur en dur), prévision de fin de mois (net travaillé contre net reçu, fourchette, hypothèses modifiables, planning manquant), heures manquantes (aucun faux positif avec congés, vacances, fériés ou mode vacances, aucune session ajoutée sans réponse, apprentissage des réponses "pas de taf").
- Brief du matin (contenu limité aux modules actifs, heure automatique ou fixe, contenu fixé à la programmation et mise à jour opportuniste, version réduite en mode examens), rotation A/B (semaine ISO, passage d'année 52 ou 53, changement d'heure, décalage de cycle, un planning réel prime sur la rotation), alerte de repos (jours consécutifs par employeur et cumulés, congés comptés comme repos, règles "à renseigner" sans affirmation), import par partage (extension présente ou absente, repli "Ouvrir dans", destination choisie, validation obligatoire).
- Planning variable (trois semaines toutes différentes, aucune habitude abusive, aucun horaire inventé, semaine sans planning signalée, copie de la semaine précédente non confirmée automatiquement), vérificateur de fiche de paie (chaque contrôle avec cas limites, ton neutre, aucun envoi), préparation d'entretien (faits issus des données seulement), disponibilités (semaines variables, jours exclus, repos respecté), prédiction d'heure de fin (échantillon minimal, prévu et probable toujours distincts), carnet d'expériences (cumul d'heures sur sessions confirmées, aucune phrase sans donnée), changements de planning (diff sur créneaux validés, pas sur l'OCR brut, versions, mise à jour des notifications), journal infalsifiable (altération détectée, correction légitime valide, chaîne après restauration, signature facultative).
- Équilibrage des heures du contrat (exemple 13 h avec planning 5 h, 8 h, 5 h : vendredi 4 h, vendredi 0 h, semaine à 18 h, semaine à 10 h ; projection recalculée à chaque changement ; périodes semaine, quinzaine, mois, annualisée ; compteurs à rattraper et d'avance ; classement complémentaires et supplémentaires selon le pack ; quota historisé par avenant ; aucune alerte en congé), détection de motifs (semaine identique, cycles de 2, 3 et 4 semaines, rythme mensuel, rupture de cycle, confiance et échantillon minimal, motif rejeté non reproposé, jours fériés avec peu et beaucoup de données, aucune application sans confirmation), prévision de charge, mode bac en approche (budget d'heures, conflit avec le contrat signalé sans envoi), retour de congé, carte de chaleur (jours incertains, accessibilité, performance), mémos de lieu (affichage unique, contenu masqué dans la notification), cohérence du trajet (échantillon minimal, aucune trace GPS conservée), trace de retard (position arrondie, aucune transmission).
- Régularisation des heures payées (écart cumulé sur plusieurs mois, heures en trop signalées, règles de report de la section 106.4, aucun envoi, dossier complet), alerte de quota (seuils, limites au choix, une alerte par seuil, aucune pendant congés ou période bloquée), plannings proposés (contraintes dures jamais violées, déterminisme, explication des scores, aucune application sans confirmation, absence de données minimales), simulateur en direct (copie isolée, mise à jour incrémentale, accessibilité sans glisser-déposer), jours fériés de l'année (jamais supposé sans planning ni historique), comparaison avec le passé (seuil de significativité, vacances comparées aux vacances, sessions incertaines exclues), périodes bloquées (écran d'impact, conflit avec un créneau prévu, aucune annulation automatique, effets sur quota, paie, objectifs et rappels, récurrence, lien avec le mode vacances).
- Arbitrage cours contre travail (gain et perte affichés, ordre neutre des options, aucune absence marquée automatiquement, aucune donnée transmise), aperçu de fin de semaine (utilisateur qui travaille le week-end, utilisateur qui ne le travaille pas, jours de repos propres, sans planning connu), périodes creuses (causes multiples, fourchette, pas assez de données), historique des plannings (navigation, versions, comparaison, conservation facultative des images, purge, stockage), départ en vacances (étapes selon les modules actifs, état mémorisé, passage au retour de congé).
- Équipe (aucune conservation par défaut, initiales ambiguës confirmées, effacement par personne, aucune donnée de collègue dans les exports par défaut), planning par texte (corpus de formats variés, ambiguïtés non devinées, bouton de collage, validation obligatoire, gabarit appris), carte Maintenant (classement déterministe, une seule carte, report, baisse de priorité d'une action ignorée, état calme, contextes de silence), notifications qui apprennent (budget, regroupement, déduplication, proposition après ignorance répétée, aucune coupure sans accord, notifications essentielles protégées), gains en direct (timeline par minute, majoration de soirée, changement de taux, aucune promesse de défilement dans la Live Activity), pile intelligente et contrôles (disponibilité iOS 18, repli iOS 17, donation d'intents), vrai taux horaire (décomposition, hypothèses, données insuffisantes), fiabilité des données (formule, seuil, aucun blocage), annuler et instantanés (annulation sélective, instantané avant opération risquée, restauration réversible, cohérence avec le journal infalsifiable).
- Délai de prévenance (règle sourcée appliquée seulement aux contrats concernés, exceptions, "accepté volontairement", aucun envoi), auto-calibration des lieux (échantillon minimal, aucune application sans confirmation, aucune trace GPS conservée), récupération après batterie vide (indices datés, fin bornée et incertaine, redémarrage détecté, aucune présence inventée), assistant de dépannage (causes probables classées, correctifs, journal des capacités purgé).
- Widgets (toutes les familles, états plein couleur, teinté et clair, texte agrandi, masquage sur l'écran verrouillé, état d'invitation d'un module désactivé, absence d'App Group, famille XL portrait derrière la vérification de compilation et de disponibilité).
- Live Activity (démarrage par notification locale, aucune promesse de démarrage en arrière-plan, relance avant et après la limite de 8 heures, jamais source de vérité d'une session).
- Préparation d'entretien (trois modèles, faits issus des données seulement, aucun envoi) et compteurs de repos compensateur de la section 106.4.

- Base de paie par employeur (exact, normalisé, planning, planning sauf dépassement), majorations aux frontières calculées sur la base exacte.

- Signaux de secours (preuves datées avec marge d'erreur, combinaison avec le GPS, arrivée probable à confirmer, aucun nom de Wi-Fi lu par l'app).
- Sauvegarde dans un dossier (signet périmé, manifeste d'empreintes, conservation de N sauvegardes, restauration avec aperçu et instantané préalable, chiffrement facultatif).
- Protection à la capture (flou pendant l'enregistrement, rappel après capture d'écran, mode démo isolé, widgets en démo, aucune écriture dans les vraies données).
- Demande-moi tout (outils déterministes, garde-fou sur les nombres, repli sans modèle sur l'appareil, lecture seule, corpus de questions).
- Scanner papier (perspective, flou, reflet, assemblage par recouvrement, validation obligatoire).
- Rodage (au plus 3 questions par jour, indicateur de précision, fin du rodage, prolongation).
- Horloge (saut simulé, dérive, changement d'heure et de fuseau, correction avec confirmation, trace dans les journaux).
- Règles selon l'âge (changement à la date exacte, règles sourcées, date de naissance exclue des exports, alimentation des modules concernés).
- Heures pleines (minutes :00 à :14 et :46 à :59 arrondies, zone de doute :15 à :45 avec propositions, valeur provisoire à choisir, apprentissage après 3 choix).

- Demande de dernière minute (lecture validée, impact avec modules actifs, trois brouillons, aucun envoi, créneau prévu seulement après confirmation).
- Emploi du temps scolaire (import photo, PDF, ICS, semaines A/B, cours annulé, créneau libéré proposé sans incitation, aucune absence transmise).
- Temps annexes (segments séparés, statuts payé ou non, quota, relevé, horodatages de la session inchangés).
- Compteurs de contraintes (frontières sur la base retenue, limites sourcées, "pas de limite renseignée", aucune limite non sourcée).
- Période de paie (rattachement sur la base exacte, décalage d'un mois, rappel de clôture).
- Contrat avant signature (checklist présent, absent, à vérifier, sources, aucun mot "illégal", rien conservé sans accord).
- Carnet de stage (journal, récapitulatif PDF avec zone de signature vierge, statut coché par l'utilisateur, aucun envoi).
- Rejouer ma journée (événements avec sources et marges, correction en un tap, aucune trace GPS conservée, purge).
- Termes expliqués (icône d'aide, source et date, recherche dans le lexique).
- Déplacements entre sites (classement, réglage de décompte, journée continue, indemnité sans doublon).
- Agenda comme contrainte (lecture seule, titres non stockés, calendriers choisis, niveaux dur et souple).

- Assistant de journée (comparaison au prévu et au même contexte, échantillon minimal, médiane et écart absolu médian, aucun faux signalement quand le planning explique l'écart, "C'est normal" appris, aucune accusation).
- Centre de fiabilité (agrégation sans duplication, indicateur global et règle consultable, badge, trois actions classées, aucune nouvelle collecte).
- Questions sans modèle (formes reconnues, résultats déterministes identiques à la section 137, base de calcul affichée, suggestions de reformulation).
- Bilan hebdomadaire (une seule notification avec la revue, aucun bilan sans activité suffisante, sessions incertaines signalées).

## Annexe E. Critères d'acceptation par module

- contrats avec fin et alertes
- contrat saisi en brut ou net avec SMIC en un tap
- convention cherchable et appliquée
- estimation de paie, primes et relevé d'heures
- prévu contre contrat
- congés payés
- simulateur
- plusieurs employeurs
- trajet et "Pars maintenant"
- objectifs d'épargne
- notes de journée
- mode examens
- pauses optionnelles
- nuit courte
- créneaux de révision
- bilans mensuels et annuels partageables
- recherche globale
- rappel d'envoi des heures
- historique des taux
- remplacements
- suivi des frais
- journal de contrat
- mode vacances de l'app
- alerte planning tardif
- statistiques de régularité
- contacts du taf
- rappel de badgeuse
- check avant de partir
- corrections à la voix avec confirmation
- équilibre de la semaine
- résumé partageable
- dossier justificatif
- carnet d'échanges
- compte à rebours de fin de journée
- journée difficile
- primes à venir
- prévision de fin de mois
- heures manquantes
- brief du matin
- rotation de planning
- alerte de repos
- import par la feuille de partage (ou son repli)
- semaines toutes différentes gérées sans hypothèse d'horaires
- vérificateur de fiche de paie
- préparation d'entretien
- générateur de disponibilités
- prédiction d'heure de fin
- carnet d'expériences
- détecteur de changements de planning
- journal infalsifiable
- équilibrage des heures du contrat
- détection de motifs de planning
- prévision de charge
- mode bac en approche
- retour de congé
- carte de chaleur annuelle
- mémos de lieu
- cohérence du trajet
- trace de retard
- régularisation des heures payées
- alerte de proximité du quota
- plannings proposés
- simulateur de semaine en direct
- jours fériés de l'année
- comparaison avec ton passé
- périodes bloquées
- arbitrage cours contre travail
- aperçu de fin de semaine adapté à l'utilisateur
- anticipation des périodes creuses
- historique des plannings
- préparation de départ en vacances
- planning par texte
- équipe et échanges malins
- carte Maintenant
- notifications qui apprennent
- gains en direct
- pile intelligente et contrôles
- vrai taux horaire
- fiabilité des données
- annuler partout et instantanés
- Concentration guidée
- widget "encore X h"
- délai de prévenance
- auto-calibration des lieux
- récupération après batterie vide
- assistant de dépannage
- galerie de widgets (familles, styles, modes d'apparence, confidentialité sur l'écran verrouillé)
- Live Activity démarrée par notification, avec relance après la limite de 8 heures
- signaux de secours
- sauvegarde automatique dans un dossier Fichiers
- protection à la capture et mode démo
- Demande-moi tout avec repli
- scanner de planning papier
- phase de rodage
- contrôle de l'horloge
- règles selon l'âge
- heures pleines avec propositions en cas de doute
- demande de dernière minute
- emploi du temps scolaire
- temps annexes
- compteurs de contraintes
- période de paie personnalisée
- vérificateur de contrat avant signature
- carnet de stage ou d'alternance
- rejouer ma journée
- termes expliqués
- déplacements entre sites
- agenda perso comme contrainte
- assistant de journée
- centre de fiabilité
- questions en langage naturel sans modèle
- bilan hebdomadaire "Ta semaine"
