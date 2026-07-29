import Foundation

private struct InstalledAppInfo {
    let name: String
    let path: String
    let bundleIdentifier: String
    let version: String
}

private struct PathSpec {
    let name: String
    let path: String
    let category: FindingCategory
    let risk: RiskLevel
    let reason: String
    let detail: String
}

private struct ResidualProfile {
    let name: String
    let appAliases: [String]
    let bundleIdentifiers: [String]
    let paths: [(label: String, path: String, risk: RiskLevel, detail: String)]
}

final class DiskScanner {
    private let manager = FileManager.default
    private let sizer = StorageSizer()
    private let home = NSHomeDirectory()
    private let largeFileThresholdBytes: Int64
    private var sizeCache: [String: Int64] = [:]
    private var inaccessible = Set<String>()

    init(largeFileThresholdMB: Int = 100) {
        self.largeFileThresholdBytes = Int64(largeFileThresholdMB) * 1_024 * 1_024
    }

    func scanAll() -> ScanResult {
        let startedAt = Date()
        var findings: [ScanFinding] = []

        let (apps, appFindings) = scanInstalledApps()
        findings.append(contentsOf: appFindings)
        findings.append(contentsOf: scanKnownAIToolData())
        findings.append(contentsOf: scanSkills())
        findings.append(contentsOf: scanModels())
        findings.append(contentsOf: scanComponents())
        findings.append(contentsOf: scanResidualProfiles(installedApps: apps))
        findings.append(contentsOf: scanGenericResiduals(installedApps: apps, existing: findings))
        findings.append(contentsOf: scanLargeModelAndComponentFiles())

        var unique: [String: ScanFinding] = [:]
        for finding in findings where finding.sizeBytes > 0 || finding.category == .installedApps {
            if let current = unique[finding.id] {
                if finding.sizeBytes > current.sizeBytes { unique[finding.id] = finding }
            } else {
                unique[finding.id] = finding
            }
        }

        let sorted = unique.values.sorted {
            if $0.category == $1.category { return $0.sizeBytes > $1.sizeBytes }
            return $0.category.rawValue < $1.category.rawValue
        }
        return ScanResult(
            findings: sorted,
            inaccessiblePaths: inaccessible.sorted(),
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    private func expanded(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func cachedSize(_ path: String) -> Int64 {
        if let value = sizeCache[path] { return value }
        let value = sizer.allocatedSize(at: URL(fileURLWithPath: path))
        sizeCache[path] = value
        return value
    }

    private func makeFinding(
        name: String,
        path: String,
        category: FindingCategory,
        risk: RiskLevel,
        reason: String,
        detail: String = "",
        canClean: Bool = true,
        isAggregate: Bool = false
    ) -> ScanFinding? {
        let resolved = expanded(path)
        guard manager.fileExists(atPath: resolved) else { return nil }
        let url = URL(fileURLWithPath: resolved)
        let metadata = sizer.metadata(at: url)
        let size = cachedSize(resolved)
        return ScanFinding(
            name: name,
            path: resolved,
            sizeBytes: size,
            category: category,
            risk: metadata.requiresAdmin ? .protected : risk,
            reason: reason,
            detail: detail,
            modifiedAt: metadata.modifiedAt,
            isDirectory: metadata.isDirectory,
            requiresAdmin: metadata.requiresAdmin,
            canClean: canClean,
            isAggregate: isAggregate
        )
    }

    private func scanInstalledApps() -> ([InstalledAppInfo], [ScanFinding]) {
        let roots = ["/Applications", "\(home)/Applications"]
        var apps: [InstalledAppInfo] = []
        var findings: [ScanFinding] = []

        for root in roots where manager.fileExists(atPath: root) {
            let rootURL = URL(fileURLWithPath: root)
            let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey]
            guard let enumerator = manager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles],
                errorHandler: { [weak self] url, _ in
                    self?.inaccessible.insert(url.path)
                    return true
                }
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "app" else { continue }
                enumerator.skipDescendants()
                let bundle = Bundle(url: url)
                let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let identifier = bundle?.bundleIdentifier ?? "未知标识"
                let version = (bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
                    ?? "未知版本"
                let app = InstalledAppInfo(
                    name: displayName,
                    path: url.path,
                    bundleIdentifier: identifier,
                    version: version
                )
                apps.append(app)
                if let finding = makeFinding(
                    name: displayName,
                    path: url.path,
                    category: .installedApps,
                    risk: .review,
                    reason: "已安装应用 \(version)",
                    detail: identifier
                ) {
                    findings.append(finding)
                }
            }
        }
        return (apps, findings)
    }

    private func scanKnownAIToolData() -> [ScanFinding] {
        let specs: [PathSpec] = [
            .init(name: "Codex 会话记录", path: "~/.codex/sessions", category: .aiTools, risk: .review, reason: "历史任务与对话", detail: "删除后无法在本机恢复任务历史"),
            .init(name: "Codex 已归档会话", path: "~/.codex/archived_sessions", category: .aiTools, risk: .review, reason: "已归档的任务记录", detail: "适合在确认不再需要历史任务后清理"),
            .init(name: "Codex 生成图片", path: "~/.codex/generated_images", category: .aiTools, risk: .review, reason: "AI 生成图片缓存", detail: "可能包含尚未另存的图片"),
            .init(name: "Codex 下载缓存", path: "~/.codex/cache", category: .aiTools, risk: .safe, reason: "可重新下载的缓存", detail: "后续使用时可能重新生成"),
            .init(name: "Codex 临时文件", path: "~/.codex/.tmp", category: .aiTools, risk: .safe, reason: "任务临时文件", detail: "建议在没有任务运行时清理"),
            .init(name: "Codex 浏览器缓存", path: "~/Library/Caches/Codex", category: .aiTools, risk: .safe, reason: "桌面应用浏览器缓存", detail: "关闭 Codex 后清理更稳妥"),
            .init(name: "Codex 应用数据", path: "~/Library/Application Support/Codex", category: .aiTools, risk: .review, reason: "桌面应用配置与组件", detail: "可能包含登录状态与本地配置"),
            .init(name: "Claude 配置与历史", path: "~/.claude", category: .aiTools, risk: .review, reason: "Claude 本地配置与任务数据", detail: "可能包含会话、项目配置与 MCP 设置"),
            .init(name: "Claude 桌面数据", path: "~/Library/Application Support/Claude", category: .aiTools, risk: .review, reason: "Claude Desktop 本地数据", detail: "可能包含登录状态与应用配置"),
            .init(name: "Claude 缓存", path: "~/Library/Caches/com.anthropic.claudefordesktop", category: .aiTools, risk: .safe, reason: "Claude Desktop 缓存", detail: "可重新生成"),
            .init(name: "Trae 用户数据", path: "~/.trae", category: .aiTools, risk: .review, reason: "Trae 配置与工作记录", detail: "可能包含扩展、项目索引和设置"),
            .init(name: "Trae 应用数据", path: "~/Library/Application Support/Trae", category: .aiTools, risk: .review, reason: "Trae 本地应用数据", detail: "可能包含扩展和用户设置"),
            .init(name: "Trae 缓存", path: "~/Library/Caches/Trae", category: .aiTools, risk: .safe, reason: "Trae 可再生缓存", detail: "清理后首次启动会重建"),
            .init(name: "WorkBuddy 应用数据", path: "~/Library/Application Support/WorkBuddy", category: .aiTools, risk: .review, reason: "WorkBuddy 本地数据", detail: "可能包含账号与项目数据"),
            .init(name: "WorkBuddy 迁移缓存", path: "~/Library/Caches/com.workbuddy.workbuddy.BundleMigration", category: .aiTools, risk: .safe, reason: "旧版本迁移与安装缓存", detail: "通常包含完整 App 副本和下载包"),
            .init(name: "CodeBuddy 扩展数据", path: "~/Library/Application Support/CodeBuddyExtension", category: .aiTools, risk: .review, reason: "CodeBuddy 扩展数据", detail: "删除可能重置扩展状态")
        ]

        return specs.compactMap {
            makeFinding(
                name: $0.name,
                path: $0.path,
                category: $0.category,
                risk: $0.risk,
                reason: $0.reason,
                detail: $0.detail
            )
        }
    }

    private func scanSkills() -> [ScanFinding] {
        var findings: [ScanFinding] = []
        let localSkills = expanded("~/.codex/skills")
        if let children = try? manager.contentsOfDirectory(
            at: URL(fileURLWithPath: localSkills),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if let finding = makeFinding(
                    name: child.lastPathComponent,
                    path: child.path,
                    category: .skills,
                    risk: .review,
                    reason: "本地 Skill",
                    detail: "删除后该 Skill 将不可用"
                ) {
                    findings.append(finding)
                }
            }
        }

        let systemSkills = "\(localSkills)/.system"
        if let children = try? manager.contentsOfDirectory(
            at: URL(fileURLWithPath: systemSkills),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if let finding = makeFinding(
                    name: "系统 · \(child.lastPathComponent)",
                    path: child.path,
                    category: .skills,
                    risk: .protected,
                    reason: "Codex 系统 Skill",
                    detail: "不建议手动删除，更新可能重新安装"
                ) {
                    findings.append(finding)
                }
            }
        }

