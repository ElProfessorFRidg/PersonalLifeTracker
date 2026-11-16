# pay : module paie, base (étape 5) + onglet Statistiques

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile et exécute. Si la CI est rouge, corriger ici d'abord.

## Fait
- `App/Core/Logic/PayCalculator.swift` (pur, Foundation + DaySummary/SessionDurations) : heures du mois par jour (coupe à minuit et aux frontières de mois), base heures pleines ou exacte, taux en vigueur chaque jour (historique), brut, net (ratio), montants en centimes entiers et Decimal, SMIC de référence (`SmicReference`), saisie (`parseAmount`), conversions brut/net, évolution en %, prévu contre réel (liste prévue vide pour l'instant), `PayPreferences` (ratio, surcharge SMIC, mode discret).
- `App/Core/Logic/PayExport.swift` : document JSON (clés triées, ISO 8601) et CSV (`;`, virgule décimale, `\r\n`, BOM ajouté seulement à l'écriture du fichier, champs protégés).
- `App/Core/Logic/StatsAggregator.swift` + `App/Features/Stats/StatsView.swift` : onglet Statistiques réel (semaine lundi à dimanche ou mois, navigation, base heures pleines/exact, totaux taf et cours, graphique empilé dessiné avec des formes SwiftUI à l'échelle de l'axe, moyennes, évolution, sessions à confirmer signalées).
- `App/Features/Paie/PaieView.swift` (`PaieView()`, poussé depuis Emploi qui l'appelle déjà), `PaieTauxView.swift` (historique des taux, ajout, SMIC en un tap, suppression avec confirmation, formulaire en feuille). États : module désactivé, pas de contrat, pas de taux, mois vide, estimation. Mode discret (masque, tap pour révéler). ShareLink CSV et JSON.
- `isAvailable: true` pour `pay` dans `ModuleRegistryData.swift`.
- Tests : `PayCalculatorTests` (29), `PayExportTests` (11), `StatsAggregatorTests` (13), valeurs calculées à la main.

## Pas fait
- Majorations (dimanche, soirée, férié), primes (section 26), conventions (sections 21 et 22) : étape 6. L'écran le dit explicitement ("je ne compte pas encore ...").
- Export PDF (section 20.2), scan de fiche de paie (20.3), abattement jeunes salariés (20.1), saisie d'un salaire mensuel (taux horaire seulement, brut ou net).
- Vue "Mon salaire dans le temps" en Swift Charts, comparaison avec le SMIC historique, proposition de mise à jour du taux quand le SMIC est revalorisé (section 69). Il y a seulement la liste datée avec l'évolution en %.
- Trace AuditEntry lors de la suppression d'un taux (le modèle n'existe pas dans mes fichiers) : la suppression dit honnêtement "aucune trace n'est gardée".
- Projection "si ton planning tient jusqu'au 30" (a besoin du planning, étape 7). Prévu contre réel : le calcul existe et est testé, l'écran l'affiche seulement si des créneaux existent (aujourd'hui `plannedSlots` est vide).
- Export du relevé : un jour par ligne, pas les arrivées et départs exacts et normalisés session par session, pas les pauses, pas de PDF.
- Statistiques : pas de ligne "Fiabilité des chiffres", pas de liste des courses non comptées.
- Pas de test d'interface, pas d'essai sur appareil.

## Valeurs qui sont des DONNÉES
| Valeur | Où | Date d'effet | Source | Vérifiée ? |
|---|---|---|---|---|
| SMIC horaire brut 12,02 EUR (1202 centimes) | `SmicReference.hourlyGrossCents` (`PayCalculator.swift`) | 1er janvier 2026 (`effectiveYear/Month/Day`) | service-public.fr (nom de la source, aucune page lue) | NON. Valeur issue du prototype et de ma mémoire, aucune vérification en ligne possible ici. L'UI écrit "pas vérifiée par l'app" et invite à vérifier. |
| Ratio net sur brut 0,79 | `PayPreferences.defaultNetRatio` | indicatif | section 20.1 de la spec | valeur de la spec, modifiable (Stepper, UserDefaults `plt.pay.netRatio`, bornes 0,50 à 1,00) |
Le SMIC est surchargeable par l'utilisateur (`plt.pay.smicOverride`, via "Garder cette valeur comme SMIC de référence"). Après une revalorisation, il faut changer la constante ET le test `testSmicReference` / `testSmicEffectiveDate...` / `testSmicStaleAfterSixMonths`.

## Choix qui ne sont pas dans la spec
- Divergence : la spec 20.1 veut le SMIC dans `Resources/reference/legal.json`, jamais en dur dans le Swift. La consigne de cette tâche demandait une constante nommée avec date. Fait en constante (un seul endroit). À migrer vers legal.json à l'étape 6 quand ce fichier existera (le dossier Resources n'existe pas encore).
- Un contrat de référence : la paie est calculée pour le contrat actif (le plus récent non terminé), avec un sélecteur s'il y en a plusieurs. Si `Contract.placeUIDs` n'est pas vide, seules les sessions de taf de ces lieux comptent, sinon toutes les sessions de taf.
- Si un contrat n'a aucun `PayRate` mais un `hourlyGrossRate`, ce taux vaut depuis le début du contrat.
- Les sessions non confirmées sont exclues des totaux et comptées à part (prototype : "Une session à confirmer n'est pas comptée"). Une session dont une borne est en zone de doute sans choix est comptée en exact et signalée (consigne), pas exclue.
- Taux : chaque jour prend le taux dont la date d'effet est ce jour ou avant (début de journée). Avant le premier taux, les heures sont comptées mais pas payées (`unratedSeconds`), affiché dans un bandeau. "Je suis au SMIC" propose comme date la plus tardive entre le début du contrat et la date d'effet du SMIC, pour ne pas appliquer 12,02 aux mois d'avant.
- Arrondi : par taux (une ligne = secondes x taux / 3600 arrondi au centime, arrondi commercial moitié vers le haut), le total est la somme des lignes (l'écran est cohérent au centime). Net = brut en centimes x ratio, arrondi au centime.
- Fuseau : un seul calendrier (`Calendar.current`) pour toute la paie, comme DaySummary, pas le `timeZoneID` de chaque session.
- Un taux saisi plus précis que 2 décimales est calculé sur 4 décimales mais affiché sur 2 par `formatMoney`.
- Deux taux à la même date d'effet pour un même contrat : refusé par le formulaire.
- Axe du graphique des statistiques : multiple de 2 h, au moins 2 h (prototype fixe 0 à 8 h).
- Les courses et trajets ne sont pas comptés dans les totaux des statistiques (prototype).

## Risques
- Le brut estimé ne contient ni majoration, ni prime, ni règle de convention : il sera plus bas qu'une vraie fiche. C'est écrit à l'écran, mais c'est le principal risque de mauvaise interprétation.
- SMIC non vérifié (voir plus haut).
- `Contract`, `Employer` et `PayRate` viennent de l'autre agent : si leur API change, `PaieView` et `PaieTauxView` cassent.
- Performance : `PayCalculator.month` appelle `DaySummary.total` deux fois par jour du mois, sur toutes les sessions du mois. Recalculé à chaque rendu de l'écran. Correct pour des milliers de sessions, pas mesuré.
- Les tests du SMIC encodent la valeur 12,02 : ils casseront volontairement à la prochaine revalorisation.
- Mutation légère à la main non faite (par exemple changer `.plain` en `.down` doit faire échouer `testRoundedCentsAvoidsBinaryErrors` et `testRoundingToCents`).

## 5 lignes les plus risquées pour la compilation
1. `PayCalculator.swift` : `NSDecimalRound(&result, &scaled, 0, .plain)` avec `var scaled: Decimal` et `var result: Decimal` (signature à pointeurs, `&` sur des `var` locales).
2. `PayCalculator.swift` : `var accumulators: [(rate: Decimal, seconds: Int)]` puis `accumulators[i].seconds += retained` dans `for i in 0..<accumulators.count where accumulators[i].rate == r`.
3. `PaieView.swift` : `.sheet(item: $formRequest) { (request: PaieRateFormRequest) in PaieTauxFormView(request: request) }` avec une struct `Identifiable` à `id` constant, et `@Query(sort: \Contract.startDate, order: .reverse)` sur un modèle de l'autre agent.
4. `PaieTauxView.swift` : `init(request:)` qui initialise `_text`, `_date`, `_note` avec `State(initialValue:)` alors que `note` a aussi une valeur par défaut et que `text` et `date` n'en ont pas.
5. `StatsView.swift` : `StatsBarChart` (ZStack avec `.offset(y:)` de graduations, `ForEach(0..<days.count, id: \.self)`, `@ViewBuilder private func bar(...)` avec `if/else` et `strokeBorder` dans `overlay`).
