import CryptoKit
import Foundation

struct CleanScopeLicensePayload: Codable, Equatable {
    let licenseID: String
    let email: String
    let plan: String
    let issuedAt: Int64
    let expiresAt: Int64?
    let seats: Int

    var isActive: Bool {
        guard plan == "pro_lifetime" || plan == "pro_team" else { return false }
        guard let expiresAt else { return true }
        return Int64(Date().timeIntervalSince1970) < expiresAt
    }
}
enum LicenseState: Equatable {
    case free
    case pro(CleanScopeLicensePayload)

    var isPro: Bool {
        if case .pro = self { return true }
        return false
    }

    var accountLabel: String {
        switch self {
        case .free:
            return "Free"
        case .pro(let payload):
            return payload.email
        }
    }
}

enum LicenseValidationError: LocalizedError {
    case malformed
    case invalidSignature
    case expired

    var errorDescription: String? {
        switch self {
        case .malformed:
            return "许可证格式不正确。"
        case .invalidSignature:
            return "许可证签名无效。"
        case .expired:
            return "许可证已过期。"
        }
    }
}

struct LicenseManager {
    private static let defaultsKey = "CleanScope.ProLicense.v1"
    private static let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEVI4pZ618E51bP1RAzknYDo57p5kl
    3SqtK1gxXtgzJdFhO6aVcomeTviY/ZvKpg3lj1Kdx9h2Md4ne1lV487RGQ==
    -----END PUBLIC KEY-----
    """

    func restoredState() -> LicenseState {
        if ProcessInfo.processInfo.environment["CLEANSCOPE_PRO"] == "1" {
            return .pro(
                CleanScopeLicensePayload(
                    licenseID: "preview",
                    email: "CleanScope Pro Preview",
                    plan: "pro_lifetime",
                    issuedAt: Int64(Date().timeIntervalSince1970),
                    expiresAt: nil,
                    seats: 3
                )
            )
        }
        guard let stored = UserDefaults.standard.string(forKey: Self.defaultsKey),
              let payload = try? validate(stored) else {
            return .free
        }
        return .pro(payload)
    }

    func activate(_ rawLicense: String) throws -> CleanScopeLicensePayload {
        let payload = try validate(rawLicense)
        UserDefaults.standard.set(
            rawLicense.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: Self.defaultsKey
        )
        return payload
    }

    func deactivate() {
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }

    private func validate(_ rawLicense: String) throws -> CleanScopeLicensePayload {
        let normalized = rawLicense
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let payloadData = Data(base64URL: String(parts[0])),
              let signatureData = Data(base64URL: String(parts[1])),
              let publicKey = try? P256.Signing.PublicKey(
                pemRepresentation: Self.publicKeyPEM
              ),
              let signature = try? P256.Signing.ECDSASignature(
                derRepresentation: signatureData
              ) else {
            throw LicenseValidationError.malformed
        }
        guard publicKey.isValidSignature(signature, for: payloadData) else {
            throw LicenseValidationError.invalidSignature
        }
        guard let payload = try? JSONDecoder().decode(
            CleanScopeLicensePayload.self,
            from: payloadData
        ) else {
            throw LicenseValidationError.malformed
        }
        guard payload.isActive else {
            throw LicenseValidationError.expired
        }
        return payload
    }
}

struct CleanupHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let bytes: Int64
    let itemCount: Int
    let mode: String

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct CommercialStore {
    private let historyURL: URL
    private static let exclusionsKey = "CleanScope.ExcludedPaths.v1"

    init() {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        historyURL = support
            .appendingPathComponent("CleanScope", isDirectory: true)
            .appendingPathComponent("cleanup-history.json")
    }

    func loadHistory() -> [CleanupHistoryEntry] {
        guard let data = try? Data(contentsOf: historyURL),
              let history = try? JSONDecoder().decode(
                [CleanupHistoryEntry].self,
                from: data
              ) else {
            return []
        }
        return history.sorted { $0.date > $1.date }
    }

    func saveHistory(_ history: [CleanupHistoryEntry]) {
        do {
            try FileManager.default.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Array(history.prefix(100)))
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // 清理主流程不能因为历史记录写入失败而失败。
        }
    }

    func loadExclusions() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.exclusionsKey) ?? [])
    }

    func saveExclusions(_ paths: Set<String>) {
        UserDefaults.standard.set(paths.sorted(), forKey: Self.exclusionsKey)
    }
}

private extension Data {
    init?(base64URL: String) {
        var value = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder > 0 {
            value += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: value)
    }
}
