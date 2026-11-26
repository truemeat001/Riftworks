# P09 独立验收合同（玩家测试候选）
P08冻结方案为基线，保留虚拟金币、6币随机招募/遗物、出售、合并、三阶段六波、波奖励、风险支路与碎冰传递。不纳入未经证实重目标、Conductive 或关卡风险新变体。除已批准选敌指令和 Shellguard 护卫，不能改数值/经济。无真货币、广告、付费。

## P0/P1
P0：不能启动/重试、错误消费/多发、目标或伤害重复、状态附着错误、订单/护卫改变RNG/经济、假命中/假冷却/错误警报、输入透过、明确取消丢进度、网页入口无法玩。P1：新机制藏在说明、错误文字与权威状态、不可预期自动选择、战中不可管理但控制显示可操作、指令无法关闭/重看教程、画面音频高峰遮挡关键事实。真人新手趣味、实际硬件音质/性能无证据只能作为外部测试问题，不能宣称已通过。P08 验收项全回归，P0/P1 未解不公开。

## 权威逻辑，实际 step 独立可复现
- Front 仍最近出口，精确距离并保留原数组 tie，Brass 固定；Screen Mist 优先未减速、同类最近出口+ID tie，若全减速回到最近出口；Cluster Hammer 实际伤害半径内存活副目标数最多、最近出口+ID tie，考虑当前被选目标 slow/真实 splash+blast/rank 范围，不为多打一个目标虚增攻击次数。无Heavy/Marked。选择指令仅 build，0币/0 RNG，非法ID/角色/阶段无 mutation；无效订单不可偷偷保留；已有合法指令随部署/召回/跨关保留，合并仅 surviving id 的 order（可继承位置但不继承被消耗者order），出售/新 run 清除。指令可无代价反复切换，no-op 不发 changed。
- Guard Escort: 先按指令选 intended，再仅 Brass/Mist 直击普通/runner；存活非Boss ready guard 距 intended≤1.2、也在攻击者真实射程内，距离近→剩余路近→ID tie，无 lane 限制（交汇可跨路）。同 tick 第一次真正拦截消耗24 ticks (1.2s)，后续不能重复直到确切 tick，其他 eligible guard 可独立拦截。普通直击 guard/Boss、Hammer area、chain副目标、dead、超范围、未ready无拦截。不降低/吸收伤害、没有暗中debuff、无额外攻击。使用实际 guard HP/slow、伤害、命中坐标、Mist slow、focus/conductive 指标；chain origin从实际 guard，原 intended 可作为独立合法 secondary。不额外触发 Tide。事件有效伤害而非 overkill，记录实际 tick/donor/recipient/位置；不把同一事件重播，按10tick期限/波间/重启清除。预测仅实际含 guard 的波/功能开，战斗ready计数须即时实时有效。
- 真实2×2同seed：orders默认/适应开关 × guard off/on（隔离版本且 only bool flip，绝不让发布UI关闭难度）；实际 P08 default/off 必须相同 trace；无 guard 波和无 eligible target 的规则不偏移；至少两类有意义正反配对，记录胜负、HP、漏、tick、伤害、收益、拦截数量、订单/阵容证据，不能把强度变动直接当趣味。重点弱开局、极端风险、同FPS/速度固定输入、同tick双塔、近射程、非法与Boss，经济RNG不变；公开平衡缺陷如实列出。

## 交互/教程与表现
- 首次指导主路径不自动设指令/不阻塞；Guide、skip、replay、Esc现有语义、实际购/部署与下一波免费开始均回归。介绍先选角色，Brass固定；Mist SCREEN“优先未减速，但可让近出口敌人漏”，Hammer CLUSTER“多打人群，但可能放走近出口敌人”；护卫选择之后拦截而非订单无效，Hammer bypass，1.2s cooldown；文字易懂，不写缩略技术变量。选角后能发现控制，禁用战中/无对象/Brass，按一次仅实际切换，失败/确认取消不改资源。960/1280实际可读、提示不重叠操作。
- 护卫 cue 对应实际 event 一次，源/target箭头明确真实伤害去了guard，guard ready和cd可辨，真实事件可终局清；Boss/死/其他队伍不得伪造盾；敌/血条可辨，2x 5塔忙战声不盖真正危险。音效如复用则明确来源和trigger（不能谎称新资源），Master软件混音与物理设备耳听分开；音频预算、静音、暂停、重试不积旧音。实际原生完整六波胜/败恢复、Guard实击、指令控制和新教程截图；真实WebGL2入口及用户首手势完成实际游戏循环才可公开。未验证环境明确阻断，不把导出或headless等价支持。

## 阻断：P08 真实浏览器没有声音 (P0)
用户实际能进入P08游戏但 SOUND ON 无声。不能因原生/软件Mixer通过而认定浏览器声音正常。
- 官方Godot Web导出说明 https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_web.rst ：Web 自4.3默认Sample，经Web Audio API，需用户交互启动；Stream 支持传统混音但单线程可能延迟/破音。
- 上游 https://github.com/godotengine/godot/issues/119026 报告4.6.2单线程Web、itch、本地http均发生多总线Sample无声。当前实际P08导出 index.js SHA 33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba 同样含 Bus.addAt(-1)→Bus.move→splice(toIndex-1,0,movedBus)。P08 GameAudio _ready 动态追加6个bus并设置send，实际Master被移动，JS索引错乱。独立脚本 tests/independent_p09_web_bus.js 从实际导出JS提取Bus类，仅用mock gain graph检查连线，旧实现物理序列[2,3,4,5,6,1,0]，7个bus都无法到达destination；按setCount(7)先顺序创建则[0,1,2,3,4,5,6]且全可达。此为真实导出代码图结构复现，非实际声音或浏览器耳听。
- 修复必须避免旧动态append Sample bus 路径；优先静态layout或先固定count顺序创建。如采用Web单Master则每voice需保留真实逻辑组优先级/上限/响度/duck/mute，在非Web保持标准混音。明确首手势、解锁实际失败或状态时不可用“SOUND ON”假装已发声。未点击不主动放音；实际可听反馈至少需真实用户同版本打开Web、手势后听到环境/开箱/攻击/静音恢复，实测页面切换和重返；有设备时检查真实输出混音不能无声。导出后检查所有45 runtime WAV/导入路径、实际 index.js/pck 和哈希；WebGL/浏览器只有软件图模拟不能代替真人音频验收。

