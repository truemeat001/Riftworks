# P10 HUD typography and boundary repair: independent candidate

Scope: current P10 Main/Tutorial snapshot, not P09 nor any other Agent project. Original real P09 browser screenshot and P10 original native screenshot establish failure: unsupported heart/coin/circled-digit/arrows appeared as tofu boxes; stage and wave labels crossed paper panel borders. User requested actual fix, not just report.

## Implementation
- Embed original Open Sans Regular, sourced from installed Debian fonts-open-sans, 217,360 bytes; Apache-2.0 complete license and copyright (Google Corporation digitized data 2010-2011), unmodified original. SHA256 e64e508b... . Explicit FontFile.allow_system_fallback=false; all authored Label/Button controls use this project-resource font and CanvasItem drawing shares same font. HUD Theme and TooltipLabel use the identical explicit font. Font size 14 for tooltips.
- Runtime src visible text and tooltips are all ASCII. HP/GOLD words replace broken heart plus coin glyph and separate coin illustration (no overlap). Explore clearly says 6 COINS; route arrow and progression use >; numbered guidance uses 1./2./3.; multiplication x, dash and |, not system-specific symbol fonts.
- Top title x21/w204; resources x230/w181, stage x448/w166 (panel 435..739), Guide x620/w107, Wave x756/w73 two lines (panel 745..1013), SOUND x835/w82, TEST SOUND x923/w85 both 12px. Original stage x421 and Wave x699 physically straddled different paper boxes. All top text authored boxes now have margin and deliberate hierarchy; no global font-shrink.
- Explicitly register 48 HUD controls with authored rect; preserve those sizes and position; deterministic word-bound wrap at actual embedded font metrics, max visible rows from height, clip safeguard for future unknown long strings with ASCII ellipsis and full tooltip. Tested real states never need ellipsis. Cache text layout per copy/size. Tooltip source text wraps at 320px / 14px retaining complete copy, and key labels allow hovering. More concise visible relic summaries; complete original detailed info remains on tooltip. Preserve interactions, UI input hit targets, model rules and route/seed.
- Retain existing UI labels for user and tests. Stage and resource title no longer overlap paper. Width/height checks derive actual engine metrics rather than string length or assumed proportional glyph size.
- Candidate changes: Main.gd and Tutorial.gd diffs, assets/fonts/OpenSans-Regular.ttf and LICENSE-OpenSans.txt, preset include filter for license. Do not overwrite independent Loot/Main changes; apply patch / 3-way merge and retain equivalent ASCII normalizations in newly inserted Loot text. No model or RNG modifications.

## Actual tests
Godot 4.7.2 headless, real Main scene UI callbacks and lawful model input: seed437 closed risk, South long, 8 waves won with 10 HP; seed452 open risk, North long, 8 waves won with 3 HP. Repeated legitimate recruit/skip, inventory selection, board clicks, recall/merge, order switch, both route orientations, combat/paused/resume, newly visible stage and terminal; all eight relic details via actual UI, Restart confirmation/cancel. 4,919 snapshots (2,100+2,819); 482,399 checks total. Each of 48 authored HUD controls in every state: explicit imported font, exact geometry, actual font width and line-height, icon/button style margins, all glyphs incl tooltip, tooltip line width<=320, no visible text overflow, no missing glyph, no real-state ellipsis. Both real runs complete and model outcomes unchanged. Evidence type-437.json/type-452.json and logs.

Representative worst logical dimensions (px, actual text measurement):
| Element | max width / box | max height / box |
|---|---:|---:|
| Stage longest TIDECROSS FERRY | 143/166 | 24/26 |
| HP 15 / GOLD 24 | 144/181 | 26/29 |
| WAVE 1/8, PLAN two lines | 53/73 | 34/36 |
| SOUND ON | 72/82 | 21/32 |
| TEST SOUND | 81/85 | 21/32 |
| Relic icons with label+margin | 50/54 | 20/36 |

Independent export verification: real Godot Web preset PCK export mounted from isolated project with no assets. Font resource loaded from PCK; license included; all 95 printable ASCII codepoints present with system fallback disabled. (PCK file itself is not a final P10 game build; root should export exact integrated freeze.)

LootReveal external candidate: independent snapshot after ASCII conversion, metric check enumerates 31 valid crew/relic-rank combinations, 214 checks pass. Longest effect 289/318px; name 187/318px; receipt 186/224, last receipt 213/224. Loot implementation agent informed and asked to retain ASCII in their source. Need independently run final integrated UI after merging.

## Native & Web gate
Native render scene candidate/tests/TypographyNativeCapture.tscn (complete same legitimate UI callback run), captures initial, relic detail, stage plans, warnings/boss/terminal at 1280×800, 960×600 and 1440×900 (the apparent effective game canvas in user's 1504×909 screenshot). Outputs user://typography-437-*.png. Compiled headless, no DISPLAY here and no GPU/browser playback claim. Root should execute native scene at those sizes or integrate harness. Actual itch Web browser text must be checked after upload; PCK resource inclusion proves asset available but is not real browser screenshot. Candidate remains isolated until final merge and independent acceptance.

## Repro
godot --headless --path candidate --editor --import --quit
godot --headless --path candidate -s tests/typography_audit.gd -- /absolute/output/type-437.json 437
godot --headless --path candidate -s tests/typography_audit.gd -- /absolute/output/type-452.json 452
godot --headless --path candidate -s tests/loot_font_audit.gd
godot --headless --path candidate --export-pack Web /absolute/output/typography.pck
godot --headless --path pack-verify -s verify.gd -- /absolute/output/typography.pck
godot --path candidate res://tests/TypographyNativeCapture.tscn

Source SHA/evidence and exact diff in own typography directory; no production merge or GitHub push.
