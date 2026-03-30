#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Mac Voice"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUNDLE_ID="com.macvoice.app"
SIGNING_IDENTITY="REDACTED_SIGNING_IDENTITY"

echo "🔨 Building Mac Voice..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

EXECUTABLE=$(swift build -c release --show-bin-path)/MacVoice

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed — executable not found"
    exit 1
fi

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/MacVoice"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Mac Voice</string>
    <key>CFBundleDisplayName</key>
    <string>Mac Voice</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>MacVoice</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Mac Voice needs microphone access to record your voice for transcription.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Mac Voice uses speech recognition for wake phrase detection and send phrase monitoring.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Start Mac Voice</string>
            </dict>
            <key>NSMessage</key>
            <string>startMacVoice</string>
            <key>NSPortName</key>
            <string>Mac Voice</string>
            <key>NSSendTypes</key>
            <array>
                <string>NSStringPboardType</string>
            </array>
            <key>NSReturnTypes</key>
            <array>
                <string>NSStringPboardType</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Generate app icon
echo "🎨 Generating app icon..."
ICON_PATH="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
swift "$SCRIPT_DIR/generate-icon.swift" "$ICON_PATH"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy beep sound files
echo "🔊 Copying beep sounds..."
if [ -d "$PROJECT_DIR/beeps" ]; then
    cp "$PROJECT_DIR/beeps/"*.wav "$APP_BUNDLE/Contents/Resources/"
fi

# Create entitlements
ENTITLEMENTS="$BUILD_DIR/MacVoice.entitlements"
cat > "$ENTITLEMENTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

# Code sign
echo "🔏 Signing with: $SIGNING_IDENTITY"
codesign --force --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    --timestamp=none \
    "$APP_BUNDLE"

# Verify signature
codesign --verify --verbose "$APP_BUNDLE" 2>&1 && echo "✅ Signature valid" || echo "⚠️  Signature verification issue"

echo ""
echo "✅ Built and signed: $APP_BUNDLE"
echo ""
echo "To run:  open \"$APP_BUNDLE\""
echo "To dock: drag \"$APP_BUNDLE\" to your Dock"
