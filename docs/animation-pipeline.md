# Riftworks P03 角色帧动画技术方案

## 定位与 NGame 的技术复用边界

原创潮汐浮陆幻想世界《裂潮驿站》中，塔的场上表现为固定驻守格位的完整人物，怪物也表现为有肢体、有动作的角色。P03 的原创建模方法是手工设计轮廓、配色、局部铰接姿势，用 Python/Pillow 确定性绘制透明像素帧，而非复用 NGame 的任何图片、角色名称、世界观或玩法代码。它是**可运行第一轮像素占位美术**，不是最终发行画风。

已核验 NGame 保存的技术源码：

- scripts/pixel_actor.gd：MergePixelActor 缓存并共享 SpriteFrames；使用 AnimatedSprite2D 与 nearest texture filter；循环 idle、非循环 attack/hurt/death；新版英雄 4/6/2/4 帧，idle 6 FPS、attack 20 FPS；通过 prepare_attack 在逻辑攻击前摆出预备帧。命中立即闪色，攻击进行中合并受击请求，死亡优先并禁止重复死亡覆盖。
- scripts/rear_hero_art.gd：根据 art/rear/rear-heroes.json 的逐帧 region 与 anchor 创建 AtlasTexture，filter_clip=true；不依赖等距网格切割，也不逐帧拉伸或翻转背面素材。例：idle 首帧 region 为 [50,41,214,246]、anchor [158.5,285]；每帧脚锚来自测量而非几何矩形中心。
- scripts/test_sprite_sampling.gd 验证 nearest 与像素变换下的透明遮挡/采样，明确几何诊断不是 GPU 实机验收。
- scripts/test_enemy_animation.gd 检查帧数、帧遍历、循环、hurt 排队、死亡不可被普通指令打断、快速事件不重启受击第 0 帧，以及不同显示比例；敌方为完整角色，身体不被旋转裁切。

以上为技术模式而非直接复制；新项目采用统一紧密 AABB 图集：根据 alpha 的实际非透明范围裁剪，保留每帧相对稳定锚点的 offset，每块四边和四角外扩 1 像素防止采样邻接串色。不要将不同构图尺寸的帧强行塞回固定框缩放。

## P03 原创角色资产与动画合约

| 角色 ID | 角色 | 轮廓及局内辨识特征 |
| --- | --- | --- |
| pulse | 铜鸣游击手 | 瘦长双足、青灰风衣、赭金背包、横向信号枪；明亮铜管指向 |
| frost | 潮雾织师 | 宽圆软帽、低重心长衣、浅青雾壶；无须依赖纯色识别 |
| burst | 礁锤护航员 | 方肩、护甲与小圆盾、上举方头铜锤 |
| crab | 裂潮寄居蟹 | 螺旋甲壳、短脚、前侧大钳 |
| sail | 风帆兽 | 鲨形口部、三角帆背、四足 |
| urchin | 棘潮亡灵 | 肩背棘刺、弯曲躯体、骨刃 |
| boss | 潮渊领主 | 王冠、深红庞大海兽、倒锚前臂，比普通怪物更宽 |

友方以青灰、奶白和赭金为主。敌方以暖珊瑚红、紫墨描边为主。形状编码与阵营色并存。该资产面向固定俯视棋盘的轻微 3/4 角色表达；保留整身角色绘制，东西朝向有独立预生成镜像帧，上下方向本轮保留横向姿势，武器轨迹、目标连线与攻击特效应按真实目标向量生成；不要把整个人体旋转 90 度。后续若需要四/八方向背面表现，另出真实背后帧，不可简单翻转前视图当背面。

| 状态 | 帧数 | 基础 FPS | 循环 | 方向 |
| --- | --- | --- | --- | --- |
| idle | 4 | 6 | 是 | 默认右、left |
| attack | 6 | 18 | 否 | 默认右、left |
| run | 6 | 10 | 是 | 默认右、left |
| hurt | 2 | 12 | 否 | 默认右、left |
| death | 4 | 9 | 否 | 默认右、left |

7×22×2 = 308 个逐帧表项。所有角色均有全部状态，但同一攻击循环允许保留回位帧：实际 attack 在不同角色中有 3–5 种不同姿势；idle 每角色 4 个不同帧、run 6 个不同帧，脚/腿位置交替；hurt 两帧、death 四帧。本轮塔攻击、怪物沿路径推进，因此资料中的怪物 attack/hurt/death 帧不等于游戏已经存在反击或怪物技能。实际状态接入由表现层负责。

