# Riftworks · 玩法验证原型

Riftworks 是一个独立的 2D 肉鸽塔防原型。它用于验证「不同战场规则 × 同一局内构筑」能否产生新的决策，而不是移植 NGame 的玩法、世界观或美术。

## 运行

- 安装 [Godot 4.7.2](https://godotengine.org/download/archive/)（标准版，不需要 .NET）。
- 在 Godot Project Manager 中导入本目录的 `project.godot`，按 F6（主场景已打开时）或 F5 运行。
- 命令行：`godot --path .`。
- 开发自测：`godot --headless --path . --script res://tests/run_tests.gd`。返回码不为零表示测试失败。
- Web 导出：先在 Godot 的 Manage Export Templates 安装与编辑器版本一致的模板；运行 `godot --headless --path . --export-release Web export/web/index.html`，确保输出目录存在。也可运行 `scripts/verify.sh`（Linux/macOS）或 `scripts/verify.ps1`（Windows），加上 `--web` / `-Web` 进行完整导出。
- 本地试玩 Web：进入 `export/web` 后运行 `python -m http.server 8080 --bind 127.0.0.1`，打开 `http://127.0.0.1:8080/`。不要直接双击 HTML，WebAssembly 加载需要本地 HTTP 服务与支持 WebGL 的浏览器。

## 玩法

选塔，点击合法网格布置，建造阶段可撤回塔并收回购买成本。开波前先观察入口、路线和基地，战斗中由塔自动执行。通过每波奖励选择局内强化；进入新地图会重新布阵，但已获得的强化持续生效。

三种地图共用同一批塔、状态和强化：

1. **Maze relay**：选择一条地形路线，在路径长度与塔覆盖之间权衡。
2. **Rift survey**：选择是否打开第二入口；难度增加，获得更好的局内成长机会。
3. **Resonance field**：合理利用地图上的放大节点与塔间配合，打最终 Boss。

注意：原型的测试通过说明规则实现符合已定义的测试场景，不代表商业游戏平衡、可读性或趣味性已经验证。独立验收与人类试玩另行记录。

## 技术方案与边界

- Godot 4.7.2，2D Compatibility 渲染器；固定逻辑步长与随机种子。
- 战斗状态（`src/Run.gd`）与显示、输入（`src/Main.gd`）分离。
- 统一顶视坐标，所有阵地与规则在相同网格上；先保证路径、入口、射程、机关与效果可读，再优化美术表现。
- 延续 NGame 的工程经验：可重复的无界面测试、资源与构建版本统一、Web 打包和实机验收分开、独立候选审核。未移入 NGame 的代码、玩法数据、美术或音频。
- 此版本使用程序绘制的临时视觉，不需要下载外部游戏素材。

详细的视角选择、产品对照、验收原则见 [设计记录](docs/design-and-acceptance.md)。