## 最终集成内部验收（外部P0仍待用户真实音频复验）
最终冻结6个源：Main 753da621947929253ebb6209bb44b88018f35ae5d1e3cc6ec14801cc82c09147；Run 0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25；Atmosphere 64d494d0b0affe3c8fdbc06a5bf256ae0d2e7e582e2154d85a46a9a4840ccd18；Audio 4637c5bd90cab17bb2ab21c981bb1683de9e96e41c7f6619e273b2254019e009；Readability 124d7fc297d86ec05cbb346140452faa9c6dca724fa942bb729f39297716a5a6；Tutorial 34c8ca5e4336ae21ab3c209d5364bf93bd1ae6e76aa30573ee8782fdf8b255d9。独立隔离副本122 source/asset及66 import sidecar（共188）SHA全部匹配；P08的109素材文件未改，新增3×2 guard音源。

- **逻辑、机制、交互：** P07独立规则586/586、P08 Tide57/57、教程42/42（含真实viewport合成鼠标输入）、UI132/132、表现1268/1268、P09组合42/42。Screen意向未减速runner而guard已减速，实际护卫hp93.5/slow0.8，runner hp100/slow0，仅实际收击者获状态；同tick双Mist第二次真正击中runner，总伤害13。Brass Focus/Conductive使用实际guard状态，chain从guard出发；Hammer Cluster命中组不消耗Escort。生产者测试隔离重跑订单49/49、Guard UI16/16、Guard VFX3630/3630（19次真实拦截、804状态显示、无隐藏状态）、Readability5911/5911（941真实ticks/7540敌人观测、峰值18、AABB面积proxy下降24.3%、血条重合1773→0）。选择不花币不耗RNG，禁止Heavy/Marked，取消不损失进度。
- 设计组2×2 600实际局（精确0302d739，P08 baseline120、guard off240、on240）：P08基线120/120一致、487无事件波末hash一致、161全tick一致，无错误，第一关两波一致。Generic关支路 A/B/C/D胜26/28/25/27、开支路23/28/21/26；special关24/27/25/27、开21/26/23/26（A Front off、B Alt off、C Front on、D Alt on）。D合计106 vs B109；Guard启用时 Alt相较Front共多12胜，5241真实拦截；10个自然无Hammer获胜，证明非强制组队，未证明真人趣味。
- **终局报告10/10：** 真实boss逃逸触发lost，显示Copy；内容与seed、HP、stage、wave、漏、gold、tick、实际order与relic一致，无账号/设备/URL/私有目录信息；只有明确点击请求本地clipboard，不变更规则，重试后隐藏；headless无法证明真实操作系统粘贴。无HTTP/WebSocket/JavaScriptBridge自动发送源路径。原生截图审阅实际订单、真实Guard波预测/1/2 ready/拦截表现；首次教学、Test Sound、点击部署、阶段切换可见。截图不是物理设备FPS证据。
- **声音：** 45组母版/运行版独立523/523、90个实际WAV哈希/格式/动态/尾音/loop，新增Cue真实48k PCM16 mono导入。独立Guard cue 30/30（初次删除.import后Godot默认压缩mode2导致格式断言失败；恢复精确生产 sidecar mode0重新导入通过，不隐瞒测试环境差异）；同tick去重5/5（0.24s实际时钟间隔仍不重放），声音UI20/20、固定bus41/41。独立Test Sound4/4：真实 viewport按下+释放，首次手势只一条请求、不影响状态、实际 native Master PCM20480帧峰0.0547（−25.24dBFS）非0不削波；无设备/Web耳听宣称。Guard压力实际软件混音各225280帧，Master/Alert/Combat/Ambience均无削波丢帧，449低优先事件拒绝、Combat上限6、危险/伤损告警留存、静音和暂停恢复。
- **P08声故障修复：** 最终GameAudio实际源码先一次固定bus_count=7并依顺序命名、设send，Web播放器显式Sample。实际P09导出 index.js SHA33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba，精确JS类模拟复现旧路径Master重排/全部断开，新count-first全连通。实际index.pck SHA7488703fb85368f1eccbf3348cedf035692e85ea3e16457ca5d23001e521599a，150条目录MD5完整，45实际运行.sample及remap全部存在，并与独立生产sidecar的导入后样本字节Hash完全匹配；45项显式PCM mode0，无母版、docs、tests、scripts打包泄入。原生总线/混音、真实导出图修复及文件完整性均通过。Test Sound反馈明确“请求”，不声称实际听到。**软件修复内部验收通过；外部音频P0只有实际用户同一构建打开Web、点击后确实听到声音才能关闭。** 在实际设备复验前不要宣称网页声音已修复成功或公开放行。
