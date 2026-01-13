#!/bin/bash

# Stop the script immediately if any command fails
set -e

APP_NAME="WindowManager"
EXECUTABLE_NAME="WindowManager"
BUNDLE_ID="com.casperkangas.windowmanager"
VERSION="0.1.0"

# 1. Clean previous builds
echo "🧼 Cleaning previous builds..."
rm -rf .build/release
rm -rf "$APP_NAME.app"
rm -rf "$APP_NAME.zip"

# 2. Build Release version (Universal)
echo "🚀 Building Release version (Optimized)..."
# We run the build first
swift build -c release --arch arm64 --arch x86_64

# 3. Get the actual path of the binary
# When building for multiple architectures, SPM changes the output folder.
# We ask SPM where the binary is located.
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
echo "📍 Binary located at: $BIN_PATH"

# 4. Create App Bundle Structure
echo "📦 Creating .app bundle..."
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# 5. Copy the binary
# We use the dynamic BIN_PATH we found earlier
cp "$BIN_PATH/$EXECUTABLE_NAME" "$APP_NAME.app/Contents/MacOS/"

# 6. Create Info.plist
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
</dict>
</plist>
EOF

# 7. Sign the App Bundle
echo "✍️  Signing app bundle..."
codesign --force --deep --sign - "$APP_NAME.app"

# 8. Zip it for GitHub
echo "🤐 Zipping for release..."
zip -r "$APP_NAME.zip" "$APP_NAME.app"

echo "✅ Done! You can find '$APP_NAME.zip' in this folder."