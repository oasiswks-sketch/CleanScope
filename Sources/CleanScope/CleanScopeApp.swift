import SwiftUI

@main
struct CleanScopeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1_280, minHeight: 780)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1_320, height: 820)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandMenu("扫描") {
                Button("重新扫描") {
                    model.startScan()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("选择可再生缓存") {
                    model.selectSafeItems()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
    }
}
