# Riftworks P05 美术重定向（2026-11-26）

用户要求摆脱 NGame 美术惯性，仅复用帧动画、图集、渲染等技术。P04 截图暴露高细节像素角色、深色金属和木板、硬色路线与工具式 HUD；角色与敌人重叠也削弱视觉辨识度。旧美术保留为回退对照，不作为新图像生成参考。

## 已确认主方向：手绘航海微缩剧场（非像素）
- 2D 帧动画，统一固定约 60° 俯视，表现立体岛礁、港口、海雾和微缩角色；保持战场网格与逻辑矩阵独立，改变视觉不改变规则。
- 以海盐蓝、浅灰绿、暖象牙、珊瑚橙为主，危险信号朱红；少量纸纹/哑光颜料，整块清晰的轮廓，无旧式金属盔甲、繁密像素纹理、黑金 HUD。
- 角色像航海玩具/绘本：潜水维修师、风帆引导员、贝壳巨锤手等原创剪影，各自相异装备、体型轮廓和作用色；敌方则由海洋生物、潮汐畸变形态构成，不借用竞品具体造型。
- 路线来自实际地形：栈桥、潮汐沙洲、礁石间的可行走地带；不中断寻路，切换路线时可高亮；非固定黄色粗线。UI 像船舱航海仪表与货签，尽量让战场占据主要视区。
- 用户已确认 A 海岛微缩手绘概念方向并要求实机一比一还原；不再用其他风格替换 A。以批准图为目标，使用真实逻辑、真实资产和交互；数值占位不进入产品。

## 对标图片（仅供研究；不可直接作为发行资产）
1. Bad North：地图留白、岛屿轮廓与阵营识别。https://www.badnorth.com/welcome
2. The Wild at Heart：手绘有机形状、奇异生物、角色动作。https://www.moonlightkids.co/the-wild-at-heart
3. Carto：地图与地貌一体、视觉层次。https://sunheadgames.com/en/press/carto/
4. DREDGE：海域材质、氛围、港口；不采用阴暗恐怖主色。https://www.dredge.game/press-kit
5. Emberward：关卡色彩区分、技能反馈；避免过强闪光淹没敌人。https://store.steampowered.com/app/2459550/Emberward/
6. Kingdom Rush Alliance：路径、单位与特效可读性；不复刻形象、场景或 HUD。https://www.kingdomrushalliance.com/en/Presskit/

## 生产流程
参考 OpenAI [Image prompting](https://developers.openai.com/api/docs/guides/image-prompting) 与 [Creating images with ChatGPT](https://openai.com/academy/image-generation/)。先明确用途、构图、对象、画面语言及限制；每张参考仅赋予一个用途；先定原创角色设定和模型表，逐次局部修改，固定角色比例、姿态、镜头、光源；保留批准图作为后续生成参照；复杂局部精确一致须合成保留，不寄希望于文字提示；对 PNG 实际 alpha 通道与边缘进行检查。不要把竞品图当作可用资产。避免将 NGame 或 P04 图片作为风格参考。

1. 定方向 → 竞品真实图 → 主方案概念（A 已确认） → 独立反方与视觉验收 → 冻结风格指南。
2. 角色转面与动作基准图（正面、侧面视图、轮廓），独立 idle/attack/run/hurt/death；动作接续与脚底 anchor，R1/R2/R3 轮廓可见区别。2D 非像素同样可用帧图集。
3. 地图先战场线框，概念图按可行走/不可行走、角色站位、边缘海面分层；UI/图标独立、文字引擎绘制、EN/ZH。
4. 选取完整一关制作，使用真实原生实机与 itch Draft 审核；不等美术全面完成才做验证。评审维度（5分）：独创性、辨识度、视野、路径和站位、构筑反馈、动画一致性、整体色彩；任何路线、怪物辨识失败不得用平均分掩盖。
