import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var findings: [ScanFinding] = []
    @Published var sidebarSelection: SidebarSelection? = .overview
    @Published var selectedIDs = Set<String>()
    @Published var focusedID: String?
    @Published var query = ""
    @Published var riskFilter: RiskLevel?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanStatus = "尚未扫描"
    @Published var lastScanAt: Date?
    @Published var inaccessiblePaths: [String] = []
    @Published var cleanupMessage: String?
    @Published var cleanupHadFailures = false
    @Published var largeFileThresholdMB = 100

    private var scanTask: Task<Void, Never>?

    init() {
        startScan()
    }

    deinit {
        scanTask?.cancel()
    }

    var filteredFindings: [ScanFinding] {
        let selection = sidebarSelection ?? .overview
        return findings
            .filter { finding in
                switch selection {
                case .overview:
                    return true
                case .category(let category):
                    return finding.category == category
                }
            }
            .filter { finding in
                guard !query.isEmpty else { return true }
                let needle = query.lowercased()
                return finding.name.lowercased().contains(needle)
                    || finding.path.lowercased().contains(needle)
                    || finding.reason.lowercased().contains(needle)
            }
            .filter { finding in
                guard let riskFilter else { return true }
                return finding.risk == riskFilter
            }
            .sorted {
                if $0.sizeBytes == $1.sizeBytes { return $0.name < $1.name }
                return $0.sizeBytes > $1.sizeBytes
            }
    }

    var focusedFinding: ScanFinding? {
        guard let focusedID else { return nil }
        return findings.first(where: { $0.id == focusedID })
    }

    var selectedFindings: [ScanFinding] {
        findings.filter { selectedIDs.contains($0.id) && $0.canClean }
    }

    var selectedSizeBytes: Int64 {
        selectedFindings.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedSizeText: String {
        ByteCountFormatter.string(fromByteCount: selectedSizeBytes, countStyle: .file)
    }

    var totalIndexedBytes: Int64 {
        findings
            .filter { !$0.isAggregate && $0.category != .largeFiles }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var totalIndexedText: String {
        ByteCountFormatter.string(fromByteCount: totalIndexedBytes, countStyle: .file)
    }

    var safeBytes: Int64 {
        findings
            .filter { $0.risk == .safe && $0.canClean }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var safeBytesText: String {
        ByteCountFormatter.string(fromByteCount: safeBytes, countStyle: .file)
    }

    var summaries: [CategorySummary] {
        FindingCategory.allCases.map { category in
            let items = findings.filter { $0.category == category }
            return CategorySummary(
                category: category,
                count: items.count,
                sizeBytes: items.reduce(0) { $0 + $1.sizeBytes }
            )
        }
    }

    func startScan() {
        scanTask?.cancel()
        isScanning = true
        scanStatus = "正在建立软件与文件索引…"
        selectedIDs.removeAll()
        focusedID = nil

        scanTask = Task {
            let threshold = largeFileThresholdMB
            let result = await Task.detached(priority: .userInitiated) {
                DiskScanner(largeFileThresholdMB: threshold).scanAll()
            }.value
            guard !Task.isCancelled else { return }
            SnapshotSupport.writeScanReportIfRequested(result)
            findings = result.findings
            inaccessiblePaths = result.inaccessiblePaths
            lastScanAt = Date()
            scanStatus = String(
                format: "完成 · %d 项 · %.1f 秒",
                result.findings.count,
                result.duration
            )
            isScanning = false
            if focusedID == nil {
                focusedID = filteredFindings.first?.id
            }
        }
    }

    func toggleSelection(_ finding: ScanFinding) {
        guard finding.canClean else { return }
        if selectedIDs.contains(finding.id) {
            selectedIDs.remove(finding.id)
        } else {
            selectedIDs.insert(finding.id)
        }
    }

    func selectSafeItems() {
        selectedIDs = Set(
            filteredFindings
                .filter { $0.risk == .safe && $0.canClean && !$0.isAggregate }
                .map(\.id)
        )
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func performCleanup(mode: CleanupMode) {
        let targets = selectedFindings
        guard !targets.isEmpty else { return }
        isCleaning = true
        scanStatus = mode == .trash ? "正在移到废纸篓…" : "正在永久删除…"

        Task {
            let report = await Task.detached(priority: .userInitiated) {
                CleanupService().clean(targets, mode: mode)
            }.value

            let succeededIDs = Set(report.succeeded.map(\.id))
            findings.removeAll { succeededIDs.contains($0.id) }
            selectedIDs.subtract(succeededIDs)
            if let focusedID, succeededIDs.contains(focusedID) {
                self.focusedID = filteredFindings.first?.id
            }

            let reclaimed = ByteCountFormatter.string(
                fromByteCount: report.reclaimedBytes,
                countStyle: .file
            )
            if report.failed.isEmpty {
                cleanupMessage = "已处理 \(report.succeeded.count) 项，释放约 \(reclaimed)。"
                cleanupHadFailures = false
            } else {
                let firstErrors = report.failed.prefix(3)
                    .map { "\($0.finding.name)：\($0.error)" }
                    .joined(separator: "\n")
                cleanupMessage = "成功 \(report.succeeded.count) 项，失败 \(report.failed.count) 项。\n\(firstErrors)"
                cleanupHadFailures = true
            }
            scanStatus = "清理完成"
            isCleaning = false
        }
    }

    func reveal(_ finding: ScanFinding) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: finding.path)])
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
