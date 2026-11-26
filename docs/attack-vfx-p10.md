# P10 攻击特效增强候选
状态：独立制作/软件验证通过，实机画面验收待执行；不直接合生产。冻结 P09 model Run.gd SHA256 0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25 完全相同。仅新建 AttackFX.gd 与 BattleAtmosphere 的最小接入、Main.draw_tower 两行。

- 普攻 Brass：先显示整条有暗边/铜色/象牙核心的箭迹、源指向楔和目标菱形，由源向命中点收束；不会画出尚未落地的延迟弹体。Mist：潮水波线与六角结晶十字；导电是真实 synergy 折线。Hammer：褐色抛物短弧从实际发起格到真实目标；实际溅射子目标独立轨迹与楔片，碎冰按已确认事件显示淡冰裂片，不画虚构半径。
- 真实受击位置、攻击塔 ID、kind、tick、synergy 来自原 authority shot snapshots，原 shot.life primary=.11 vs secondary=.07 的现有契约标识源楔（仅主击）。Guard 拦截实际目标仍为护卫，保留原有虚线保护关系和盾闪，无新 protected-unit 伪命中。
- 0–50–100–150ms：轨迹立即完整显示，随后向命中点缩退；150ms 后仅保留少量局部反馈，300ms 回收（20Hz 逻辑）；2x 相同 tick 寿命缩短，暂停不推进，同 tick 不重复消费。
- 4.4/2.25 逻辑 px 主迹宽度，暗边额外 2px；次级 3/1.45 px，降低其 alpha；密集度超过8按每多一个 contact 减 0.025 alpha，最低 0.5，实际命中保留至少 0.78 的相对强度。28 上限不变。保留首触局部小环，不新增大面积高亮。Main 仍在全部战斗特效后画 guard-status、血条和警报。
- Main 友方动作：权威即时命中对应既有 frame4 (zero-based index3, 18fps) 开始；持续到 0.16s 内最后两帧恢复，避免先实际命中后才挥击，不虚构前摇；攻击逻辑与音频触发不改。

## 软件验收实际结果
同 seed 执行两份完全独立 Run，基线 atmosphere 与新 atmosphere 各自观察，合法抽取/合并/部署/选择风险线路。6 局、9647 ticks、123016 checks、0失败，逐tick权威序列全部相等；主击2148（Brass1008/Mist724/Hammer416），每次真实射击台数和主击数/发射源一致，chain 532、Hammer secondary648、Guard 109 实际拦截；实际峰值14 contacts，小于28。命中位置/记录数量/寿命对照完全一致，同 tick 重复观察不改变记录。结果: 种子437 closed胜15HP/open败0HP；438 closed胜15/open胜9；56 closed胜15/open胜6。原始日志 vfx-ab.log。旧 regression: Atmosphere1627/1627、Guard art3630/3630、Guard UI16/16、攻击音频去重5/5。
已检查 Main.gd 与 CaptureVFX.gd 可解析。当前执行环境 headless (DISPLAY none)，未验证 GPU、实际浏览器画面和真实人类辨识度；实际绘制的正常速度、密集可读性、960px缩放均须由独立视觉验收确认，不能把软件通过称为正式通过。

## 集成与实机验证
只拷贝 AttackFX.gd；BattleAtmosphere.patch 的 const AttackFX、_new_impact primary 字段和 draw_combat 的主体，保留其他组 lane/alert 改动；Main.patch 只改 tower attack clip 的两处，勿覆盖敌人修复/性能缓存等并行文件。P09 和P10其它组不改。原有 move/stage 清理保留。最后击杀在本轮 authority step 切 phase/stage 同时清除 hit FX，是既有问题（与 death-tail 一起独立修复；不得阻塞权威结算，不在新地图错误位置残留）。本候选不声称已修。
在图形环境运行 godot --path <candidate> res://CaptureVFX.tscn ，脚本基于实际合法 Run 操作及真实事件抓取每类主击、链/溅射、guard、dense 的真实原生截图，输出 screenshots/capture-log.json。它只自动触发用户等价的规则操作，不代表独立玩家；正式审核仍按相同seed全局实际 UI、两分辨率、1x/2x、长时稠密场景播放，同时检查新关卡警报无冲突、最终包新增体积及 GPU/CPU timings。待验收：起手/命中实际显示、轨迹非颜色区分、源/目标姿势自然、密集可读性与实际包/浏览器性能。
