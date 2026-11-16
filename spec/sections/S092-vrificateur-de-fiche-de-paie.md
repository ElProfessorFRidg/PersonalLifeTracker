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
