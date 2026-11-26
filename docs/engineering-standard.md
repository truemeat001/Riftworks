# 游戏工程师职责、优化和发布验收规范 v1.0
本规范先核对行业真实职责，再应用到独立游戏 Riftworks。目标是可玩性、稳定性、跨设备表现和可持续的 AI 高效率制作。工程师主动发现技术问题，而不是等制作人分派打包；不能用优化名义改变未批准的玩法、降低已确认美术质量或掩盖兼容风险。
## 1. 职责分工及边界
| 职责 | 执行工作 | 与其他角色关系与交付 |
|---|---|---|
| 客户端/运行时架构 | 逻辑权威与表现隔离，确定性、事件单次语义、资源/对象生命周期、暂停/倍速/前后台、错误恢复；数据驱动接口与低耦合；适用平台安全与隐私 | 与玩法明确合同，技术实现可独立复验；维护关键架构文档、边界与测试 |
| CPU/GPU性能 | 分离CPU/GPU/IO bottleneck；逐帧耗时、p50/p95/p99、长帧、draw calls、粒子/透明叠画、脚本与GC、峰值并发及长时稳定 | 与技术美术定义预算，先实测再优化；同场景对照，实际平台不支持标待验证 |
| 资源与包体 | 构建产物清单（源/运行时/压缩传输分别）、重复/无用资源、图集采样和压缩质量、加载时序、引用计数、释放/缓存；音效母版与运行副本、LFS和授权清晰 | 技术美术/音频保持风格和听感门禁，工程处理可重建资源流程；不擅自删源文件、压缩或降低显示品质 |
| 跨平台兼容 | 浏览器与桌面/移动实际支持范围，WebGL2、音频 autoplay/路由、触控/鼠标/键盘、存储和剪贴板、不同硬件与系统；平台特有缺陷真实复现并修复 | QA独立复验；本地Headless通过不等于Web真实可听/可玩，记录可用设备及未验证项 |
| 自动化工具、构建及发布 | CLI-first 导入/构建/测试，版本和依赖锁定，完整源码、清单、PCK/ZIP检查、可重建、干净工作区、自动化回归、发布与回退包 | 制作人负责发布范围与授权、工程执行构建；不得向主分支强推、上传凭据/未授权素材、dangling LFS pointers |
| 技术质量与可观测性 | 代码审查、热点/复杂度、异常日志、数据/资源不变量、真实事件日志、可复现缺陷、依赖审查与技术债；开发者工具和迭代速度 | 各工种负责体验，工程主动修复根因；独立验收角色不由工程师自签。只采集测试必要信息，不默认自动将玩家数据上传 |

