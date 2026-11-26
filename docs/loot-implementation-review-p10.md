# P10 Loot 独立实现验收（过程记录，尚未放行）

冻结设计 SHA256 `d8c22d0f3f5781f1946ff3107b1691ee60e97b7a957d4bbe3a2d491b7b0fa45a`。在实现冻结后单独复制源文件，独立编写 Godot viewport 输入、边界、PCM 和 WAV 核验脚本，未改生产代码。

## 决策
初版输入/音频技术测试通过，但新增独立边界发现真实 keyboard focus loss 会扣6金币；退回修复。Main SHA ae3dea094e43512833f0dbdb7383388f9ed489d8af4afc245441d9db72e8ce93 下独立复验34/34通过，焦点离开及离开再返回均正确取消原付费手势。两项早期触摸失败先确认测试流重复注入，随后实际 Godot 全局自动 emulation 及独立显式 viewport companion 流均验证通过。此为软件输入事件，不等于物理触屏真机。

**G04 初版实际画面 FAIL，返工；正式集成/公开测试未通过。** 1280×800 native GPU 真实截图的 .27s 无标签容器裁片（native-grayscale-review.png）显示：三类实际箱体仍为同一个青木、绳索与贝壳主体。晶紫仅细带与小侧结晶，金铜仅金带和细锁；灰阶中 T0/T2 主体轮廓与大材质区域极近。即便在裁片放大时可看见锁形变化，仍不满足冻结规范的三类材料/质量明显跃迁与实际显示尺寸辨识。建议以有明显面积的晶质盖/生长晶簇、厚实金铜/象牙边框与大锁形改变主体材质及轮廓；用同风格光向、纹理完成，拒绝只加同色圈/通用多边形贴纸。重新验证打开前后材质一致、不闪回、灰阶辨识。人类真实盲辨阈值尚未评估，不虚构百分比。

## 门禁证据与状态

| Gate | 独立证据 | 结论 |
|---|---|---|
| G01 | 1862输入总检查内含219个真实付费检查、50种子×4合法抽取、全3角色8遗物，独立 P09 Run 对照，边界 fixture 全池/满池、R3；成功单扣6、失败无奖励，模型状态/随机状态一致。 | 初版通过，最终源冻结需回归 |
| G02 | 实际 Input.parse_input_event 30/60及按住跨自然结束、地图跨结束、鼠标退出、重复按键混输、焦点；修复版34/34边界含直接viewport touch/companion、自动emulation touch、焦点离开及回归。 | 已关闭初版焦点P0；最终冻结待全量回归 |
| G03 | 实际Start、Retry/Esc 确认/取消、出售确认、应用失焦（通知模拟）、拒绝旧收据、立即skip。 | 软件边界通过，最终冻结待回归 |
| G04 | 原生两尺寸四轮各十关键帧；.27s RGB/灰阶裁片可复查。 | FAIL 初版品质材质不够清晰；返工后复验 |
| G05 | 独立正常四轮20自然cue、30/60逻辑模拟及真实软件PCM运行52/52，.25/.40/.55/.56长帧、mute未来cue跳过、快速skip。 | 软件路径通过；实际视觉时间/浏览器声画同步待证 |
| G06 | 269/269文件技术检查通过，19个新增WAV 527876B，45份旧运行/母版SHA未动，48k24bit母版/16bit运行差≤1LSB，组内RMS跨度及各文件真峰值校核；软件真实Master PCM 475136 stereo frames，0clip/0discard、最大并发2、-9.8dBTP，12次快跳。 | 文件与软件采样通过，最终PCK、实际Web音频另验 |
| G07 | 没有8–12独立玩家真实音频、灰阶辨识、疲劳及发现skip答卷。 | 未验证，不虚构人类听感 |
| G08 | GPU实际截图已采，图材质改版尚未完成；性能与冷暖包体由亲自运行的工程负责人核验。 | 未放行 |
| G09 | 目前仅软件混音及原生截图，未有真实itch浏览器扬声器/设备回执。 | 未验证，不公开放行 |

