#!/bin/bash
set -e

APP_NAME="OpenPaw"
BUILD_DIR=".build/debug"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Build
swift build

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.openpaw.app</string>
    <key>CFBundleName</key>
    <string>OpenPaw</string>
    <key>CFBundleDisplayName</key>
    <string>OpenPaw</string>
    <key>CFBundleExecutable</key>
    <string>OpenPaw</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

# Codesign with entitlements
codesign --force --sign - --entitlements OpenPaw.entitlements "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Built: ${APP_BUNDLE}"
open "$APP_BUNDLE"
