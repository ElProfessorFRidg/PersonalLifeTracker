# PHASE 0 : UI/UX et thème (artefact), avant tout code d'app

Objectif : que l'utilisateur voie et valide l'app avant qu'une ligne de Swift soit écrite.

## Étapes
1. Lis seulement : sections 47 (UX), 48 (onboarding), 49 (réglages), 50 (voix et ton), 44 et 125 (Live Activity, widgets), 122 (carte Maintenant). Commande : `python3 scripts/spec_section.py 47` etc.
2. Écris design/tokens.json (couleurs clair/sombre/AMOLED, typographie, rayons, espacements, ombres, animations, haptiques). Lance `python3 scripts/gen_theme.py` : il génère App/Core/Design/Theme.swift et design/theme.css à partir des tokens. Une seule source : tokens.json.
3. Crée un artefact HTML interactif unique : écris design/prototype/index.html puis PUBLIE-LE comme artefact (outil Artifact de Claude, lien claude.ai que l'utilisateur ouvre et teste sur son téléphone). Si ton outil n'a pas d'artefacts, livre le fichier index.html et dis-le. À chaque itération, republie le même artefact (même URL) au lieu d'en créer un nouveau. Le prototype qui contient un cadre iPhone et ces écrans, navigables :
   - Onboarding (choix des modules, tutoiement, permissions expliquées)
   - Accueil avec carte Maintenant, session en cours, résumé du jour
   - Lieux (liste, ajout sur carte, travail contre courses)
   - Sessions et saisie manuelle, choix en zone de doute (:15 à :45)
   - Planning (semaine, photo importée, alerte planning tardif)
   - Emploi et paie (optionnels), contrat 13 h avec équilibrage
   - Fonctionnalités (ModuleRegistry, interrupteurs)
   - Réglages (modes clair, sombre, AMOLED, statuts détectés)
   - Live Activity, widgets (petit, moyen, grand, écran verrouillé), notifications
   - États vides, erreurs, chargement, fiabilité des données
4. Mode clair, sombre et AMOLED basculables dans le prototype. Textes réels en français tutoyé, jamais de lorem ipsum.
5. Accessibilité : contrastes, tailles dynamiques, cibles 44 pt, VoiceOver (étiquettes listées dans design/SCREENS.md).
6. Remplis design/SCREENS.md : un écran = nom, rôle, composants, états, module concerné. C'est la liste que la Phase 2 devra livrer.
7. Donne le lien de l'artefact à l'utilisateur et demande-lui de valider ou de lister ce qui change (écran par écran). Liste honnêtement ce qui est maquetté et ce qui ne l'est pas. Itère sur ses retours.
8. Quand l'utilisateur écrit "UI validée" (ou une phrase équivalente sans réserve) : crée design/UI_VALIDATED.md avec la ligne `Validation de l'utilisateur : <sa citation exacte>`, la date et l'URL de l'artefact, passe phase:P0_ui à TESTS AUTO OK avec cette preuve, puis ENCHAÎNE SANS REDEMANDER sur la Phase 1 puis la Phase 2. Tu ne t'arrêtes que pour ce que toi tu ne peux pas faire (dépôt public, gh auth, test sur iPhone), en le disant clairement.

## Preuve attendue
design/prototype/index.html présent, design/tokens.json cohérent (gen_theme.py passe), design/SCREENS.md rempli, UI_VALIDATED.md créé sur validation explicite.

## Interdits
Coder l'app avant validation. Se déclarer validé sans la phrase de l'utilisateur.
