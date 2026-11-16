#!/usr/bin/env bash
# Construit un IPA NON SIGNÉ (AltStore le resigne à l'installation).
# usage: build_ipa.sh <version x.y.z> <build number> <sortie.ipa>
set -euo pipefail
VERSION="${1:?version}"; BUILD="${2:?build}"; OUT="${3:?sortie.ipa}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERREUR: version x.y.z requise"; exit 1; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "ERREUR: numéro de build invalide"; exit 1; }
SCHEME="${SCHEME:-PersonalLifeTracker}"
rm -rf build && mkdir -p build
xcodebuild archive -project PersonalLifeTracker.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/app.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" | tail -40
APP=$(ls -d build/app.xcarchive/Products/Applications/*.app | head -1)
[ -d "$APP" ] || { echo "ERREUR: .app introuvable dans l'archive"; exit 1; }
# Entitlements facultatifs via ldid (à vérifier sur appareil : pas garanti)
if command -v ldid >/dev/null 2>&1 && [ -f App/PersonalLifeTracker.entitlements ]; then
  ldid -SApp/PersonalLifeTracker.entitlements "$APP/$(basename "$APP" .app)" || echo "avertissement: ldid a échoué, IPA sans entitlements"
fi
rm -rf build/Payload && mkdir -p build/Payload && cp -R "$APP" build/Payload/
(cd build && zip -qry "../$OUT" Payload)
unzip -l "$OUT" | grep "Payload/.*\.app/Info.plist" >/dev/null || { echo "ERREUR: IPA invalide"; exit 1; }
echo "IPA: $OUT ($(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT") octets)"
