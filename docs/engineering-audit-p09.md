# P09 engineering audit — build weight, latency, memory, render work

Status: measured P08 shipping package; P09 CPU fixture frozen-source run; P09 final export inventory pending. No changes to production code or quality made in this audit. Measurements reflect Linux cloud Godot 4.7.2, headless CPU only; no claim of browsers/mobile FPS, actual GPU resident bytes, or startup/download time.

## Reproducibility

```sh
python scripts/audit_build_p09.py ../RiftworksP08-delivery/RiftworksP08-web.zip ../RiftworksP08
python scripts/audit_build_p09.py ../RiftworksP09-delivery/RiftworksP09-web.zip .
godot --headless --path . --script res://tests/p09_perf_ticks.gd
godot --headless --path . --script res://tests/p09_perf_cache_ab.gd
```

The inventory validates ZIP CRCs, v4 PCK directory boundaries and every entry's MD5 payload digest, lists ZIP raw/compressed and PCK imported bytes separately, maps exact source import remaps, and distinguishes logical RGBA/PCM sizes from actual allocated process/GPU memory. The build comparison must use the final Web archive, not source ZIP, repository size or a stale editor import cache.

## Actual P08 baseline

| Component | Bytes |
|---|---:|
| Web ZIP complete | 26,790,261 |
| Web ZIP uncompressed total | 57,547,045 |
| Wasm raw | 39,514,754 |
| Wasm in ZIP | 10,114,273 |
| PCK raw | 17,697,660 |
| PCK in ZIP | 16,563,788 |
| PCK texture payload | 11,723,606 |
| PCK audio payload (imported samples) | 5,788,590 |
| PCK compiled scripts | 105,519 |
| PCK other payload | 65,072 |
| PCK directory, alignment, header | 14,873 |

144 entries, all verified. ZIP SHA-256 `de1ed44051c6257576b7a86591c5416565f306e5440b7c66c737ecbccd198283`; PCK SHA-256 `2c218447d9e7becb29ee963794fb74ef075d3567b03661e2c929c109119e68bf`. No docs, tests, scripts, authoring master audio remaps present. However unused concept lineup was still packaged (196,684 payload bytes); production should exclude that exact presentation-independent asset, not blindly drop resources loaded by path.

The WASM engine is a significant fixed download floor (~10.11 MB ZIP deflate); PCK dominates compressed ZIP (~61.8%). The raw 39.5MB WASM and 17.7MB PCK are **not** RAM or actual HTTP transfer sizes: hosting may use gzip/Brotli/cache, and actual browser fetch must be verified in DevTools/network trace. Development source ZIP and ZIP compression are not Web-network compression guarantees.

## Main content/MEM budget

P08 (same P05 hand-painted asset pipeline) imported texture payload:
- Atlas 4,226,200 bytes, 2048x2006 pixels = 15.67 MiB at 4 bytes/pixel; 136 frame entries share one atlas, not 136 unique GPU textures.
- Tidecross 2,202,760, Twin Tide 1,950,750, Echo Reef 1,932,536 bytes; each 1585x992 = 6.00 MiB RGBA theoretical.
- Crew portraits combined ~0.75 MiB RGBA; two chest images 2 MiB; icons small. Concept art 1.44 MiB theoretical, but not loaded by Main.
- Total packaged texture uncompressed upper estimate 41,293,920 bytes (39.38 MiB). Subtracting unused concept lineup gives ~37.95 MiB for source-image RGBA of runtime candidates. These are single copies without mipmaps, not driver/CPU staging/browser memory. Current PNG import lossless, no mipmap.
- PCM source bytes for packaged WAV 5,772,480 (~5.51 MiB); raw imported resource 5,788,590. Two ambience loops each ~2.30 MB, ~80% of audio payload. GameAudio._ready eagerly loads all sound variants and both loops; Web sample playback may create additional float32/driver buffers. Original masters excluded in actual P08 PCK, raw authoring files retained for regeneration.
- Main.load_sprites eagerly loads three background textures simultaneously; stage-resident memory opportunity is ~12.0 MiB RGBA by keeping one active background instead of three. This **does not** shrink PCK and can add a stage-transition decode stall; measure before adopting. Atlas is already a sensible draw-batching layout for this game; don't duplicate it per role or indiscriminately scale it.

## Six fixed actual-wave CPU fixture

