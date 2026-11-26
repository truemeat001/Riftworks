# P08 声音验收与改动审查

**目标**：依据 P07 `audio-perception-standard.md` 对玩家测试候选进行客观回归，优先检查重要告急不被普通声遮蔽、2x 密集战斗、暂停、静音和首次手势。仅当可复现缺陷证据明确时改动。素材全量保持 P07，不将声学数据冒充真实听感。

## 1. 先复看 P07 的真实记录

重新实际运行已有 `scripts/evaluate_audio.py`，输入 P07 42 条冻结素材和两个真实 native Master capture `.riftworks-p07-root-qa/{1280,960}/native-mixed.wav`，与 `docs/audio-quantitative-p07.csv` 比较。42/42 PASS，无波形/哈希变更、无警告；最大 source true peak -6.0dBTP，0 削波，32条过短/无有效门控 LUFS-I 缺省。两段 native capture 29.164s / 20.898s、-11.1 / -11.2 dBTP、0 削波，整体 LUFS-I -32.3/-31.0。它们不是主观音量标尺。

查对应 `native-events.json`，两段实际事件均 24 条：4次charge、4次open、2次crew、1次relic、1次upgrade、3次arrive（首箱跳过）、1次wave_start、4次hit_burst、3次kill、1次wave_clear。所有接受事件来自实际回调和种子7真实结果。但无 danger、无 leak，未覆盖高密度2x、音色遮蔽和告警保留，不能宣称这些已验证。

## 2. P07 发现的问题及 P08 最小修复

原音频模块 Alert 并发上限2，FIFO 替换最早尾音。当 danger 已响且同时连续漏怪，后续真实 leak 会挤走仍有效的危险钟；低优先级 wave_start 在满组时还能挤掉伤害提示。这个现象不是“音量不够”而是声源被停止。P08 保持素材、总线名、音量/包络/阈值、战斗公式与现有 API，只调整 `src/GameAudio.gd` 的 Alert 溢出优先级：

- danger（3）、leak（2）、wave_start（0）。若满组先替换同 ID 的旧尾音；否则只替换不高于来者的最低优先级已有事件，否则丢弃低优先级来者。
- 两个真实裂隙同时开始仍可各占空位播放；满组下普通起波不得挤掉危险钟和真实伤害；危险解除或场景结束仍执行原来的 stop。
- 不增大并发上限和全局音量，不引入隐蔽音色或虚构稀有度。主要战斗/命中仍用现有 cue；新增真实机制若仅改变状态传播，保持既有真实碎冰声音，不加第二次伤害音，避免同事件重复。

## 3. 实际软件混音与告警压力 A/B

新 fixture `tests/p08_audio_stress.gd`，在隔离的最小 Godot4.7.2 项目加载控制器与相同42个 runtime WAV。比较 P07 冻结 GameAudio 与 P08 修订版。以40次/s（2x×20Hz）循环尝试六类实际战斗事件，固定API和音频增益；包含首次 unlock、危险钟、暂停、两次漏怪挤占、低优先级起波请求、静音和恢复。**这是控制器压力回放，不是真实关卡逻辑或实机手玩。** 各版本实际 Godot software mixer 的 Master/Combat/Alert/Ambience 独立效果 tap 录音（44.1k stereo）。`scripts/audio_stress_review.py` 重用 `evaluate_audio.py` PCM 解码/FFmpeg true peak。

门槛（当前单一确定性压力用例建议）：Master ≤-1 dBTP，0削波；实际 Alert 在重复漏怪后同时保留危险及伤害，拒绝普通起波；第二钟关键窗 .27–.39s 相对正常危险钟的归一投影≥0.8、相关≥0.7；正常危险钟第二响时对战斗+环境混音代理 RMS 余量≥2dB、150–800Hz余量≥4dB；锁定态无声，暂停稳定后战斗/警示 tap≤-60dBFS，真实 Master mute flag，Combat≤6。以上不是已证明对真人普遍可懂的阈值，只是工程验收门槛，另需真人盲听。

| 实测 | P07 | P08 |
|---|---:|---:|
| 重复 leak 后实际 Alert voices | leak + leak | danger + leak |
| 随后普通 wave_start | 接受、覆盖旧 leak | 拒绝、保留两关键 cue |
| 第二钟 .27–.39s 波形投影/相关 | -0.043 / -0.029 | 0.994 / 0.928 |
| 正常危险钟第二响时实际 gain 重建：RMS 相对余量 | +2.90dB | +4.03dB |
| 同窗 150–800Hz 相对余量 | +7.79dB | +8.65dB |
| Master tap True peak / 削波 | -17.5dBTP / 0 | -18.2dBTP / 0 |
| 首次手势前 Master tap | 实际零采样 | 实际零采样 |
| 暂停200ms缓冲后 Combat/Alert tap | -70.17dBFS / 零采样 | 零采样/零采样 |
| Master mute/unmute API 实际状态 | 正确 | 正确 |
| 最高 Combat voice 数 | 6 | 6 |
| 该用例工程门槛 | FAIL | PASS |

