# Riftworks P07 原创音效制作与接入记录

## 1. 目的与素材权利

潮汐微缩剧场的声音应像木、铜、绳索、贝壳、石头、海水组成的世界，而非单一电子提示音。玩家应从声音知道开箱过程和真实结果、来敌方向、职业攻击、危急、漏怪与结果。**制作和可解码/逻辑验收已完成；没有硬件声卡和听觉输入，实际试听通过仍待人工。** 不声称音色已达到发布级。

采用本地 NumPy 2.3.5、SciPy 1.17.0 声学合成及 Python wave，所有振荡器、滤波噪声、包络、叠加时序、随机种子由 `scripts/make_audio_p07.py` 独立实现，无第三方采样、AI 语音或付费 API、商业游戏音频。原始生成参数为源文件及 `docs/audio-p07-manifest.json`，42 条文件一一对应，含精确 SHA256、时长、峰值、RMS 和循环指标。初始种子 `70926` 按事件/变体确定性偏移，不使用战斗 RNG。参考文档（方法，不是实际使用音源）：[BOOM Casual UI](https://www.boomlibrary.com/blog/casual-ui/)、[Pro Sound Effects Footsteps](https://www.prosoundeffects.com/libraries/game-audio-collection-footsteps)、[Audacity 零交叉](https://manual.audacityteam.org/man/select_menu_at_zero_crossings.html) 和 [交叉淡化](https://manual.audacityteam.org/man/creating_a_crossfade.html)。参考样音未能试听，只有分层方法、起音/材质/衰减及循环接缝思想。未使用 Fortnite 等竞品素材，未购买任何资源。合成 WAV 作为本项目新产物，无外部样本许可负担。

## 2. 文件规范和事件清单

- `assets/audio/master/`：48 kHz、24-bit PCM WAV，40 个非循环单声道事件变体、2 个立体声 12s 循环。`.gdignore` 阻止母版导入 Godot 及作为运行资源打包。
- `assets/audio/runtime/`：由同一浮点采样量化为 48 kHz、16-bit PCM WAV，保留母版；Godot `.wav.import` 明确 `compress/mode=0`、不强制单声道/采样率、不 normalize、不 trim。
- 文件单次动作独立：`sfx_<event>_<nn>.wav`；环境 `ambience_sea_loop.wav`、`ambience_battle_loop.wav`。循环时序和调制在整数周期上构造，运行时由 AudioStreamWAV 完整区间 forward loop。

| 事件 ID | 玩家信息、材质/声源 | 起音→主体→尾巴 | 秒 / 变体 | 参考 |
|---|---|---|---:|---|
| chest_charge | 木箱近端蓄势，铜扣、潮气 | 短铜触碰、木撞→滤波潮噪升调 | .32 / 1 | UI 分层 |
| chest_open | 木盖开启、中等重量 | 木质瞬态→铜扣共鸣、空气声→低木响 | .30 / 3 | UI 分层 |
| loot_crew | 船员普通招募 | 木铃两音与柔暖谐波，自然收尾 | .36 / 1 | UI 分层 |
| loot_relic | 遗物首次获得 | 贝壳/玻璃般晶响，金属泛音→三层音高 | .52 / 1 | UI 分层 |
| loot_upgrade | 已有遗物升级 R2+ | 较厚低木冲击、铜铃→向上和声及细泛音 | .65 / 1 | UI 分层 |
| loot_arrive | 入库 | 轻木咔哒和金属细尾 | .10 / 1 | UI 分层 |
| ui_press / ui_reject | 按下、真实拒绝 | 轻木点击 / 下行短音与噪声 | .08/.14 / 1各 | UI 分层 |
| deploy | 放到真实驻守格 | 石座木质低冲击→微砂噪 | .16 / 3 | Foley 方法 |
| recall | 收回 | 布帆掠过和音高下行 | .14 / 1 | Foley 方法 |
| merge | 实际合成晋升 | 木响和递进的和声 | .44 / 1 | UI 分层 |
| sell | 实际释放/出售 | 金币铜响两击 | .24 / 1 | UI 分层 |
| wave_start | 确认开始，实际活跃入口 | 低潮涌→低频短号和敲击，世界声像 | .65 / 1 | 环境层次 |
| hit_pulse | 铜鸣枪打击 | 锐利脉冲→短木感/气噪 | .14 / 3 | Foley 方法 |
| hit_frost | 潮雾减速的真实命中 | 冷气→晶响 | .20 / 3 | Foley 方法 |
| hit_burst | 礁锤真实锤击 | 低沉厚重瞬态→碎砂尾 | .26 / 3 | Foley 方法 |
| kill | 真实死亡 | 短碎壳与下沉轻敲 | .20 / 3 | Foley 方法 |
| conductive | 真实导电联动 | 短电弧滤波声、微上行 | .18 / 3 | Foley 方法 |
| shatter | 真实碎冰联动 | 短玻璃片、晶体高频尾 | .22 / 3 | Foley 方法 |
| danger | 存活的敌人剩余路径≤2格，海钟 | 两次金属低钟，低基音短共鸣 | .82 / 1 | 关键声优先 |
| leak | 权威漏怪增加，灯塔受损 | 重木石冲击→低噪与下滑短音 | .36 / 1 | 关键声优先 |
| wave_clear / victory / defeat | 真实波清/通关/失败 | 短上行和声/较长上行/低沉下行 | .58/.95/.80 / 1各 | UI 分层 |
| ambience_sea / ambience_battle | 环境与交战背景，低音量 | 带限循环海潮与泡沫，战斗层增加低频水势，不虚构来敌数 | 12 / 1各，立体声循环 | Audacity 循环思想 |

上述音色描述是**合成设计目标**而非真实试听结论。每个变体使用同类共振结构、独立噪声和小音高变化；同组 RMS 跨幅约0.14–2.72dB，仍需耳辨强弱与机械重复。没有新 BGM 曲目（Music bus 已为以后预留），不把淡海潮称为音乐。

## 3. 运行接入与混音

`src/GameAudio.gd` 独立 Node，不持有 DefenseRun，不读取/修改 RNG、金币、伤害、敌数。Main 在首次真实 `_input` 手势调用 `unlock()` 后才启动环境语音；初始化无自动播放。六宝箱事件以 P06/P07 已定现实结果和 `loot_age` 为唯一来源：0.00 charge，0.32 open，0.34 仅 crew/relic/upgrade 其一，1.22 arrive。重复调用相同 age 不重放，失败不会调用有效 start，skip/新事件/重开停止当前 loot 组；后台时间跃迁>0.55s 丢弃过时音效，避免堆叠。真实金币/结果已先确定，不等音频结束。正常播放 1.35s 动效时，标记结束但允许自然短尾，下一次跳过或新动作清除。

公交：Master(-4dB)；SFX(-2dB)汇总 UI(-2dB)、Combat(-4dB)、Alert(-1dB)，另有 Ambience(-4dB)、Music(-4dB)。每事件另有音量 trim，见 `BASE_DB` / `EVENT_GAIN`，玩家线性音量通过独立总线 API 设置，0为实际 mute；Master 独立一键静音与音量值相容，不修改规则。环境两个循环同时保留，prepare→fight 0.45s 平滑混合，pause 降回准备背景；战斗音暂停/继续、结束清理旧声。危险由权威剩余距离表现辅助触发，边沿一次鸣钟，冷却2.2s；存在危险时 Combat/Music 额外降低4dB，150ms入、500ms退。危险解除即停止未完危险钟，不启动任何新游戏状态。战斗/警示音以真实逻辑 cell 0–11/0–7 映射到 viewport 世界坐标（2D AudioStreamPlayer2D），UI/loot不空间化。环境使用 AudioStreamPlayer stereo。

并发上限：loot4、普通UI2、Combat6、Alert2、Ambience2，总计最多16播放源；Combat 每类70–150ms间隔，超额丢装饰音，避免高攻速/多段动作声堆叠；Alert/UI/loot 达限替换最旧尾音，危险告警组独立于普通战斗。音频变体按自身循环计数/可选稳定提示，不消耗战斗 RNG。重开/reset保留玩家总线配置与已unlocked环境，清除旧箱/战斗/告警/UI声音。`set_volume` 为逐总线可用 API；本轮界面接入Master静音，并不宣称已有完整音量设置面板或持久化磁盘配置。

## 4. 实际可复现验收

  cd RiftworksP07
  python scripts/make_audio_p07.py             # 重新生成母版、运行版、清单，验证
  python scripts/make_audio_p07.py --verify-only  # 只校验和生成试听拼接
  godot --headless --path . --editor --import --quit
  godot --headless --path . --script res://tests/audio_p07_tests.gd

若 Godot 的 XDG 路径不可写，应在工作区创建可写临时目录并设置 XDG_CONFIG_HOME、XDG_CACHE_HOME、XDG_DATA_HOME。测试实际在独立最小 Godot 4.7.2 项目复制相同 GameAudio、运行 WAV、`.import` 元数据及脚本执行，避免多角色同时导入写同一缓存。

| 检验 | 实测结果 |
|---|---|
| WAV 正确解码与双版本 | 42 对 PCM，采样率/位深/声道/帧数及清单 SHA 全匹配；最大量化误差 1.53185e-5，无 NaN/异常静音，最高源文件峰值 -6.0002 dBFS |
| 循环接点波形 | 两个12s stereo loops，首尾最大差 .00330；各声道差均低于该循环相邻采样差95分位（.00729–.00974）；不是三轮连续人工聆听结论 |
| 宝箱真实时序离线混音 | 三类别混合（实际默认 bus 和 event trims）；最高峰值为 -15.81dBFS，无削波；每次只有真实类别的奖励声 |
| 高压混音模拟 | 250组 capped 的6类战斗+危险/漏怪2警示+UI click+环境双层，随机重叠音源、保守不衰减声像，峰值 -10.94dBFS；属于离线用例，不是所有可能设备配置/主观音量保证 |
| 实际 Godot 音频控制器 | 168/168，导入40 mono+2 stereo actual AudioStreamWAV PCM16 / 48k；循环 576000 帧；Dummy 播放 cursor 0.280s 实际推进；无自动播放、独立总线、声音数量、时序一次、失败/skip、后台跃迁、危险边沿/duck、暂停、0总音量、reset均通过。最终测试无资源泄漏告警。 |
| 主项目接入/实际界面 | UI Agent 负责真实权威 tick / 按钮绑定及整包回归，独立验收单列。当前报告仅覆盖模块与素材，不替代 GUI。 |
| Web、硬件听感与设备 | 当前无 `/dev/snd`，音频能力返回内容省略，因此不能确认重音、金属感、噪声听感、声像方向、长时循环、混音主观舒适。真实浏览器首次手势及切换后台后的回放需要在可用设备复验。 |

人类待试听文件：`docs/audio-review-preview.wav`，48k16 stereo 6s，0–1.35秒船员、2–3.35秒新遗物、4–5.35秒升级；采用实际默认增益，不归一化为演示响度。SHA-256见 `audio-p07-qa.json`；建议实际用户试听后根据音色识别和手感调整，而不是以波形合格认定已试听。全量声音可在游戏中按事件触发，也可从 master/runtime 分别逐条试听。
