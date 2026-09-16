#!/bin/bash
# Build Cube Scrambler and install it into /Applications.
#
# swift build alone produces a bare executable, not something the Dock can hold:
# the .app around it - Info.plist, icon, ad-hoc signature - is assembled here.
# That assembly used to be done by hand, which is how the installed copy ended up
# four commits behind the source with nothing to notice it.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CubeScrambler"
APP="$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_NAME.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "Icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.andrewlarkins.cubescrambler</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Cube Scrambler</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.education</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP"

rm -rf "$INSTALL_PATH"
cp -R "$APP" "$INSTALL_PATH"
touch "$INSTALL_PATH"

echo "Installed to $INSTALL_PATH"