## 复现与证据定位
- `independent_loot_input.gd`、`independent_loot_boundary.gd`、`independent_loot_pcm.gd`、`independent_audio_assets.py` 为独立脚本。
- 初版日志 `independent-run/input.log`/ `pcm.log` 及同目录JSON/WAV/true-peak.log；资产技术记录 `asset-review.json`。
- 边界修复日志 `independent-run/boundary-retest.log`，触摸旧测试流分离记录 `independent-run/touch-debug2.log`。
- 部分 Godot headless 测试进程退出时报 ObjectDB/resource 引用残留；同脚本 verbose 复跑未复现。当前不能以测试进程退出表现证明游戏运行泄漏或无泄漏，G08须按同样实际运行/回收测量。
- 实际GPU截图 `native-project/native-loot-evidence/`（初版），人眼截图比较和真人盲测是不同证据级别。

## R2 回归（9a9a559 LootReveal，ae3dea Main）

独立复制全部 source/assets 并冻结 `independent-run-r2/source-sha256.txt`，64 个 WAV import 均为 PCM mode 0。复验：G01/02/03/05输入 1862/1862、边界34/34、资产269/269、Master PCM 52/52，471040双声道采样帧、0clip/0discard、max loot voices 2、true peak -11.3dBTP。旧输入 P0 确认已关。

**R2 新增明确渲染缺陷**：实际常速PCM录制同时渲染过程中日志34次 `Invalid polygon data, triangulation failed`，回溯 `LootReveal.gd:87 diamond <- :288 draw <- Main.gd:1459`。疑因 burst 末段趋零尺寸的粒子退化。已退回实现者为亚像素/近零alpha粒子加安全跳过，下一冻结重新运行；不能以52/52测试数掩盖引擎错误。初版程序声音仅作为回归基线，声音最终选型仍待独立评审。R2 GPU图像另存 `native-project-r2/native-loot-evidence-r2`，禁止覆盖第一版证据。

### R2 真实图像视觉审查，非真人盲测

实际截图 80 张，8 次真实 seed7 reward（2 个角色、新 Echo burst R1、Echo burst R2 ×2 请求窗口）；`native-project-r2/native-loot-evidence-r2/evidence.json` 确认每次真实结果、最终金币及实际目标槽。**尺寸证据限制：960×600 是窗口请求，Godot viewport 图像实际仍1280×800。** 这说明固定逻辑像素/伸缩而非真实960最终屏幕采样，不能把两套图冒称两个屏幕尺寸视觉通过，需补真实桌面/物理输出截图。

1280px .27s 无标签预开盖固定胸箱区域对比（`native_material_review.py`；RGB+灰阶图和数值分别 `visual-review-r{1,2}/`）：R1→R2 灰阶≥20/255像素差比例 T0/T1 7.37→39.68%，T0/T2 7.66→43.41%，T1/T2 7.59→31.39%，均为固定body矩形区域、非整个屏幕；无标签绘画三体目视明显可识别。仅用于客观变化对比，不能代替G07至少8真人盲辨。R2静态材质/形状子项 PASS：木箱、晶紫大晶体/面板、金铜厚板/铆钉在灰阶仍可区分。

**仍需返工布局与锁形连续性：** R2 原生 .52s 两类截图有 category glyph y174 压在header底 y175附近，图标底 y332 与名称顶 y331相触。要求上下至少 8–12px 呼吸区；避免紫色/金色信息紧贴边框。开箱后 T1/T2 一个完整锁突然变成上下各一个完整同形锁，破坏实体一致性；上盖应只留匹配的小扣座/残留片，下方保持主锁。已通知实现者。R2暂不宣称完整G04通过。

亚像素 diamond 守卫修订 SHA `03ecfdc484b6f454fd1ca1d743f1defe79076e56199a130f44767986016a9d2f` 单独复验 `independent-run-r2/pcm-guard-fix.log`：52/52，渲染三角化 ERROR 0。该日志仍有不稳定 teardown resource 提示，不能假造长期内存回收结论。上面的R2原生截图是旧 9a9a559 视觉源，不是 guard 修订源；最终应复捕当前冻结SHA。
