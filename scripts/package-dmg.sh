#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_bundle="${1:-$project_root/.build/MacWipePlus.app}"
output_path="${2:-$project_root/.build/MacWipePlus.dmg}"

test -d "$app_bundle"
rm -f "$output_path"
hdiutil create \
  -volname "MacWipePlus" \
  -srcfolder "$app_bundle" \
  -ov \
  -format UDZO \
  "$output_path" >/dev/null

echo "Packaged $output_path"
