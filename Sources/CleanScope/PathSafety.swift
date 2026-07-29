import Foundation

enum PathSafetyError: LocalizedError {
    case missing
    case unsafeRoot
    case outsideAllowedRoots
    case aggregate

    var errorDescription: String? {
        switch self {
        case .missing: return "目标已经不存在"
        case .unsafeRoot: return "安全策略禁止删除根目录或关键系统目录"
        case .outsideAllowedRoots: return "目标不在允许清理的目录中"
        case .aggregate: return "汇总条目不能直接清理，请选择其子项"
        }
    }
}

struct PathSafety {
    private let manager = FileManager.default

    func validate(_ finding: ScanFinding) throws -> URL {
        guard finding.canClean, !finding.isAggregate else { throw PathSafetyError.aggregate }
        let url = URL(fileURLWithPath: finding.path).standardizedFileURL
        guard manager.fileExists(atPath: url.path) else { throw PathSafetyError.missing }

        let forbidden = [
            "/",
            "/Applications",
            "/Library",
            "/System",
            "/Users",
            NSHomeDirectory(),
            NSHomeDirectory() + "/Library",
            NSHomeDirectory() + "/Documents"
        ]
        guard !forbidden.contains(url.path) else { throw PathSafetyError.unsafeRoot }

        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path + "/"
        let allowedSystemPrefixes = [
            "/Applications/",
            "/Library/Application Support/",
            "/Library/Caches/",
            "/Library/LaunchAgents/",
            "/Library/LaunchDaemons/",
            "/Library/PrivilegedHelperTools/"
        ]
        let allowed = url.path.hasPrefix(home)
            || allowedSystemPrefixes.contains(where: { url.path.hasPrefix($0) })
        guard allowed else { throw PathSafetyError.outsideAllowedRoots }
        return url
    }
}
