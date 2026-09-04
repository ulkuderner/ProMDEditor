#!/bin/bash
# MarkPad icin dagitima hazir DMG uretir.
#   ./Tools/make_dmg.sh            -> ad-hoc imza (yalnizca bu makinede sorunsuz)
#   ./Tools/make_dmg.sh "Developer ID Application: Ad (TEAMID)"
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
NAME="MarkPad"
VERSION=$(grep -A0 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
IDENTITY="${1:--}"
DIST="$ROOT/dist"
STAGE="$(mktemp -d)/$NAME"
DMG="$DIST/$NAME-$VERSION.dmg"
RW_DMG="$(mktemp -d)/rw.dmg"

echo "==> Release derleniyor (imza: $IDENTITY)"
xcodegen generate >/dev/null
xcodebuild -project "$NAME.xcodeproj" -scheme "$NAME" -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$ROOT/.build" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
    DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" \
    build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

APP="$ROOT/.build/Build/Products/Release/$NAME.app"
[ -d "$APP" ] || { echo "Uygulama bulunamadi: $APP"; exit 1; }

echo "==> Imza dogrulaniyor"
codesign --verify --deep --strict "$APP" && echo "imza gecerli"

echo "==> Disk imaji hazirlaniyor"
mkdir -p "$STAGE" "$DIST"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 40 ))
hdiutil create -srcfolder "$STAGE" -volname "$NAME" -fs HFS+ \
    -format UDRW -size "${SIZE}m" "$RW_DMG" >/dev/null

MOUNT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" |
        grep -o '/Volumes/.*' | head -1)
sleep 2

echo "==> Pencere duzeni ayarlaniyor"
osascript <<EOF || echo "(duzen atlandi)"
tell application "Finder"
    tell disk "$NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 800, 540}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 13
        set position of item "$NAME.app" of container window to {150, 190}
        set position of item "Applications" of container window to {450, 190}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

sync
# Spotlight/Finder birimi bir sure daha tutabildigi icin detach ilk denemede
# "Resource busy" ile dusebiliyor. Birkac kez dene, sonra zorla ayir.
for i in 1 2 3 4 5; do
    hdiutil detach "$MOUNT" >/dev/null 2>&1 && break
    if [ "$i" = 5 ]; then
        hdiutil detach "$MOUNT" -force >/dev/null
    else
        sleep 2
    fi
done
rm -f "$DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

if [ "$IDENTITY" != "-" ]; then
    codesign --sign "$IDENTITY" "$DMG"
fi

echo
echo "Hazir: $DMG"
ls -lh "$DMG" | awk '{print "Boyut:", $5}'
shasum -a 256 "$DMG"