        let pluginCache = expanded("~/.codex/plugins/cache")
        if let vendors = try? manager.contentsOfDirectory(
            at: URL(fileURLWithPath: pluginCache),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for vendor in vendors {
                guard let plugins = try? manager.contentsOfDirectory(
                    at: vendor,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for plugin in plugins {
                    guard let versions = try? manager.contentsOfDirectory(
                        at: plugin,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    ), !versions.isEmpty else { continue }
                    for version in versions {
                        if let finding = makeFinding(
                            name: "\(plugin.lastPathComponent) · \(version.lastPathComponent)",
                            path: version.path,
                            category: .skills,
                            risk: .safe,
                            reason: "\(vendor.lastPathComponent) 插件缓存",
                            detail: "插件需要时可能重新下载"
                        ) {
                            findings.append(finding)
                        }
                    }
                }
            }
        }

        let claudeSkills = expanded("~/.claude/skills")
        if let children = try? manager.contentsOfDirectory(
            at: URL(fileURLWithPath: claudeSkills),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in children {
                if let finding = makeFinding(
                    name: "Claude · \(child.lastPathComponent)",
                    path: child.path,
                    category: .skills,
                    risk: .review,
                    reason: "Claude Skill",
                    detail: "删除后 Claude 将无法使用该 Skill"
                ) {
                    findings.append(finding)
                }
            }
        }
        return findings
    }

