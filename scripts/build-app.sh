#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

swift build -c release

app_bundle="$project_root/.build/MacWipePlus.app"
rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$project_root/.build/arm64-apple-macosx/release/MacWipePlus" "$app_bundle/Contents/MacOS/MacWipePlus"
cp "$project_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"
cp "$project_root/Resources/MacWipePlus.icns" "$app_bundle/Contents/Resources/MacWipePlus.icns"
chmod +x "$app_bundle/Contents/MacOS/MacWipePlus"

echo "Built $app_bundle"
