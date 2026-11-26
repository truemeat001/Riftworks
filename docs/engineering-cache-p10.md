# P10 lab — generation-scoped presentation cache

Independent engineering experiment, not a production release. Baseline P09 exact Main SHA256 `753da621947929253ebb6209bb44b88018f35ae5d1e3cc6ec14801cc82c09147`, Run `0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25`, BattleAtmosphere `64d494d0b0affe3c8fdbc06a5bf256ae0d2e7e582e2154d85a46a9a4840ccd18`, BattleReadability `124d7fc297d86ec05cbb346140452faa9c6dca724fa942bb729f39297716a5a6`. Source assets wholly unchanged. Only the lab copies changed.

## Design and invalidation

`BattlePresentationCache.gd` computes actual layout, guard cooldown status and actual historical redirect records at most once per valid presentation state. Main invalidates after each Run.step and on the existing model changed signal (reset, start, legal planning change, stage/wave/terminal transitions). Key also includes model, readability and atmosphere identities; stage, wave, phase, tick, route choice, opened flag, logical origin and tile, and viewport size. Model replacement clears previous model's death-anchor history. Logical geometry change also clears pixel-offset history; physical viewport resize alone recalculates without changing logical coordinates. Any direct same-tick fixture mutation must explicitly invalidate; production Run actions are covered by signals or step. Repeated unchanged paused frames reuse geometry. Arrays/dictionaries recursively made read-only; no model object or authoritative state is frozen. 
   
Draw call ordering, colors, geometry, effect time, actual health, audio, authoritative shot destination, frame sprites, and art remain unchanged. Main continues to increment idle/loot/death clocks and draw every frame. Only the expensive query results are reused. The two atmosphere drawing methods accept optional records with fallback to original direct query for existing callers. Compared against the pinned baseline: every 47 `canvas.draw_*` lines in BattleAtmosphere exactly unchanged; Main's 53 `draw_*` lines excluding the two changed argument lists exactly unchanged. Full actual-record equality and death-anchor equality tested below; physical pixel equivalence still requires native/exported Web capture.

## Independent correctness and performance

`tests/p10_presentation_cache_tests.gd`: 35/35 assertions; fixed six real Run.start/step waves, five legal rank-2 towers, seed 437, same pressure fixture as P09. 1710 total computed generations and 3420 cache hits (three presentations per logic tick, alternating A/B order to reduce ordering bias). Every actual layout/status/redirect bundle equal across all three display-query calls each tick, all authoritative state snapshots unchanged, 940 death-anchor/scale comparisons and 1791 guard observation counts, no mismatches. Fixture also covers model/helper replacement, explicit same-tick mutation, viewport and logical size changes, rollback, same-seed reset/restart, recursively read-only arrays, unchanged pause reuse. The final boss escape is a deliberate stress fixture, not a balance claim.

| Actual wave | Baseline 3 queries median / p95, µs | Implemented cache 1 query + 2 hits median / p95, µs |
|---|---:|---:|
| Tidecross 1 | 464 / 2298 | 203 / 980 |
| Tidecross 2 | 627 / 2915 | 251 / 1571 |
| Twin Tide 1 | 2067 / 7557 | 721 / 3344 |
| Twin Tide 2 | 2327 / 13397 | 814 / 4544 |
| Echo Reef 1 | 3565 / 18784 | 1241 / 5825 |
| Echo Reef 2 | 4496 / 23690 | 1463 / 8347 |

Godot Linux headless time elapsed, shared-cloud scheduling contention; no GPU or FPS claims. In heaviest fixture median -67.5%, p95 -64.8% for the query batch only. Work reduction exact 3→1. Full production frame time may differ, especially at 2x speed, low FPS or large model changes. No per-frame model state copy or hash is used in actual candidate.

`tests/p10_cache_main_hooks.gd`: **20/20** actual Main instance/headless UI hook checks. Actual loot accepted, legal deploy, start, one Run.step from Main._process, pause/resume, model/idle clocks, unchanged geometry during ongoing animation, confirm restart, accepted retry same seed clear cached enemies. Initial test used reserved tile (4,2) and correctly rejected; corrected fixture legal (5,2), no code change needed. Existing regressions: 1627/1627 atmosphere, 5911/5911 readability, 3630/3630 guard art (no native screenshot implied).

## Port and gate

Only port the small Main integration diff, optional BattleAtmosphere record inputs and new BattlePresentationCache; don't overwrite other P10 agents' Main/Run/map logic. Preserve existing animated redraw/audio and use explicit invalidation on any new accepted model action. If dual-exit map alters warning/readability inputs, include model revision and new layout geometry; recompute actual danger marker placement before production. Independent native 1280x800/960x600 and exported Web comparison required: frozen same seed/model tick and idle/loot/death clocks, actual guard ready/cooldown/redirect samples, pause/resume/resize/2x and stage/reset, screenshots or frame-diff, performance traces. This lab machine has no graphics backend available to these tests; the report makes no native performance claim.
