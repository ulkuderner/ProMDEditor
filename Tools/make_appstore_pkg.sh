#!/bin/bash
# MarkPad'i Mac App Store'a yuklenebilir .pkg olarak paketler.
#
#   ./Tools/make_appstore_pkg.sh
#
# Gereken:
#   - Etkin Apple Developer Program uyeligi
#   - Xcode > Settings > Accounts'ta Apple ID ile oturum acilmis olmasi
#   - Portal'da kayitli bundle ID'ler:
#       com.caglar.MarkPad
#       com.caglar.MarkPad.QuickLook
#
# Dagitim sertifikasi ve provisioning profili yoksa -allowProvisioningUpdates
# bunlari Xcode hesabi uzerinden olusturur.
#
# Cikti: dist/appstore/MarkPad.pkg  -> Transporter veya Xcode Organizer ile yuklenir.
# NOT: App Store DMG kabul etmez; Tools/make_dmg.sh yalnizca Store disi dagitim icindir.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
TEAM="W4A4C428H6"
DIST="$ROOT/dist"
ARCHIVE="$DIST/MarkPad.xcarchive"
EXPORT="$DIST/appstore"
OPTS="$(mktemp -d)/ExportOptions.plist"

mkdir -p "$DIST"
rm -rf "$ARCHIVE" "$EXPORT"

echo "==> Proje uretiliyor"
xcodegen generate >/dev/null

cat > "$OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>            <string>app-store-connect</string>
    <key>teamID</key>            <string>$TEAM</string>
    <key>destination</key>       <string>export</string>
    <key>uploadSymbols</key>     <true/>
    <key>signingStyle</key>      <string>automatic</string>
</dict>
</plist>
PLIST

echo "==> Arsiv olusturuluyor (Release)"
xcodebuild -project MarkPad.xcodeproj -scheme MarkPad -configuration Release \
    -destination 'platform=macOS' -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates archive

echo "==> .pkg disa aktariliyor"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OPTS" -exportPath "$EXPORT" \
    -allowProvisioningUpdates

PKG=$(ls "$EXPORT"/*.pkg 2>/dev/null | head -1)
echo
echo "Hazir: $PKG"
echo "Yukleme: Transporter uygulamasi, ya da"
echo "  xcrun altool --upload-app -f \"$PKG\" -t macos -u <apple-id> -p <app-specific-password>"