Run.start/step used 6 separate seeded waves (seed 437, five legal rank-2 towers, normal + opened second-stage rift, freeze2/blast1/chain1/relay1, P09 observed SCREEN/CLUSTER where appropriate). This is a forced pressure fixture, not a playable economy or balance report: final boss escaped with HP15. First run per wave discarded as warm-up; 5 measured repetitions, 30 result rows; each row hashes ordered model outputs at every simulation tick. All five repetitions of each wave have same result hash and tick count; no failures. Measurements use monotonic elapsed microseconds including possible shared-cloud scheduling stalls; table contains median of the five per-run P95s, not global pooled P95 or measured rendering. Logic tick interval = 50 ms (20 Hz), presentation may execute more often. Guard query includes guard_status_records + guard_redirect_records and is not additional damage.

| Stage / wave | Steps | Peak live enemies | Run.step p95 µs | Atmosphere.observe p95 µs | Readability.layout p95 µs | Guard queries p95 µs |
|---|---:|---:|---:|---:|---:|---:|
| Tidecross 1 | 112 | 5 | 153 | 59 | 296 | 46 |
| Tidecross 2 | 145 | 5 | 198 | 91 | 635 | 106 |
| Twin Tide 1 | 306 | 10 | 373 | 107 | 1628 | 2927 |
| Twin Tide 2 | 357 | 12 | 292 | 127 | 1758 | 3346 |
| Echo Reef 1 | 331 | 12 | 241 | 128 | 2062 | 6561 |
| Echo Reef 2 | 459 | 15 | 410 | 148 | 2682 | 5453 |

Source hotspot evidence: `BattleReadability.layout` loops over all living enemies for every enemy, then collision-aware health bar placement. `guard_status_records` scans candidate badge placements with protected bars and unrelated unit silhouettes. Main._process queues redraw every frame regardless of tick; Main._draw recomputes readability layout and guard badges every frame, even during pause or when simulation is unchanged. Max samples include >40 ms scheduling/CPU tails; not measured graphical frames. The 50ms logic tick itself is relatively inexpensive in this fixture; Run.choose_target CLUSTER is quadratic with candidate count, but do not rewrite deterministic logic ahead of measured larger stress. No actual GPU or browser FPS inferred from this table.

## Priority and production gates

1. **P0** measured package manifest and reproducible export: no importable authoring/master/docs/tests, exact runtime assets preserved, all dynamic loads resolve. Parse binary pack, compare hashes. Separate source archive from public Web ZIP.
2. **P1** reduce duplicate presentation geometry at identical simulation state. Cache layout + guard status per immutable frame-state generation, invalidate after every Run step/start/reset/stage/wave/phase change or resize/geometry/config change. Keep animation, impacts/alerts, audio clocks live. Explicit generation beats comparing only tick count, because reset or external test fixture can mutate same tick. Preserve death anchor/scale semantics. No model changes. A/B below.
3. **P1** render work separation: stage map/UI panels/socket eligibility independent of idle animation; cache procedural drawing in separate CanvasItems, redraw only on relevant events (selection, hover, stage/rules, build layout), keep units/health/VFX/loot animation dynamic. Profiling only, not assumed performance gain. Avoid baking text in image; responsive UI must stay readable. Native and Web frame-time traces required to decide actual draw cost.
4. **P2** memory/startup: stage-only background residency and asynchronous preload of next map; test initial activation, transition and repeat restart with no placeholder/flicker, source hashes unchanged. Consider loop compression/streaming only after audible A/B and Web sample mixer compatibility; preserve exact loop timing, original audio masters and real actual browser playback. Don't choose OGG solely because disk smaller; in-browser decode/memory may be same, audio loop seam and working mixed playback need verification.
5. **P2** consider precomputation for repeated static stats/route tail distance, only if profiler shows logic cost. Exact deterministic result/event hashes, 30/60/120 rendering tests, 1x/2x speed, pause, long frame, same seed/input; no hidden target-tie, event loss or speed-based cooldown behavior. A source-level optimization isn't a proof of native benefit.

Proposed release budgets (targets, not established device measurements): 1280x800 and 960x600 at 60Hz p95 total frame ≤16.7ms on named target machine; if 30Hz low-power policy is chosen, p95 ≤33.3ms. Record 1% low, P99, stalls >50ms, input latency, draw calls, texture bytes, process RSS and web JS heap/wasm linear memory separately; cold load transfer bytes/time, warm reload, 3× stage cycles/restarter memory. Hardware/OS/browser/version/DPR/render backend and throttling required. Measure paused/static and dense actual battle, not only empty scene. Test native individually plus actual exported Web, no Xvfb-only claims of target GPU FPS. Engine/container/platform, no arbitrary quality sacrifice. Final acceptor must independently rerun.

