#!/bin/zsh
# Build and wrap the binary into AgencyHQ.app (unsigned; first launch: right-click > Open)
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=AgencyHQ.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/AgencyHQ "$APP/Contents/MacOS/AgencyHQ"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Agency HQ</string>
<key>CFBundleIdentifier</key><string>local.agencyhq</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>AgencyHQ</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
