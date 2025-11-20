#!/bin/bash

set -e  # Exit on error

echo "📦 BetterDocs Packaging Script"
echo "=============================="
echo ""

# Configuration
APP_NAME="BetterDocs"
VERSION="1.0.0"
BUNDLE_ID="com.betterdocs.app"
XCODE_BUILD_DIR="/Users/robertwinder/Library/Developer/Xcode/DerivedData/BetterDocs-bgamzcypyjutrgcvauzcwwzqlugh/Build/Products/Release"
DIST_DIR="dist"
APP_BUNDLE="$XCODE_BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Clean previous dist
echo "🧹 Cleaning previous distribution..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build the app with Xcode in Release mode
echo ""
echo "🔨 Building $APP_NAME in Release mode with Xcode..."
xcodebuild -scheme BetterDocs -configuration Release clean build > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Build succeeded"
else
    echo "❌ Build failed"
    exit 1
fi

# Verify the app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at: $APP_BUNDLE"
    exit 1
fi

echo -e "  ${GREEN}✓${NC} App bundle found at: $APP_BUNDLE"

# Add icon to the app bundle
echo ""
echo "🎨 Adding app icon..."
mkdir -p "$APP_BUNDLE/Contents/Resources"

if [ -f "BetterDocs/Resources/AppIcon.icns" ]; then
    cp "BetterDocs/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo -e "  ${GREEN}✓${NC} App icon copied"

    # Add CFBundleIconFile to Info.plist
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist"
    echo -e "  ${GREEN}✓${NC} Icon reference added to Info.plist"
else
    echo -e "  ${YELLOW}⚠${NC}  App icon not found at BetterDocs/Resources/AppIcon.icns"
    echo "     Run: python3 create_icon.py"
fi

# Bundle Claude Agent SDK
echo ""
echo "📦 Bundling Claude Agent SDK..."
SDK_SOURCE="BetterDocs/Resources/claude-agent-sdk"
SDK_DEST="$APP_BUNDLE/Contents/Resources/claude-agent-sdk"

if [ -d "$SDK_SOURCE" ]; then
    # Copy entire SDK directory including node_modules
    cp -R "$SDK_SOURCE" "$APP_BUNDLE/Contents/Resources/"

    # Extract version from package.json if available
    if [ -f "$SDK_SOURCE/package.json" ]; then
        SDK_VERSION=$(grep '"version"' "$SDK_SOURCE/package.json" | sed 's/.*"version": "\(.*\)".*/\1/')
        echo -e "  ${GREEN}✓${NC} Claude Agent SDK bundled (v$SDK_VERSION)"
    else
        echo -e "  ${GREEN}✓${NC} Claude Agent SDK bundled"
    fi
else
    echo -e "  ${YELLOW}⚠${NC}  Claude Agent SDK not found at $SDK_SOURCE"
fi

# Code sign the app (ad-hoc signing for local distribution)
echo ""
echo "✍️  Code signing..."
if command -v codesign &> /dev/null; then
    # Ad-hoc signing (works without Apple Developer account)
    codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 | grep -v "replacing existing signature" || true
    echo -e "${GREEN}✓${NC} App signed (ad-hoc)"
else
    echo -e "${YELLOW}⚠${NC}  codesign not found, skipping signing"
fi

# Verify the app bundle
echo ""
echo "🔍 Verifying app bundle..."
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [ -x "$APP_EXECUTABLE" ]; then
    echo -e "${GREEN}✓${NC} App bundle is valid"
    echo -e "  ${BLUE}→${NC} Executable: $APP_EXECUTABLE"
else
    echo "❌ App bundle verification failed"
    exit 1
fi

# Check icon
if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    echo -e "  ${GREEN}✓${NC} App icon verified in bundle"
else
    echo -e "  ${YELLOW}⚠${NC}  App icon missing from bundle"
fi

# Create DMG
echo ""
echo "💿 Creating DMG installer..."

# Create a temporary directory for DMG contents
DMG_TEMP="dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temp directory
echo "  → Copying app bundle..."
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create Applications symlink
echo "  → Creating Applications symlink..."
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
echo "  → Building DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME" > /dev/null 2>&1

# Clean up temp directory
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✓${NC} DMG created: $DIST_DIR/$DMG_NAME"

# Get file size
DMG_SIZE=$(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)

# Clear icon cache to ensure icon shows up
echo ""
echo "🔄 Clearing icon cache..."
sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
killall Finder 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Icon cache cleared"

# Summary
echo ""
echo "=============================="
echo -e "${GREEN}✅ Packaging Complete!${NC}"
echo "=============================="
echo ""
echo "📦 Outputs:"
echo -e "  ${BLUE}•${NC} App Bundle: $APP_BUNDLE"
echo -e "  ${BLUE}•${NC} DMG Installer: $DIST_DIR/$DMG_NAME ($DMG_SIZE)"
echo ""
echo "🚀 Next Steps:"
echo -e "  ${BLUE}1.${NC} Test the app:"
echo "     open \"$APP_BUNDLE\""
echo ""
echo -e "  ${BLUE}2.${NC} Install to Applications:"
echo "     cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo -e "  ${BLUE}3.${NC} Mount DMG:"
echo "     open \"$DIST_DIR/$DMG_NAME\""
echo ""
echo -e "  ${BLUE}4.${NC} Distribute:"
echo "     Share the DMG file with others"
echo ""
echo "📝 App logs will be written to: ~/Library/Logs/BetterDocs/"
echo ""
echo "Note: If the icon doesn't appear immediately, you may need to restart Finder"
echo "      or wait a few moments for the icon cache to refresh."
echo ""