行业资料：Riot [Wild Rift 客户端技术负责人](https://www.riotgames.com/en/work-with-us/job/7015284) 涵盖架构、设备扩展、非功能性指标、渲染与工具；[引擎性能工程师](https://www.riotgames.com/pl/work-with-us/job/8275281/staff-software-engineer-engine-performance-central-technology-unreal-ecosystem-los-angeles-usa) 强调实测、基准、分析和动手优化；[自动化与构建工程师](https://www.riotgames.com/en/work-with-us/job/7959470/staff-software-engineer-automation-build-systems-unpublished-r-d-product-australia-based-relocation-visa-sponsorship-provided-sydney-australia) 配合多工种改进 pipeline；[渲染技术美术](https://www.riotgames.com/en/work-with-us/job/8302365) 连接画面风格、性能预算及资源工作流。上述岗位为行业职责参考，并非要求小项目有同等人力/架构。
### 独立角色约定
工程 Agent 从原型即并行运作。每轮专门提交 Profile/包体/兼容/CI 证据与可执行优化项；P0技术阻断优先修复，但其他独立制作继续推进（制作人 v1.1）。工程师负责解决技术根因，而不是把问题全部推给独立验收；验收角色对冻结候选再独立核验。当前无付费资源，不新增追踪服务和跨站通信。

## 2. 先定设备、基线和测量口径
版本、commit、engine/export template、分辨率、配置、浏览器/OS/GPU、音频、seed、玩法策略、是否debug/headless、加载缓存、并发和采样窗口必须记录。区分 native actual、Web actual、headless model、资源推导、模拟图与人类反馈。只在一致条件作前后比较；采样用真实主循环，不在计时帧写截图、导出报告或调试打印，预热后运行多个独立样本。同一机器的变化可作相对证据，不是玩家设备的绝对FPS保证。
| 指标 | 当前/建议门槛 | 测法 |
|---|---|---|
| 稳定性 | P0 主流程可玩、无未处理崩溃/资源缺失/权威结果改变 | 真实完整流程、重复开局/失败/暂停/恢复/平台实际入口；关键异常可复现 |
| 帧时间 | 参考60FPS p95≤16.7ms、p99≤33.3ms（建议值，目标设备待确认），30FPS低档另标，不用平均FPS掩盖长帧 | 预热≥3s、正常/最密波、1x/2x、窗口尺寸至少960与1280，各3次完整采样，CPU/GPU分别；帧时间/1% slow frames，记录真实模型Tick与资源 |
| 内存 | 不预设伪造硬件值；峰值与稳定后基线；反复重开清理不应持续增长 | 实测debug RAM、引擎对象/纹理/音频、GPU或浏览器JS heap（若有）；分别记可释放资源、源图RGBA推导与测量；重复5轮、快照与冷加载 |
| 加载/下载 | P08 ZIP26,790,261字节为实际归档基线（不同于HTTP传输）；≤30 MiB为建议预算，不牺牲实际品质；加载耗时目标待真实设备 | 文件分布WASM/PCK/资源、ZIP raw/compressed、实际网络冷/热cache及首个可操作帧，固定网络条件；按贡献定位 |
| 音频/输入 | 真实Web点击后有声，音效开关/暂停/重复/失焦恢复正确，无规则影响；P0静音异常必须解决 | 真实设备声音+实际PCM捕获不同证据，音效量化与主观规范；检验平台音频上下文和总线图、触控和系统输入 |
| 构建可重现 | 版本、source hash、export config、engine、依赖、artifact SHA、清单；无过期缓存/密钥/测试源图泄漏 | import→headless smoke→适用tests→export→CRC/PCK entry hash→实际平台入口→Draft验证→公开门禁 |

## 3. 优化顺序与质量约束
1. 分析实际数据，最大贡献项先排；区分包体占用与内存、下载、运行时。先去除明确不在运行时引用链的临时/源文件，不能把动态路径资源当未引用。保留所有母版，输出运行资源清单。
2. 对热点提出单一变量优化：纹理/图集/音频压缩必须A/B实机画面和听感，保持帧锚/透明边缘；缓存绘制/对象复用/减少逐帧分配必须确保状态和事件语义不变，固定种子逐Tick比较；加载懒化确保无首次触发卡顿、缺资产。CPU/GPU优化分开。
3. 优化前后比较性能、质量、内存、大小、风险和兼容性。证据不足不宣称提升。P0先修回归，P1明显慢帧/资源超标，P2技术债可独立并行，禁止以传统工期延期有价值优化。回退路径/原包保留。

## 4. P09 初始工程事故与包体例证
- 玩家实际 P08 Web SOUND ON 而无声，网页进入不等于声音通过。P08 shipped JS 的动态 Bus.addAt(-1) 导致索引错乱，独立连接图复现全部7条无输出；count-first 路由7/7。原生工程曾能录音，因此此前的 native QA 无法覆盖Web平台。修复后用户真实声卡需复验。
- P08 实际包 26,790,261 字节，WASM raw 39,514,754/zip内10,114,273，PCK raw17,697,660/zip内16,563,788；不是HTTP实际传输。工程继续审查P09实际包、未引用资源、性能与资源生命周期，实测后给版本建议。未经画质/声音比较，不擅自有损压缩或换引擎。
- 源码与资产必须一致，若Git LFS尚无正常授权上传对象，保留完整源码归档并报告远端文本checkpoint，不能声明远端完整可构建。

## 5. 输出与验收
每轮：技术结论｜实际版本&设备/场景｜指标&口径｜当前/目标&差值｜瓶颈证据｜改动文件/风险｜前后结果&回归｜独立验收｜待验证。明确 P0/P1/P2 及下一项实际执行任务，不以制作周期为理由拖延。将可重建查询、脚本、原始日志、包/源哈希和具体复验流程提交仓库，证据单列，不交付私人日志或凭据。
参考 Godot [优化方法](https://docs.godotengine.org/en/latest/tutorials/performance/general_optimization.html) · [Profiler](https://docs.godotengine.org/en/latest/tutorials/scripting/debug/the_profiler.html) · [Performance monitors](https://docs.godotengine.org/en/latest/classes/class_performance.html) · [4.7 导出](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) · [4.7 图片导入](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_images.html)。