    private func scanModels() -> [ScanFinding] {
        var findings: [ScanFinding] = []
        let hfHub = expanded("~/.cache/huggingface/hub")
        if let children = try? manager.contentsOfDirectory(
            at: URL(fileURLWithPath: hfHub),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in children where child.lastPathComponent.hasPrefix("models--") {
                let modelName = child.lastPathComponent
                    .replacingOccurrences(of: "models--", with: "")
                    .replacingOccurrences(of: "--", with: "/")
                if let finding = makeFinding(
                    name: modelName,
                    path: child.path,
                    category: .models,
                    risk: .safe,
                    reason: "Hugging Face 模型权重",
                    detail: "删除后，下次使用会重新下载"
                ) {
                    findings.append(finding)
                }
            }
        }

        let modelRoots: [PathSpec] = [
            .init(name: "Ollama 模型", path: "~/.ollama/models", category: .models, risk: .safe, reason: "Ollama 本地模型", detail: "删除后对应本地模型不可用"),
            .init(name: "LM Studio 模型", path: "~/.cache/lm-studio/models", category: .models, risk: .safe, reason: "LM Studio 本地模型", detail: "可在 LM Studio 中重新下载"),
            .init(name: "LM Studio 应用模型", path: "~/Library/Application Support/LM Studio/models", category: .models, risk: .safe, reason: "LM Studio 模型库", detail: "删除后对应本地模型不可用"),
            .init(name: "ModelScope 模型", path: "~/.cache/modelscope", category: .models, risk: .safe, reason: "ModelScope 模型缓存", detail: "需要时会重新下载"),
            .init(name: "Whisper 模型", path: "~/.cache/whisper", category: .models, risk: .safe, reason: "Whisper 语音模型", detail: "需要时会重新下载"),
            .init(name: "Torch Hub 模型", path: "~/.cache/torch", category: .models, risk: .safe, reason: "PyTorch 模型缓存", detail: "需要时会重新下载"),
            .init(name: "MLX 模型", path: "~/.cache/mlx", category: .models, risk: .safe, reason: "Apple MLX 模型缓存", detail: "删除后对应本地模型不可用"),
            .init(name: "ComfyUI 模型", path: "~/ComfyUI/models", category: .models, risk: .review, reason: "ComfyUI 模型库", detail: "可能包含手动下载的模型")
        ]
        findings.append(contentsOf: modelRoots.compactMap {
            makeFinding(
                name: $0.name,
                path: $0.path,
                category: $0.category,
                risk: $0.risk,
                reason: $0.reason,
                detail: $0.detail
            )
        })
        return findings
    }

