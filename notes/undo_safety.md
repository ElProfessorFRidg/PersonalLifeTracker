# undo_safety : Annuler partout et instantanés (section 128)

STATUT : NON COMPILÉ, NON TESTÉ. Écrit sans toolchain Swift. Seule la CI compile.

## Fait
- `App/Core/Undo/UndoCenter.swift` : @Observable @MainActor, `register(message:undo:)`, toast 6 s, un nouveau toast remplace l'ancien, historique 20 entrées / 7 jours, `undo(recordID:)` (une seule fois par entrée), `isEnabled` (faux si le module est coupé).
- `UndoToastView.swift` : toast au-dessus de la barre d'onglets, bouton Annuler 44 pt, annonce VoiceOver, animation coupée si réglage app ou système.
- `SnapshotPlan.swift` (pur) : `isDue`, `ageInDays`, `entriesToPrune` (14 jours, plafond 30 fichiers, le plus récent jamais supprimé), `SnapshotFormat`.
- `SnapshotStore.swift` : JSON `ExportDocument` dans Application Support/Snapshots, exclu des sauvegardes, protection fichier iOS.
- `UndoSnapshots.swift` : copies de valeurs, `restoreSession`, `restorePlace` (ré-attache les sessions), `replaceAll`, `takeDailySnapshotIfDue`.
- `InstantanesView.swift` (`InstantanesView()`), restauration en deux étapes (feuille), instantané de sécurité avant restauration, restauration annulable via le toast.
- RootView : UndoCenter dans l'environnement, toast en overlay, instantané du jour à l'activation si `undo_safety` actif. Suppression d'une session et d'un lieu enregistrent une annulation. Module passé `isAvailable: true`.
- Tests : `SnapshotTests.swift`, `UndoTests.swift`.

## Pas fait (écart avec la spec)
- Pas d'annulation par secousse ni menu Édition, pas d'annulation des modifications d'heure, de type, de note, de planning, de contrat (seules les suppressions de session et de lieu sont enregistrées).
- Pas d'écran "Modifications récentes" (l'historique existe dans UndoCenter, aucune vue ne l'affiche), pas de détection de conflit.
- Pas d'instantané avant import, suppression par période, changement de convention, migration (ces opérations n'existent pas encore). La suppression totale de ReglagesDonnees ne prend pas d'instantané ni d'annulation.
- Restauration complète seulement (pas d'aperçu des différences ligne à ligne, pas de restauration sélective). Pas de limite d'espace en octets (plafond en nombre de fichiers).
- Pas de journal des modifications ni de journal infalsifiable (non modélisés).
- Nombre de jours de conservation fixé à 14, pas de réglage utilisateur.
- L'instantané est pris au premier lancement du jour (activation), pas à minuit exact.
- Le lien vers InstantanesView depuis Réglages est ajouté par un autre agent.

## Risques
- `@Environment(UndoCenter.self) private var x: UndoCenter?` (valeur optionnelle) : syntaxe iOS 17, à confirmer.
- Marge basse du toast fixée à 64 pt (hauteur de barre d'onglets supposée), pas mesurée.
- Restauration d'un lieu : suppose que SwiftData met `session.place` à nil sans l'inverse déclaré des deux côtés (voir core_models), et que `session.place = place` après `insert` met à jour l'inverse.
- Test `testToastDisappearsAfterItsDuration` repose sur un délai réel (0,05 s, attente 0,6 s).
- Options d'écriture `.completeFileProtectionUntilFirstUserAuthentication` sur simulateur : supposées acceptées.

## Les 5 lignes les plus susceptibles de ne pas compiler
1. `App/RootView.swift` : `.onChange(of: modules.isActive("undo_safety"), initial: true) { (_: Bool, isOn: Bool) in ... }`.
2. `InstantanesView.swift` : `@Environment(UndoCenter.self) private var undoCenter: UndoCenter?`.
3. `InstantanesView.swift` : `.confirmationDialog("...", isPresented:, titleVisibility:, presenting:) { (info: SnapshotInfo) in ... } message: { ... }`.
4. `InstantanesView.swift` : `Date.FormatStyle(date: .long, time: .shortened).locale(Locale(identifier: "fr_FR"))`.
5. `UndoCenter.swift` : `init(toastDuration:now:)` avec `@ObservationIgnored private let now` et valeur par défaut `UndoCenter.defaultToastDuration` dans une classe @MainActor @Observable.
