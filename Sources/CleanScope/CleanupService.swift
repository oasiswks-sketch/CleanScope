import AppKit
import Foundation

struct CleanupService {
    private let manager = FileManager.default
    private let safety = PathSafety()

    func clean(_ findings: [ScanFinding], mode: CleanupMode) -> CleanupReport {
        var succeeded: [ScanFinding] = []
        var failed: [(finding: ScanFinding, error: String)] = []
        var validatedAdmin: [(finding: ScanFinding, url: URL)] = []

        for finding in findings {
            do {
                let url = try safety.validate(finding)
                if finding.requiresAdmin {
                    guard mode == .permanent else {
                        failed.append((finding, "系统受保护项目不能移到用户废纸篓，请使用“永久删除”"))
                        continue
                    }
                    validatedAdmin.append((finding, url))
                    continue
                }

                unloadUserLaunchAgentIfNeeded(url)
                switch mode {
                case .trash:
                    var resultingURL: NSURL?
                    try manager.trashItem(at: url, resultingItemURL: &resultingURL)
                case .permanent:
                    try manager.removeItem(at: url)
                }
                succeeded.append(finding)
            } catch {
                failed.append((finding, error.localizedDescription))
            }
        }

        if !validatedAdmin.isEmpty {
            do {
                try removeWithAdministratorPrivileges(validatedAdmin.map(\.url))
                succeeded.append(contentsOf: validatedAdmin.map(\.finding))
            } catch {
                for item in validatedAdmin {
                    failed.append((item.finding, error.localizedDescription))
                }
            }
        }

        return CleanupReport(succeeded: succeeded, failed: failed)
    }

    private func unloadUserLaunchAgentIfNeeded(_ url: URL) {
        guard url.path.contains("/Library/LaunchAgents/"),
              url.pathExtension == "plist" else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = [
            "bootout",
            "gui/\(getuid())",
            url.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func removeWithAdministratorPrivileges(_ urls: [URL]) throws {
        var commandParts: [String] = []
        for url in urls where url.path.contains("/Library/LaunchDaemons/") && url.pathExtension == "plist" {
            commandParts.append(
                "/bin/launchctl bootout system \(shellQuote(url.path)) >/dev/null 2>&1 || true"
            )
        }
        let paths = urls.map { shellQuote($0.path) }.joined(separator: " ")
        commandParts.append("/bin/rm -r -- \(paths)")
        let shellCommand = commandParts.joined(separator: "; ")
        let appleScriptCommand = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(appleScriptCommand)\" with administrator privileges"

        let process = Process()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CleanScope.AdminRemoval",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: message?.isEmpty == false
                        ? message!
                        : "管理员认证取消或系统删除失败"
                ]
            )
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
