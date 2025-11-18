#!/bin/bash

# Build the Swift package
echo "Building BetterDocs..."
swift build

# Create app bundle structure
APP_NAME="BetterDocs.app"
APP_DIR="build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating app bundle structure..."
rm -rf build/$APP_NAME
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the executable
echo "Copying executable..."
cp .build/arm64-apple-macosx/debug/BetterDocs "$MACOS_DIR/"

# Bundle Claude Agent SDK
echo "Bundling Claude Agent SDK..."
if [ -d "BetterDocs/Resources/claude-agent-sdk" ]; then
    cp -R BetterDocs/Resources/claude-agent-sdk "$RESOURCES_DIR/"
    chmod +x "$RESOURCES_DIR/claude-agent-sdk/node_modules/@anthropic-ai/claude-agent-sdk/cli.js"
    chmod +x "$RESOURCES_DIR/claude-agent-sdk/agent-wrapper.mjs"
    echo "  ✓ Claude Agent SDK bundled (v0.1.37)"
else
    echo "  ⚠ Claude Agent SDK not found in Resources, app will use system CLI if available"
fi

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>BetterDocs</string>
    <key>CFBundleIdentifier</key>
    <string>com.betterdocs.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>BetterDocs</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "✅ App bundle created at: $APP_DIR"
echo ""
echo "To run the app:"
echo "  open $APP_DIR"
echo ""
echo "To install to Applications:"
echo "  cp -r $APP_DIR /Applications/"
