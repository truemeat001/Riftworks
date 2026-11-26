---
version: alpha
name: Riftworks UI
description: "P05 A 方向已获用户批准；具体设计 token 仍需实机验收。"
colors:
  primary: "#AD4631"
  on-primary: "#FFF8EB"
  background: "#C7DDDA"
  surface: "#F5EBD6"
  surface-raised: "#FFF6E4"
  ink: "#213D48"
  ink-muted: "#546568"
  border: "#80999A"
  border-functional: "#607C7D"
  selected: "#176D72"
  on-selected: "#FFFFFF"
  danger: "#9D343C"
  resource: "#865517"
  disabled: "#D9D8CA"
  on-disabled: "#526062"
typography:
  title:
    fontFamily: "Noto Sans CJK SC"
    fontSize: 26px
    fontWeight: 700
    lineHeight: 1.25
  section:
    fontFamily: "Noto Sans CJK SC"
    fontSize: 20px
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "Noto Sans CJK SC"
    fontSize: 18px
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Noto Sans CJK SC"
    fontSize: 16px
    fontWeight: 500
    lineHeight: 1.4
rounded:
  icon: 4px
  button: 8px
  panel: 12px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
motion:
  hover:
    duration: 100ms
  reveal:
    duration: 850ms
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.button}"
    typography: "{typography.body}"
    padding: 12px
    height: 44px
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.button}"
    typography: "{typography.label}"
    padding: 12px
    height: 44px
  button-disabled:
    backgroundColor: "{colors.disabled}"
    textColor: "{colors.on-disabled}"
    rounded: "{rounded.button}"
    typography: "{typography.label}"
    padding: 12px
    height: 44px
  panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.panel}"
    padding: 16px
  selected-slot:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.on-selected}"
    rounded: "{rounded.icon}"
    padding: 8px
---
# Riftworks UI 视觉规范 · P05 A

## Overview
本次任务：提炼规范；对象：战斗 HUD、角色合成/升级弹窗、资源与遗物图标、后续所有页面。构图基准是 P04 实际战斗截图（仅信息及操作关系，不带入色彩/画法）；风格基准是 P05 参考板，**手绘航海微缩剧场**，非像素；NGame 仅复用技术。用户已确认概念 A，锁定美术方向；具体 token 与交互仍需实机验收。建议值不是对原图精确取色。

1. **U1 地图优先**（Bad North 01 / Carto 03）：低密度背景、岛屿轮廓与实际地形路径；HUD 边缘留白，主画面不用管理后台式栅栏。正例：只有下一波/生命/金币常驻。
2. **U2 色块与轮廓**（The Wild at Heart 02）：角色和图标靠形状识别，简洁大色块、局部纸纹和统一光向，而非密集像素与金属铠甲。正例：不同剪影的潜水师、引风员、贝壳锤手。
3. **U3 海洋物件语言**（DREDGE 04）：象牙航海纸、盐洗木、墨蓝线；材质只在边缘/大图具象表达，内文安静。正例：货签面板无铺满纹理。
4. **U4 瞬间读懂战斗**（Emberward 05 / Kingdom Rush 06）：入口/路径/目标、单位状态、技能分层；强调色只服务行动或事件，不能靠色彩单独区分。正例：橙色行动按钮与图标、文字共存，敌方红色警告附形状或标签。
5. **U5 只在决策时展开**（Thronefall 升级参考 / DREDGE 造船参考）：默认简洁；选中才展开成本/收益与确认。正例：合成弹窗对比 R1→R2、消耗两名同类同阶角色，明确取消/确认，不复制其布局或造型。

## Colors
上述 YAML 颜色均为建议值。冷色海面（background）退后，暖色纸面（surface）承载文字，深墨 ink 用于内容、ink-muted 仅次要内容；primary 珊瑚色只用于当前首要行动（探索/开始/确认之一）；selected 仅选中与提示，danger 专用于损伤、不可逆出售等警示，resource 用深金对应金币数字；禁用态保持可读并解释原因。正文≥4.5:1、关键图标/控件边界≥3:1 为研发验收目标；检查真实合成后的颜色，不能仅以 token 数值作保证。装饰不夺取行动色。border 是装饰线；功能描边使用 border-functional（建议值，实测纸面3.79:1、抬高纸面4.18:1、海面3.16:1），海面文字使用深墨而不是次要墨色。实际叠层仍须检验。

## Typography
基准视口 1280×800，统一 Noto Sans CJK SC（中文优先，英文可同字族，须核验字体实际包及许可证），标题26/700，区块20/700，正文18/400，标签16/500，数字使用等宽进位；英中按真实字形检查，不画进背景。缩小至 itch 960×600 时，正文约13.5px；小字不承担核心信息，标签可扩大。按钮一行、数值右对齐，文字左对齐，避免强制全大写中文。

## Layout
4px 基础网格，8/16/24/32px 间距；主战场目标占可用屏幕宽≥72%，常驻 HUD 放在边缘，开箱/角色细节可折叠；重要操作≥44px 高，按钮组间距≥8px；弹窗留24px；被遮挡路径、单位、关键操作为阻断缺陷。支持窗口缩放到960×600且无截断、键鼠可操作、Esc 取消。

## Elevation & Depth
以哑光纸为主、盐洗木/陶瓷/布为辅助；统一左上约45°漫射光，边缘1–2px窄高光，底部阴影2–4px偏右下（透明度12–20%）；同组图标不混用写实反射与平涂。大面板纹理只在外缘、装饰角或标题区（低对比、非全铺）；内容区至少70%安静，正文下无图案。战场脚底接触阴影独立于UI。

## Shapes
大面板12px圆角，按钮8px，小图标底4px；线宽1.5–2px（1280基准），小图标轮廓1–1.5px，特殊边角仅主面板使用一种海图角钉，禁止多重金属套框、通用粗描边和不同形状任意混搭。

## Motion & Micro-interaction
悬停100ms明度变化；按压1–2px视觉位移；抽取动画850ms可免费跳过；状态变化有短暂清楚反馈，避免全屏闪光。表现层不得改变抽取结果或战斗逻辑。

## Components
- HUD：生命、金币、关卡波次、开始/暂停/倍速；数值和图标组合，图标尺寸24/32px；次要内容集中展开查看，选中态加描边和标记。
- 角色合成/升级：原/新角色对比、R1→R2、明确消耗/收益与按钮状态；关闭/取消无消耗；警示色不用于普通升级。
- 材料/遗物：建议画 128×128 源图，实际32/48px，图标占框70–80%，留白一致，约60°俯视、左上光、少量细节，不将文字和星级烘焙进图；并排检查 6 个，32px 仍识别。金币圆盘、霜晶三棱、珊瑚破片分开剪影，不能仅凭颜色。
- 角色卡：64px或更高头像，姓名/阶位/角色标记引擎文字，选中、锁定、禁用、可合成都有状态，不靠颜色单一表达。

## Do's and Don'ts
**必做** 先线框再整屏概念，再冻结 token 与组件；同样式贯穿所有页面，资产独立透明层，验收真实截图；每条审稿意见写「位置 → 规则ID → 改法」，可选偏好单列。
**禁做** 复用 NGame 美术、混用不同材质和光向、用一张整屏生成图直接作运行 UI、使用竞品原图作为发行资产、未审查就批量生成。Game UI Database 的自动检索受限，改用公开官方/评测实机截图（来源见流程文档），不假装已访问。
**待确认** 确切字体与配色、面板宽度和折叠方式、角色尺寸/实际图标轮廓及深色可读性。确认后提升为正式 v1.0，变更必须评审。
