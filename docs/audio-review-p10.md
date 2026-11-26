# P10 「潮汐交付」音频正式实现 / 实现者验收记录

冻结设计：`../loot-reveal/DESIGN.md` SHA256 `d8c22d0f3f5781f1946ff3107b1691ee60e97b7a957d4bbe3a2d491b7b0fa45a`，独立设计评审 PASS 对应的 G05/G06 实现。这里是独立工作区、无 P09/P10 生产修改，非产品独立 QA 判决。实际真人听感、原生完整画面/操作联动、真实浏览器声卡与用户反馈继续待验证。

## 资产及来源
执行 `python scripts/make_loot_p10.py` 只生成 19 个新运行版本及各自独立母版。已核对 P09 45/45 每份母版和运行版的 SHA256 原样，所有旧 _01 与三个 open 变体均保留。源为 Python/NumPy/SciPy 原创程序拟音，使用项目已有原创合成风格与代码作为复用参考，未使用任何非项目录音、游戏音轨或商业样本、不付费。Fortnite/BOOM 样音参考未试听，不能冒称音色复刻；开发方法只参考分层思路。每个文件一完整近景非空间化 mono 事件，不循环，新文件命名和源参数/seed/许可在 audio-p10-new-only.json，64条总体清单 audio-p10-manifest.json。48kHz/24bit PCM母版，48kHz/16bit PCM运行副本，样本数、哈希、量化严格校验；连续环境床保持 P09 两个 12s stereo 循环不变。母版沿用 .gdignore 不进运行包。

| 新事件/变体 | 材质结构与动作 | 时长 | 源参考/参数 |
|---|---|---:|---|
| loot_material_wood 01–03 | 干木闷触，短低中频木质阻尼，两枚较轻铜扣，短噪声尾；不是升级同声变调 | 140ms | 200Hz木钟基频小变体、700–1010Hz铜扣、1/32/58ms级联 |
| loot_material_crystal 01–03 | 实际新遗物晶紫锁材料生成；三枚不规则玻璃贝壳轻碰，泛音细颗粒尾，无低频重撞 |190ms| 1760/2230/1330Hz 非整数分音，6/44/98ms间隔，1300–7700Hz短噪声 |
| loot_material_brass 01–03 | 实际升阶金铜边加固两声不同重量厚铜合拢，低中频级联与细铜边短瞬态 |200ms|255/416Hz 多个非整数分音、1/46ms双重动势，700–5800Hz短边噪 |
| chest_charge 02–03 | 铜扣/木板/潮纹微升，保持P09时序与旧01；另独立seed噪声、约±1.4%共振时间细变 |320ms|项目P09原始01及合成配方 |
| loot_crew 02–03 | 木铃两谐音，清楚普通到账，既有木质碰撞起音，非放大音量 |360ms|同上 |
| loot_relic 02–03 | 贝壳晶体短拨弦，区别于开前的晶体碎响，多分音衰减 |520ms|同上 |
| loot_upgrade 02–03 | 厚铜铃和温暖和声/木质低音起势，尾巴更长，非虚构稀有收益 |650ms|同上 |
| loot_arrive 02–03 | 短木卡合+铜触，实际仓位收束，短而克制 |100ms|同上 |

每组 RMS 落在对应旧版参考附近（新材质中木 -24.23～-26.73 dBFS，晶 -23.54～-23.95，铜 -22.30～-22.64）；木材目标建议 -22至-25，并非硬门，01/03 低于建议但仍组内未越3dB；听感及实际混音是否足够突出须由独立试听决定，不以技术指标替代。首次80ms能量重心：木437–459Hz、晶2165–2213Hz、铜363–377Hz；结构与起音不同，独立 RMS 匹配盲听能进一步区分纯音量。每组含 crest、频带、起音5ms包络、尾音、真实 dBTP、短音LUFS空值记录 audio-quantitative-p10.csv。新增运行总计 **527,876 bytes = 515.50 KiB**，低于640KiB；增量不含母版。所有原64本体峰值≤-3dBTP、0削波、缺少LUFS（短音或门控）50个保留空值，0跨组 RMS告警；最终运行资源及 Web PCK 保留45及新增19运行版、母版隔离、LFS字节校验由根负责最终导出验收。

