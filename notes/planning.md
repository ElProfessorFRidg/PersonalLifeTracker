# planning : semaine datée (section 91)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift, seule la CI compile.

## Fait
- Modèles `PlannedShift` et `LeaveEntry` (contrat figé), ajoutés au schéma (`AppModelContainer`).
- `PlanningRules` (pur) : bornes de semaine (lundi), jours, créneaux d'une semaine ou d'un jour, minutes prévues et faites (coupe à minuit, session en cours jusqu'à `now`), comparaison par jour, validation, chevauchement, copie de semaine (décalage en jours calendaires, donc heure affichée conservée à travers un changement d'heure), couverture de congé, titre de semaine.
- 14 tests écrits à la main (`PlanningRulesTests`), dont minuit, changement d'heure Paris (25 octobre 2026) et copie sur ce changement.
- Écrans : `PlanningView` (semaine, navigation, jour par jour prévu/fait, totaux, bandeau semaine suivante sans planning, état vide, bouton caméra si `planning_ocr`), `PlanningJourView(day:)` (rubans prévu/réel, créneaux, congé), `PlanningShiftEditView` (ajout, modification, suppression avec confirmation), `PlanningCopyView`, `PlanningLeaveView`.

## Pas fait
- Rotation (section 88), détection de motif (107), "semaine vide" explicite, modification d'un congé (suppression seulement), liens lieu/employeur dans la saisie (champs présents dans le modèle, non éditables), source "photo" écrite par l'agent d'import.
- Pas de pointillés pour le prévu sur les rubans : `HourRibbon` ne les gère pas, le prévu est un second ruban plein étiqueté.
- Pas de relevé employeur, pas de notification de planning manquant.

## Choix hors spec
- Semaine du lundi au dimanche, calendrier grégorien du fuseau courant.
- Un créneau appartient à la semaine de son début (un créneau du dimanche soir passe sur le lundi suivant sans changer de semaine).
- Les totaux prévu et fait ne comptent que Taf et Cours (`PlanningRules.countedActivities`).
- Durée maximale 24 h. Le chevauchement avertit, ne bloque pas. Copier ajoute sans effacer la semaine cible.
- Changer le début déplace la fin du même écart.

## 5 lignes les plus risquées
1. `PlanningView.body` : instructions (`var`, `for`) avant `return PLTScreen {...}` (même schéma que PLTCard, sans builder).
2. `.sheet(item: $editing)` dans PlanningJourView : suppose `PlannedShift: Identifiable` via `PersistentModel`.
3. `@Query(sort: \PlannedShift.start)` : key path sur un @Model neuf.
4. `.onChange(of: start) { oldValue, newValue in ... }` (forme iOS 17 à deux paramètres) dans PlanningShiftEditView.
5. `PlanningRules.copyWeek` : `calendar.dateComponents([.day], from:to:)` entre deux débuts de semaine, attendu 7 à travers le changement d'heure (test dédié).
Aussi : `PlanningImportView()` n'existe pas tant que l'autre agent n'a pas livré, la CI échoue sans lui.
