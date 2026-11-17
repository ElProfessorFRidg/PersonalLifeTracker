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