    private func scanComponents() -> [ScanFinding] {
        let specs: [PathSpec] = [
            .init(name: "Codex 原生运行时", path: "~/.cache/codex-runtimes", category: .components, risk: .protected, reason: "Codex 自带 Python、Node 与原生依赖", detail: "删除可能导致当前功能失效或触发重新下载"),
            .init(name: "Manim 共享环境", path: "~/.codex-manim-envs", category: .components, risk: .review, reason: "Manim、FFmpeg 与科学计算依赖", detail: "删除后视频与数学动画功能需要重建"),
            .init(name: "Python 用户组件", path: "~/Library/Python", category: .components, risk: .review, reason: "用户级 Python 包", detail: "可能被多个项目共同使用"),
            .init(name: "Pip 下载缓存", path: "~/Library/Caches/pip", category: .components, risk: .safe, reason: "Python 安装包缓存", detail: "可重新下载"),
            .init(name: "pnpm 下载缓存", path: "~/Library/Caches/pnpm", category: .components, risk: .safe, reason: "Node.js 包缓存", detail: "可重新下载"),
            .init(name: "npm 下载缓存", path: "~/.npm", category: .components, risk: .safe, reason: "Node.js 包缓存", detail: "可重新下载"),
            .init(name: "uv 下载缓存", path: "~/.cache/uv", category: .components, risk: .safe, reason: "Python uv 包缓存", detail: "可重新下载"),
            .init(name: "Playwright 浏览器", path: "~/Library/Caches/ms-playwright", category: .components, risk: .safe, reason: "Chromium、Firefox 与 FFmpeg", detail: "自动化测试时会重新下载"),
            .init(name: "FFmpeg Node 缓存", path: "~/Library/Caches/ffmpeg-static-nodejs", category: .components, risk: .safe, reason: "Node.js FFmpeg 下载缓存", detail: "需要时会重新下载"),
            .init(name: "Homebrew 下载缓存", path: "~/Library/Caches/Homebrew", category: .components, risk: .safe, reason: "Homebrew 安装包缓存", detail: "不影响已安装的软件"),
            .init(name: "Mamba/Conda 缓存", path: "~/.cache/mamba", category: .components, risk: .safe, reason: "Conda 包缓存", detail: "环境本体不会受影响")
        ]
        return specs.compactMap {
            makeFinding(
                name: $0.name,
                path: $0.path,
                category: $0.category,
                risk: $0.risk,
                reason: $0.reason,
                detail: $0.detail
            )
        }
    }

