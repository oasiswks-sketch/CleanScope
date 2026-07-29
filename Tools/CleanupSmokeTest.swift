import Foundation

@main
struct CleanupSmokeTest {
    static func main() throws {
        let manager = FileManager.default
        let fixture = URL(
            fileURLWithPath: "/Users/panwei/Documents/Codex/2026-07-28/a/work/CleanScope/.build/cleanup-smoke-fixture",
            isDirectory: true
        )

        if manager.fileExists(atPath: fixture.path) {
            try manager.removeItem(at: fixture)
        }
        try manager.createDirectory(at: fixture, withIntermediateDirectories: true)
        try Data("CleanScope cleanup smoke test".utf8)
            .write(to: fixture.appendingPathComponent("sample.txt"))

        let finding = ScanFinding(
            name: "清理测试",
            path: fixture.path,
            sizeBytes: 29,
            category: .components,
            risk: .safe,
            reason: "验证清理服务",
            detail: "只作用于 CleanScope 构建目录中的临时测试文件"
        )
        let report = CleanupService().clean([finding], mode: .permanent)

        guard report.succeeded.count == 1,
              report.failed.isEmpty,
              !manager.fileExists(atPath: fixture.path) else {
            let errors = report.failed.map(\.error).joined(separator: "; ")
            throw NSError(
                domain: "CleanScope.CleanupSmokeTest",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: errors.isEmpty ? "清理验证失败" : errors]
            )
        }

        print("cleanup smoke test passed")
    }
}
