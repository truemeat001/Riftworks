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
for test in gameplay_p07_tests.gd loot_feedback_tests.gd atmosphere_tests.gd audio_p07_tests.gd ui_p07_test.gd p08_gameplay_tide_tests.gd p08_ui_tutorial.gd readability_p08_tests.gd p08_audio_main.gd p08_audio_stress.gd p09_guard_tests.gd p09_integrated_logic_tests.gd p09_orders_logic_tests.gd p09_guard_art_tests.gd p09_ui_guard.gd p09_ui_orders.gd p09_ui_attack_dedup.gd p09_audio_guard_tests.gd p09_audio_guard_stress.gd p09_web_audio_contract.gd p09_ui_sound_test.gd; do
  "$GODOT" --headless --path . --script "res://tests/$test"
done
python3 scripts/make_audio_p07.py --verify-only
python3 scripts/evaluate_audio.py --manifest docs/audio-p09-manifest.json --baseline docs/audio-quantitative-p07.csv --output /tmp/riftworks-p09-audio-verify.csv
if [[ "${1:-}" == "--web" ]]; then
  mkdir -p export/web
  "$GODOT" --headless --path . --export-release Web export/web/index.html
  for file in index.html index.js index.pck index.wasm; do test -s "export/web/$file"; done
  echo "Web export complete: export/web/index.html"
fi
