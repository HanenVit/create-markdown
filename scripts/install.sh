#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/Create Markdown.app"
SERVICE="$HOME/Library/Services/Создать .md.workflow"
SDK="$(xcrun --show-sdk-path)"
BUILD="$ROOT/build"
ICONSET="$BUILD/AppIcon.iconset"

if ! command -v clang >/dev/null; then
  echo "Нужны Command Line Tools: xcode-select --install" >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$BUILD/Resources" "$ICONSET" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SERVICE/Contents"

clang -fobjc-arc -isysroot "$SDK" -mmacosx-version-min=13.0 \
  -framework Cocoa \
  -o "$APP/Contents/MacOS/CreateMarkdown" \
  "$ROOT/src/main.m"

cp "$ROOT/src/Info.plist" "$APP/Contents/Info.plist"

for spec in \
  "16:icon_16x16.png" \
  "32:icon_16x16@2x.png" \
  "32:icon_32x32.png" \
  "64:icon_32x32@2x.png" \
  "128:icon_128x128.png" \
  "256:icon_128x128@2x.png" \
  "256:icon_256x256.png" \
  "512:icon_256x256@2x.png" \
  "512:icon_512x512.png" \
  "1024:icon_512x512@2x.png"
do
  px="${spec%%:*}"
  name="${spec##*:}"
  sips -z "$px" "$px" "$ROOT/assets/AppIcon.png" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"
codesign --force --sign - --identifier com.hanenvit.create-markdown "$APP"

clang -fobjc-arc -isysroot "$SDK" -mmacosx-version-min=13.0 \
  -framework Cocoa \
  -o "$BUILD/set-icon" \
  "$ROOT/scripts/set-icon.m"
"$BUILD/set-icon" "$ROOT/assets/AppIcon.png" "$APP"

cp "$ROOT/service/Info.plist" "$SERVICE/Contents/Info.plist"
cp "$ROOT/service/document.wflow" "$SERVICE/Contents/document.wflow"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$APP" >/dev/null
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true

echo "Готово: $APP"
echo "Служба: $SERVICE"
echo "Перетащите программу в Dock. При первом клике разрешите управление Finder."
