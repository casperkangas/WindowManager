#!/bin/bash
set -e

APP_NAME="WindMan"
EXECUTABLE_NAME="WindMan"
BUNDLE_ID="com.casperkangas.windman"

echo "💀 Killing old instances..."
# Kill any existing instance so we can overwrite the file
killall -9 "$APP_NAME" 2>/dev/null || true

echo "🔨 Building Debug version..."
# We use standard 'swift build' (Debug) because it's faster than Release
swift build

# Create the .app structure manually (Fast packaging)
echo "📦 Packaging local dev app..."
mkdir -p "$APP_NAME.app/Contents/MacOS"

# Copy the DEBUG binary (not Release)
cp ".build/debug/$EXECUTABLE_NAME" "$APP_NAME.app/Contents/MacOS/"

# Create a minimal Info.plist to hide the terminal window
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "✍️  Signing..."
codesign --force --deep --sign - "$APP_NAME.app"

echo "🚀 Launching $APP_NAME.app..."
# open -a uses LaunchServices, so no terminal window will be attached
open "$APP_NAME.app"

echo "✅ Dev version updated and running."