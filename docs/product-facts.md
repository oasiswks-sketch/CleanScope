# CleanScope 2.0 · 产品事实与市场基线

更新时间：2026-07-29

## 已验证的产品事实

- CleanScope 是原生 SwiftUI macOS 应用。
- 当前扫描范围包括：已安装软件、卸载残留、AI 工具数据、Skills / 插件、
  模型权重、第三方运行组件与大文件。
- 删除前展示路径、容量、风险、权限、识别依据与删除影响。
- 默认删除方式为移入废纸篓；永久删除需要二次确认。
- `/`、用户主目录、`~/Library`、`~/Documents` 等关键根目录受硬编码保护。
- 系统级项目只在用户主动执行时请求 macOS 管理员认证。
- 扫描和判断在本机完成，不上传磁盘数据。

## 2026 市场基线

- DaisyDisk 官方售价为 9.99 美元一次买断，强调快速空间分析、系统保护、
  本地隐私与最多 5 台个人 Mac。
- CleanMyMac 官方 1 台 Mac 年付为 39.95 美元，同时提供订阅、一次买断与
  7 天全功能试用。
- Nektony App Cleaner & Uninstaller 官方售价为 14.95 美元/年或
  34.95 美元一次买断。
- BuhoCleaner 官方售价为 17.99 美元/年或 25.99 美元终身版。
- Apple 的 macOS 设计指引强调：大屏信息密度、可调整窗口、菜单栏命令、
  键盘工作流、可访问性与有目的的动效。

## 产品差异化事实

传统 Mac 清理软件通常围绕系统垃圾、应用卸载或磁盘目录展开。CleanScope
的核心差异不是“更多清理项”，而是对现代 AI 开发工作流的来源解释：

- Codex / Claude / Trae / WorkBuddy 等工具的内部数据
- 会话、任务、索引、浏览器缓存与共享运行时
- Skills、插件、模型权重与本地推理资源
- FFmpeg、Manim、Python、Node、Playwright 等可重新生成组件

因此 CleanScope 2.0 的商业定位是：

> 面向 AI 重度用户与开发者的 Mac 空间智能，而不是通用“加速神器”。

## 权威来源

- https://daisydiskapp.com/support/pricing/
- https://macpaw.com/store/cleanmymac
- https://nektony.com/mac-app-cleaner/buy
- https://www.drbuho.com/buhocleaner/buy
- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/
- https://developer.apple.com/design/human-interface-guidelines/sidebars
- https://developer.apple.com/design/human-interface-guidelines/motion
