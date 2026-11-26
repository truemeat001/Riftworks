#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT:-godot}"
mkdir -p export/web
touch export/.gdignore
"$GODOT" --version
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --quit-after 30
"$GODOT" --headless --path . --script res://tests/run_tests.gd
if [[ "${1:-}" == "--web" ]]; then
  mkdir -p export/web
  "$GODOT" --headless --path . --export-release Web export/web/index.html
  for file in index.html index.js index.pck index.wasm; do test -s "export/web/$file"; done
  echo "Web export complete: export/web/index.html"
fi
