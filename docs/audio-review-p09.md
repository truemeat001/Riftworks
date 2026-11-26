# P09 Guard Escort 音效生产与验收

本轮只增加真实护卫拦截的一类短声音。P08 的42对原始母版/运行版保持逐文件 SHA-256 不变，不重新生成、不调全局增益、不改旧声音。真实规则从 Run `guard_intercepts` 发出实际 tick、tower_id、intended_id、guard_id、位置与伤害；Main 的权威 `note_attacks()` 检查当前攻击真实匹配，`hit_intercept` **替换**普通 Brass/Mist 主击音，不叠同一个普通 hit；既有真实导电联动可以另发 conductive（独立真实效果），Hammer 主/次击和链次级不发拦截音。没有从动画或预测/盾徽/冷却增发音效，也没有新 RNG、攻击或伤害。视觉+听觉承认“护卫替同伴承受了这次攻击”，不是成功升级、获得稀有物或新的警报。

## 制作与权限

原创新事件 `hit_intercept`：单一近端贝壳边缘与钝铜片相撞的短促防护重击，轻木/壳瞬态→615Hz附近的多分音板材共振→短陶瓷碎响及过滤噪声尾。三变体独立种子 `90926+101×variant`、小幅音高偏移，同一24ms量级瞬态、总长240ms；点声源 mono。目标是比原普通铜鸣/锤击更偏高中的金属/壳质反馈，又不与潮雾高频或低沉告急海钟混同。参考和方法来自既有 [音效制作规范](sound-production-standard.md) 的 BOOM 分层、材质/起音/尾巴；未取得或试听商业样本。全部本地可复现 Python NumPy/SciPy 合成，无录音外部授权、无付费API、无竞品音轨；当前描述仅是设计目标与电气代理，**主观听感未测试**。

- 母版 `assets/audio/master/sfx_hit_intercept_01–03.wav` 48kHz、24-bit PCM、mono，独立保留（.gdignore）。
- 运行版 `assets/audio/runtime/sfx_hit_intercept_01–03.wav` 48kHz、16-bit PCM、mono；导入 `compress/mode=0`、无归一化/强制变率/trim。
- `scripts/audio_guard_p09.py` 可生成+测量，`--verify-only` 只核对全部 P07 和 P09 SHA/格式、复算新增声学指标与试听序列。`docs/audio-p09-manifest.json` 完整45对；旧 P07 manifest 保持冻结42对。`scripts/evaluate_audio.py` 可显式 `--manifest docs/audio-p09-manifest.json`，默认仍 P07；历史盲听工具原样，旧42对样本依然合法复用。
- 各声源仍按 P08 `GameAudio` 走真实逻辑格位→世界声像；仅 `Combat` 总线新增事件、-5dB 事件 trim、100ms同类速率门限。Combat 仍最多6声音，普通过载继续丢新音；新护卫回馈可在已满时替换最旧普通Combat尾音（不是另起第七声），全为拦截时丢新声；不抢Alert/UI/loot，不提升总音量。关键危险/漏怪优先规则 P08 保持。多guard同tick/短窗口可因速率合并掉装饰性晚来的声音，但全部权威攻击/VFX不变；不将音频 accepted count 称为模型攻击计数。

## 客观资产回归

45/45 `evaluate_audio.py --manifest docs/audio-p09-manifest.json --baseline docs/audio-quantitative-p07.csv --output docs/audio-quantitative-p09.csv` 门禁通过。0削波、最高全库 True Peak −6.0 dBTP；只有三个确知新事件作为 review warning，旧42无描述差异；35个过短/无有效门控 LUFS-I 留空。新增3个源文件24/16量化误差在1LSB内。`docs/audio-guard-metrics-p09.json` 是新增可复算指标及旧hit族对比。

| 变体 | 时长 | True Peak | RMS dBFS | 起音80ms重心 | Rise / Tail (5ms包络) |
|---|---:|---:|---:|---:|---:|
| Guard 01 | 240ms | -10 dBTP | -24.63 | 850Hz | 5/110ms |
| Guard 02 | 240ms | -10 dBTP | -23.78 | 885Hz | 5/110ms |
| Guard 03 | 240ms | -10 dBTP | -25.22 | 911Hz | 10/100ms |