## GameAudio 接入
- `start_loot(result,plan)` 消费已成功的真实 result，复制冻结只读 plan，验证 tier/时间轴（普通招募1.35s、遗物1.60s、升级1.85s），内部只触发真实内容，未访问 Run/RNG。0.00 charge、.12 对应唯一 wood/crystal/brass、.32 共同 open、.34 对应唯一结果、到仓1.22/1.47/1.72。每组实际注册3个运行stream；独立音频变体轮换不使用Run随机。
- `update_loot(age,delta)` 时钟消费阈值；正常30/60Hz只发送单显示帧内仍新鲜事件，.32/.34同帧允许；卡顿最多允许最近34ms的真实新cue，其余记 stale；>0.55s立即结束并记 suspended。重复相同age不重播。流播放记录带 draw_id 与 loot_age，相同Draw五项唯一。
- `finish_loot(reason="cancelled")` 即刻停止本箱voice，记录待触发cue跳过理由。别名 `advance_loot(age)` 和 `skip_loot()` 兼容P09 method名称，但正常5cue语义是P10新合同，不沿用4cue测试预期。Main 必须真实传plan/delta、所有跳过/后台/重开路径调用finish，不能先扣币后回调第二笔；Main 由另Agent实现，集成后需真实事件/UI测试。
- 静音立即停止已起音loot voice、取消duck；时钟仍消费阈值；解静音仅未来新鲜cue，不重播过去。清除/暂停焦点、重开、开战均清本箱声音。事件组loot cap=4；现有一切 gain/master/Alert/Combat优先保护保留。新增材质 per-event trim -8dB。Music −3 dB，Ambience −2 dB，100ms进/160ms出；danger优先以更低trim取min非叠加，Music当前无实际音乐流，测试的是总线而非真实音乐听感。海潮循环始终不重新播放，只有未播放才unlock重试。Web P09 bus_count sequential/父send/SAMPLE 不变。
- 旧 P09 retry TEST SOUND、固定总线、禁autoplay、实际bed不重启/静音恢复41项合同保持。

## 实际可复现测试与交付
`godot --headless --path . --script res://tests/p10_loot_audio.gd`：独立真实Godot软件混音控制器测试，不是伪造波形或声卡。3类×3变体（60/30Hz交替）实捕获；219个检查、零失败，包括每个正常实际5事件与阈值误差≤1 fixture帧、重复age、.25/.40/.55s跨阈值及>0.55s、静音后只未来cue、focus out、拒绝、不解锁不播放、12次快速skip、报警恢复、动态鸭音、总线、voice cap。报告 controller-report.json 含每次实际事件age/variant/Draw-ID、drop_history、实际Mixer采样帧/丢帧/最大声数；录音 preview/p10-native-{master,ui,ambience,alert}.wav。最终重跑（明确关闭 Godot 导入压缩后）：Master 823,296帧/18.669s，-11.2dBTP，0 float clip/丢帧；UI -7.3dBTP，Ambience -21.6，Alert -15.0；实际最大loot并发4，均在门槛内。软件混音的44100Hz设备输出不是运行素材采样率。录音峰值以 FFmpeg 真峰值实际测量重新写入 audio-quantitative-p10.json；此处技术 gate/感知 gate 不混称。

参考预览：`preview/P10-loot-3-categories-native-preview.wav` 约6.75秒，依次普通招募、新遗物、升阶，每组真实Godot native软件mixer第1变体摘录（仅重采样至48k/边缘4ms防断点/间隔静音，不改音量），不是完整玩家游玩录音。 `preview/P10-blind-listening.zip` A真实混音9条+B-material九条单材质RMS匹配+C-result九条奖励RMS匹配，固定seed随机，空表27行/人，另存 answer-key.csv 未加入给听众的ZIP。B/C不是主观等响。至少8–12位独立真实首次玩家、识别>=80%且每类>=70%、材质/清晰/冲击中位>=4/5、疲劳/刺耳<=2/5，在真实画面再检验；**尚未完成、无听力样本，不填写或伪造得分**。真实浏览器WebGL2/手势/实际声卡/切后台及独立画面G05-G09仍待验证。GitHub/LFS/itch由根统一授权合入，不由本Agent外发。

## Godot 运行格式修正与回归
独立实现集成检查发现新19个WAV自动生成 `.import` 默认 `compress/mode=2` 会改变 Godot 运行流格式，虽然源PCM正常。现明确19份 `compress/mode=0`（旧45每份母版、运行源及 `.import` 与 P09 SHA/字节不变）。Godot 4.7.2 实际重导入，`tests/p10_pcm_import.gd` 64/64 实际运行流格式检查无失败：62 one-shot PCM16/48000/mono/不循环，2 ambience PCM16/48000/stereo/循环。重新运行现有兼容P10合同的 P07 回归219/219（保留全部PCM格式检查、旧计数变为62、原真实4 cue升级为5），Web音频合同41/41，P10独立混音219/219；更新实际PCM混音、技术指标及试听包。`docs/p10-pcm-import-hashes.json` 按19份 `.import` SHA列出最终结果。
