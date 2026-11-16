## 54. ICLOUD ET CLOUDKIT (module icloud, facultatif)

Derrière le flag ENABLE_CLOUDKIT. Détection automatique de la disponibilité, sans jamais crasher :
1. Vérifier à l'exécution que l'entitlement iCloud est présent dans la build AVANT d'instancier CKContainer (ne jamais appeler CKContainer.default() sans cette vérification).
2. Si présent, vérifier CKContainer.accountStatus (connecté, non connecté, restreint, indéterminé) et le réseau.
3. Ne pas prétendre détecter "compte gratuit ou payant" : détecter si la sauvegarde est possible ou non.
Réglages : ligne "Sauvegarde iCloud", possible (connecté, dernière sauvegarde, bouton "Sauvegarder maintenant") ou impossible avec la raison en français ("cette version de l'app n'a pas iCloud", "tu n'es pas connecté à iCloud", "iCloud est restreint", "pas de réseau"). Dans tous les cas impossibles, proposer l'export JSON de secours.
Synchronisation incrémentale, sans doublons, gestion des conflits, reprise après perte de réseau, jamais bloquante, jamais de téléchargement complet à chaque modification, regroupement des écritures, sauvegardes différées, nouvelles tentatives, vérification d'intégrité, versionnement. Jamais de suppression locale à cause d'un échec cloud.
Export/import JSON, sauvegarde complète, restauration, migration entre versions, suppression des données cloud. Documenter le format.
