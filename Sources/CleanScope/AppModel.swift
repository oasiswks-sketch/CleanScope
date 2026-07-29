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
    @Published var cleanupHistory: [CleanupHistoryEntry] = []
    @Published var excludedPaths = Set<String>()
    @Published var licenseState: LicenseState = .free
    @Published var showsUpgrade = false
    @Published var licenseMessage: String?

    private var scanTask: Task<Void, Never>?
    private let commercialStore = CommercialStore()
    private let licenseManager = LicenseManager()

    init() {
        cleanupHistory = commercialStore.loadHistory()
        excludedPaths = commercialStore.loadExclusions()
        licenseState = licenseManager.restoredState()
        switch ProcessInfo.processInfo.environment["CLEANSCOPE_SCREEN"] {
        case "smartPlan":
            sidebarSelection = .smartPlan
        case "activity":
            sidebarSelection = .activity
        default:
            break
        }
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
                case .overview, .smartPlan, .activity:
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

    var isPro: Bool {
        licenseState.isPro
    }

    var totalReclaimedBytes: Int64 {
        cleanupHistory.reduce(0) { $0 + $1.bytes }
    }

    var totalReclaimedText: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimedBytes, countStyle: .file)
    }

    var smartPlanFindings: [ScanFinding] {
        findings
            .filter {
                $0.risk == .safe
                    && $0.canClean
                    && !$0.isAggregate
                    && !excludedPaths.contains($0.path)
            }
            .sorted { lhs, rhs in
                let leftAge = lhs.modifiedAt ?? .distantFuture
                let rightAge = rhs.modifiedAt ?? .distantFuture
                if leftAge != rightAge { return leftAge < rightAge }
                return lhs.sizeBytes > rhs.sizeBytes
            }
    }

    var smartPlanSizeBytes: Int64 {
        smartPlanFindings.reduce(0) { $0 + $1.sizeBytes }
    }

    var smartPlanSizeText: String {
        ByteCountFormatter.string(fromByteCount: smartPlanSizeBytes, countStyle: .file)
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
            if !isPro && selectedIDs.count >= 3 {
                showsUpgrade = true
                return
            }
            selectedIDs.insert(finding.id)
        }
    }

    func selectSafeItems() {
        guard isPro else {
            showsUpgrade = true
            return
        }
        selectedIDs = Set(
            filteredFindings
                .filter {
                    $0.risk == .safe
                        && $0.canClean
                        && !$0.isAggregate
                        && !excludedPaths.contains($0.path)
                }
                .map(\.id)
        )
    }

    func applySmartPlan() {
        guard isPro else {
            showsUpgrade = true
            return
        }
        selectedIDs = Set(smartPlanFindings.map(\.id))
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
            if !report.succeeded.isEmpty {
                cleanupHistory.insert(
                    CleanupHistoryEntry(
                        id: UUID(),
                        date: Date(),
                        bytes: report.reclaimedBytes,
                        itemCount: report.succeeded.count,
                        mode: mode == .trash ? "移入废纸篓" : "永久删除"
                    ),
                    at: 0
                )
                cleanupHistory = Array(cleanupHistory.prefix(100))
                commercialStore.saveHistory(cleanupHistory)
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

    func toggleExclusion(_ finding: ScanFinding) {
        guard isPro else {
            showsUpgrade = true
            return
        }
        if excludedPaths.contains(finding.path) {
            excludedPaths.remove(finding.path)
        } else {
            excludedPaths.insert(finding.path)
            selectedIDs.remove(finding.id)
        }
        commercialStore.saveExclusions(excludedPaths)
    }

    func activateLicense(_ value: String) {
        do {
            let payload = try licenseManager.activate(value)
            licenseState = .pro(payload)
            licenseMessage = "CleanScope Pro 已激活。"
        } catch {
            licenseMessage = error.localizedDescription
        }
    }

    func deactivateLicense() {
        licenseManager.deactivate()
        licenseState = .free
        licenseMessage = "许可证已从这台 Mac 移除。"
    }
}
