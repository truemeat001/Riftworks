# P10 正式宝箱表现候选（实现 Agent 交付）
冻结设计 SHA256 d8c22d0f3f5781f1946ff3107b1691ee60e97b7a957d4bbe3a2d491b7b0fa45a；独立设计审查 G01–G09 已批准进入正式实施，不代表实现通过。此目录独立从 P09 复制，未改 P09 或 P10 主集成。

## 文件/集成
- Main.gd（5e441d1174f7733b54ed32bd615726321c2fce8d021943929078a6f95c0f9a2f）：真实事务 + 只读收据/时间轴；新输入 token 在 GUI 之前固定物理按下语义；实际目的地址；结束/失焦/跳过统一回收。Main.patch 是从 P09 基线生成，集成建议对 Main 三方合并，保留 P10 关卡、攻击、loader、缓存、atlas、Web hook、字体等独立变更，不直接覆盖 P10 Main。
- LootReveal.gd（3ec99143f8adc57b5cadc9fbd08a89cc4e3c2f7c333d470c7ac2dac75ca636a0）：只读取真实结果及不可变 presentation plan，三类 1.35/1.60/1.85s，.12 材质、.32开盖、.34唯一真奖励、最后.47飞出、.13到达归位。程序画箱饰锁、纹样及粒子，复用原512闭开箱图，无新增纹理/生成假稀有级别。
- GameAudio.gd（b3cdbdd8e3a767410831978c8da3f859ccbf2fd11f20b4ddc21b1d722d23174f）及19新母版/运行声=.12材质cue＋变体，由独立音频Agent拥有。Main 已接统一接口 start_loot(result,plan), update_loot(age,delta), finish_loot(reason)。请集成最新音频Agent目录文件，不从我这边覆盖音频修订。
- Run.gd 实测与原 P09 SHA256 都为 0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25；未修改概率或兑换。
- 测试 p10_loot_ui.gd，native capture 脚本 LootNativeCapture.gd/.tscn；四份旧同步测试仅修改因冻结规范发生的 presentation 合同预期，需与其他 P10 测试改动合并。
- 512原始箱图按新256显示尚需真机512/320 A/B；不可为省包直接替换源稿。

## 可复现测试
Godot 4.7.2，headless 实例化 Main SceneTree，Viewport.push_input 实际事件，明确断言并写 JSON：
  godot --headless --path candidate --script res://tests/p10_loot_ui.gd
结果 1711 checks / 0 failed，见 p10-loot-ui.json。正常60Hz 5项事件+完整真实seed7四次结果；另64 seed *4真实成功付费并逐次免费跳过；真实8遗物3角色类别覆盖。完整模型快照与第二个Run一致，包括RNG、gold、reserve、towers、upgrades、nextID、last_loot、phase、odds。库存边界是明确 fixture（不是完整游玩）。包含跨自然结束按住按钮及地图、触屏模拟伴随鼠标、键盘echo与混合输入、失败、失焦、拖出、长帧、目标消失等测试。引擎退出时有4 ObjectDB instances / 2 resources teardown警告，测试返回0；尚未确定是否真实运行累积泄漏，不能代替 G08。Main 与原生截图测试通过 --check-only。

原生截图（真实渲染，非概念图）需有 DISPLAY：
  godot --path candidate res://tests/LootNativeCapture.tscn
在实际Viewport采集1280/960三类，每次固定30Hz模拟时序，输出 loot-native-output 中PNG和frame manifest。此机器未执行GUI录制，不能将脚本冒充产出；应在集成机执行并确认真实截图像素尺寸、无标签灰阶及正常速度。固定帧序列不是性能测试。

## G门禁自查
- G01 实现侧PASS：冻结权威Run和64真实seed覆盖/拒绝/库存 fixture。
- G02 实现侧PASS：真实Viewport输入、按下意图、跨自然时钟边界不误扣，失焦后立即明确真实6金币；独立QA待复核。
- G03 实现侧覆盖：取消、首次确认、出售确认、选中、音效/遮罩清理、失焦长帧、收据；完整P10流程/重开/合成由独立QA补齐。
- G04 只验证pose最大尺寸、精确时点、真目的格；实际1280/960、灰阶无标签、粒子亮区、正常速度必须看真实图。
- G05 Main 中60Hz实际事件5项通过；软件混音实录、异常delta/mute边界由音频Agent与独立QA执行。
- G06 独立音频Agent负责技术资产和混音；不得用日志冒充听觉。
- G07 未验证。需8–12真实玩家，明确无需模拟为真人。
- G08 新图0B；资源、真实帧时间、内存、导出包及512/320 A/B待集成测。
- G09 未验证。真实 itch Web GL2与设备可听取决于实际浏览器/用户反馈。

