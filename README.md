# CleanScope

看清每一 GB，再决定删什么。

CleanScope 是一款原生 macOS 空间侦察与清理工具。它把应用本体、卸载残留、
Codex / Claude / Trae / WorkBuddy 内部数据、Skills、模型权重和第三方运行组件
拆解为清晰、可判断的空间地图。

[访问官网](https://cleanscope-website.oasiswks.workers.dev) ·
[下载 CleanScope 1.0](https://github.com/oasiswks-sketch/CleanScope/releases/latest)

## 主要能力

- 分析已安装软件及关联数据
- 定位软件卸载后的配置、缓存、启动项和服务残留
- 梳理 AI 工具内部的大文件、Skills 与插件
- 识别 Hugging Face、Whisper、Ollama 等模型权重
- 发现 FFmpeg、Manim、Python、Playwright 与包管理器缓存
- 展示路径、来源、风险、权限与删除影响

## 安全边界

- 默认移入 macOS 废纸篓，支持恢复
- 永久删除需要再次确认
- `/`、用户主目录、`~/Library`、`~/Documents` 等关键根目录不可清理
- 系统级残留需要一次 macOS 管理员认证，密码不会被应用读取或保存
- 汇总项目不可直接删除，只能选择具体子项目

## 系统要求

- macOS 13 或更高版本
- Intel Mac 原生运行
- Apple Silicon Mac 需要 Rosetta 2

## 本地构建

使用 Swift Package Manager：

```sh
swift build
```

也可以使用 Command Line Tools 自带的 Swift 编译器：

```sh
swiftc -parse-as-library \
  -target x86_64-apple-macosx13.0 \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  Sources/CleanScope/*.swift \
  -o CleanScope \
  -framework SwiftUI -framework AppKit
```

## 版本

当前公开版本：`v1.0.0`
