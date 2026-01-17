#!/bin/bash
set -e

APP_NAME="WindMan"
EXECUTABLE_NAME="WindMan"
BUNDLE_ID="com.casperkangas.windman"

# ---------------------------------------------------------
# ⚠️ UPDATE THIS VERSION NUMBER BEFORE EVERY RELEASE!
# This determines what version the app thinks it is.
# Match this to your GitHub Release tag WITHOUT THE "V" (e.g. v1.2 -> 1.3)
VERSION="1.3"
# ---------------------------------------------------------

echo "💀 Killing old instances..."
killall -9 "$APP_NAME" 2>/dev/null || true
rm -rf WindMan.iconset WindMan.icns

echo "🔨 Building Debug version..."
swift build

echo "📦 Packaging local dev app..."
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"
cp ".build/debug/$EXECUTABLE_NAME" "$APP_NAME.app/Contents/MacOS/"

# --- ICON GENERATION ---
if [ -f "icon.png" ]; then
    echo "🎨 Generating AppIcon.icns..."
    mkdir WindMan.iconset
    sips -z 1024 1024 icon.png --out WindMan.iconset/icon_512x512@2x.png > /dev/null
    iconutil -c icns WindMan.iconset
    cp WindMan.icns "$APP_NAME.app/Contents/Resources/AppIcon.icns"
    rm -rf WindMan.iconset WindMan.icns
fi

# --- INFO.PLIST WITH VERSION ---
cat <<EOF > "$APP_NAME.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "✍️  Signing..."
codesign --force --deep --sign - "$APP_NAME.app"

echo "✅ Dev version updated! Launch '$APP_NAME.app' from Finder."