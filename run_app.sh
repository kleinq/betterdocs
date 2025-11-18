#!/bin/bash

echo "🚀 BetterDocs - Building and Launching..."
echo ""

# Build the Xcode project
echo "📦 Building app..."
xcodebuild -project BetterDocs.xcodeproj \
           -scheme BetterDocs \
           -configuration Debug \
           -destination 'platform=macOS' \
           build 2>&1 | grep -E "(BUILD SUCCEEDED|error:)" | tail -1

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""

    # Find and launch the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/BetterDocs*/Build/Products/Debug -name "BetterDocs.app" 2>/dev/null | head -1)

    if [ -n "$APP_PATH" ]; then
        echo "🎯 Launching: $APP_PATH"
        open "$APP_PATH"
        sleep 2

        # Check if app is running
        if ps aux | grep -v grep | grep "BetterDocs.app" > /dev/null; then
            echo "✅ BetterDocs is now running!"
            echo ""
            echo "📝 Note: Check your Dock for the BetterDocs icon"
            echo "   If no window appears, check Console.app for errors"
        else
            echo "⚠️  App launched but may have crashed. Check Console.app"
        fi
    else
        echo "❌ Could not find built app"
    fi
else
    echo "❌ Build failed"
fi
