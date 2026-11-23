## 23. CONGÉS PAYÉS (module leave, exige employment)

Un compteur de congés par employeur.
Règles : période de référence (défaut proposé après vérification des sources officielles, modifiable car la convention ou l'entreprise peut la fixer autrement), nombre de jours acquis par mois de travail effectif, unité (jours ouvrables ou ouvrés), périodes assimilées à du travail effectif (à renseigner), mode de calcul de l'indemnité (dixième ou maintien du salaire, le plus favorable, indicatif), indemnité compensatrice pour un CDD ou à la sortie. Toutes ces règles viennent de Resources/reference/leave.json avec sources et dates de vérification, rien en dur dans le Swift. L'agent les recherche sur service-public.fr et Légifrance, et marque "à vérifier" ce qui est incertain.
Fonctionnement :
- Solde de départ saisi ou lu sur la fiche de paie (acquis, pris, restant) avec la date du relevé. L'app calcule ensuite l'évolution à partir des mois travaillés.
- Calendrier des congés : poser des jours (pris ou prévus), par jour ou par plage, avec un statut (demandé, accepté, pris). Les jours de congé ne créent aucune fausse anomalie d'absence et sont exclus des attentes de session.
- Affichage : "Il te reste 12,5 jours", acquis, pris, prévus, date d'expiration de la période, projection ("à ce rythme, tu en auras 8 de plus").
- Alertes configurables : "Tes congés expirent le 31 mai, t'en as encore 6".
- Estimation de l'indemnité en euros, indicative, masquable en mode discret. Mode comparaison avec la fiche de paie. Pour un contrat court, indemnité compensatrice estimée à la fin.
