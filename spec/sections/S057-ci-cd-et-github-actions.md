## 57. CI/CD ET GITHUB ACTIONS

Workflows : ci.yml, beta.yml, release.yml, pull-request.yml, manual-build.yml.
Pull requests : compilation, tests, rapports, aucun déploiement, aucun secret exposé. Branche dev : compilation, tests, artefacts, logs. Branche main : compilation, tests, artefacts, prerelease beta, notes de version. Tags SemVer : vérification, build Release, tests, signature si configurée, IPA, checksums SHA-256, release stable, changelog.
Signature : secrets APPLE_TEAM_ID, APPLE_CERTIFICATE_BASE64, APPLE_CERTIFICATE_PASSWORD, APPLE_PROVISIONING_PROFILE_BASE64, APPLE_BUNDLE_IDENTIFIER. Le workflow installe le certificat, crée un keychain temporaire, installe le profil, signe, exporte, vérifie l'IPA et nettoie. Sans secrets, il produit automatiquement une IPA non signée. Ne jamais prétendre qu'une IPA non signée est installable directement.
Deux voies documentées dans docs/CI-CD.md :
- Voie gratuite : IPA non signée en artefact, installable avec Sideloadly ou AltStore, certificat qui expire tous les 7 jours (réinstallation nécessaire), procédure pas à pas.
- Voie payante : signature automatique par secrets GitHub, release et TestFlight facultatif via l'API App Store Connect.
Sécurité : permissions minimales, secrets protégés, pas de secrets dans les PR non fiables, actions maîtrisées et épinglées, pas de releases en double, workflows idempotents.
Documentation : README.md, CONTRIBUTING.md, docs/CI-CD.md.
