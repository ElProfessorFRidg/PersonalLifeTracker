# planning_ocr : planning par photo, alerte de planning tardif (étape 7)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift (Linux). Seule la CI compile. La qualité de lecture (Vision) ne peut se juger que sur un vrai iPhone avec de vrais plannings : aucun test ne la prouve, les tests couvrent seulement l'analyse de lignes positionnées écrites à la main.

## Fichiers
- `App/Core/Logic/ScheduleTextParser.swift` : pur (Foundation). `OCRTextLine` (texte + boîte normalisée, origine en haut à gauche), `ScheduleTextParser.parse(lines:options:)`, `parseCell`, `parseRanges`, `parseDayHeader`, `parseWeekTitle`, `parseClockInput`, `nameScore`, `date(day:minutes:calendar:)`. Résultat : `ScheduleParseResult` (créneaux avec confiance et raison, repos, cases illisibles, candidats de nom, zone à surligner).
- `App/Core/Logic/LatePlanningRules.swift` : pur. `LatePlanningRules.decide(_:) -> LatePlanningDecision` (`.silent(raison)` ou `.remind(LatePlanningReminder)`), `suggestedSlot(importDates:calendar:)`.
- `App/Core/Services/ScheduleOCR.swift` : Vision (`VNRecognizeTextRequest`, fr-FR si dispo, `.accurate`, correction de langue coupée), redessine l'image à l'endroit (max 3200 px).
- `App/Features/PlanningImport/` : `PlanningImportView` (écran poussé, sans argument), `PlanningImportModel` (@Observable, @MainActor), `PlanningImportRows` (ligne de créneau, éditeur en ligne, textes), `DocumentScannerView` (VisionKit, gardé par `isSupported`), `LatePlanningBanner`.
- `project.yml` : `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`. `ModuleRegistryData.swift` : `planning_ocr` passe à `isAvailable: true`.
- Tests : `ScheduleTextParserTests` (54), `LatePlanningRulesTests` (21).

