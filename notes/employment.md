# employment : employeurs, contrats, fin de contrat (sections 18 et 19)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile.

## Fait
- Modèles `Employer`, `Contract`, `PayRate`, `ContractKind` (contrat figé demandé), ajoutés au schéma (AppModelContainer).
- `ContractRules` (pur, Foundation) : contrat actif à une date (début et fin inclus, chevauchement : début le plus récent), jours restants (jours calendaires, pas 86 400 s), avancement, statut (à venir, essai, en cours, bientôt terminé à 14 jours, terminé), statut d'essai, rappels (essai 7 et 2 j, fin 14 et 3 j, 9 h, jamais dans le passé, pas pour un CDI), validation des dates et heures, actions proposées en fin de contrat, brouillons de renouvellement et de CDI, checklist de fin de contrat (7 lignes).
- Écrans : `EmploiView` (Réglages, module activé ou non, état vide, carte employeur avec décompte et barre, lignes du contrat, fin de contrat, autres contrats), feuilles `EmployeurEditView`, `ContratEditView` (type, dates, heures, taux facultatif, essai, lieux Taf), `FinContratChecklistSheet`, `IndemniteInfoSheet`. Lien "Paie" vers `PaieView()` si `pay` est actif. Entrée "Emploi" dans Réglages si `employment` est actif. `isAvailable: true`.
- Tests : Tests/UnitTests/ContractRulesTests.swift (valeurs écrites à la main : 23 jours du 16 nov au 9 déc, 76/99 d'avancement, changement d'heure du 25 oct 2026, bornes 14 et 15 jours, renouvellement au 19 mars 2027).

## Pas fait
- Notifications de rappel réellement planifiées (les rappels sont calculés et testés, pas envoyés). L'écran le dit.
- Anniversaire du contrat, alertes configurables, motif, nombre de renouvellements, période d'essai renouvelable.
- Indemnité de fin de contrat : aucun montant (Resources/reference/contracts.json n'existe pas, et la spec interdit de coder les règles en dur). La feuille l'explique et cite les sources à consulter.
- Convention collective (champ `conventionID` présent, pas d'écran), icône, paramètres de pause, rappel d'envoi des heures, statut archivé d'un employeur.
- multi_employer (rattachement session vers employeur, vue "Tout", conflits). L'UI montre tous les employeurs si plusieurs existent, sans sélecteur.
- Contrats par mois (heures par semaine seulement), jours et horaires habituels.
- Aucune vérification ni test d'UI. Pas de test de mutation à la main fait.

## Choix hors spec
- `Employer.colorHex` stocke une clé de ton de la palette ("work", "accent", "study", "errand"), pas un hexadécimal, pour respecter "pas de couleur en dur".
- Les lieux sont rattachés au contrat (`Contract.placeUIDs`, liste d'UUID), pas à l'employeur : le contrat figé n'a pas de champ lieux côté employeur.
- "Archivé" n'est pas un champ : un contrat est terminé par ses dates et reste affiché ("Autres contrats"). Suppression seulement pour une erreur de saisie (contrat) ou un employeur sans contrat.
- Cases de la checklist dans UserDefaults par contrat (`plt.employment.checklist.<uid>`), pas dans SwiftData (modèle figé).
- "Bientôt terminé" = 14 jours ou moins (aligné sur le rappel de 14 jours). Plafond de saisie 80 h par semaine : contrôle de plausibilité, pas une durée légale.
- Renouvellement : même durée en jours, commence le lendemain de la fin, sans essai. Les lieux du contrat le plus récent sont repris.
- "Taf" chip en dur sur la carte (Employeur = lieu de travail), conformément au prototype.

## Risques
- Relation `Employer.contracts` (cascade) avec inverse `Contract.employer` : déclaré d'un seul côté comme dans Place. Test `testEmployerContractsInverseRelationship` à surveiller.
- `PaieView()` n'existe que si l'agent pay l'a créé : sinon la CI échoue sur EmploiView.
- Le schéma gagne 3 modèles : les agents qui ajoutent aussi des modèles dans AppModelContainer peuvent entrer en conflit de fusion.
- Les modèles @Model non insérés (`Contract(...)` seul) sont utilisés dans un test.

## 5 lignes les plus risquées pour la compilation
1. `EmploiView.swift` : `NavigationLink { PaieView() } label: { PLTListGroup { ... } }` (type externe).
2. `EmploiView.swift` : `.sheet(isPresented: $showChecklist, onDismiss: { refreshChecked() }) { if let c = current { ... } }`.
3. `ContratEditView.swift` : init personnalisé avec `State(initialValue:)` et variables locales qui portent le nom des propriétés (`hours`, `rate`).
4. `ContratEditView.swift` : `ForEach(Array(issues.enumerated()), id: \.offset) { item in ... item.element ... }`.
5. `EmploiView.swift` : `let ratio: Double = ...` déclaré dans un `@ViewBuilder` imbriqué (VStack dans PLTCard).
