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
for test in gameplay_p07_tests.gd loot_feedback_tests.gd atmosphere_tests.gd audio_p07_tests.gd ui_p07_test.gd p08_gameplay_tide_tests.gd p08_ui_tutorial.gd readability_p08_tests.gd p08_audio_main.gd p08_audio_stress.gd; do
  "$GODOT" --headless --path . --script "res://tests/$test"
done
python3 scripts/make_audio_p07.py --verify-only
if [[ "${1:-}" == "--web" ]]; then
  mkdir -p export/web
  "$GODOT" --headless --path . --export-release Web export/web/index.html
  for file in index.html index.js index.pck index.wasm; do test -s "export/web/$file"; done
  echo "Web export complete: export/web/index.html"
fi
