import AppKit
import Foundation

@MainActor
enum SnapshotSupport {
    static func captureIfRequested() {
        guard let destination = ProcessInfo.processInfo.environment["CLEANSCOPE_SNAPSHOT"],
              !destination.isEmpty else { return }
        let delay = Double(
            ProcessInfo.processInfo.environment["CLEANSCOPE_SNAPSHOT_DELAY"] ?? "8"
        ) ?? 8

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let window = NSApp.windows.first(where: { $0.contentView != nil }),
                  let view = window.contentView,
                  view.bounds.width > 0,
                  view.bounds.height > 0,
                  let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                return
            }

            view.cacheDisplay(in: view.bounds, to: representation)
            guard let data = representation.representation(using: .png, properties: [:]) else {
                return
            }
            try? data.write(to: URL(fileURLWithPath: destination))
        }
    }

    static func writeScanReportIfRequested(_ result: ScanResult) {
        guard let destination = ProcessInfo.processInfo.environment["CLEANSCOPE_SCAN_REPORT"],
              !destination.isEmpty else { return }

        let items: [[String: Any]] = result.findings.map { finding in
            [
                "name": finding.name,
                "path": finding.path,
                "category": finding.category.rawValue,
                "risk": finding.risk.rawValue,
                "sizeBytes": finding.sizeBytes,
                "requiresAdmin": finding.requiresAdmin
            ]
        }
        let payload: [String: Any] = [
            "durationSeconds": result.duration,
            "findingCount": result.findings.count,
            "inaccessibleCount": result.inaccessiblePaths.count,
            "findings": items
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
              ) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: destination))
    }
}
