import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    if owner == "CleanScope" {
        print(window)
    }
}