## Fait
- Import depuis Photos (PhotosPicker) ou scanner de documents (si disponible), lecture 100 % locale, états chargement / résultat / lecture ratée (avec conseils) / enregistré.
- Reconstruction par position : en-têtes de jours (3 au moins) = colonnes, une personne par ligne ; aussi jours en lignes et personnes en colonnes (transposition). Semaine en colonnes, cases vides, repos (R, repos, RH, off), congés (CP, congé, RTT...), "8h-12h / 14h-18h", "9-16", "9h-16h", "09:00-16:30", "9h à 16h", fin le lendemain (22-6), case sur deux lignes rattachée si elle est tout près.
- Dates : numéros d'en-tête validés contre le jour de la semaine, sinon titre "du 23 au 29 nov.", sinon semaine du prochain lundi marquée "devinée" (confiance plafonnée à 50 %, boutons Semaine d'avant / d'après).
- Nom insensible aux accents et à la casse, variantes (prénom, nom, initiales, surnoms) : exact 1, contenu 0,9, initiales 0,8, ressemblant (une lettre d'écart, "Léo" / "Léa") 0,55. Deux candidats : bannière + choix, et le bouton Garder reste désactivé tant que la ligne n'est pas confirmée. Égalité parfaite : aucune ligne choisie, jamais la première.
- Relecture : confiance par créneau (fiable >= 85 %, à vérifier >= 60 %, incertain en dessous), raison en français. "C'est bon" seulement pour "à vérifier". Un incertain se corrige ou se retire. Une case illisible devient un créneau sans heures à saisir ou retirer. Garder désactivé tant qu'il reste un point. Jeter la lecture avec confirmation. Surlignage de la ligne sur la photo.
- Confirmer crée des `PlannedShift` (activité work, source "photo"), sans doublon exact déjà présent.
- Alerte tardive (section 70) : règles pures et bandeau `LatePlanningBanner(reminder:onAction:)`. Ordre des silences : désactivé, pas de créneau d'habitude, avant l'échéance, planning présent, semaine ignorée, congés/vacances, mode examens, déjà relancé cette semaine (semaine lundi premier), heures silencieuses. Moment appris : 3 imports minimum, au moins 3 le même jour de la semaine et 60 % du total, heure médiane arrondie au quart d'heure inférieur.

## Pas fait
- Aucune notification locale ni écran de réglage de l'alerte (jour et heure, "Ne plus me le rappeler") : seulement les règles et le bandeau. À brancher par l'orchestrateur (heures silencieuses, congés, examens viennent d'ailleurs).
- Contrôles de qualité avant analyse (flou, reflets, lumière, résolution) : seulement des conseils sur l'écran d'échec. Fusion de plusieurs photos ou pages : le scanner n'en lit que la première (l'écran le dit). Import depuis Fichiers, PDF, feuille de partage. Conservation de l'image selon la section 118 : l'image n'est pas gardée.
- Édition du lieu, de l'activité et de la date d'un créneau (heures seulement). Ajout manuel d'un créneau manquant sur cet écran. Comparaison à un contrat (le prototype montre "17 h pour 13 h au contrat").
- Écriture manuscrite jamais devinée : tout passe par la relecture, mais aucune lecture spécifique.
- En-têtes en deux rangées (lettres puis numéros), noms écrits sur deux lignes (la deuxième ligne devient une ligne à part), "9 h 30" avec espaces, chiffres confondus par l'OCR (O pour 0).
- Point d'entrée : l'écran existe, personne ne le pousse encore depuis Planning.

## Choix hors spec
- Profil de noms stocké dans UserDefaults `plt.planning.profileNames` (texte séparé par virgules). Si vide, le choix de ligne dans la feuille est mémorisé comme nom.
- Seuils de confiance et pénalités (0,6 pour plus de 12 h ou moins d'une heure, 0,8 pour fin le lendemain, 0,65 pour nom approché, 0,85 pour texte entre deux colonnes, 0,5 plafond date devinée) : inventés, à régler sur de vraies photos.
- Seuil de 3 en-têtes de jours pour reconnaître un tableau. Texte hors colonnes ignoré avec un avertissement.
- Changer de ligne ou de semaine relance l'analyse : les corrections déjà faites sont perdues.
- Les lignes dont le nom contient "=" (légende "R = repos") ne sont pas des lignes de personne.

## 5 lignes les plus risquées
1. `App/Core/Classification/VisitClassifier.swift` ligne 4 : `struct PlannedShift: Equatable` existe déjà et entre en collision avec le `@Model PlannedShift` (App/Core/Models/PlannedShift.swift) : redéclaration, erreur de compilation. Pas dans mes fichiers : à renommer (ClassificationTests l'utilise aussi).
2. `PlanningImportModel.start` : `Task { [weak self] in ... await ScheduleOCR.recognizeLines(...) { value in Task { @MainActor in self?.progress = value } } }` : isolation d'acteur et capture faible, jamais compilées.
3. `ScheduleOCR.recognizeLines` : `request.progressHandler`, `supportedRecognitionLanguages()` (méthode d'instance) et le cast de `request.results` selon la version du SDK.
4. `ScheduleTextParser.buildGrid` : regroupement en lignes par tolérance (0,6 x hauteur médiane, clamp 0,008 à 0,03) et seuil de colonne 0,6 x pas : les valeurs numériques sont devinées, elles décident de toute la reconstruction sur de vraies photos.
5. `PlanningImportView` : `@State private var model = PlanningImportModel()` (init d'une classe @MainActor), `PhotosPicker` avec label maison, `.onChange(of:) { _, newItem in }`, `fullScreenCover` du scanner (non testable au simulateur).

## À faire sur iPhone
Photographier un vrai planning papier et une capture d'écran, vérifier : lecture du nom, colonnes, "R", cases vides, reflets, surlignage, passage de minuit. Note : un test de mutation léger à la main reste à faire (changer 0,85 en 0,9 dans `ScheduleConfidence.highThreshold` doit casser `testConfidenceLevels` ; changer 2,5 en 0,5 dans `mergeGap` doit casser `testCellWrittenOnTwoLinesIsMergedIntoOneDay`).
