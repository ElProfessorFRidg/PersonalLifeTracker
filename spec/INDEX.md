# INDEX DE LA SPEC

Lire UNIQUEMENT les sections utiles : `python3 scripts/spec_section.py N`.

| § | Mots | Titre | Fichier |
|---|---|---|---|
| 0 | 90 | MISSION | spec/sections/S000-mission.md |
| 1 | 589 | ORGANISATION AVEC SUBAGENTS | spec/sections/S001-organisation-avec-subagents.md |
| 2 | 143 | PROFIL ET CONTEXTE D'USAGE | spec/sections/S002-profil-et-contexte-d-usage.md |
| 3 | 397 | MODULARITÉ : LES FONCTIONS OPTIONNELLES NE SONT JAMAIS OBLIGATOIRES | spec/sections/S003-modularit-les-fonctions-optionnelles-ne-.md |
| 4 | 2946 | SCÉNARIOS DE RÉFÉRENCE (base des tests d'intégration) | spec/sections/S004-scnarios-de-rfrence.md |
| 5 | 140 | PERFORMANCE (PRIORITÉ ABSOLUE) | spec/sections/S005-performance.md |
| 6 | 234 | TECHNOLOGIES ET CONTRAINTES | spec/sections/S006-technologies-et-contraintes.md |
| 7 | 119 | ARCHITECTURE | spec/sections/S007-architecture.md |
| 8 | 208 | GÉOLOCALISATION ET AUTORISATION ALWAYS | spec/sections/S008-golocalisation-et-autorisation-always.md |
| 9 | 105 | APPRENTISSAGE DES HABITUDES | spec/sections/S009-apprentissage-des-habitudes.md |
| 10 | 121 | AJOUT ET CONFIGURATION D'UN LIEU | spec/sections/S010-ajout-et-configuration-d-un-lieu.md |
| 11 | 252 | LOGIQUE TRAVAIL CONTRE COURSES | spec/sections/S011-logique-travail-contre-courses.md |
| 12 | 53 | ÉTUDES | spec/sections/S012-tudes.md |
| 13 | 834 | HORAIRES INTELLIGENTS ET NORMALISATION | spec/sections/S013-horaires-intelligents-et-normalisation.md |
| 14 | 94 | SESSIONS | spec/sections/S014-sessions.md |
| 15 | 133 | SAISIE MANUELLE, IMPORT ET DÉMARRAGE RAPIDE | spec/sections/S015-saisie-manuelle-import-et-dmarrage-rapid.md |
| 16 | 213 | PLANNING PAR PHOTO (module planning_ocr) | spec/sections/S016-planning-par-photo.md |
| 17 | 53 | DÉCOUVERTE AUTOMATIQUE DES LIEUX (module place_discovery) | spec/sections/S017-dcouverte-automatique-des-lieux.md |
| 18 | 275 | EMPLOYEURS ET CONTRATS (module employment, puis multi_employer) | spec/sections/S018-employeurs-et-contrats.md |
| 19 | 289 | CYCLE DE VIE DU CONTRAT ET FIN DE CONTRAT (module employment) | spec/sections/S019-cycle-de-vie-du-contrat-et-fin-de-contra.md |
| 20 | 431 | SALAIRE, PAIE ET ESTIMATIONS (module pay) | spec/sections/S020-salaire-paie-et-estimations.md |
| 21 | 220 | CONVENTIONS COLLECTIVES : RECHERCHE ET CHOIX (module pay) | spec/sections/S021-conventions-collectives-recherche-et-cho.md |
| 22 | 486 | PACKS DE CONVENTION (module pay) | spec/sections/S022-packs-de-convention.md |
| 23 | 252 | CONGÉS PAYÉS (module leave, exige employment) | spec/sections/S023-congs-pays.md |
| 24 | 199 | SIMULATEUR "ET SI ?" (module simulator, exige pay) | spec/sections/S024-simulateur-et-si.md |
| 25 | 69 | PRÉVU CONTRE RÉEL (module pay) | spec/sections/S025-prvu-contre-rel.md |
| 26 | 81 | PRIMES ET INDEMNITÉS (module pay) | spec/sections/S026-primes-et-indemnits.md |
| 27 | 63 | DATE DE PAIE ATTENDUE (module pay_date, exige pay) | spec/sections/S027-date-de-paie-attendue.md |
| 28 | 37 | BANQUE D'HEURES (fusionnée dans la section 106.4) | spec/sections/S028-banque-d-heures.md |
| 29 | 93 | SEUIL FISCAL (module tax_threshold, exige pay) | spec/sections/S029-seuil-fiscal.md |
| 30 | 64 | CALENDRIER SCOLAIRE, VACANCES ET JOURS FÉRIÉS (module school_calendar) | spec/sections/S030-calendrier-scolaire-vacances-et-jours-fr.md |
| 31 | 64 | MODE EXAMENS (module exam_mode) | spec/sections/S031-mode-examens.md |
| 32 | 129 | PAUSES (module breaks) | spec/sections/S032-pauses.md |
| 33 | 75 | ALERTE NUIT COURTE (module short_night) | spec/sections/S033-alerte-nuit-courte.md |
| 34 | 68 | CRÉNEAUX LIBRES DE RÉVISION (module study_slots) | spec/sections/S034-crneaux-libres-de-rvision.md |
| 35 | 161 | TRAJET ET "PARS MAINTENANT" (module travel_departure) | spec/sections/S035-trajet-et-pars-maintenant.md |
| 36 | 108 | COÛT DU TRAJET (module travel_cost, optionnel, désactivé par défaut) | spec/sections/S036-cot-du-trajet.md |
| 37 | 90 | "JE RENTRE" (module going_home, optionnel, désactivé par défaut) | spec/sections/S037-je-rentre.md |
| 38 | 95 | OBJECTIFS D'ÉPARGNE (module savings, exige pay) | spec/sections/S038-objectifs-d-pargne.md |
| 39 | 40 | NOTES DE JOURNÉE (module notes) | spec/sections/S039-notes-de-journe.md |
| 40 | 277 | BILANS MENSUELS ET ANNUELS, FAÇON WRAPPED (module recaps) | spec/sections/S040-bilans-mensuels-et-annuels-faon-wrapped.md |
| 41 | 173 | RECHERCHE GLOBALE (module search) | spec/sections/S041-recherche-globale.md |
| 42 | 121 | RAPPEL D'ENVOI DES HEURES (module send_hours_reminder, exige employment) | spec/sections/S042-rappel-d-envoi-des-heures.md |
| 43 | 171 | CONCENTRATION (module focus) | spec/sections/S043-concentration.md |
| 44 | 551 | LIVE ACTIVITY, WIDGETS ET APP INTENTS (module live_activity_widgets) | spec/sections/S044-live-activity-widgets-et-app-intents.md |
| 45 | 134 | NOTIFICATIONS LOCALES | spec/sections/S045-notifications-locales.md |
| 46 | 54 | REVUE DE LA SEMAINE (module weekly_review) | spec/sections/S046-revue-de-la-semaine.md |
| 67 | 156 | SUIVI DES FRAIS (module expenses, désactivé par défaut) | spec/sections/S067-suivi-des-frais.md |
| 68 | 145 | MODE REMPLACEMENT (module replacements, désactivé par défaut) | spec/sections/S068-mode-remplacement.md |
| 69 | 133 | HISTORIQUE DES TAUX HORAIRES (partie du module pay) | spec/sections/S069-historique-des-taux-horaires.md |
| 70 | 124 | ALERTE PLANNING TARDIF (réglage du module planning_ocr, désactivé par défaut) | spec/sections/S070-alerte-planning-tardif.md |
| 71 | 131 | STATISTIQUES DE RÉGULARITÉ (module regularity, désactivé par défaut) | spec/sections/S071-statistiques-de-rgularit.md |
| 72 | 164 | JOURNAL DE CONTRAT (module contract_journal, exige employment, désactivé par défaut) | spec/sections/S072-journal-de-contrat.md |
| 73 | 182 | MODE VACANCES DE L'APP (module vacation_mode, désactivé par défaut) | spec/sections/S073-mode-vacances-de-l-app.md |
| 74 | 131 | CONTACTS DU TAF (module work_contacts, désactivé par défaut) | spec/sections/S074-contacts-du-taf.md |
| 75 | 144 | RAPPEL DE BADGEUSE ET COMPARAISON (module badge_reminder, exige employment, désactivé par défaut) | spec/sections/S075-rappel-de-badgeuse-et-comparaison.md |
| 76 | 144 | CHECK AVANT DE PARTIR (module departure_checklist, désactivé par défaut) | spec/sections/S076-check-avant-de-partir.md |
| 77 | 180 | CORRECTIONS À LA VOIX (module voice_corrections, désactivé par défaut) | spec/sections/S077-corrections-la-voix.md |
| 78 | 116 | ÉQUILIBRE DE LA SEMAINE (module weekly_balance, désactivé par défaut) | spec/sections/S078-quilibre-de-la-semaine.md |
| 79 | 91 | RÉSUMÉ PARTAGEABLE (module share_summary, désactivé par défaut) | spec/sections/S079-rsum-partageable.md |
| 80 | 140 | DOSSIER JUSTIFICATIF (module proof_pack, désactivé par défaut) | spec/sections/S080-dossier-justificatif.md |
| 81 | 147 | CARNET D'ÉCHANGES DE CRÉNEAUX (module shift_swaps, désactivé par défaut) | spec/sections/S081-carnet-d-changes-de-crneaux.md |
| 82 | 116 | COMPTE À REBOURS DE FIN DE JOURNÉE (module end_of_day_countdown, désactivé par défaut) | spec/sections/S082-compte-rebours-de-fin-de-journe.md |
| 83 | 118 | MODE "JOURNÉE DIFFICILE" (module rough_day, désactivé par défaut) | spec/sections/S083-mode-journe-difficile.md |
| 84 | 153 | PRÉVISION DES PRIMES DE DIMANCHE ET DE FÉRIÉ (module premium_planner, exige pay, désactivé par défaut) | spec/sections/S084-prvision-des-primes-de-dimanche-et-de-fr.md |
| 85 | 157 | PRÉVISION DU SOLDE DE FIN DE MOIS (module month_forecast, exige pay, désactivé par défaut) | spec/sections/S085-prvision-du-solde-de-fin-de-mois.md |
| 86 | 213 | DÉTECTION D'HEURES MANQUANTES (module missing_hours, proposé et coché par défaut) | spec/sections/S086-dtection-d-heures-manquantes.md |
| 87 | 185 | BRIEF DU MATIN (module morning_brief, désactivé par défaut) | spec/sections/S087-brief-du-matin.md |
| 88 | 181 | ROTATION DE PLANNING SEMAINE A/B (module schedule_rotation, exige planning_ocr, désactivé par défaut) | spec/sections/S088-rotation-de-planning-semaine-a-b.md |
| 89 | 140 | ALERTE DE JOURS CONSÉCUTIFS ET DE REPOS HEBDOMADAIRE (module rest_alert, exige employment, désactivé par défaut) | spec/sections/S089-alerte-de-jours-conscutifs-et-de-repos-h.md |
| 90 | 186 | IMPORT PAR LA FEUILLE DE PARTAGE (module share_import, désactivé par défaut) | spec/sections/S090-import-par-la-feuille-de-partage.md |
| 91 | 357 | PLANNING VARIABLE : TOUTES LES SEMAINES PEUVENT ÊTRE DIFFÉRENTES (principe transversal) | spec/sections/S091-planning-variable-toutes-les-semaines-pe.md |
| 92 | 207 | VÉRIFICATEUR DE FICHE DE PAIE (module payslip_check, exige pay, désactivé par défaut) | spec/sections/S092-vrificateur-de-fiche-de-paie.md |
| 93 | 220 | PRÉPARATION D'ENTRETIEN (module interview_prep, exige employment et pay, désactivé par défaut) | spec/sections/S093-prparation-d-entretien.md |
| 94 | 127 | GÉNÉRATEUR DE DISPONIBILITÉS (module availability_planner, désactivé par défaut) | spec/sections/S094-gnrateur-de-disponibilits.md |
| 95 | 126 | PRÉDICTION D'HEURE DE FIN (module end_prediction, désactivé par défaut) | spec/sections/S095-prdiction-d-heure-de-fin.md |
| 96 | 156 | CARNET D'EXPÉRIENCES (module experience_log, désactivé par défaut) | spec/sections/S096-carnet-d-expriences.md |
| 97 | 153 | DÉTECTEUR DE CHANGEMENTS DE PLANNING (module planning_diff, exige planning_ocr, désactivé par défaut) | spec/sections/S097-dtecteur-de-changements-de-planning.md |
| 98 | 186 | JOURNAL INFALSIFIABLE (module tamper_log, désactivé par défaut) | spec/sections/S098-journal-infalsifiable.md |
| 99 | 170 | PRÉVISION DE CHARGE DE LA SEMAINE (module load_forecast, désactivé par défaut) | spec/sections/S099-prvision-de-charge-de-la-semaine.md |
| 100 | 148 | MODE "BAC EN APPROCHE" (module exam_budget, exige exam_mode, désactivé par défaut) | spec/sections/S100-mode-bac-en-approche.md |
| 101 | 111 | ASSISTANT DE RETOUR DE CONGÉ (module return_recap, désactivé par défaut) | spec/sections/S101-assistant-de-retour-de-cong.md |
| 102 | 120 | CARTE DE CHALEUR ANNUELLE (module heatmap, désactivé par défaut) | spec/sections/S102-carte-de-chaleur-annuelle.md |
| 103 | 126 | MÉMOS DE CONTEXTE PAR LIEU (module place_memos, désactivé par défaut) | spec/sections/S103-mmos-de-contexte-par-lieu.md |
| 104 | 107 | COHÉRENCE DU TRAJET (module travel_calibration, exige travel_departure, désactivé par défaut) | spec/sections/S104-cohrence-du-trajet.md |
| 105 | 130 | TRACE DE RETARD (module delay_log, désactivé par défaut) | spec/sections/S105-trace-de-retard.md |
| 106 | 754 | ÉQUILIBRAGE DES HEURES DU CONTRAT (module contract_hours, exige employment, proposé et coché par défaut) | spec/sections/S106-quilibrage-des-heures-du-contrat.md |
| 107 | 428 | DÉTECTION DE MOTIFS DE PLANNING ET SUGGESTIONS INTELLIGENTES (module pattern_detection, proposé et coché par défaut) | spec/sections/S107-dtection-de-motifs-de-planning-et-sugges.md |
| 108 | 192 | RÉGULARISATION DES HEURES PAYÉES (module pay_reconciliation, exige pay et contract_hours, désactivé par défaut) | spec/sections/S108-rgularisation-des-heures-payes.md |
| 109 | 133 | ALERTE DE PROXIMITÉ DU QUOTA (réglage du module contract_hours, désactivé par défaut) | spec/sections/S109-alerte-de-proximit-du-quota.md |
| 110 | 206 | PLANNINGS PROPOSÉS (module plan_proposals, exige employment, désactivé par défaut) | spec/sections/S110-plannings-proposs.md |
| 111 | 111 | SIMULATEUR DE SEMAINE EN DIRECT (mode du module simulator, section 24) | spec/sections/S111-simulateur-de-semaine-en-direct.md |
| 112 | 99 | JOURS FÉRIÉS DE L'ANNÉE (module holiday_outlook, désactivé par défaut) | spec/sections/S112-jours-fris-de-l-anne.md |
| 113 | 120 | COMPARAISON AVEC TON PROPRE PASSÉ (module self_compare, désactivé par défaut) | spec/sections/S113-comparaison-avec-ton-propre-pass.md |
| 114 | 308 | PÉRIODES BLOQUÉES : JOUR, SEMAINE OU PLAGE (module blocked_periods, désactivé par défaut) | spec/sections/S114-priodes-bloques-jour-semaine-ou-plage.md |
| 115 | 168 | ARBITRAGE COURS CONTRE TRAVAIL (module class_work_tradeoff, désactivé par défaut) | spec/sections/S115-arbitrage-cours-contre-travail.md |
| 116 | 184 | APERÇU DE TA FIN DE SEMAINE (module weekend_preview, désactivé par défaut) | spec/sections/S116-aperu-de-ta-fin-de-semaine.md |
| 117 | 145 | ANTICIPATION DES PÉRIODES CREUSES (module low_period_alert, exige employment, désactivé par défaut) | spec/sections/S117-anticipation-des-priodes-creuses.md |
| 118 | 122 | HISTORIQUE DES PLANNINGS CONSULTABLE (module schedule_archive, exige planning_ocr, proposé et coché par défaut) | spec/sections/S118-historique-des-plannings-consultable.md |
| 119 | 161 | PRÊT À PARTIR EN VACANCES (module vacation_prep, désactivé par défaut) | spec/sections/S119-prt-partir-en-vacances.md |
| 120 | 218 | ÉQUIPE ET ÉCHANGES MALINS (module team_swaps, exige planning_ocr, désactivé par défaut) | spec/sections/S120-quipe-et-changes-malins.md |
| 121 | 202 | PLANNING PAR TEXTE (module planning_text, exige planning_ocr, désactivé par défaut) | spec/sections/S121-planning-par-texte.md |
| 122 | 228 | MAINTENANT : UNE SEULE CHOSE À FAIRE (module now_card, proposé et coché par défaut) | spec/sections/S122-maintenant-une-seule-chose-faire.md |
| 123 | 197 | NOTIFICATIONS QUI APPRENNENT (module smart_notifications, proposé et coché par défaut) | spec/sections/S123-notifications-qui-apprennent.md |
| 124 | 198 | COMPTEUR DE GAINS EN DIRECT (module live_earnings, exige pay, désactivé par défaut) | spec/sections/S124-compteur-de-gains-en-direct.md |
| 125 | 160 | PILE INTELLIGENTE ET CONTRÔLES (réglage du module live_activity_widgets, activé avec lui) | spec/sections/S125-pile-intelligente-et-contrles.md |
| 126 | 172 | TON VRAI TAUX HORAIRE (module true_hourly_rate, exige pay, désactivé par défaut) | spec/sections/S126-ton-vrai-taux-horaire.md |
| 127 | 147 | SCORE DE FIABILITÉ DES DONNÉES (module data_trust, proposé et coché par défaut) | spec/sections/S127-score-de-fiabilit-des-donnes.md |
| 128 | 219 | ANNULER PARTOUT ET INSTANTANÉS (module undo_safety, proposé et coché par défaut) | spec/sections/S128-annuler-partout-et-instantans.md |
| 129 | 180 | DÉLAI DE PRÉVENANCE (module notice_check, exige planning_ocr et employment, désactivé par défaut) | spec/sections/S129-dlai-de-prvenance.md |
| 130 | 137 | AUTO-CALIBRATION DES LIEUX (module place_calibration, proposé et coché par défaut) | spec/sections/S130-auto-calibration-des-lieux.md |
| 131 | 210 | RÉCUPÉRATION APRÈS BATTERIE VIDE OU EXTINCTION (module battery_recovery, proposé et coché par défaut) | spec/sections/S131-rcupration-aprs-batterie-vide-ou-extinct.md |
| 132 | 166 | ASSISTANT DE DÉPANNAGE : "POURQUOI L'APP A RATÉ ÇA ?" (module detection_help, proposé et coché par défaut) | spec/sections/S132-assistant-de-dpannage-pourquoi-l-app-a-r.md |
| 133 | 877 | GALERIE DE WIDGETS : FORMATS, STYLES ET PERSONNALISATION (extension du module live_activity_widgets) | spec/sections/S133-galerie-de-widgets-formats-styles-et-per.md |
| 134 | 248 | SIGNAUX DE SECOURS (module backup_signals, désactivé par défaut) | spec/sections/S134-signaux-de-secours.md |
| 135 | 218 | SAUVEGARDE AUTOMATIQUE DANS UN DOSSIER FICHIERS (module folder_backup, proposé et coché par défaut) | spec/sections/S135-sauvegarde-automatique-dans-un-dossier-f.md |
| 136 | 193 | PROTECTION À LA CAPTURE ET MODE DÉMO (module privacy_shield, proposé et coché par défaut) | spec/sections/S136-protection-la-capture-et-mode-dmo.md |
| 137 | 278 | DEMANDE-MOI TOUT (module ask_assistant, désactivé par défaut) | spec/sections/S137-demande-moi-tout.md |
| 138 | 155 | SCANNER DE PLANNING PAPIER (sous-fonction du module planning_ocr, activée avec lui) | spec/sections/S138-scanner-de-planning-papier.md |
| 139 | 158 | PHASE DE RODAGE (module break_in, proposé et coché par défaut) | spec/sections/S139-phase-de-rodage.md |
| 140 | 248 | CONTRÔLE DE L'HORLOGE (module clock_check, proposé et coché par défaut) | spec/sections/S140-contrle-de-l-horloge.md |
| 141 | 202 | RÈGLES SELON L'ÂGE (module age_rules, désactivé par défaut) | spec/sections/S141-rgles-selon-l-ge.md |
| 142 | 231 | DEMANDE DE DERNIÈRE MINUTE (module last_minute_offer, exige planning_text, désactivé par défaut) | spec/sections/S142-demande-de-dernire-minute.md |
| 143 | 155 | EMPLOI DU TEMPS SCOLAIRE (module school_timetable, proposé et coché par défaut) | spec/sections/S143-emploi-du-temps-scolaire.md |
| 144 | 146 | TEMPS ANNEXES (module extra_time, exige employment, désactivé par défaut) | spec/sections/S144-temps-annexes.md |
| 145 | 116 | COMPTEURS DE CONTRAINTES (module constraint_counters, exige employment, désactivé par défaut) | spec/sections/S145-compteurs-de-contraintes.md |
| 146 | 140 | PÉRIODE DE PAIE PERSONNALISÉE (module pay_period, exige pay, désactivé par défaut) | spec/sections/S146-priode-de-paie-personnalise.md |
| 147 | 147 | VÉRIFICATEUR DE CONTRAT AVANT SIGNATURE (module contract_check, exige pay, désactivé par défaut) | spec/sections/S147-vrificateur-de-contrat-avant-signature.md |
| 148 | 123 | CARNET DE STAGE OU D'ALTERNANCE (module internship_log, désactivé par défaut) | spec/sections/S148-carnet-de-stage-ou-d-alternance.md |
| 149 | 138 | REJOUER MA JOURNÉE (module day_replay, désactivé par défaut) | spec/sections/S149-rejouer-ma-journe.md |
| 150 | 86 | TERMES EXPLIQUÉS (module glossary, proposé et coché par défaut) | spec/sections/S150-termes-expliqus.md |
| 151 | 116 | DÉPLACEMENTS ENTRE SITES (module multi_site, exige employment, désactivé par défaut) | spec/sections/S151-dplacements-entre-sites.md |
| 152 | 132 | AGENDA PERSO COMME CONTRAINTE (module calendar_constraints, désactivé par défaut) | spec/sections/S152-agenda-perso-comme-contrainte.md |
| 153 | 312 | ASSISTANT DE JOURNÉE (module day_assistant, proposé et coché par défaut) | spec/sections/S153-assistant-de-journe.md |
| 154 | 212 | CENTRE DE FIABILITÉ (module reliability_center, proposé et coché par défaut) | spec/sections/S154-centre-de-fiabilit.md |
| 47 | 293 | INTERFACE ET UX | spec/sections/S047-interface-et-ux.md |
| 48 | 293 | ONBOARDING | spec/sections/S048-onboarding.md |
| 49 | 251 | RÉGLAGES ET PERSONNALISATION | spec/sections/S049-rglages-et-personnalisation.md |
| 50 | 159 | VOIX ET TON DE L'APPLICATION | spec/sections/S050-voix-et-ton-de-l-application.md |
| 51 | 279 | DÉTECTION DES CAPACITÉS ET ÉCRAN "ÉTAT DE L'APP" | spec/sections/S051-dtection-des-capacits-et-cran-tat-de-l-a.md |
| 52 | 63 | FIABILITÉ ET DIAGNOSTIC | spec/sections/S052-fiabilit-et-diagnostic.md |
| 53 | 79 | DONNÉES ET PERSISTANCE | spec/sections/S053-donnes-et-persistance.md |
| 54 | 177 | ICLOUD ET CLOUDKIT (module icloud, facultatif) | spec/sections/S054-icloud-et-cloudkit.md |
| 55 | 79 | CONFIDENTIALITÉ ET SÉCURITÉ | spec/sections/S055-confidentialit-et-scurit.md |
| 56 | 52 | MODE TEST GPX | spec/sections/S056-mode-test-gpx.md |
| 57 | 184 | CI/CD ET GITHUB ACTIONS | spec/sections/S057-ci-cd-et-github-actions.md |
| 58 | 62 | QUALITÉ DU CODE | spec/sections/S058-qualit-du-code.md |
| 59 | 228 | TESTS | spec/sections/S059-tests.md |
| 60 | 281 | ORDRE DE LIVRAISON (MVP D'ABORD) | spec/sections/S060-ordre-de-livraison.md |
| 61 | 65 | RÈGLES DE TRAVAIL DANS LE DÉPÔT | spec/sections/S061-rgles-de-travail-dans-le-dpt.md |
| 62 | 185 | CRITÈRES D'ACCEPTATION | spec/sections/S062-critres-d-acceptation.md |
| 63 | 120 | LIVRABLES | spec/sections/S063-livrables.md |
| 64 | 78 | RAPPORT FINAL | spec/sections/S064-rapport-final.md |
| 65 | 1039 | CE QUE L'APP NE DOIT PAS FAIRE | spec/sections/S065-ce-que-l-app-ne-doit-pas-faire.md |
| 66 | 112 | INSTRUCTION FINALE | spec/sections/S066-instruction-finale.md |

## Quoi lire selon la phase

- Phase 0 (UI) : 3, 13 (zone de doute), 44.1, 47, 48, 49, 50, 51, 122, 133, 154.
- Phase 1 (CI/CD) : 6, 7, 57 et docs/CI-CD.md.
- Phase 2 : section 60 (ordre), puis `module_info.py --step N`, jamais le fichier entier.