同组 RMS 跨幅1.439dB；旧 pulse onset centroid 508–576Hz，frost1887–2030Hz，burst615–726Hz，danger267Hz且尾巴455ms。新增音色参数使guard电气指标位于铜鸣/锤击与冰晶之间，且短于危险钟；只是提供差异依据，不证明玩家能辨认、擬音逼真或比原来好听。

人工候选试听 `docs/audio-guard-preview-p09.wav`：6秒48k16 mono，不归一化，依次每秒开头 pulse、frost、burst、guard01、guard02、guard03，留静音方便辨识；不是游戏混音或耳试听确认。正式玩家测试应使用真实游戏增益和同时发生的其他战斗/告急音，分开记录“能理解替身”、“不刺耳”、“多次拦截不机械”，继续此前盲听和硬件检查流程。

## 实际 Godot 模块及集成验收

以隔离全项目副本导入 Godot4.7.2 正常资源（新3个运行 WAV 强制不压缩，实际 `AudioStreamWAV.FORMAT_16_BITS`/48k/mono/240ms），然后运行：

- `tests/p09_audio_guard_tests.gd`：30/30。Main 首手势 unlock；真实 Run.step fixture 的 Brass、Mist 各产生一真实guard事件，Main 只发 `hit_intercept` 到实际guard位置，普通主击不发；真实导电时恰好 redirect + conductive；Hammer bypass/普通直接照旧。重复同tick通知被速率门抑制。6 Combat先满，再实际guard声音能替换旧普通tail且不超过6；普通过载不能挤掉guard；Alert danger/leak同时保留；Pause拒绝新combat、结束清除。受控 fixture 并非真人完整关卡。
- 继承 P07 音频控制器全部回归，P09 副本唯一预期修改为“40原始+3新增one-shot”，175/175，Dummy cursor实际0.280秒推进，退出无泄漏告警。历史42源文件仍独立逐一不变。
- `tests/p09_audio_guard_stress.gd`：继承P08实际 mixer fixture x2等价合成高压事件表，六既有Combat事件每25ms尝试，加最密每300ms一次Guard（4/s设计压力近似）。实际 Godot Master/Alert/Combat/Ambience tap 44.1k stereo捕获5.016s，0 float clipping、0丢捕获帧、最高6 Combat；FFmpeg Master -15.7dBTP、0削波。`scripts/audio_stress_review.py` 电气门槛 PASS；稳定危险段拟合真实各轨bus增益(-3.001/-9.997/-4.000dB)，相对残差0.161%，告急第二钟 RMS余量+4.62dB / 150–800Hz余量+9.75dB；饱和连续leak后第二钟投影0.994、相关0.928，实际 Alert 保留danger和leak并拒普通wave_start。锁定态和暂停稳定后对应tap为零采样，Master mute flag及恢复正确。不同墙钟调度背景不同，不归因于新增声音使原告急音更好听。实际Master effect tap在最终fader之前，静音不能冒充真实扬声器测量。

源快照 SHA-256：Main.gd `3fa8b82aaf5ef06bca134a8d53f6eda36d8f25c47732976bbd464a65b1e567a0`，Run.gd `0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25`，GameAudio.gd `6a0595c59b4e7629de362d64ba34e7158f54f703abbe90cfd75970a31c56dd34`。测试日志、真实捕获原始 WAV 与 `stress-comparison.json` 存在独立QA目录（非运行包）。若其他Agent后续修改Main/Run，需重新用最终合入版本跑 `p09_audio_guard_tests.gd`；音效文件、GameAudio另行验收。

仍待真实用户/设备试玩：相邻告急是否听得懂、壳质与旧打击区别、倍速密集不机械、浏览器首个物理手势与前后台恢复、静音实际扬声器。当前环境不能提供真实人耳试听，不把合成或电气指标称为“已试听好听”。
