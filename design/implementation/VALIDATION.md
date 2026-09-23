# 验证记录

日期：2026-09-23

## 构建

- Xcode 26.6，iOS Simulator 26.5 SDK。
- Scheme: Gaibreanno，Configuration: Debug。
- 使用 simulator SDK，构建时 `CODE_SIGNING_ALLOWED=NO`；没有改动项目中的签名设置。
- 最终结果：`BUILD SUCCEEDED`。
- 无应用源代码编译警告。Xcode 输出一条 App Intents 元数据提取跳过提示，原因是本项目不使用 AppIntents.framework。
- 主项目的 Bundle ID、自动签名方式、部署目标及 Debug / Release 配置保持不变。

## 游戏状态机

执行 `./scripts/check-game.sh`，结果：

```
PASS: 73 game engine checks, including all three encounters and save round-trip.
```

覆盖费用、卡槽限制、无效操作不扣费、过去成长、未来等待及首次翻倍、护盾剩余与致命伤害顺序、回溯、能量上限、手牌上限、卡牌守恒、三关的可通关路径、奖励防重领、关卡与收藏解锁、存档编码往返。

## 模拟器交互

### iPhone 17 Pro / iOS 26.5

- 大厅、设置图标、卡牌插画及底部导航正常显示。
- 点选手牌、选择时间槽、能量扣除、卡牌离开手牌正常。
- 实际拖放种子炮台至过去、发条幼龙至现在成功。
- 将护盾拖到过去会显示原因，手牌与能量保持不变。
- 种子炮台在敌方行动后成长，插画、名称与攻击数值更新。
- 护盾、未来卫士、敌人强化回合和战斗记录可用。
- 实际打通第一关和第二关。
- 通关选牌、替换原卡、收藏保留、下一关解锁正常。
- 终止并重新运行应用后，奖励卡、已通关关卡、当前回合、生命、能量及场上成长状态恢复正常。

### iPhone SE (3rd generation) / iOS 26.5

- 使用本项目新建的 `Time Cards SE` 模拟器验证。
- 紧凑大厅无需滚动即可看到开始牌局和底部导航。
- 战场的卡槽、手牌、玩家状态和结束回合按钮完整显示。
- 空过回合至失败后，重试、调整卡组和返回大厅入口正常。
- 取消一张卡后，保存按钮变为禁用；恢复六张后可保存。
- 图鉴与未解锁卡牌详情正常，关闭后返回原页面。

## 实际截图

- `screenshots/iphone17-lobby.png`
- `screenshots/iphone17-battle.png`
- `screenshots/iphone17-victory.png`
- `screenshots/iphone-se-lobby.png`

截图来自实际运行的模拟器，不是设计原型。

## 验证边界

- 未在物理 iPhone 上测试。
- 当前环境只安装了 iOS 26.5 模拟器；保留项目 iOS 14 部署目标，但未运行旧版系统。
- 当前交付为本地单机版本，不包含支付、广告、联网、账号或云同步。
