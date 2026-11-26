# P09 Web 音频 P0 修复 / Web audio silent incident

## 证据与范围

Player reported P08 itch.io Web audio silent while SOUND ON, not confirmed muted.
P08 delivered JS `index.js` SHA256 `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` contains the problematic sample mixer Bus.addAt/move implementation. P08 GameAudio creates six buses through the default append argument (-1), then restates all sends. The exact 4.7.2 source connects AudioServer.add_bus to the JS sample-bus append call; this is not a conjecture from a general WebAudio article. Upstream issue [#119026](https://github.com/godotengine/godot/issues/119026) documents the same symptom and problematic graph, including itch.io hosting; milestone 4.8.

- [AudioServer 4.7.2 source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/servers/audio/audio_server.cpp) L729-785 and L805-855: count path forwards sample count, append path forwards -1.
- [Web audio driver 4.7.2 source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/audio_driver_web.cpp) L332-359: same operations forward to JS sample-bus APIs.
- [Web display server 4.7.2 source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/display_server_web.cpp) L174,282,710: physical keyboard, mouse button, and touch gestures attempt audio context resume independently of game logic. P08 delivered JS resume code calls ctx.resume when the context is not running. A game toggle alone is not proof of context state.

Independent exact exported JS execution (mock WebAudio connection nodes; actual exported Bus class, not copied algorithm): old physical order [2,3,4,5,6,1,0], logical Master displaced, 0/7 routes to destination. Fixed count-first order [0,1,2,3,4,5,6], Master at zero, all 7 routes reach destination. This is strong reproducible engine-level causal evidence. End-user browser output, OS/tab mute and iframe autoplay policy remain unverified until a real browser/user playback witness.

## Fix

- Set the known 7-bus layout once with AudioServer.bus_count, name buses in explicit order, then configure child sends and gains. This uses the sequential setCount/create path in the actual shipped JS, not addAt or move. All routes and dB gains preserved on native and Web.
- Web player playback type explicitly SAMPLE, native mode unchanged. No generated engine JS patch, no new sound resources.
- Main physical input gesture remains only entry point for unlocking. Engine retries browser AudioContext resume on each mouse/key/touch event. Unlock uses the same existing ambience player instances, only starts a stopped loop; running loops are not rewound by future clicks.
- Explicit test_sound() requests a real UI-press sound, never claims hearing, no RNG/economy/model effects, returns false if muted. The UI binds a discrete sound-test button on physical input. Mute and zero-volume behavior remain separate from requested playback.
- All existing event scheduling, alert priority, loot progression and pause semantics unchanged.

## Acceptance gates

1. Run exact-export graph regression: `node tests/independent_p09_web_bus.js PATH_TO_EXPORTED/index.js` (expect old broken, count-first fully connected).
2. Native actual runtime: `godot --headless --path . --script tests/p09_web_audio_contract.gd` verifies exact bus order/sends/gains, no autoplay, muted test, audible-cue *request*, real playback cursor, no duplicate/rewound loops, explicit stopped loop retry, and mute/volume restoration.
3. Rerun existing audio_p07_tests, p09_audio_guard_tests and actual mixed stress checks. Native mixer success does not confirm Web sound.
4. End-user real itch browser: hard refresh latest build, ensure SOUND ON, click SOUND TEST, hear short click, then confirm normal chest and battle cues. Test mute→unmute and background→foreground, no duplicate ambience. If still silent, inspect browser context/OS output and export sample path (do not assert success from the UI state).

Cloud browser WebGL2 unsupported; no actual user-browser hardware/ear confirmation claimed.

## Verified candidate (native and JS graph, not browser hardware)

Frozen GameAudio SHA256 `4637c5bd90cab17bb2ab21c981bb1683de9e96e41c7f6619e273b2254019e009`. Clean reimport (including three P09 PCM intercepts): existing native audio 175/175, Guard 30/30, new Web-audio contract 41/41, zero failures. Controller's actual software mix stress after fixed bus initialization: 4.923s stereo at 44.1kHz, peak -16.2dBTP, zero clip samples and zero capture drops, Combat≤6, danger + leak retained, second-chime projection .9944 / correlation .9282, RMS margin +3.92dB and 150–800Hz margin +6.91dB; gate PASS. Evidence JSON: `web-audio-mixer-regression-p09.json`.

[Godot official Web export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#audio-playback) confirm Web defaults to sample playback to minimize latency in single-threaded exports; effects and some positional features may be limited. Native captured signals are not evidence of browser spatial balance or physical speaker output. Actual Web retest remains pending.
