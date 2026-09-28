# 启动页验证

2026-09-28，最终简化为系统静态启动页。

- 插画由本地 image-plan 3.1.3 的 Image-2 生成，1024 × 1824，沿用机械幼龙、沙漏、卡牌和金币主题。提示词见 `launch-artwork-prompt.txt`。
- LaunchScreen.storyboard 仅保留一张 scaleAspectFill 全屏图片及四边约束，已移除标题、副标题、底部说明和对应约束。
- SceneDelegate 已恢复为新增启动页之前的版本；不再包含覆盖层、延时、点击跳过、淡出或调试预览参数。
- 简化后 Debug iOS Simulator 构建成功；Storyboard 结构检查确认仅剩一张图片、四条约束，`git diff --check` 通过。
- 原 `screenshots/launch-pro.png` 和 `screenshots/launch-se.png` 为带文字的历史方案截图，不代表当前版本。
- Bundle ID、签名团队、发布配置和部署目标保持不变。
