# P10 candidate: eight-wave campaign presentation and Twin Beacons P0 repair

Independent candidate only. Frozen P09 and encounter insertion lab untouched. Do not ship as public before integrated GPU/Web and independent QA. This uses the approved insertion model, not a new rebalance.

## Scope / merge ownership
- candidate/src/Run.gd: exact encounter/insertion source with small presentation additions in patches/Run-leak-events.diff: public active_lanes() getter and recent authoritative leak_events snapshots at actual escape (tick, original stage/wave, endpoint, lane, enemy ID and boss), before removal/transition. No damage, odds, health, gold, count, speed, routing, reward, or RNG changes.
- candidate/src/LanePresentation.gd: shared pure helper. Reads actual lanes/remaining-distance <=2 cells, groups unique endpoints (P09 optional risk lanes have ONE shared core), computes exact warning center/count and visible clamped rectangle, exposes lane names.
- candidate/src/BattleAtmosphere.gd: both active entries, one warning per actual endangered exit, distinct North/South labels; per-exit leak ring/receipt; clears previous stage/run state; new hazard entry emits endpoint event once. Guard badges avoid all warnings; duplicate observations do not replay. Existing attacks/Guard/transfer FX preserved. Use patch rather than blind overwriting other agents' VFX integration.
- candidate/src/BattleReadability.gd: same warning footprints; permits nearby leader-linked compact bars inward at lower board edge after ordinary positions fail; keeps north lane silhouettes below HUD, retaining actual coordinates + render-only foot offset. Real 8 unresolved bars resolved.
- candidate/src/Main.gd: four sector maps, unique active entry names and actual separate core destinations, existing lighthouse reused twice, off corridor with marker on exact endpoint. Shift Echo-only amplifier props/links to stage3. Global wave 1–8, route switch state/forecasts, North/South coverage, free reversible switch, mandatory two lanes with one shared HP/no fake bonus, exact per-endpoint hazard/escape counts; old optional risk still visible. Sound requests actual endpoint; additional lane enter bounded per endpoint to 44 ticks (2.2s), normal mixer caps remain. Terminal leak cue after battle group stop. Real UI revealed P09 rank3 merge synchronous changed signal previewing rank4: revalidate partner before refresh to prevent invalid array index; no rule change.
- candidate/assets/environment/twinbeacons_background.png: ImageGen original landscape 1586×992, 2,259,177 bytes. Existing Twin-Tide reference solely for isometric gouache, cream sand/teal/shale/coral materials. Broad flat terrain, separate sandy promontories, side entry ledges, no baked route, buildings, UI, fake obstacles or labels. Actual route and existing lighthouse assets dynamic. Original generated raster preserved. Headless import/load verified; visual validation pending, no claim of package contribution until actual engineering export.

Use patch or 3-way merge with independently modified Main/Atmosphere/Readability. Required scripts, new helper, new landscape + import only; don't copy .godot cache. Other agents own death/attack/atlas/load implementation; do not overwrite those with this candidate's untouched baseline.

## Verified evidence

### Actual Godot model, 8 seeded complete-to-terminal runs
evidence/trace.json, twin-trace.log, candidate/tests/twin_trace.gd. Six same seeds and policy as independent prior VFX audit (437,438,441,447,450,452, open/closed and north/south long); two additional legal seed437/438 runs with weak one-crew defense at Wave5 to observe natural simultaneous pressure (not invented enemies). 52 real waves, 13,668 ticks, 96,764 checks, zero failures. Strong runs reproduce earlier phase/outcome patterns (3 wins, 3 losses); weak runs legitimately fail, pressure witness not balance recommendation.

| Metric | Result |
|---|---:|
| Twin north-only danger ticks | 504 |
| Twin south-only danger ticks | 811 |
| Twin simultaneous danger ticks | 214 |
| Twin actual confirmed leaks N / S | 35 / 43 |
| Correct warning records, all sectors | 2,354 |
| Misattributed / omitted / extra / out-of-board warnings | 0 |
| Warning overlaps with HP bars / guard badges | 0 |
| Unresolved ordinary health bars (was 8) | 0 |
| Hidden guard badges | 0 |
| Model snapshots altered by presentation / duplicate leak/alert entries | 0 |
| Reset residue | 0 |

Post-step actual state: independently tally alive enemies below remaining-distance threshold, compare exact endpoint counts to Atmosphere and warning records, board enclosure (2 px outline safety), actual center formula. Every bar/guard badge vs each warning, authoritative leak delta vs new events, Twin leak endpoint vs lane identity incl stage transition/terminal; duplicate observe no replay or authority mutation. Both mandatory lane forecasts/paths present, only one endpoint in original shared-core stages. Insertion rules rerun 708 checks pass (twin-rules.log).

### Actual Main scene/legitimate UI callbacks (NOT physical player)
candidate/tests/twin_ui.gd, evidence/ui-437.json, ui-452.json and logs. Two complete UI callback runs with paid explores, reveal skip, merge buttons/reserve selection, actual board press+release deploy/recall, order toggle, special/start button signals, model advancement via Main._process. Actual acquired assets, no roster injection. Both reach 8-wave Echo Boss victory:
- seed437 closed earlier optional risk, South long: 10 HP, north actual danger/leak cues 7.
- seed452 open earlier optional risk, North long: 3 HP, south actual danger/leak cues 6.
- 162 + 175 = 337 UI checks, zero failure. Wave labels, correct art resources, two forecast rows per lane, shared HP text, no fake bonus, reversible free route choice with unchanged layout/HP/gold, old optional risk, correct progression/final boss/report. Forecast label real font minimum height<=79 logical px and every line actual font measured width<=231; wave label actual measured width<=147. UI disabled while fighting, complete logs clean (no script errors).
- Sound events are actual mixer requests; no WebGL listening claim.

## Reproduce
Godot 4.7.2:
  godot --headless --path candidate --editor --import --quit
  godot --headless --path candidate -s tests/insertion_rules.gd
  godot --headless --path candidate -s tests/twin_trace.gd -- /absolute/output/trace.json
  godot --headless --path candidate -s tests/twin_ui.gd -- /absolute/output/ui-437.json 437
  godot --headless --path candidate -s tests/twin_ui.gd -- /absolute/output/ui-452.json 452
Separate writable XDG cache/data/config paths. Source hashes and exact patches supplied; no production changes.

## Native gate still outstanding
candidate/tests/TwinNativeCapture.tscn actual Main UI capture harness, plan/W5-W6 danger/Boss/terminal viewport screenshots at 1280×800 default. Run: godot --path candidate res://tests/TwinNativeCapture.tscn; exported capture_seed 452 for North long/South threat, 437 default. Compiles headless, native GPU screenshots not run here because no DISPLAY. Outputs user://twin-<seed>-*.png and JSON. Root must independently assess 1280/960 and perform real normal speed end-to-end. Confirm viewport pixel contrast, map-edge silhouette/destination relationship, both simultaneous alerts, correct route overlay on art, terminal/restart/actual browser sound. This standalone candidate not release-ready; other agents' VFX/animation/audio/loading gates remain.

Independent pre-existing model trace comparison: all 294 per-wave fields (stage/wave/start HP/ticks/leaks/end HP/phase across same 42 waves) match exact prior P10 insertion+old-presentation trace, zero mismatches. No gameplay behavior changes from event metadata.
