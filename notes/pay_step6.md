# pay étape 6 : conventions, règles de paie, primes, relevé d'heures

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile et exécute. Si la CI est rouge, corriger ici d'abord.
Sections de la spec : 21, 22, 26 (20.2 pour le relevé).

## Fait
- `App/Core/Logic/ConventionPack.swift` (pur) : format Codable d'un pack (id, nom, IDCC, secteur, mots-clés, date de validité, date de vérification, note de source, liens, "à renseigner", règles), validation (`ConventionPackValidator`, 13 sortes d'erreurs en français), chargement de tous les `convention_*.json` du bundle (un fichier cassé est signalé, jamais un plantage), recherche tolérante (accents, casse, une faute sur les mots de 5 lettres ou plus, IDCC avec ou sans zéro), choix d'un pack depuis `Employer.conventionID` (identifiant de pack ou IDCC), surcharges de l'utilisateur par pack (UserDefaults, JSON, règle par règle, validées avant écriture), stockage des primes (UserDefaults, JSON, refuse d'écraser des données illisibles).
- `App/Core/Logic/PayRules.swift` (pur) : découpe d'une session en morceaux aux minuits et aux bornes de la fenêtre de nuit, classement normal / nuit / dimanche / férié, jours fériés légaux calculés (Pâques, Ascension, Pentecôte), heures au-delà du seuil par semaine ISO (lundi à dimanche, `firstWeekday = 2`, `minimumDaysInFirstWeek = 4`, calendrier explicite), majorations en centimes (Decimal, arrondi moitié vers le haut, une fois par ligne), primes (section 26), relevé d'heures (modèle, texte, CSV), lecture des saisies (`parsePercent`, `parseMoneyCents`, `parseHoursToMinutes`).
- `PayCalculator.swift` : ajout de `PayDetailResult` et `PayCalculator.monthDetail(...)` (base + majorations + primes). L'API existante (`month`, etc.) est inchangée : sans règle ni prime, le brut du détail égale le brut de `month`.
- `App/Resources/reference/convention_pack_generic.json` (pack général) et `convention_directory.json` (21 packs "coquilles" : nom et IDCC de la liste de la spec 22, plus le pack Personnalisé, AUCUNE règle).
- Écrans : `PaieConventionView` ("Ta convention" : recherche, liste, "Je ne sais pas", pack général, pack personnalisé ; `PaieConventionRulesView` : règles avec source et date, "à renseigner", choix, modification de chaque valeur dans `PaieRuleOverrideView`), `PaiePrimesView` (liste, ajout, modification, suppression), `PaieReleveView` (jour par jour avec catégories, totaux, partage en texte et CSV), `PaieSupport.swift` (contexte règles et primes). `PaieView` : brut et net avec majorations et primes, une ligne par majoration avec sa source, une ligne par prime "saisie par toi", alerte taux sous le minimum de la convention si un minimum est renseigné, liens vers convention, primes et relevé.
- Tests : `PayRulesTests` (61), `ConventionPackTests` (37) : bornes de nuit des deux côtés (20:59 à 21:01, 05:59 à 06:01, fin exclue), dimanche à cheval sur minuit (samedi vers dimanche, dimanche vers lundi), seuil exactement atteint (35 h pile : 0 ; une seconde de plus : 1), deux tranches, semaine à cheval sur deux mois, toutes les sortes de primes, erreurs de validation, recherche, surcharges, stockage. Valeurs calculées à la main (commentées dans les tests).

## Pas fait
- Aucun pack de convention avec de vraies règles : seul le pack général a des valeurs (voir plus bas). Les 21 autres sont des coquilles : tout y est "à renseigner". Je n'ai pas pu vérifier de source en ligne, donc je n'ai pas écrit d'exemple de convention.
- Pas de scan OCR de la fiche de paie pour trouver la convention (20.3, 21), pas de filtres par secteur, pas de rubrique "Les plus courantes" séparée (liste unique triée comme le fichier).
- Pas de primes suggérées par le pack (le format ne les porte pas).
- Pas d'import de pack depuis un fichier JSON ni de téléchargement par URL (section 22, option) : seuls les fichiers du bundle sont lus.
- Pas d'alerte de pause, de durée maximale quotidienne ou hebdomadaire, ni de repos de 11 h (section 22).
- Pas d'heures complémentaires du temps partiel (taux propres) : pour un temps partiel, l'utilisateur met son nombre d'heures au contrat comme seuil hebdomadaire.
- Pas de banque d'heures, pas d'Alsace-Moselle (jours fériés en plus).
- Relevé : pas de PDF, pas de temps annexes ni de période de paie de l'employeur, pas de mention "session corrigée ou reconstituée" (le modèle n'a pas cette information), pas de total sur l'autre base de calcul.
- Les exports CSV et JSON de l'étape 5 (`PayExport`) ne contiennent toujours ni majorations ni primes ; l'écran le dit et renvoie au relevé d'heures.
- Le SMIC reste une constante dans `SmicReference` (migration vers `legal.json` non faite : le fichier n'existe pas, je n'ai pas pu vérifier de valeur).
- Prime en pourcentage : base = brut de base plus majorations, sans les autres primes.
- Prime mensuelle sans prorata, prime annuelle par mois de versement choisi.

## Valeurs légales : une seule source, tout est NON VÉRIFIÉ
Aucune valeur n'est dans le Swift. Elles sont dans `App/Resources/reference/convention_pack_generic.json`. Chaque valeur est surchargeable. Aucun accès en ligne : tout est écrit de mémoire par l'agent le 2026-11-17 et n'a PAS été relu sur Légifrance. `verifiedOn` est absent, l'écran affiche "valeurs à vérifier" et "jamais vérifié par l'app".

