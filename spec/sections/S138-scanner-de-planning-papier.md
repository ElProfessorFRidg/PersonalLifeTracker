## 138. SCANNER DE PLANNING PAPIER (sous-fonction du module planning_ocr, activée avec lui)

Pour un planning affiché au mur ou imprimé : scanner de documents du système (VisionKit) avec détection des bords et correction de perspective, plusieurs pages ou photos possibles.
- Contrôles de qualité avant l'analyse : flou (reprise suggérée), reflets ou zones surexposées (conseil "incline un peu le téléphone"), lumière faible (suggestion d'éclairage), résolution insuffisante.
- Grand tableau en plusieurs photos : l'assemblage se fait au niveau des résultats de lecture, pas des pixels. Les tableaux reconstruits de chaque photo sont fusionnés grâce aux en-têtes et aux noms de lignes ou colonnes communs, avec contrôle des recouvrements. Les doublons et les conflits sont signalés.
- Écriture manuscrite : lecture possible mais moins fiable, toujours soumise à l'écran de validation de la section 16, jamais devinée.
- L'image d'origine et l'image corrigée sont conservées selon le réglage de la section 118. Tout reste local.