### Same-tick presentation cache A/B — isolated proof (not production code)

The independent test `tests/p09_perf_cache_ab.gd` alternates uncached/cached order on the same actual model tick; three presentation query batches per 50ms simulation state emulate 60Hz/20Hz without measuring any draw or animation. Baseline runs Readability.layout, guard_status_records, guard_redirect_records three times; candidate computes once and reuses the immutable result, invalidated explicitly on every step. Full structural equality checked each tick across all six waves; **1,710 samples × 3 result bundles each, zero mismatches**. Both candidates return actual events and preserve UI geometry. The isolated test does not change production.

| Wave | 3 queries baseline P95 µs | 1 query+reuse candidate P95 µs |
|---|---:|---:|
| Tidecross 1 | 4851 | 3097 |
| Tidecross 2 | 4675 | 1647 |
| Twin Tide 1 | 13624 | 5003 |
| Twin Tide 2 | 13080 | 7844 |
| Echo Reef 1 | 10295 | 4259 |
| Echo Reef 2 | 17187 | 6634 |

Echo Reef 2 median batch elapsed: 2751→834µs, p95 17187→6634µs in this interleaved shared-cloud run. Tail is noisy and includes substantial scheduling contention, so do not call this a frame-rate improvement. Exact work reduction is three expensive geometry queries to one per unchanged tick; strongest next candidate for P10. Do not implement cache across changed model generations. Production integration must verify pause/resume, stage change, reset same seed, restart, selection, hover, resize, speed and death anchors (including skipped presentation ticks), plus real native/browser frame-time and unchanged actual art.

Benchmark frozen source hashes: Run.gd `0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25`, BattleAtmosphere.gd `64d494d0b0affe3c8fdbc06a5bf256ae0d2e7e582e2154d85a46a9a4840ccd18`, BattleReadability.gd `124d7fc297d86ec05cbb346140452faa9c6dca724fa942bb729f39297716a5a6`.

## P09 exported package audit (actual export, local audit envelope)

P09 final export output found in `export/web`; verified all nine output files and actual PCK from export. To audit before delivery archive is available, wrapped those exact nine exported files in a local DEFLATE ZIP, not a separate build and not an official delivery file. P09 raw PCK SHA-256 `7488703fb85368f1eccbf3348cedf035692e85ea3e16457ca5d23001e521599a`. Every one of 150 entries passed MD5, remap paths resolved to source import destinations. No authoring/master, test, docs or scripts directory files. Source concept lineup remains unnecessarily packaged; not a release-blocking size.

| Component | P08 delivery | P09 actual export / local audit envelope | Change bytes |
|---|---:|---:|---:|
| ZIP size | 26,790,261 | 26,858,241* | +67,980* |
| Raw PCK | 17,697,660 | 17,782,456 | +84,796 |
| PCK in ZIP | 16,563,788 | 16,631,768* | +67,980* |
| Wasm raw | 39,514,754 | 39,514,754 | 0 |
| Wasm in ZIP | 10,114,273 | 10,114,273* | 0 |
| Texture payload | 11,723,606 | 11,723,606 | 0 |
| Imported audio payload | 5,788,590 | 5,858,859 | +70,269 |
| Compiled scripts | 105,519 | 118,700 | +13,181 |
| Other payload | 65,072 | 65,762 | +690 |
| PCK overhead | 14,873 | 15,529 | +656 |

*Local ZIP wrapping of actual export; final delivery ZIP checksum/files must still be checked when available. Envelope SHA-256 `e35c6b95957667b2598502a4cbd5a251808caee69aa5fcc3c4261f1d06f135d2`, not the final download hash. Actual source/runtime comparison: new intercept variants 3 × 23,040 PCM16 bytes (mono 48kHz, .24 seconds each), three imported samples 23,423 bytes each, exactly +70,269 audio payload. Packaged PCM16 source estimate now 5,841,600 bytes, theoretical RGBA still 41,293,920 bytes. No major art-size regression.

P09 raw PCK growth +0.48%; local deflated ZIP growth +0.25%. The export audit verifies payloads and content, but does not establish network speed, browser decode latency, display performance, or actual GPU memory.
