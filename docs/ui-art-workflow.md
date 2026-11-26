# Riftworks UI 美术工作流及验收合同
状态：P05 A 方向已获用户批准；实现验收进行中；适用于设计、生成与审稿。以 DESIGN.md 为共享规则，art-direction-p05.md 为美术总方向。所有竞品材料仅供研究，不作为游戏资产。NGame 仅供工程技术借鉴。

## 1. 输入模板
- 任务：提炼风格规范 / 按规范出稿 / 审稿；对象：页面/面板/图标/插画。
- 风格参考：已确认作品及风格板；构图参考：线框、草图或当前稿（标注是信息/几何/材质/光向哪种用途）；已有规范：当前 DESIGN.md 版本与字体、组件、品牌规则。
- 确定画面实际展示尺寸、目标语言、交互状态和返回路径。缺失项标记待确认，候选不冒充已批准。
## 2. 参考库：每图 1–2 个借鉴点
| 类别 | 参考图与来源 | 只借鉴 |
|---|---|---|
| 布局/地图 | [Bad North](https://www.badnorth.com/welcome), [Carto](https://sunheadgames.com/en/press/carto/) | 微缩岛轮廓与留白；低密度地形 |
| 角色 | [The Wild at Heart](https://www.moonlightkids.co/the-wild-at-heart) | 大色块、辨识剪影 |
| 海洋材质 | [DREDGE 官方截图](https://www.dredge.game/press-kit) | 海盐木/纸、整体色调 |
| 战斗 HUD | [Kingdom Rush Alliance 官方实机](https://www.kingdomrushalliance.com/img/kr5/screenshots/KRA_screenshot_01.jpg) | 数值图标层级，底部操作栏 |
| 战斗反馈 | [Emberward 商店截图](https://store.steampowered.com/app/2459550/Emberward/) | 战场与技能重点色区分 |
| 建筑/升级 | [Thronefall 实机截图（WWGDB）](https://cdn.nichesites.pikoya.com/wwgdb_com/images/games/72335/gallery/99061.jpg) | 局部升级收益与标题层级 |
| 材料图标 | [DREDGE 造船升级实机（Gamepressure）](https://www.gamepressure.com/dredge-pc/how-to-increase-cargo-space/z810a2d) | 消耗材料与价格分区、材料轮廓 |
Game UI Database [入口](https://www.gameuidatabase.com/)：自动检索被 robots 拒绝；后续人工可按 HUD、Building > Upgrade、Item/Resource Icon 检索，再增补带出处截图。不针对网站限制进行规避。参考亦不可复刻标识/形状。
## 3. 生产，按门禁推进
1. 设计 Agent 做任务输入与用户旅程、线框（含返回、状态、动画、禁用/错误、多语言），需求用可观察规则描述。反方 Agent 检查信息负荷、误触、技术可行性。
2. 美术 Agent 对照参考图归纳 3–5 条可画规则，记录来源、建议色值；三种同构图方向对比后选主方案，在实际尺寸检查。先主页面效果图，确认后 DESIGN.md token 与组件库冻结，未确认内容单列。
3. ImageGen 用途、对象、构图、参照角色、材质、色彩、光源、必须保留/不得出现分别写清；草图只管布局，原创造型表锁定身份，材质样例只管质感。按单一改动迭代，用户确认后的参考图持久化；保留原始输出、prompt、版本/hash；不要用整屏图直接作 UI。图像文字/按钮/数值引擎渲染。
4. 美术资源拆分：背景、角色转面/帧动画、可交互遮罩、9宫格边框、按钮状态、图标；统一 alpha、AABB/anchor、1px extrusion；非像素资源使用合适线性采样，缩放后测试。逻辑与表现分离；已有 LFS 政策生效，先验证远程 LFS 对象和免费配额，不提交裸指针。
5. UI Agent 用统一 token / Godot Theme 实现，动态数值、多语言使用真实文本。不得随意新增色号/圆角/字体；变更提出理由、影响范围、图例并回到冻结步骤。
6. 实现 Agent 先自行审核及适用自动化测试；独立验收 Agent 按下列合同、真实 Godot 截图和实际状态验收。旧正式候选可回退，不将概念图当实机。关键里程碑经验收提交 GitHub 私有开发分支并更新 itch 私有 Draft；不公开发布、不收费、不强推。
## 4. 独立验收（阻断优先）
- P0：在 1280×800、960×600 可识别生命/币/波次/路径、每个角色与敌人，关键操作无遮挡，无错字截断，交互/返回正确；按钮显示真实可用状态，点击不误触，动画不重复扣费；重要信息不只靠色彩。
- P1：所有页面 token 与组件一致；正文对比≥4.5:1、重要边界/图标≥3:1；实际截图检查，不只看名义值；颜色、形状、光向和纹理规则一致；图标32/48px 并排检查；角色帧脚底 anchor/方向/动作连续。
- P2：细节密度、留白、局部装饰、动画力度、原创性与主题表达；主观意见标为可选建议。
- 审稿格式：优先级 | 具体位置 | 偏离 DESIGN.md Ux/章节 | 证据（截图/状态） | 改法 | 复验结果；不得将客观P0/P1缺陷平均掉。视觉迭代结果标注风格/材质/光影/装饰，具体差异。
## 5. 方法参考
[Google DESIGN.md](https://github.com/google-labs-code/design.md)：YAML 设计 token 与可读说明结合，使用 lint/diff 做结构回归；Google 格式目前 alpha，未宣称本文件已通过其工具。
[Google Stitch](https://blog.google/innovation-and-ai/models-and-research/google-labs/stitch-ai-ui-design/)：先多方向探索再收敛，以项目级规则复用组件，原型连通页面验证流程。
[OpenAI Image prompting](https://developers.openai.com/api/docs/guides/image-prompting)：输入与目标明确、参考角色分工、小步修改和保留约束。
[OpenAI Academy](https://openai.com/academy/image-generation/)：简洁具体描述，逐项迭代，强调设计原创性。
