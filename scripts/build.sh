#!/bin/zsh
set -eu
cd "${0:A:h}/.."
APP="$PWD/build/DualSense Cursor.app"
mkdir -p "$APP/Contents/MacOS" "$PWD/build/module-cache"
xcrun swiftc Sources/main.swift Sources/DualSenseInput.swift Sources/DualSenseReport.swift Sources/CursorMotion.swift Sources/TouchGestures.swift Sources/ClickSequence.swift Sources/PermissionChange.swift -o "$APP/Contents/MacOS/DualSenseCursor" -module-cache-path "$PWD/build/module-cache" -framework AppKit -framework IOKit -framework ApplicationServices -target "$(uname -m)-apple-macosx12.0" -O
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DualSenseCursor</string>
<key>CFBundleIdentifier</key><string>local.dualsense.cursor</string>
<key>CFBundleName</key><string>DualSense Cursor</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
print "Built $APP"
