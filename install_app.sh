#!/bin/bash
# Install the latest built OpenFlux app to /Applications
# This ensures "Open with OpenFlux" handler uses the latest version

set -e

# Find the Xcode DerivedData path dynamically
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
XCODE_BUILD_PATH=$(find "$DERIVED_DATA" -maxdepth 2 -type d -name "Flux-*" 2>/dev/null | head -1)
if [ -n "$XCODE_BUILD_PATH" ]; then
    XCODE_BUILD_PATH="$XCODE_BUILD_PATH/Build/Products/Release/OpenFlux.app"
fi
INSTALL_PATH="/Applications/OpenFlux.app"

if [ ! -d "$XCODE_BUILD_PATH" ]; then
    echo "❌ Error: Built app not found."
    echo ""
    echo "Please build the project first:"
    echo "  xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Release build"
    exit 1
fi

echo "📦 Installing latest OpenFlux build..."
rm -rf "$INSTALL_PATH" 2>/dev/null || true
cp -r "$XCODE_BUILD_PATH" "$INSTALL_PATH"

echo "🔄 Updating launch services database..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_PATH"

echo "✅ Installation complete!"
echo ""
echo "OpenFlux is now installed to: $INSTALL_PATH"
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown")
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown")
echo "Version: $SHORT_VERSION (Build $BUNDLE_VERSION)"
echo ""
echo "💡 Tip: You can now use 'Open with OpenFlux' from Finder on .exe files"