    private func scanResidualProfiles(installedApps: [InstalledAppInfo]) -> [ScanFinding] {
        let profiles: [ResidualProfile] = [
            .init(
                name: "WorkBuddy",
                appAliases: ["workbuddy"],
                bundleIdentifiers: ["com.workbuddy.workbuddy"],
                paths: [
                    ("WorkBuddy 迁移缓存", "~/Library/Caches/com.workbuddy.workbuddy.BundleMigration", .safe, "完整 App 副本、升级包或迁移文件"),
                    ("WorkBuddy 应用数据", "~/Library/Application Support/WorkBuddy", .review, "可能含项目和账号数据"),
                    ("WorkBuddy 日志", "~/Library/Logs/WorkBuddy", .safe, "历史运行日志")
                ]
            ),
            .init(
                name: "飞书",
                appAliases: ["lark", "feishu", "飞书"],
                bundleIdentifiers: ["com.electron.lark"],
                paths: [
                    ("飞书应用数据", "~/Library/Application Support/LarkShell", .review, "可能含消息数据库、资源和账号状态"),
                    ("飞书缓存", "~/Library/Caches/LarkShell", .safe, "可重新生成的资源缓存"),
                    ("飞书辅助缓存", "~/Library/Caches/com.electron.lark.helper", .safe, "辅助进程缓存")
                ]
            ),
            .init(
                name: "Google Chrome",
                appAliases: ["google chrome"],
                bundleIdentifiers: ["com.google.Chrome"],
                paths: [
                    ("Chrome 用户数据", "~/Library/Application Support/Google/Chrome", .review, "可能含书签、浏览记录、扩展与登录配置"),
                    ("Chrome 缓存", "~/Library/Caches/Google/Chrome", .safe, "浏览器可再生缓存"),
                    ("Chrome 更新缓存", "~/Library/Caches/com.google.SoftwareUpdate", .safe, "Google 更新安装包")
                ]
            ),
            .init(
                name: "腾讯会议",
                appAliases: ["tencent meeting", "voov", "腾讯会议"],
                bundleIdentifiers: ["com.tencent.meeting"],
                paths: [
                    ("腾讯会议沙盒", "~/Library/Containers/com.tencent.meeting", .review, "可能含会议资料与配置"),
                    ("腾讯会议缓存", "~/Library/Caches/com.tencent.meeting", .safe, "可再生缓存"),
                    ("腾讯会议系统组件", "/Library/Application Support/Tencent/Meeting", .protected, "可能需要管理员权限")
                ]
            ),
            .init(
                name: "Microsoft Office",
                appAliases: ["microsoft word", "microsoft excel", "microsoft powerpoint", "microsoft outlook", "microsoft onenote"],
                bundleIdentifiers: ["com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint", "com.microsoft.Outlook"],
                paths: [
                    ("Office 共享容器", "~/Library/Group Containers/UBF8T346G9.Office", .review, "模板、自定义词典、许可和字体缓存"),
                    ("Word 沙盒", "~/Library/Containers/com.microsoft.Word", .review, "Word 本地数据"),
                    ("Excel 沙盒", "~/Library/Containers/com.microsoft.Excel", .review, "Excel 本地数据"),
                    ("PowerPoint 沙盒", "~/Library/Containers/com.microsoft.Powerpoint", .review, "PowerPoint 本地数据"),
                    ("Teams 更新器", "/Library/Application Support/Microsoft/TeamsUpdaterDaemon", .protected, "卸载后残留的更新包")
                ]
            ),
            .init(
                name: "百度网盘",
                appAliases: ["baidunetdisk", "百度网盘"],
                bundleIdentifiers: ["com.baidu.BaiduNetdisk-mac"],
                paths: [
                    ("百度网盘应用数据", "~/Library/Application Support/baidunetdisk", .review, "可能含登录与下载任务记录"),
                    ("百度网盘旧版数据", "~/Library/Application Support/com.baidu.BaiduNetdisk-mac", .review, "旧版配置与临时文件"),
                    ("百度网盘启动项", "~/Library/LaunchAgents/netdisk_service.plist", .safe, "可能指向已经不存在的程序")
                ]
            ),
            .init(
                name: "Zoom",
                appAliases: ["zoom"],
                bundleIdentifiers: ["us.zoom.xos"],
                paths: [
                    ("Zoom 缓存", "~/Library/Caches/us.zoom.xos", .safe, "可再生缓存"),
                    ("Zoom 系统守护程序", "/Library/PrivilegedHelperTools/us.zoom.ZoomDaemon", .protected, "卸载残留的特权辅助工具"),
                    ("Zoom 启动配置", "/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist", .protected, "卸载残留的系统服务")
                ]
            ),
            .init(
                name: "OrcaTerm",
                appAliases: ["orcaterm"],
                bundleIdentifiers: ["com.orcaterm.app"],
                paths: [
                    ("OrcaTerm 缓存", "~/Library/Caches/com.orcaterm.app", .safe, "终端网页缓存"),
                    ("OrcaTerm WebKit 数据", "~/Library/WebKit/com.orcaterm.app", .safe, "可再生网页数据")
                ]
            ),
            .init(
                name: "HP Smart",
                appAliases: ["hp smart"],
                bundleIdentifiers: ["com.hp.SmartMac"],
                paths: [
                    ("HP Smart 沙盒", "~/Library/Containers/com.hp.SmartMac", .review, "打印机配置和本地数据"),
                    ("HP 打印监控", "~/Library/Containers/com.hp.PSDrMonitor", .review, "打印机监控数据")
                ]
            ),
            .init(
                name: "Adobe Creative Cloud",
                appAliases: ["adobe creative cloud", "adobe photoshop", "adobe illustrator", "adobe premiere", "adobe after effects"],
                bundleIdentifiers: ["com.adobe.acc.AdobeCreativeCloud"],
                paths: [
                    ("Adobe 公共组件", "/Library/Application Support/Adobe", .protected, "桌面组件、安装数据库和 IPC 资源"),
                    ("Adobe 安装器", "/Library/PrivilegedHelperTools/com.adobe.acc.installer.v2", .protected, "特权安装辅助工具"),
                    ("Adobe 启动服务", "/Library/LaunchDaemons/com.adobe.acc.installer.v2.plist", .protected, "系统级安装服务")
                ]
            )
        ]

        var findings: [ScanFinding] = []
        for profile in profiles where !isProfileInstalled(profile, apps: installedApps) {
            for item in profile.paths {
                if let finding = makeFinding(
                    name: item.label,
                    path: item.path,
                    category: .residuals,
                    risk: item.risk,
                    reason: "\(profile.name) 主程序未找到",
                    detail: item.detail
                ) {
                    findings.append(finding)
                }
            }
        }
        return findings
    }

