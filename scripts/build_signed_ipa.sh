#!/usr/bin/env bash
# CHEMIN SIGNÉ : NON TESTÉ. Nécessite des secrets (certificat p12, profil). À n'utiliser que si l'utilisateur le demande.
# Secrets attendus : P12_BASE64, P12_PASSWORD, PROFILE_BASE64, TEAM_ID, KEYCHAIN_PASSWORD
set -euo pipefail
: "${P12_BASE64:?}" "${P12_PASSWORD:?}" "${PROFILE_BASE64:?}" "${TEAM_ID:?}" "${KEYCHAIN_PASSWORD:?}"
KC="$RUNNER_TEMP/build.keychain-db"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KC"
security set-keychain-settings -lut 21600 "$KC"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KC"
echo "$P12_BASE64" | base64 --decode > "$RUNNER_TEMP/cert.p12"
security import "$RUNNER_TEMP/cert.p12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KC"
security list-keychain -d user -s "$KC"
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
echo "$PROFILE_BASE64" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/build.mobileprovision
echo "Étape suivante à écrire et tester : xcodebuild archive signé puis -exportArchive avec ExportOptions.plist"
exit 2
