#!/bin/zsh
# Builds a signed, notarized Neuralyzer.dmg in the repo root.
# Needs the Developer ID certificate in the keychain and the "notary" notarytool profile.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="Developer ID Application: Shiv Vyas (Z42YU5W6WY)"
BUILD=build/release
APP="$BUILD/Build/Products/Release/Neuralyzer.app"
DMG=Neuralyzer.dmg

xcodegen generate
xcodebuild -scheme Neuralyzer -configuration Release -derivedDataPath "$BUILD" build \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=Z42YU5W6WY CODE_SIGN_IDENTITY="$IDENTITY" \
  ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS="--timestamp" | tail -3

codesign --verify --deep --strict "$APP"

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname Neuralyzer -srcfolder "$STAGE" -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --sign "$IDENTITY" --timestamp "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile notary --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"
echo "Built $DMG"
