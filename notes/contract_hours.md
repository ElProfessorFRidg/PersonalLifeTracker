# contract_hours : équilibrage des heures du contrat (sections 28, 106, 109)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile. Aucun commit fait.

## Fait
- `App/Core/Logic/ContractHoursBalance.swift` (pur, Foundation seulement) : `ContractHoursBalance.report(contract:sessions:planned:today:rule:calendar:)`.
  - Par semaine ISO (lundi, calendrier explicite) : quota, réalisé, planifié restant, projection, écart, statut (dans le contrat, en dessous, au-dessus, en cours, à confirmer), barres jour par jour prévu contre réalisé (106.2).
  - Phrases de 106.3 (`ContractHoursText.headline`) : cas vendredi 4 h (9 h restantes, planning 13 h, fin à 17 h, 4 h de plus), 13 h pile, 5 h au-dessus, 3 h manquantes.
  - Compteurs 106.4 : heures d'avance, heures à rattraper, heures payées en plus, selon le réglage "ce qui se passe réellement" (à renseigner, reporté, lissé sur le mois, payé en plus, non reporté).
  - Distribution 106.6 (moyenne, min, max, nombre de dépassements, dépassement récurrent signalé doucement).
  - Suggestions 106.3 et 106.7 (rien à changer, comment sont comptées les heures en plus, où placer les heures, répartition égale).
  - Alerte de proximité 109 (`quotaAlert`) : seuils 2 h, 1 h, atteint, session en cours incluse, paramètre `suppressed`.
  - Semaines partielles (début et fin de contrat), semaines à cheval sur un mois (mois du jeudi) et sur une année (semaine 53 et 1), changement d'heure (découpe au prorata du temps réel, somme exacte).
- Écran `ContratHeuresView()` (App/Features/ContratHeures/) : alerte en bandeau, carte de la semaine (jauge avec repère du contrat, fait, prévu, reste, projection), jour par jour, "Ce que je te propose", compteurs, historique en barres (au-dessus en accent, en dessous en neutre, trait du contrat) avec lignes semaine par semaine, états module désactivé, pas de contrat, contrat pas commencé, contrat terminé, pas de quota. Feuilles : règle (106.4), classement des heures (106.5, sans chiffre), répartition, alerte.
- Réglages par employeur dans UserDefaults (`plt.contracthours.<réglage>.<uid>`), aucun modèle SwiftData touché.
- EmploiView : liens "Mes heures au contrat" (module contract_hours) et "Congés" (module leave). `isAvailable: true` pour contract_hours.
- Tests : Tests/UnitTests/ContractHoursBalanceTests.swift, 21 tests, valeurs calculées à la main (13 h pile, 10 h, 18 h, vendredi 4 h avec planning, alerte de part et d'autre du seuil, première et dernière semaine partielles, semaine 53 et 1, mois à cheval, semaine du changement d'heure du 25 octobre 2026).

## Pas fait
- Planning réel : la liste des créneaux planifiés est vide côté écran (PlannedShift d'un autre agent non branché). La projection vaut donc le réalisé, et l'écran le dit. La logique et les tests acceptent déjà des créneaux.
- Congés, absences, créneau annulé : réglage "comment compter un créneau prévu non travaillé" absent, aucune coupure de l'alerte pendant les congés, les vacances ou une période bloquée (`suppressed` existe, rien ne l'alimente). L'écran de l'alerte le dit.
- Notification réelle de l'alerte, heures silencieuses, un rappel par seuil, affichage Live Activity : seulement le bandeau dans l'écran.
- Limites autres que le quota du contrat (plafond personnel, plafond d'heures complémentaires, durée maximale) : pas de pack de convention (Resources/reference/contracts.json absent), donc aucun classement, majoration ni plafond chiffré. La feuille dit "à renseigner" et "à vérifier".
- Repos compensateur : ligne "À renseigner", aucun calcul ni expiration.
- Période de référence autre que la semaine (quinzaine, mois, annualisation), historisation du quota par avenant (un seul contrat à la fois, celui de l'écran Emploi), contrat de période différente de la paie.
- multi_employer : toutes les sessions de type Taf sont comptées pour l'employeur affiché, sans rattachement. Le sélecteur d'employeur change seulement le contrat comparé.
- Aide à la répartition qui lit disponibilités, repos et motifs (106.7) : répartition égale seulement.
- Interactions paie, simulateur, rappel d'envoi (106.8) : non branchées.

## Choix hors spec
- Semaine partielle : quota proratisé au nombre de jours couverts par le contrat sur 7, arrondi à la minute (13 h sur 4 jours = 446 min). La spec ne donne pas de règle. Signalé "Semaine partielle, à vérifier avec ton contrat". Ces semaines sont exclues de la moyenne.
- Semaine en cours sans créneau prévu : statut "En cours" (pas "en dessous du contrat") tant que le réalisé n'atteint pas le quota, pour ne pas alarmer un lundi.
- Une session à cheval sur deux jours ou deux semaines est répartie au prorata du temps réel (cumul arrondi, la somme reste exacte).
- Session en cours : comptée à l'exact jusqu'à maintenant (comme DaySummary). Session finie avec doute non résolu ou non confirmée : exclue et marquée "à confirmer", la semaine passe en statut "À confirmer" et ne compte pas dans les compteurs.
- Compteurs : solde cumulé depuis le début du contrat (reporté), solde du mois de la semaine la plus récente (lissé, mois du jeudi), trop seulement (payé), zéro (non reporté ou à renseigner). Seules les semaines finies comptent.
- Un dépassement est "récurrent" à partir de 4 semaines et si au moins la moitié dépasse (la spec cite 5 sur 8). Stats sur les 8 dernières semaines finies pleines.
- Alerte : seuils par employeur 2 h (coché), 1 h, atteint ; éteinte par défaut. Au-delà du quota, le bandeau dit "Tu es X au-dessus de ton quota".
- Phrases avec unité ("ton planning en prévoit 13 h") là où la spec écrit "13".
- Les jours restants comptent aujourd'hui en entier, même tard dans la journée.

## 5 lignes les plus risquées pour la compilation
1. ContratHeuresView.swift : `Picker("Employeur", selection: binding)` avec `Binding<UUID?>` construit par `Binding(get:set:)` et `.tag(Optional<UUID>(e.uid))`.
2. ContratHeuresView.swift : `@ViewBuilder private func suggestionRow(...)` avec `switch` et `case .placeMissing(let minutes, _)`, sous-titres en ternaires multilignes.
3. ContratHeuresParts.swift : `GeometryReader { (geo: GeometryProxy) in let width ...; ZStack { ... } }` (instruction `let` dans un ViewBuilder) et `strokeBorder(_, style: StrokeStyle(...))`.
4. ContratHeuresSheets.swift : `ForEach(HoursCarryRule.allCases, id: \.rawValue) { ... let isSelected ...; PLTRow(...).accessibilityAddTraits(traits) }`.
5. ContractHoursBalance.swift : `let status: WeekStatus` initialisé dans une chaîne if / else if, et la signature de tuple `(year: Int, week: Int)` renvoyée par `isoWeek`.
Tests à surveiller : , le test du changement d'heure (dépend de la base de fuseaux Europe/Paris du simulateur).
Mutation légère à la main : non faite ici (changer 120 en 121 dans le seuil de l'alerte doit faire échouer `testAlertThresholdBothSides`).
