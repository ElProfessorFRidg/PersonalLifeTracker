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
