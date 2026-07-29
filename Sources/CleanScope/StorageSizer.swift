import Foundation

struct StorageSizer {
    private let manager = FileManager.default

    func allocatedSize(at url: URL) -> Int64 {
        guard manager.fileExists(atPath: url.path) else { return 0 }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        if values.isDirectory == true, let size = directorySizeUsingDu(url) {
            return size
        }

        return recursiveAllocatedSize(at: url, keys: keys)
    }

    private func directorySizeUsingDu(_ url: URL) -> Int64? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8),
                  let first = text.split(whereSeparator: {
                      $0 == " " || $0 == "\t" || $0 == "\n"
                  }).first,
                  let kilobytes = Int64(first) else {
                return nil
            }
            return kilobytes * 1_024
        } catch {
            return nil
        }
    }

    private func recursiveAllocatedSize(at url: URL, keys: Set<URLResourceKey>) -> Int64 {
        guard let enumerator = manager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [],
                errorHandler: { _, _ in true }
              ) else {
            return 0
        }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            autoreleasepool {
                guard let childValues = try? child.resourceValues(forKeys: keys) else { return }
                if childValues.isSymbolicLink == true {
                    if childValues.isDirectory == true { enumerator.skipDescendants() }
                    return
                }
                if childValues.isRegularFile == true {
                    total += Int64(childValues.totalFileAllocatedSize ?? childValues.fileAllocatedSize ?? 0)
                }
            }
        }
        return total
    }

    func metadata(at url: URL) -> (isDirectory: Bool, modifiedAt: Date?, requiresAdmin: Bool) {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        let values = try? url.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory ?? false
        let requiresAdmin = url.path.hasPrefix("/Library/")
            || (url.path.hasPrefix("/Applications/") && !manager.isWritableFile(atPath: url.path))
        return (isDirectory, values?.contentModificationDate, requiresAdmin)
    }
}
