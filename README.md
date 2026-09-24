# Time Cards（时空牌局）

一个使用 UIKit 实现的竖屏、离线策略卡牌游戏。基于项目中的第二版彩色原型，已实现卡组大厅、时间战场、胜利选牌、卡组编辑、图鉴和卡牌详情。

应用界面统一使用英文，开发文档保留中文。卡名支持两行，较长的规则与搭配提示已适配小屏；旧存档中的中文战斗记录会归档并显示英文续战提示，保留牌局、卡组和通关进度。

## 命运契约（Fate Contracts）

保留当前时空场景、角色和卡图，借鉴参考应用的配牌、确定性战斗、资源取舍与连续挑战，加入独立的风险收益模式。参考资料为 [Abyssal Signal: Deep Dive 玩法介绍](https://appagg.com/ios-games/card/abyssal-signal-deep-dive-43755020.html?hl=en)；契约、金币与加注规则是本项目的新设计。

- 大厅入口与底部 Contracts 标签：初始 300 虚拟金币，选择 25 / 50 / 100 的投入。
- Measured：20 HP、敌方攻击不变，三轮回报为投入的 1.5 / 3 / 6 倍。
- Daring：20 HP、敌方攻击 +1，回报 2 / 4 / 8 倍。
- Ruthless：16 HP、敌方攻击 +2，回报 3 / 6 / 12 倍。
- 每轮胜利可立即落袋，或者押上当前全部可领取奖励继续。总回报包含初始投入，向下取整至整数金币；失败或主动放弃回报为 0。第三轮后结算。
- 三场分别复用森林警报、铁皮树、节拍甲虫。六张卡在开局锁定；回合机制沿用过去、现在、未来。
- 连战保留生命，下一场可选恢复 6 HP（上限 20），或获得 8 护盾。旧护盾、手牌与能量重置。
- 战斗新增 Overdrive：每回合一次，消耗 3 HP 换取 2 能量；不会突破 5 能量，生命不足时禁用。
- 金币、最近八次结果、最好连胜及进行中的契约保存到原存档的新增可选字段。普通冒险的牌局、星级、卡牌奖励独立保留。
- 契约结束后，余额不足 25 时可免费补充 100 金币；没有购买、兑换、现金价值或真钱功能。

新增状态机在 `Gaibreanno/Game/Contracts.swift`。验证记录见 [契约验证](design/implementation/CONTRACTS.md)。

## 当前可玩内容

- 配牌工作台：6 张出战卡固定展示，平均费用与单位/法术数量实时更新；点选旧牌，再用已拥有的替补替换，支持保存、还原和未保存离开提示。
- 卡牌收藏册：逐张大图预览、收集进度、获取条件、卡牌效果与搭配提示；可通过缩略图和上一张/下一张翻阅。

- 独立设置页面：触感反馈、减少动态效果、玩法说明，设置即时保存。

- 6 个直接选择、逐步解锁的关卡，9 种可收集卡牌；普通通关后解锁六种困难规则。
- 6 张卡组成卡组，初始手牌 4 张，每回合补充 2 张，手牌上限 6。
- 点选手牌后点击时间卡槽出牌，也支持拖放。
- 过去：仅限单位，等待一次敌方回合后成长，攻击永久 +2。
- 现在：单位本回合攻击，法术立即生效。
- 未来：等待一次敌方回合，单位第一次攻击或法术效果翻倍。
- 每回合依次进行己方攻击、敌方攻击；存活后恢复能量，激活延迟卡牌并抽牌。
- 初始能量 3，第二回合 4，此后 5；缺能小径每回合恢复 3。额外能量不能超过 5。
- 护盾可跨回合保留。敌人拥有树皮、开合护甲、重击节奏、缺能或半血狂暴等关卡机制；战场展示当前状态。
- 回溯术召回最左侧单位并重置成长；已支付费用不会退回。
- 第 2、4、6 关首次通关后选择一张未拥有的卡，直接替换卡组中的一张牌，或仅加入收藏。
- 战斗失败可重试或调整卡组；关卡、收藏、卡组、进行中的牌局和偏好自动保存在本机。

所有界面按钮、文本、卡槽、数值与交互均为原生 UIKit 组件。插画用于卡牌画面，未将原型截图当作应用界面。

每关三星分别来自通关、剩余生命至少 12、专属挑战。普通与困难各自保存 18 星，重玩只刷新最好星级，不重复发卡。界面隐藏章节层级，直接展示 01–06 和难度。详见 [当前关卡设计](design/implementation/LEVELS.md)。

第五关新增单位减伤，首领转阶段削减护盾，鼓励调整卡组与出牌顺序。前四关有初始卡组三星路线，后两关已验证三种奖励组合均可三星通关，困难六关也各有三星路线。旧六关存档保留卡牌、星级和牌局，缺少难度字段时默认为普通；进行中的牌局按更新后的规则继续。

旧三关原型存档升级时保留卡组、收藏与偏好，保留第一关完成记录；原第二、三关不是本章的新关卡，因此不沿用其通关编号，旧牌局结束并从新第二关继续。

## 运行

用 Xcode 打开 `Gaibreanno.xcodeproj`，选择 `Gaibreanno` scheme 和 iPhone 模拟器运行。

保留了原有 Bundle ID `com.cvlc.Gaibreanno`、签名方式、部署目标以及 Debug / Release 配置。应用显示名称为“Time Cards”。没有添加第三方依赖。

```sh
xcodebuild -project Gaibreanno.xcodeproj \
  -scheme Gaibreanno -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/gaibreanno-build \
  CODE_SIGNING_ALLOWED=NO build
```

## 验证

运行独立于 UI 的状态机检查：

```sh
./scripts/check-game.sh
```

检查包含：费用与无效操作、成长与未来连击、护盾与致命伤害顺序、回溯、手牌上限、牌的数量守恒、普通及困难的三星路线、不同奖励组合的通关路径、两套星级隔离、旧存档兼容、奖励防重领和存档编码往返。测试文件位于 `Tests/`，不打包进主应用。

## 代码结构

- `Gaibreanno/Game/GameModel.swift`：卡牌定义、回合状态机、关卡、奖励与本地存档。
- `Gaibreanno/UI/GameViews.swift`：原生卡牌、能量标记、时间槽、按钮、生命条与背景。
- `Gaibreanno/ViewController.swift`：页面、组牌、点选 / 拖放、对局、选牌、设置和详情。
- `Gaibreanno/Assets.xcassets/CardAtlas.imageset`：九宫格角色插画，运行时按格取图并缓存。
- `Gaibreanno/Assets.xcassets/EnemyAtlas.imageset`：第一章六种敌人的插画图集，3 × 2 格。
- `Gaibreanno/Assets.xcassets/AppIcon.appiconset`：应用图标。
- `design/prototypes`：原始两版产品原型和提示词。
- `design/implementation`：插画提示词、验证记录和实际运行截图。

## 美术资源

「能量风暴」已使用独立紫蓝雷暴插画与紫色卡框、雷云符号；「能量火花」保留黄色电光形象。新增资源由内置 ImageGen 生成，文件为 `Gaibreanno/Assets.xcassets/EnergyStorm.imageset/energy-storm.png`，提示词为 `design/implementation/energy-storm-prompt.txt`。所有卡牌页面共用同一资源映射。

卡牌插画图集、敌人图集与应用图标由内置 ImageGen 生成，已保存为项目内资源。完整提示词分别保存在 `design/implementation/card-art-prompt.txt` 与 `design/implementation/icon-prompt.txt`。第一章敌人提示词位于 `design/implementation/enemy-art-prompt.txt`，成品位于 `Gaibreanno/Assets.xcassets/EnemyAtlas.imageset/enemy-atlas.png`。App Icon 已规范为 iOS 资源目录要求的 1024 × 1024 像素。

## 版本范围

这是可运行的本地单机版本。当前没有接入内购、广告、联机、账号服务或云同步；游戏进度随本机应用数据保存。关卡数值与卡牌效果集中在状态机中，可继续扩展内容与平衡性。
