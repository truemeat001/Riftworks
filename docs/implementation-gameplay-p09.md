# P09 生产候选：职业指令与护卫拦截
## 冻结范围
P08 Run SHA256 d1a16caee466754bf25e1ae22a21ccd8e9701960e47366b2705e8178a4425681 保留，不改。P09候选 Run SHA256 0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25。经独立lab原型实验后，仅合入获批准的两项规则；渡口节拍、风险HP契约、Heavy Brass/导电其它候选均未合入。无新金币、抽取概率、职业/遗物池、HP/速度、波次/路径、伤害基础公式或局外成长变化。显示这个候选不等同已发布。

## 1. 备战职业指令（自主、可逆、免费）
- 全体默认Front，保持P08严格最短剩余路径优先，同距数组原顺序，不增加RNG；默认不增加order字段。仅当角色本身有效可选、build阶段允许更改，合法重复设置是无状态更新的幂等操作；Front擦除可选字段。
- 铜鸣只有Front；不允许Heavy或其他角色指令。潮雾可以SCREEN（先未缓速的真实可打活敌，再最短剩余路径、spawnID），礁锤可以CLUSTER（实际可打活敌中，选择本次真实可达到的活次目标最多者；实际半径含Blast/R阶位及被攻击目标slow时的原碎冰加成；同数最短剩余路径、spawnID）。无虚假的预测未来移动、无改变攻击次数/实际伤害公式。被guard拦截时，指令只决定拟定主目标，不保证该拟定目标实际受击。
- set_order(id,mode)仅build，绑定已有现场/仓库角色ID。部署、收回、跨关保留；合并保留实际第一身份自有指令，继承第二格时仍是第一ID。卖出角色不保留指令。draw_loot新角色默认Front。错误职业、ID、模式、阶段均不消耗金币/RNG、不更改状态。

## 2. 护卫拦截（独立lab规则原样集成）
- 每个本波实际存在的活非Boss Shellguard初始就绪；铜鸣/Mist按指令选择一个活非Boss、非guard主目标，若其周围≤1.2格且在攻击者真实攻击范围的就绪Guard存在，则将一次直接攻击的实际目标换成guard。最近拟定目标→最短剩余路径→spawnID决胜。纯几何判定，双路线相交附近可跨线拦截，无隐藏路线限制。
- 原CD和攻击时刻不变，实际guard从本tick起24逻辑tick冷却（20Hz=1.2s），同一tick不重复使用相同guard。不能护卫Boss或另一个guard；不拦截Hammer主击/范围伤害和Brass次级连锁，无额外伤害、攻击或状态复制。Focus、导电、Mist缓速、连锁起点、死亡均按真实guard目标重新计算；原拟定目标在实际级联范围内可以被合法次级命中，这不是第二次guard转移。
- 事件guard_intercepts为只读表现快照：{tick,tower_id,intended_id,guard_id,from,to,attacker_pos,damage,ready_tick}；damage是实际移除的HP（截断过杀），shot.to真实guard。事件留10tick，下一波/重开清空；不得增加第二声音效或纯视觉伤害。guard_ready、guard_remaining_ticks反映权威真实状态；forecast仅有实际Guard的波加入guard_escort:{radius,cooldown_ticks,cooldown_seconds}。
- 实验隔离：GUARD_ESCORT_ENABLED=true为编译期生产常量，不是玩家设置或运行时选项。独立实验复制源码后只改false，关闭实际拦截及元数据/就绪读数，不改其他规则；仅用于2×2对照，不进入对外发布假设。

## 3. 真实产品入口开发者检查
在Godot4.7.2运行以下产品脚本，独立XDG缓存，无脚本或断言错误：
| 测试 | 结果 |
|---|---:|
| tests/p09_guard_tests.gd | 53/53 |
| tests/p09_orders_logic_tests.gd | 36/36 |
| tests/p09_integrated_logic_tests.gd | 11/11 |
| tests/p08_gameplay_tide_tests.gd | 81/81 |
| tests/gameplay_p07_tests.gd | 129/129 |
| tests/run_tests.gd | 41,426/41,426 |

组合夹具真实Run.step：SCREEN选未缓速拟定敌、被已有slow的Guard拦截，实际guard刷新；同tick第二个Mist攻击受冷却约束，不再被同一guard截获。跨线在真实半径内允许；CLUSTER Hammer选择密集缓速主敌并绕过守卫，P08 Deep Frost真实状态时长转移到两名实际受击存活者（含普通guard），既没有重复shot，也没有虚假的damage。Brass错误heavy字段不能改变实际Front优先级。以上为开发者工程边界，而非玩家试玩。

### Front+Guard关闭的等价性
同一合法购置/合并及覆盖策略，固定437/438/56三个种子×风险开关；P08原Run与P09拷贝仅将GUARD_ESCORT_ENABLED=false、保持全Front。对实际权威每tick的HP、金币、角色/敌人字典、伤害/生成/死亡/潮雾事件、RNG及各准备波forecast序列化散列；六对完全相同。P09关闭态guard事件始终空。可复现脚本tests/p09_front_trace.gd须在这两份隔离临时工程执行，不能用正常guard开启版本冒充关闭基线。六对散列证明已测试输入轨迹等价，不等于穷尽所有状态：
- false /437: 98d05f5d96cbea88d836e0a6d414bda0c8e083a37a192bcbe057fa553fe81f68
- false /438: 64fcc6aa9b37466f1e9a8152f4c434a93278a7d5df7b5ecd6c9592675fbe1d79
- false /56: e07d2a6cf0de7dcc31c7547523780596862b3eafc41dedf0479d1133af7f15ed
- true /437: dd01f3b849336f06099b8d0b173a0655a6d229503ed84239da85df9d186094f9
- true /438: ddbc192f61abd608b6a0ab323687dc039c6c7292e783ad7f0334054f8f0a13f5
- true /56: a51c12ecfad44123f90ab69775080d39e65115ceb32fcca371393d1aa29010a2

独立设计组2×2（Front/可选指令×Guard关闭/开启）真实种子模型、独立挑战验收、实际UI可读性仍属生产审签门禁；本记录不预判其结论。
