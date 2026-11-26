# P10 网页首载与资源减重：独立 P09 基线实验

**结论：工程候选已真实 Godot 4.7.2 Web release 导出，P09 冻结版未修改。首载体验还需目标浏览器验收。** 不拿压缩档案大小当网络下载时间，也不拿 Node wasm 编译时间当浏览器首屏。

## 1. 实际包体和资源
同一官方单线程 Web 模板，P09 实际 ZIP26,858,241B / PCK17,782,456B / WASM39,514,754B。PCK实际载荷：texture 11,723,606B，audio 5,858,859B，script 118,700B，other 65,762B（额外表头/对齐）；背景3张约6.09MB，图集4.23MB，2条环境音各2.30MB。仅排除纯文档 concept-lineup，未删源或任意其他动态引用资源。45音频导入载荷逐字节一致，权威战斗、WASM、engine JS、worklets 均不变。

| 候选 | ZIP bytes | PCK bytes | 与 P09 ZIP 差 |
|--|--:|--:|--:|
| P09 | 26858241 | 17782456 | — |
| 只去 concept + 新 shell 图 | 26794610 | 17585732 | -63631 |
| 仅尺寸（含 pad/lighthouse 探索） | 24459235 | 15249876 | -2399006 |
| 背景 q95 WebP + 尺寸（含 pad/lighthouse 探索） | 21513368 | 12304388 | -5344873 |
| **最终保守候选** | **21597707** | **12388852** | **-5260534（-19.59%）** |

最终 PCK 比原少30.33%；理论 RGBA8 原始解码上限 41,293,920→31,766,112（-23.07%，不是实际VRAM）；PCM16 bytes 5,841,600 不变。ZIP SHA256 5aef81752e039436382f0603d756419011d2f7c793e2ea6b701a7eb4abc68a3c。7个真实ZIP文件，CRC 全部匹配；PCK150→148项，每项MD5校验。只缺 concept 导入及其remap；再无文档/测试/母版或loading art进入PCK。Run、BattleAtmosphere、BattleReadability、GameAudio 的打包 GDC 与原 engine JS、WASM、worklet 相同。Main 只有网页诊断调用。场景源 tscn 未改（编译场景资源元数据受导入变化）。P09 master 完整保留。

## 2. 图片真实尺寸及质量候选
- 三背景由1585×992→1280×800，依旧高于1280×800逻辑屏实际1016×630地图，采用 Godot 导入 WebP q95（仅不透明背景，损失性，需验收）。实际 PCK CTEX WebP载荷解码，按 draw_rect 双线性 CPU 采样对照1280/960，深/浅底合成。三背景最差RGB PSNR 37.07、39.535、39.558dB，alpha无任何变化。背景实际 packed bytes 2202760→439820、1932536→383286、1950750→380600。
- burst/frost两头像256→212，宝箱512→320，实际PCK仍用lossless图像导入（源像素缩尺寸不是bit-exact）。显示最差RGB PSNR 35.72、35.45、37.24、36.307dB。透明边按 dark/sand 合成和alpha单独统计。脉冲头像、portal因源候选PSNR低于33dB保留；pad、lighthouse因实际CTEX透明边差/PSNR门槛恢复原始版本；relic128接近显示106保留，Atlas不全局缩放。实际资产模式、宽高、payload差异见 packed-final-comparison/metrics.json；缩尺寸源SHA见 runtime-resize-manifest.json，P09原件不改。CPU双线性对照是像素质量proxy，不假称原生实机或高DPI屏QA。
- 1024×640背景探索虽小，显示近1×，目前不选，保持画质及高分辨率余量。独立 Atlas mirror/dedup 由root单独验证，不能将这次实际ZIP减重和未合入Atlas理论空间重复加总。45音频 byte exact，编码切换需真实听感/浏览器复验。

