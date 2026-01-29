#!/bin/bash

# Flux Build Script
# Builds the Flux app for macOS

set -e

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="${PROJECT_DIR}/build"
PRODUCT_NAME="Flux"
BUNDLE_ID="com.flux.launcher"
APP_NAME="${PRODUCT_NAME}.app"
CONTENT_DIR="${BUILD_DIR}/${APP_NAME}/Contents"
MACOS_DIR="${CONTENT_DIR}/MacOS"
RESOURCES_DIR="${CONTENT_DIR}/Resources"

echo "🔨 Building Flux..."

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile Swift files
echo "📦 Compiling Swift sources..."

SWIFT_FILES=(
    "FluxApp.swift"
    "Models/AppState.swift"
    "Models/Game.swift"
    "Services/SteamLibraryDetector.swift"
    "Services/GameLauncher.swift"
    "Services/DependencyManager.swift"
    "Services/LogManager.swift"
    "Services/SettingsManager.swift"
    "Services/ProcessMonitor.swift"
    "Services/MetalDeviceDetector.swift"
    "Views/ContentView.swift"
    "Views/GamesView.swift"
    "Views/PrefixesView.swift"
    "Views/LogsView.swift"
    "Views/SettingsView.swift"
)

# Build command
BUILD_OUTPUT="${BUILD_DIR}/${PRODUCT_NAME}"

swiftc \
    -parse-as-library \
    -emit-executable \
    -o "${MACOS_DIR}/${PRODUCT_NAME}" \
    -target arm64-apple-macosx13.0 \
    -framework AppKit \
    -framework Foundation \
    -framework Combine \
    -framework SwiftUI \
    -Osize \
    "${SWIFT_FILES[@]/#/${PROJECT_DIR}/}"

echo "✅ Swift compilation complete"

# Copy Info.plist
echo "📋 Configuring bundle..."
cp "${PROJECT_DIR}/Info.plist" "${CONTENT_DIR}/Info.plist"

# Create PkgInfo
echo "APPLFlux" > "${CONTENT_DIR}/PkgInfo"

# Create app icon placeholder
echo "🎨 Setting up resources..."
mkdir -p "${RESOURCES_DIR}/Assets.xcassets/AppIcon.appiconset"

# Make executable
chmod +x "${MACOS_DIR}/${PRODUCT_NAME}"

echo ""
echo "✨ Build complete!"
echo "📍 App location: ${BUILD_DIR}/${APP_NAME}"
echo ""
echo "To run the app:"
echo "  open ${BUILD_DIR}/${APP_NAME}"
