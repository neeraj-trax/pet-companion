#!/bin/zsh
# Build a shareable Pet.dmg. The personal-use sprite atlas is deliberately excluded.
set -e
set -o pipefail
cd "$(dirname "$0")"

./build-app.sh

DMG_ROOT="build/dmg-root"
SHARE_APP="$DMG_ROOT/Pet.app"
DMG="build/Pet.dmg"

rm -rf "$DMG_ROOT" "$DMG"
mkdir -p "$DMG_ROOT"
cp -R build/Pet.app "$SHARE_APP"
rm -f "$SHARE_APP/Contents/Resources/pet-atlas.webp"
xattr -cr "$SHARE_APP"
ln -s /Applications "$DMG_ROOT/Applications"

# Removing a bundled resource invalidates the build signature, so sign the shareable copy again.
# A Developer ID identity can replace "-" later for warning-free external distribution.
codesign --force --deep --sign - "$SHARE_APP"

hdiutil create -volname "Pet" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG" >/dev/null
codesign --force --sign - "$DMG"
hdiutil verify "$DMG" >/dev/null

test ! -e "$SHARE_APP/Contents/Resources/pet-atlas.webp"
echo "Done → $DMG (shareable fallback artwork; private atlas excluded)"