## 3. 加载屏和可观测性
source/web/loading-shell.html 是 Godot 官方 custom HTML shell（由真正导出替换变量），仅用项目相对资源，无外部字体/脚本/telemetry。root批准的 loading.webp 1280×800 168336B（≤200KiB），不进PCK；原logo/icon文件不进最终ZIP。直到Main UI完成、process帧及frame_post_draw后主动通知，再经两个browser rAF隐藏。该标记是可交互候选；首个Main._input pressed和首个成功Explore回调分别计时，真正点击仍需人实际测试。
- shell立刻显示插画和status；下载可计量时展示Godot decoded byte progress，不当wire bytes或整体加载百分比；未知为indeterminate。
- 接收完明确初始化。engine JS加载、PCK完成、engine init、startGame resolve、Main ready、overlay hidden、用户首次pressed input、首次成功Explore各自计时。
- WebAssembly.instantiateStreaming/instantiate真实调用起止，流式包含网络重叠，不宣称独立CPU编译；结束后原函数恢复。Resource Timing记录transferSize、encodedBodySize、decodedBodySize、responseStart/End等，同源受缓存/隐私策略约束。
- download/JS/known WASM rejection明确失败；missing WebGL2时失败图层保留；45s无活动提供重试入口、不假称失败；重试由用户点击reload（无自动并发请求），继续进度会隐藏retry。
- 本地诊断：在itch实际iframe的devtools console运行 JSON.stringify(window.riftworksLoadDiagnostics(), null, 2)，数据仅当页内存，不自动传出，资源名只保留basename。
- test_loader.cjs 对真实导出HTML inline script模拟DOM/Engine；确定/不确定进度、100%到初始化、Engine resolve不能提前隐藏、Main ready+2rAF、首次input/action、45秒重试、WASM实际调用包装及拒绝、PCK拒绝、missing WebGL2、JS下载失败、未处理WASM下载拒绝。Mock不是browser/WebGL通过。

## 4. 冷热加载与真实 release gate
itch官方说未预压缩js/wasm/pck等会经CDN gzip：https://itch.io/docs/creators/html5#compression 。不是当前用户HTTP实测。相同gzip level6估算总传输（非实测CDN）26,859,478→21,597,002B，WASM proxy10,114,291B固定，PCK proxy16,631,786→11,238,167B。若真实10Mbit/s，仅少传5.26MB相当于约4.2s理想传输，不包括RTT/波动/解压/编译；不能承诺实际节省。Node V8本地raw WASM compile四次约167/239/136/96ms，仅CPU proxy；当前执行环境无Chrome/Chromium二进制或DISPLAY，Playwright预期浏览器亦不存在，不能实测冷/热WebGL2。没有降级安全限制或安装浏览器。待root云浏览器或用户设备验证。

实测流程：独立Draft/本机HTTP，devtools Network disable cache+hard reload 3次cold，再关闭disable cache同URL reload 3次warm；记录Windows/浏览器/GPU、网络条件、真实transferSize和content-encoding、timeline JSON、实际看到插画、完成首个EXPLORE、声音和pause；960×600和1280×800，各实际切关/重开/长等待。缓存transfer=0不等同无成本。首交互标记必须与实际点击通过。最终确认首载p50/p95、画质/边缘/动态、音效。无真实测量标待验证。
下一步最大项Atlas（独立pixel-exact dedup待GPU），其次两环境音编码（必须先听感/浏览器门禁）。WASM精简引擎高风险单独研发，目前不改官方runtime。

## 5. 合入方法（仅合必要改动）
- 使用source/assets中runtime-resize-manifest.json列出的7张批准候选。原始母版保留于P09或专门作者资源目录，不能复制成PCK资源；复制3背景的.import q95参数（或合入同样参数），其他资产保留。不得覆盖其他Agent新美术；新Twin场景单独同口径检测。
- 合入loader-main.diff三处Web-only hook（若Main已改只按上下文移植）；loader-export-preset.diff中的concept排除、web/*排除、html/export_icon=false、html/custom_html_shell，不覆盖P10其他排除项。复制source/web/loading-shell.html；加载插画独立Web资产不进PCK。
- 正常Godot headless editor import + export-release Web export/web/index.html后，运行 python pack_web.py PROJECT/export/web PATH/loading.webp FINAL.zip。对最终HTML运行 node test_loader.cjs PROJECT/export/web/index.html；检查实际fileSizes、7个文件、art预算及CRC。
- verify_pack.py严格核对相同P09基线（P10新功能会合法改GDC和资产，不能要求相同，重做冻结基线审计）。image_candidate.py AUDIT BASE_ASSETS CANDIDATE_ASSETS OUT可复算尺寸；透明素材保守拒绝pad/lighthouse等，q95通过明确导入参数。试验与证据不进运行PCK。
- Native headless startup、41,426 rules、32UI、20SOUND/UI、41WEB_AUDIO_CONTRACT、36tutorial、49orders全过（native-targeted-tests.log）。WebGL2实际首载、浏览器听感及GPU实机对照尚未过门禁。

参考：Godot 4.7 custom shell https://docs.godotengine.org/en/4.7/tutorials/platform/web/customizing_html5_shell.html ，JavaScriptBridge https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html 。
