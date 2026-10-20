#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/MenuBarPet.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MenuBarPet "$APP/Contents/MacOS/"
cp -R Resources/sprites "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.kavyaagar.MenuBarPet</string>
<key>CFBundleName</key><string>MenuBarPet</string>
<key>CFBundleExecutable</key><string>MenuBarPet</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSCalendarsFullAccessUsageDescription</key><string>Lets your dog bark when a meeting is about to start.</string>
<key>NSCalendarsUsageDescription</key><string>Lets your dog bark when a meeting is about to start.</string>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>com.kavyaagar.MenuBarPet</string><key>CFBundleURLSchemes</key><array><string>menubarpet</string></array></dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