    private func isProfileInstalled(_ profile: ResidualProfile, apps: [InstalledAppInfo]) -> Bool {
        let aliases = profile.appAliases.map { $0.lowercased() }
        let identifiers = Set(profile.bundleIdentifiers.map { $0.lowercased() })
        return apps.contains { app in
            let name = app.name.lowercased()
            let identifier = app.bundleIdentifier.lowercased()
            return aliases.contains(where: { name.contains($0) })
                || identifiers.contains(identifier)
        }
    }

    private func scanGenericResiduals(
        installedApps: [InstalledAppInfo],
        existing: [ScanFinding]
    ) -> [ScanFinding] {
        let roots = [
            ("~/Library/Caches", RiskLevel.safe, "未匹配到现存 App 的缓存目录"),
            ("~/Library/Application Support", RiskLevel.review, "未匹配到现存 App 的应用数据"),
            ("~/Library/Containers", RiskLevel.review, "未匹配到现存 App 的沙盒容器"),
            ("~/Library/Group Containers", RiskLevel.review, "未匹配到现存 App 的共享容器"),
            ("~/Library/WebKit", RiskLevel.safe, "未匹配到现存 App 的 WebKit 数据")
        ]
        let existingPaths = Set(existing.map(\.path))
        let activeTokens = installedApplicationTokens(installedApps)
            .union(["apple", "openai", "codex", "sogou", "xinwechat", "clash"])
        var findings: [ScanFinding] = []

        for (rootPath, risk, reason) in roots {
            let resolvedRoot = expanded(rootPath)
            guard let children = try? manager.contentsOfDirectory(
                at: URL(fileURLWithPath: resolvedRoot),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                guard !existingPaths.contains(child.path) else { continue }
                let name = child.lastPathComponent
                if name.hasPrefix("com.apple.") || name.hasPrefix("group.com.apple.") { continue }
                let tokens = normalizedTokens(name)
                if !tokens.isDisjoint(with: activeTokens) { continue }
                let size = cachedSize(child.path)
                guard size >= 5 * 1_024 * 1_024 else { continue }
                let metadata = sizer.metadata(at: child)
                findings.append(ScanFinding(
                    name: name,
                    path: child.path,
                    sizeBytes: size,
                    category: .residuals,
                    risk: metadata.requiresAdmin ? .protected : risk,
                    reason: reason,
                    detail: "通用规则识别，建议在删除前打开目录确认内容",
                    modifiedAt: metadata.modifiedAt,
                    isDirectory: metadata.isDirectory,
                    requiresAdmin: metadata.requiresAdmin,
                    canClean: true,
                    isAggregate: false
                ))
            }
        }
        return findings
    }

