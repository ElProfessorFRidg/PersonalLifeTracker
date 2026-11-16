# Fonctionnalités, Réglages, CapabilityService

STATUT : NON COMPILÉ, NON TESTÉ (pas de toolchain Swift ici, seule la CI compile).

## Fait
- `App/Core/Logic/ModuleCatalog.swift` (pur) : thèmes (les 108 ids du registre sont tous mappés, 0 dans "Autres" aujourd'hui, vérifié par script Python), recherche sans casse ni accents (tous les mots doivent matcher titre ou résumé), compteurs (actif = activé ET livré, total = modules optionnels), `changeRequest` (ce qui s'active ou se coupe en plus).
- `App/Core/Logic/DataExport.swift` (pur) : structs Codable, JSON trié, dates ISO 8601, fichier temporaire.
- `App/Core/Services/CapabilityService.swift` : localisation (toujours, pendant l'utilisation, refusée, restreinte, pas demandée), précision, notifications, actualisation en arrière-plan, mode économie. Lecture seule, `refresh()`.
- `FonctionnalitesView` (recherche, noyau verrouillé, groupes, interrupteurs, badge Bientôt, feuille de confirmation, compteur), `ModuleDetailView`.
- `ReglagesView` : détection (bandeau + bouton réglages iOS), lien Fonctionnalités avec compteur, apparence, devise avec exemple, base de calcul + feuille d'explication, export JSON via ShareLink, tout supprimer en deux étapes (lieux et sessions), réinitialiser les réglages, version et "100 % local". Fichiers `ReglagesDonnees.swift` (conversion modèles vers export, deux feuilles).
- Tests : `ModuleCatalogTests` (16), `DataExportTests` (5), valeurs écrites à la main.

## Pas fait
- Rien n'est testé en vrai : ni ShareLink, ni la suppression SwiftData, ni les statuts sur appareil.
- Pas de réglages de la section 49 hors périmètre (accent, icône, haptique, notifications par catégorie, format 24 h, Face ID, import JSON, suppression par période).
- Les 108 modules sont `isAvailable: false` : tous affichent "Bientôt" avec un interrupteur coupé et grisé, donc le compteur affiche 0 actives. Le noyau est une liste statique de 5 lignes (pas le module `core` du registre).
- L'export ne contient pas les réglages (la spec 49 le demande), seulement lieux et sessions.
- Pas de bouton Import.

## Risques
- Les titres du registre sont longs (listes de fonctions) : lignes à plusieurs lignes.
- `@State private var capabilities = CapabilityService()` : init non isolé, accès UIKit seulement dans `refresh()`.
- Le fichier d'export est régénéré à chaque apparition (écriture temporaire).
- L'export reste prêt seulement si l'écriture réussit, sinon la ligne est grisée avec un bandeau d'erreur.

## Les 5 lignes les plus susceptibles de ne pas compiler
1. ReglagesView : `try context.delete(model: WorkSession.self)` (API SwiftData iOS 17).
2. ReglagesView : `ShareLink(item: url) { PLTRow(...) }` (label personnalisé avec URL).
3. CapabilityService : `Task { @MainActor [weak self] in ... self?.notifications = ... }` (setter `private(set)` dans une closure).
4. ModuleCatalog : `normalize` avec `folding(options:locale:)` et `byTheme[..., default: []].append`.
5. FonctionnalitesView : `body` avec `let` puis `return PLTScreen(...) { ... }.sheet(item:)` et `ForEach` sur `ModuleCatalog.Group`.
