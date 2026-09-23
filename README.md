# 时空牌局

一个使用 UIKit 实现的竖屏、离线策略卡牌游戏。基于项目中的第二版彩色原型，已实现卡组大厅、时间战场、胜利选牌、卡组编辑、图鉴和卡牌详情。

## 当前可玩内容

- 3 个逐步解锁的关卡，9 种可收集卡牌。
- 6 张卡组成卡组，初始手牌 4 张，每回合补充 2 张，手牌上限 6。
- 点选手牌后点击时间卡槽出牌，也支持拖放。
- 过去：仅限单位，等待一次敌方回合后成长，攻击永久 +2。
- 现在：单位本回合攻击，法术立即生效。
- 未来：等待一次敌方回合，单位第一次攻击或法术效果翻倍。
- 每回合依次进行己方攻击、敌方攻击；存活后恢复能量，激活延迟卡牌并抽牌。
- 初始能量 3，第二回合 4，此后 5；额外能量不能超过 5。
- 护盾可跨回合保留。每第三回合敌人攻击额外 +2。
- 回溯术召回最左侧单位并重置成长；已支付费用不会退回。
- 通关后选择一张未拥有的卡，直接替换卡组中的一张牌，或仅加入收藏。
- 战斗失败可重试或调整卡组；关卡、收藏、卡组、进行中的牌局和偏好自动保存在本机。

所有界面按钮、文本、卡槽、数值与交互均为原生 UIKit 组件。插画用于卡牌画面，未将原型截图当作应用界面。

## 运行

用 Xcode 打开 `Gaibreanno.xcodeproj`，选择 `Gaibreanno` scheme 和 iPhone 模拟器运行。

保留了原有 Bundle ID `com.cvlc.Gaibreanno`、签名方式、部署目标以及 Debug / Release 配置。应用显示名称为“时空牌局”。没有添加第三方依赖。

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

检查包含：费用与无效操作、过去成长、未来延迟与首次翻倍、护盾与致命伤害顺序、回溯、手牌上限、牌的数量守恒、三关可通关路径、奖励防重领和存档编码往返。测试文件位于 `Tests/`，不打包进主应用。

## 代码结构

- `Gaibreanno/Game/GameModel.swift`：卡牌定义、回合状态机、关卡、奖励与本地存档。
- `Gaibreanno/UI/GameViews.swift`：原生卡牌、能量标记、时间槽、按钮、生命条与背景。
- `Gaibreanno/ViewController.swift`：页面、组牌、点选 / 拖放、对局、选牌、设置和详情。
- `Gaibreanno/Assets.xcassets/CardAtlas.imageset`：九宫格角色插画，运行时按格取图并缓存。
- `Gaibreanno/Assets.xcassets/AppIcon.appiconset`：应用图标。
- `design/prototypes`：原始两版产品原型和提示词。
- `design/implementation`：插画提示词、验证记录和实际运行截图。

## 美术资源

卡牌插画图集与应用图标由内置 ImageGen 生成，已保存为项目内资源。完整提示词分别保存在 `design/implementation/card-art-prompt.txt` 与 `design/implementation/icon-prompt.txt`。App Icon 已规范为 iOS 资源目录要求的 1024 × 1024 像素。

## 版本范围

这是可运行的本地单机版本。当前没有接入内购、广告、联机、账号服务或云同步；游戏进度随本机应用数据保存。关卡数值与卡牌效果集中在状态机中，可继续扩展内容与平衡性。
