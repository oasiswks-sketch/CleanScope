import Foundation
import SwiftUI

enum FindingCategory: String, CaseIterable, Identifiable, Codable {
    case installedApps
    case residuals
    case aiTools
    case skills
    case models
    case components
    case largeFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installedApps: return "已安装软件"
        case .residuals: return "卸载残留"
        case .aiTools: return "AI 工具数据"
        case .skills: return "Skills 与插件"
        case .models: return "模型权重"
        case .components: return "第三方组件"
        case .largeFiles: return "大文件"
        }
    }

    var shortTitle: String {
        switch self {
        case .installedApps: return "软件"
        case .residuals: return "残留"
        case .aiTools: return "AI 数据"
        case .skills: return "Skills"
        case .models: return "模型"
        case .components: return "组件"
        case .largeFiles: return "大文件"
        }
    }

    var symbol: String {
        switch self {
        case .installedApps: return "square.grid.2x2"
        case .residuals: return "app.badge.checkmark"
        case .aiTools: return "sparkles.rectangle.stack"
        case .skills: return "puzzlepiece.extension"
        case .models: return "brain.head.profile"
        case .components: return "shippingbox"
        case .largeFiles: return "externaldrive.fill.badge.exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .installedApps: return Color(hex: 0x87A8FF)
        case .residuals: return Color(hex: 0xFF9D6C)
        case .aiTools: return Color(hex: 0x9B8CFF)
        case .skills: return Color(hex: 0xF4C95D)
        case .models: return Color(hex: 0x64D9B7)
        case .components: return Color(hex: 0x72C7F4)
        case .largeFiles: return Color(hex: 0xF0788C)
        }
    }
}

enum RiskLevel: String, CaseIterable, Codable, Comparable {
    case safe
    case review
    case protected

    var title: String {
        switch self {
        case .safe: return "可重新生成"
        case .review: return "删除前确认"
        case .protected: return "受保护"
        }
    }

    var symbol: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .review: return "exclamationmark.triangle.fill"
        case .protected: return "lock.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe: return Color(hex: 0x58C79A)
        case .review: return Color(hex: 0xE9A84C)
        case .protected: return Color(hex: 0xE66A77)
        }
    }

    private var rank: Int {
        switch self {
        case .safe: return 0
        case .review: return 1
        case .protected: return 2
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct ScanFinding: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let sizeBytes: Int64
    let category: FindingCategory
    let risk: RiskLevel
    let reason: String
    let detail: String
    let modifiedAt: Date?
    let isDirectory: Bool
    let requiresAdmin: Bool
    let canClean: Bool
    let isAggregate: Bool

    init(
        name: String,
        path: String,
        sizeBytes: Int64,
        category: FindingCategory,
        risk: RiskLevel,
        reason: String,
        detail: String = "",
        modifiedAt: Date? = nil,
        isDirectory: Bool = true,
        requiresAdmin: Bool = false,
        canClean: Bool = true,
        isAggregate: Bool = false
    ) {
        self.id = "\(category.rawValue)|\(path)"
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.category = category
        self.risk = risk
        self.reason = reason
        self.detail = detail
        self.modifiedAt = modifiedAt
        self.isDirectory = isDirectory
        self.requiresAdmin = requiresAdmin
        self.canClean = canClean
        self.isAggregate = isAggregate
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var pathAbbreviated: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

struct ScanResult {
    let findings: [ScanFinding]
    let inaccessiblePaths: [String]
    let duration: TimeInterval
}

struct CategorySummary: Identifiable {
    let category: FindingCategory
    let count: Int
    let sizeBytes: Int64

    var id: FindingCategory { category }
    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

enum SidebarSelection: Hashable {
    case overview
    case smartPlan
    case activity
    case category(FindingCategory)
}

enum CleanupMode: String, Equatable, Identifiable {
    case trash
    case permanent

    var id: String { rawValue }
}

struct CleanupReport {
    let succeeded: [ScanFinding]
    let failed: [(finding: ScanFinding, error: String)]

    var reclaimedBytes: Int64 {
        succeeded.reduce(0) { $0 + $1.sizeBytes }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
