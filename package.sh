#!/bin/bash
set -e

APP_NAME="WindMan"
EXECUTABLE_NAME="WindMan"
BUNDLE_ID="com.casperkangas.windman"
VERSION="1.0.0"

echo "🧼 Cleaning previous builds..."
rm -rf .build/release
rm -rf "$APP_NAME.app"
rm -rf "$APP_NAME.zip"
rm -rf WindMan.iconset WindMan.icns

echo "🚀 Building WindMan v1.0 Release..."
swift build -c release --arch arm64 --arch x86_64

BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"
cp "$BIN_PATH/$EXECUTABLE_NAME" "$APP_NAME.app/Contents/MacOS/"

# --- ICON GENERATION ---
if [ -f "icon.png" ]; then
    echo "🎨 Generating AppIcon.icns from icon.png..."
    mkdir WindMan.iconset
    sips -z 16 16     icon.png --out WindMan.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     icon.png --out WindMan.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     icon.png --out WindMan.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     icon.png --out WindMan.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   icon.png --out WindMan.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   icon.png --out WindMan.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   icon.png --out WindMan.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   icon.png --out WindMan.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   icon.png --out WindMan.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 icon.png --out WindMan.iconset/icon_512x512@2x.png > /dev/null
    
    iconutil -c icns WindMan.iconset
    cp WindMan.icns "$APP_NAME.app/Contents/Resources/AppIcon.icns"
    rm -rf WindMan.iconset WindMan.icns
else
    echo "⚠️ Warning: icon.png not found. App will have default generic icon."
fi

# --- INFO.PLIST ---
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
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "✍️  Signing app bundle..."
codesign --force --deep --sign - "$APP_NAME.app"

echo "🤐 Zipping WindMan_v1.0.zip..."
zip -r "WindMan_v1.0.zip" "$APP_NAME.app"

echo "✅ Release ready: WindMan_v1.0.zip"