## 126. TON VRAI TAUX HORAIRE (module true_hourly_rate, exige pay, désactivé par défaut)

Calcule ce que rapporte vraiment une heure : (net estimé moins frais directs) divisé par (heures travaillées plus temps de trajet plus temps de préparation ou d'attente).
- Entrées : net du module pay sur la période choisie (semaine, mois, trois mois, depuis le début), frais du module expenses et coût du trajet (section 36) s'ils sont actifs, remboursements déduits, heures confirmées, temps de trajet réel observé ou estimé (aller-retour), temps de préparation saisi (par exemple 10 minutes par session, facultatif), temps de présence non payé.
- Affichage : "Taux net du contrat 9,50 € de l'heure, vrai taux 7,80 € de l'heure (trajets et frais)", avec décomposition en barres. Hypothèses visibles et modifiables, "pas assez de données" sinon, sessions incertaines exclues, montants masquables en mode discret.
- Aucun jugement : l'app donne des faits, jamais un avis sur le fait de travailler ou non. Peut alimenter le simulateur (section 24) pour comparer, par exemple, deux modes de transport.