技术解释：正常危险场景的 Alert 单独 bus tap 波形用作同样实际回放的模板，饱和场景相同 .27–.39s 区间比较归一投影，可确定 P07 丢第二钟而 P08 保留，即使有两次 leak 重叠。各轨实际采样对齐，在稳定 duck 段以 `Master≈gA×Alert+gC×Combat+gE×Ambience` 拟合，两个版本得到约 -3/-10/-4dB，重建相对误差<0.11%，确认 tap 位于各自 fader 前，对相对余量使用实际拟合增益，而不是把未衰减原始 combat 当成用户听到的混音。Master effect tap 本身也在最终 mute/fader 前，静音时 tap 仍有波形；只能证明真实 AudioServer mute flag，并非物理扬声器静音测试。A/B 两次墙钟调度的 combat 密度略不同，两个余量值不可归结为优先级改动带来的 +1.13dB 提升；此轮确定修复是告警保留。源音色无证据需要重做。

复现：将同版本 `src/GameAudio.gd`, `assets/audio/runtime/`（含 import 配置）, `tests/p08_audio_stress.gd` 拷入独立最小 Godot 项目；使用可写 XDG 配置/缓存/数据，`godot --headless --path <project> --editor --import --quit` 后 `godot --headless --path <project> --script res://tests/p08_audio_stress.gd`。保存 `user://p08-stress-{master,alert,combat,ambience}.wav` 及 `p08-stress-report.json`，以源版本区分目录 A/B。`python scripts/audio_stress_review.py A B --output comparison.json`。本次实际捕获无丢帧或浮点削波，结果原始 WAV 和 JSON 保留于隔离 QA 归档（不进 Web 包）。

## 4. 真玩家测试计划（人工未发生）

继续使用 P07 已有 `prepare_audio_listening.py`、`score_audio_listening.py` 与既定双区块盲听，不重复发明工具；42个 WAV 未改，之前答案表和同种子刺激可重新生成。建议至少8–12名目标玩家分组，记录耳机/扬声器、环境、音量和平台。先盲听区块 A/B 再实机：连续开箱普通/遗物/升级、跳过、2x多塔、两次或更多逼近/漏怪，明确哪个 cue 是真实告急、哪个是灯塔受损，是否因同屏打击声音遗漏，是否有刺耳或听疲劳。真实前后台、Web 首次输入、连续3次12s loop、静音与恢复，检查物理声音实际听得到/静得掉。答题准确率、混淆矩阵、各维度评分中位数保留原方法，空白不填。工程已通过并不能声称好听或分类率80%等真人目标已完成。

## 5. 真实 Main + Run 事件接入复验

另新增 `tests/p08_audio_main.gd`，复制当时实际 P08 Main/Run/资源至隔离项目；seed7，真实按钮打开一箱（18金币、1船员），通过实际按下/释放鼠标回调布置到合法但覆盖为0的 `(0,0)`，真实倍率按钮切到2x，开始关卡故意让危险与漏怪发生。期间实际暂停并确认模型 tick 冻结且 Audio battle pause 状态一致；恢复后 tick 继续；实际静音按钮改变 Master mute flag 但不影响模型推进；最后恢复。不是人为增加HP、制造假怪或直接注入告警。真实第一波在 `build` 结束、8漏、HP7、tick397；记录 `danger:1`、`leak:8`、`wave_start:1`、`deploy:1`、`loot_crew:1` 以及正确的 charge/open/arrive 和 `wave_clear:1`，所有断言通过。真实软件 Master tap 录音12.817s：-13.0dBTP、0削波、无丢音频capture帧；原始 `p08-main-audio.json`、`p08-main-mixed.wav` 在隔离 QA 归档。该场景无战斗命中，故与 §3 多命中x2压力用例结合验证，不能冒充密集实战主观听感。

本次隔离源码 SHA-256：Main.gd `46000c68e23e91c53eb27553298f4b2533a7c40db983f5300a92d30bd6fd888c`，Run.gd `438eb757a53d1c795ce7fc64910232f0c9f42f01a93379e572122c2f25eb2fa6`，GameAudio.gd `9ef597f3eb18d9a79b0374b71337f34b684c1a1481f7d448e659bf775bb1ac08`。若合并其他 P08 改动后 Main/Run 变更，应在冻结项目再次运行该脚本，不能将这一快照当作所有后续代码的独立验收。既有 `tests/audio_p07_tests.gd` 同步对 P08 模块回归 168/168 全过。

同 P08 控制器压力用例第二次独立运行亦 PASS：真实危急第二钟投影 0.994/相关0.928不变，RMS余量 +2.12dB、150–800Hz余量 +7.36dB（墙钟密度波动），Master -17.4dBTP、0削波、0丢帧、真实危急和伤害保留。最小余量只略高于该 fixture 建议门槛，继续保留人工密集战斗辨识任务，不将一次或两次电气信号代理值夸大为普遍可听性证明。