    private func installedApplicationTokens(_ apps: [InstalledAppInfo]) -> Set<String> {
        var result = Set<String>()
        for app in apps {
            result.formUnion(normalizedTokens(app.name))
            result.formUnion(normalizedTokens(app.bundleIdentifier))
        }
        return result
    }

    private func normalizedTokens(_ value: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        let ignored: Set<String> = [
            "com", "org", "net", "app", "mac", "desktop", "helper", "service",
            "application", "support", "cache", "caches", "group"
        ]
        return Set(
            value.lowercased()
                .components(separatedBy: separators)
                .filter { $0.count >= 4 && !ignored.contains($0) }
        )
    }

    private func scanLargeModelAndComponentFiles() -> [ScanFinding] {
        let roots = [
            expanded("~/.cache/huggingface"),
            expanded("~/.ollama"),
            expanded("~/.cache/lm-studio"),
            expanded("~/Library/Application Support/LM Studio"),
            expanded("~/Library/Caches/ffmpeg-static-nodejs"),
            expanded("~/Downloads")
        ]
        let extensions: Set<String> = [
            "safetensors", "gguf", "ckpt", "pth", "pt", "onnx", "tflite",
            "mlmodel", "engine", "bin", "dylib", "so", "zip", "body"
        ]
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey
        ]
        var findings: [ScanFinding] = []
        var seen = Set<String>()

        for root in roots where manager.fileExists(atPath: root) {
            guard let enumerator = manager.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: keys,
                options: [],
                errorHandler: { [weak self] url, _ in
                    self?.inaccessible.insert(url.path)
                    return true
                }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard findings.count < 300 else { break }
                guard !seen.contains(fileURL.path) else { continue }
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true else { continue }
                let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                guard size >= largeFileThresholdBytes else { continue }
                let ext = fileURL.pathExtension.lowercased()
                let hasKnownExtension = extensions.contains(ext)
                let isModelBlob = fileURL.path.contains("/huggingface/")
                    || fileURL.path.contains("/.ollama/")
                    || fileURL.path.contains("/models/")
                guard hasKnownExtension || isModelBlob else { continue }
                seen.insert(fileURL.path)
                findings.append(ScanFinding(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    sizeBytes: size,
                    category: .largeFiles,
                    risk: .review,
                    reason: isModelBlob ? "大型模型或权重文件" : "大型第三方组件或下载文件",
                    detail: "这是单个文件；删除前请确认没有项目正在引用",
                    modifiedAt: values.contentModificationDate,
                    isDirectory: false,
                    requiresAdmin: false,
                    canClean: true,
                    isAggregate: false
                ))
            }
        }
        return findings
    }
}
