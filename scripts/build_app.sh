#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_NAME="LifePlan Pro"
PRODUCT="LifePlanPro"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "Building $APP_NAME…"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Keep this source compatible with the macOS 13 deployment target while building with newer SDKs.
python3 - <<'PY'
from pathlib import Path
p = Path('Sources/LifePlanPro/main.swift')
s = p.read_text()
s = s.replace('.onChange(of: context.date){ _,v in now=v }', '.onChange(of: context.date){ v in now=v }')
p.write_text(s)
PY

# Build a Universal 2 executable when the installed Swift toolchain supports both architectures.
if swift build -c release --arch x86_64 --arch arm64; then
  BIN_DIR="$(swift build -c release --arch x86_64 --arch arm64 --show-bin-path)"
else
  echo "Universal build unavailable on this runner; falling back to native architecture."
  swift build -c release
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi

cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
chmod +x "$APP/Contents/MacOS/$PRODUCT"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>LifePlan Pro</string>
<key>CFBundleDisplayName</key><string>LifePlan Pro</string>
<key>CFBundleIdentifier</key><string>com.motive.lifeplanpro</string>
<key>CFBundleExecutable</key><string>LifePlanPro</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
cd "$DIST"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "LifePlan-Pro-macOS.zip"
echo "Built: $APP"
