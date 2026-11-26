# Riftworks P10：基于真实声源的开箱音效素材库（实验，不替换正式版）
检索与下载：2026-11-26。目标：降低程序合成听感单调，使用短拟音元素与不同材质的层次组合，而非三段长背景音乐。所有已用源页面明确标记 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。原作不要求署名，但推荐在项目资产清单及 credits 保留出处。禁止将未核实授权素材替换入产品。

| 原作者与来源 | 文件及数量 | 授权与实测下载 |
|---|---|---|
| rubberduck [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx) | 100-CC0-SFX_0.zip / 100 | CC0，完成 |
| rubberduck [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2) | sfx_100_v2.zip / 100 | CC0，完成 |
| rubberduck [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | 100-CC0-wood-metal-SFX.zip / 100 | CC0，完成 |
| rubberduck [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | water-splash-slime-sfx.zip / 40 | CC0，完成 |
| PWL [Bell dings/chimes](https://opengameart.org/content/bell-dingschimes) | bell_ding1.wav, bell_ding2.wav（选择2/4） | CC0，原文亦声明 public domain，完成 |
| Vinrax [Coin Drop](https://opengameart.org/content/coin-drop) | coin_drop.wav / 1 | CC0，完成 |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds), [Interface Sounds](https://kenney.nl/assets/interface-sounds) | 未取得原包 | 官方页面检索摘要及 [作者商业使用说明](https://kenney.nl/support) 均明确 CC0；直接下载网页访问返回403，因此不纳入样音。未绕过限制。 |

原始公开下载文件保存在 originals/，素材页面 HTML 保存在 pages/。原始附件和 ZIP 成员级哈希可追溯；未登录、不付费、未下载未经许可的商业游戏音效。压缩包既含 Ogg 原源，也有 WAV；导出的24位 PCM 文件不是原始24位录音（不要把转码后的位深误称录制位深）。

## 音效元素
详见 elements.csv：20 项独立可编辑、可试听 WAV。木箱锁扣/开盖/木撞各2，玻璃3、金属合拢2、金属共鸣2、水2+气流1、清亮魔法铃2、归仓2。材质名称以源文件命名/作者说明为分类线索，尤其铜材质、玻璃碎裂等实际拟音是否贴合仍需人耳判断。所有候选均实际解码。独立 stems 使用 48 kHz / 24-bit PCM 单声道，轻微去头尾静音、65–13.5kHz带通、最多2s、首尾淡化和 -3dBFS 峰值归一。源文件保持不变。

## 三种分层试听
遵照已冻结的真实开箱合同：仅使用局内真正发生的分类，不改变结果或概率；charge 0.00 / 材质 0.12 / open .32 / 结果 .34 / 入仓1.22/1.47/1.72；三类总时长1.35/1.60/1.85s。
- crew 普通招募：短气流、锁扣、共用木盖与撞击、水花主体+小铃点缀、物件入仓。
- relic 新遗物：清脆玻璃扣、共用木盖、玻璃碰撞+铃音、水滴收尾、入仓声。
- upgrade 升级：厚重金属扣、木盖、大金属共鸣+延伸小铃音及碎响、入仓声。仅加强真实高阶事件，不强化错误/虚假的结果，不增加金币损失。
mixes 下每种包含 five event stems + 1 full audition。mix-recipes.json 数据化列出每层源文件、时点、速度、频带、峰值、时长、淡化，并由 mix.py 复现。制作仅使用上述公开真实声源的剪辑、变速、滤波、叠混，没有额外合成波形。所有音效是单次事件，非循环。

## 验收边界
这是可编辑的候选实验素材，尚未接入生产版，也未做实际人耳盲听。技术可解码性、峰值、RMS、采样率、位深、声道、首尾边界和无硬削波可验证；主观上是否比程序合成更有质感，需在真实游戏中，与原音和独立模型音以固定播放响度进行随机编号 A/B/C 试听，至少评价材质辨识、重量感、节奏、奖励反馈、与战斗/音乐的遮蔽。不要用响度提高冒充品质提高。若替换生产版，分别接入五个事件音，沿用现有静音、生命周期、跳过、Web路由规则；不得将整体混音强行单流塞入会发生 skip 的运行时。

实测文件验收：`python verify.py` 39/39 WAV（20个独立声源、15个事件层、3个完整试听、1个串联试听），全为48kHz 24-bit mono，可解码/长度一致/非全静音/0个硬削波样本/首尾精确近零（<=1e-6）。三种整段的 sample peak / RMS：crew −13.00/−37.23 dBFS，relic −13.00/−36.07，upgrade −11.37/−31.56。并未测得真实播放声压，也未把不同长度的整段 RMS 视为感知响度评分；升级响度稍强需独立确认。完整技术检查见 `wav-checks.csv`。
