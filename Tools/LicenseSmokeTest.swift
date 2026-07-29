import Foundation

@main
struct LicenseSmokeTest {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(
                domain: "LicenseSmokeTest",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "需要许可证文件路径"]
            )
        }
        let value = try String(
            contentsOfFile: CommandLine.arguments[1],
            encoding: .utf8
        )
        let manager = LicenseManager()
        let payload = try manager.activate(value)
        manager.deactivate()
        print("LICENSE_OK \(payload.email) \(payload.plan) seats=\(payload.seats)")
    }
}