## 旧测试合同回归
- p08_ui_tutorial: 36/36。
- independent_p07_presentation: 1268/1268，完整波次真实 contact exercised。
- ui_p07_test: 32/32。
- independent_p07_ui: 132/132，包括原960布局、真实Start、重试/取消、已到帐选择、自然结束。
- audio_p07_tests 初次跑出真实问题：新19个WAV的引擎 .import compress/mode=2 使运行AudioStreamWAV格式变化；已报告音频Agent，要求保留 old PCM FORMAT_16_BITS 检查不降低，而总数应从43→62。其余cue、混音、资源回归等检查无额外失败；须修复导入后重跑。

## 独立验收返修 R2
- 独立边界复现：键盘在 Explore 按下后失去控件焦点，释放仍错误购买。真实 Godot Input.parse_input_event 观察到引擎先发 device=-1 的 emulated MouseButton，随后 ScreenTouch，取消释放也同序且 canceled=true。已修复 Focus Exited 永久标记当前键盘 token 被取消，释放再核对原控件焦点；真实 touch 负责抽取，屏蔽控制区域先到的 emulated mouse，鼠标/触屏 canceled 都不可提交。独立 reviewer 新 34/34 通过（含焦点移动/返回/新键盘、真实触摸与取消、显式伴随输入）。
- 新 Main SHA ae3dea094e43512833f0dbdb7383388f9ed489d8af4afc245441d9db72e8ce93，最小 focus-touch-fix.patch 与完整 Main.patch 均更新。独立旧 regression 所有219+36+1268+32+132均通过。自测1717/1717，见更新 JSON；退出 teardown警告14 ObjectDB/7 resources，尚不解释为运行时泄漏/通过。
- 新19 runtime .import 已从音频Agent同步 compress/mode=0 并重导入；audio_p07_tests 219/219，实际 PCM FORMAT_16_BITS 合同保持。
- 独立原生 RGB/灰阶审查否决早期视觉（仅细色带/小晶体）。R2 visual SHA 9a9a559c41eda91d643093f76fb27bd909507fbe911b31814f389a395ad3bc25；六块大面积材料遮罩各闭合/开放姿态，以原图对应 UV 保留画作的笔触；紫晶明显的不同光暗面、厚晶体簇、异形大锁；黄铜铆钉实体板、亮暗倒角、加厚连接带与八边形锁。统一 ASCII；无新增纹理。已通过脚本编译，独立 reviewer 重采集 RGB/gray；实际材质与覆盖面积/亮区/质量待审，不能宣布通过。
- R2材质遮罩源图几何统计（512原图 alpha>127）：闭箱 six masks 覆盖49.79%原有可见像素、遮罩越出原本透明轮廓0.06%；开箱覆盖26.40%、越出0.44%，不含额外晶体、锁、金边。仅为源图几何证据，不代替实际实机灰阶辨识与亮度/性能审核。R2后全套 viewport 测试再跑1717/1717。
- R2 独立实机 PCM过程中报告34个近burst终点的几何三角剖分错误（超小 diamond 四角浮点坍塌），新增<.25像素半宽/半高或 alpha<.02 的不可见粒子跳过，避免向Renderer提交退化多边形；LootReveal新SHA 03ecfdc484b6f454fd1ca1d743f1defe79076e56199a130f44767986016a9d2f，编译通过，最小 diamond-fix.patch 存档，待独立重新实机采样确认无错误。其它表现/时间轴/资源完全保持R2。
- R3 visual polish after independent actual R2 material/grayscale static subgate pass: category baseline197 (+10), icon center268 and max98, name362 (+14) / effect393/secondary414/rank446; transient rise arcs up while actual slot endpoint unchanged. Target gaps category/header and icon/name ≥8–12px including icon shadow considered, real pixels require recapture; lid now retains complementary empty pentagonal slit mount / open brass half catch with bolts, no full-latch duplication. LootReveal SHA dfe9bdf54ab223ab4d9aac1645b57c5a243b04d6d7cbe3a8dc5081212f2554be; compile passed, visual-polish.patch and all-stage previous material-rework.patch updated; Main, GameAudio, Run unchanged.