| Valeur | Pack | Source citée | Date de saisie | Statut |
|---|---|---|---|---|
| Seuil hebdomadaire 35 h (2100 minutes) | général | Code du travail L3121-27 | 2026-11-17 | NON VÉRIFIÉ |
| Heures au-delà : +25 % pour les 8 premières heures (480 minutes) | général | Code du travail L3121-36 | 2026-11-17 | NON VÉRIFIÉ |
| Heures au-delà : +50 % ensuite | général | Code du travail L3121-36 | 2026-11-17 | NON VÉRIFIÉ |
| 1er mai travaillé : +100 % (portée "1er mai seulement") | général | Code du travail L3133-6 | 2026-11-17 | NON VÉRIFIÉ |
| Cumul "la plus haute" | général | choix de calcul de l'app, pas une règle légale | 2026-11-17 | choix de conception |
| Nuit, dimanche, autres jours fériés, minimum de convention, heures complémentaires | général | aucune valeur : "à renseigner" | | à renseigner |
| 11 jours fériés (liste fixe et Pâques, Ascension, Pentecôte) | calculés dans `FrenchHolidays` | liste de l'article L3133-1 de mémoire | 2026-11-17 | NON VÉRIFIÉ, hors Alsace-Moselle |
| Noms et IDCC des 21 packs coquilles | `convention_directory.json` | liste de la spec section 22 | 2026-11-17 | NON VÉRIFIÉ sur Légifrance |
| Ratio net sur brut 0,79 et SMIC 12,02 | étape 5, voir `notes/pay.md` | | | inchangés |
Tests qui encodent les valeurs du pack général : `testBundledGenericPackIsMarkedUnverifiedWithSources` vérifie seulement que le pack existe, qu'il est non vérifié, a une source, une règle de seuil et ni nuit ni dimanche. `testBundledPacksOtherThanGenericHaveNoRuleValues` interdit toute règle dans les packs coquilles : si quelqu'un y ajoute une valeur, il doit modifier ce test en connaissance de cause. Les pourcentages des autres tests sont des données de test, pas des valeurs légales.

## Choix de calcul qui ne sont pas dans la spec
- Une même heure relève d'une seule catégorie : férié, dimanche, nuit, sinon normal. Plusieurs règles possibles : la plus haute (défaut) ou la somme (`cumulation: "sum"`). Les heures au-delà du seuil se combinent avec la catégorie de la même façon.
- Dimanche et férié se jugent sur le jour calendaire (minuit à minuit) du morceau, pas sur le début de la session. Fenêtre de nuit : début inclus, fin exclue.
- Les heures au-delà du seuil sont les dernières de la semaine ISO dans l'ordre chronologique. Les jours du mois précédent dans la même semaine comptent (le détail demande la semaine entière), mais la majoration n'est payée que pour les jours du mois affiché.
- Un morceau sans taux (avant le premier taux) n'a pas de majoration chiffrée, comme pour la base.
- Un pourcentage 0 est accepté : c'est la façon de dire "je n'applique pas cette règle" quand le pack en a une.
- Surcharge : seules les valeurs qui diffèrent du pack sont stockées. Une règle éteinte dans l'éditeur alors que le pack en a une est stockée à 0 %.
- Primes : brut ajouté au brut puis converti en net par le ratio ; net ajouté au net seulement. La case "soumise à cotisations" est indicative et ne change rien. Condition "soirée" : heure de début saisie par l'utilisateur, aucune valeur par défaut appliquée (sans heure, prime non comptée et message).
- Plusieurs sessions qui se chevauchent sont comptées deux fois (le reste de l'app ne les empêche pas non plus).

## 5 lignes les plus risquées pour la compilation
1. `PayRules.swift` : `classify(...) -> (category: PayCategory, percent: Decimal)` avec `var applicable: [(category: PayCategory, percent: Decimal)]`, `var best` du même type, et `return (PayCategory.normal, Decimal(0))` (tuple non étiqueté converti en étiqueté).
2. `PaieConventionView.swift` : `PaieRuleOverrideView.init` : `_nightPercent = State(initialValue: eff.night.map { (n: PackNightRule) -> String in ... } ?? "")` et les 18 `@State` sans valeur par défaut initialisés dans `init` avant tout usage de `self`.
3. `PaieReleveView.swift` : `var body: some View` avec `let` puis `return PLTScreen(...) { ... }.task(id:)`, et dans `totalsSection` un `ForEach(0..<PayCategory.allCases.count, id: \.self) { i in let c = ...; PLTRow(...) }`.
4. `PaiePrimesView.swift` : `PaiePrimeFormView.init` (`_condition = State(initialValue: p?.condition ?? PremiumCondition.none)`, `switch` dans `init` avant que tout soit initialisé) et `.onChange(of: amountType) { _, newValue in ... }` (forme iOS 17 à deux paramètres).
5. `ConventionPack.swift` : `ConventionPack` avec `CodingKeys` privé, `init(from:)` écrit à la main en plus de l'init mémoire, `Encodable` synthétisé ; et `static let bundled = ConventionPackLoader.loadAll(bundle: Bundle.main)`.
Risque de test (pas de compilation) : `testBundled*` supposent que `Bundle.main` est le bundle de l'app (tests hébergés, XcodeGen met `TEST_HOST` quand la cible de tests dépend de l'app). Si la CI est rouge sur ces tests, vérifier d'abord que les `.json` sont dans "Copy Bundle Resources".