工作画布 96×96 透明 RGBA，名义角色造型尺度使用原始 64 空间（四周 +16px 安全区），统一世界锚点=(48,68)，角色鞋底/接触位置置于近锚区域。死亡旋转围绕脚锚而不是贴图中心，且有足够工作画布余量。所有帧 AABB 都与画布边缘有间距。镜像以垂直锚线为轴，锚点不变。

## 图集消费与展示约束

- assets/characters/atlas.png：512×1491 RGBA，透明底、1px 边缘外扩，113,591 字节。
- assets/characters/manifest.json：characters[id][state] 帧数组，每帧 {rect:[x,y,w,h],offset:[x,y]}；states[state] 提供 {fps,loop,count}；方向名如 run_left。
- assets/characters/concept-lineup.png：角色静态轮廓预览，仅供概念评阅，不作战斗贴图。
- docs/character-motion-preview.gif：七角色 24 帧循环演示，包含 idle、attack 与 run，带帧号和脚锚线；为原始素材动作证据，不是实机录屏。
- assets/characters/generate_character_atlas.py 和 verify_character_atlas.py：源生成和资产验收工具，需 Pillow（生成 PNG 不需要游戏运行时 Python）。

Godot CanvasItem 可直接画图集局部，frame rect 排除外扩像素。角色世界位置是逻辑锚点，而非贴图中心：

    var frame: Dictionary = manifest.characters[actor_id][state][frame_index]
    var r: Array = frame.rect
    var o: Array = frame.offset
    var world_dest = Rect2(anchor + Vector2(o[0], o[1]) * visual_scale,
        Vector2(r[2], r[3]) * visual_scale)
    draw_texture_rect_region(atlas_texture, world_dest,
        Rect2(r[0],r[1],r[2],r[3]), Color.WHITE, false, true)

若用 Node2D + AnimatedSprite2D，帧资源使用 region 与 filter_clip=true；当 centered=true 时每帧本地 offset = manifest.offset + cropped_size/2，脚锚世界位置不随帧变化。请按 Y 轴脚锚排序人物，独立绘制脚下阴影与血条，不把阴影、血条或进阶星标烘入帧图。镜像状态已经生成，不需要负宽度绘图。推荐 64px 格子常规角色比例 0.85–1.0、Boss 1.10，最终以 960×600 实机读图调整。地图路径与交互格线应仍可辨认，允许武器适当越格，非法放置逻辑不取决于图片 bbox。

逻辑动作与渲染分离。20Hz 固定战斗 Tick 保持权威，攻击、命中、漏怪事件不受渲染帧数、贴图状态、动画是否播放完影响。真正的动作触发时让 actor 播放 attack，用目标位置选左右朝向；render 插值追随世界位置。attack 只在事件发生时启动，不能每次 redraw 重置第 0 帧。同一角色频繁攻击时允许演出压缩到攻击间距（动画表现速度改变不改变权威冷却与伤害结算）；同 Tick 事件确保单一事件 ID，不能由动画完成 signal 二次结算伤害。伤害命中时立即短闪色并保持 opacity；attack 中不强制重启动画，death 覆盖其它队列；死亡表现完成才回收视图，不再生成攻击或受击特效。暂停冻结同一模拟时间轴；倍速同步缩短表现时长。建议补同种子相同输入 30/60/120fps、x1/x2/x3 或渲染抖动的有序事件/状态一致性验收。

## 实际资产验收（不是实机游戏验收）

在 P03 目录执行：

    python assets/characters/generate_character_atlas.py
    python assets/characters/verify_character_atlas.py

已实际执行：308 项帧条目全部通过真实 PNG 像素与生成源逐帧对比、正确 AABB、重建 alpha、offset、左右镜像、1px 四边四角外扩、分块不重叠、画布边缘无裁断及 distinctness 检查。再次生成后 atlas、manifest、预览三文件 SHA256 不变化。非透明矩形内容面积 644,996；含外扩面积 702,412；图集面积 763,392。相比将 308 个 96×96 主帧平铺占 2,838,528 像素，面积降约 73.1%；此处不是显存或实际浏览器加载耗时实测。可见 PNG 预览已检查，七角色具有可区分的完整身体，不使用 NGame 图片。

- atlas SHA256: b11fe0e707f725374015ed6b1f422803501efca18e8167e4a92b7376a60529e3
- manifest SHA256: 37793975506099596189595a9aade9f9d2774fd8322a037245a425cba090acb0

剩余验收：真机验证高频攻击/连击时角色状态与事件对应、移动过程中清晰看到交替腿而非滑动、离场与跨关不存在残留动画、死者能顺畅回收、显示比例和像素边缘是否自然、WebGL2 实机及资源导出（PNG 和 JSON）是否正常。当前是首轮角色资产，尚需产品美术评审，不声称已达到发布级质量。
