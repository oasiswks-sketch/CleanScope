import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pendingCleanupMode: CleanupMode?
    @State private var showCleanupResult = false

    var body: some View {
        ZStack {
            AppBackground()
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 242)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                Group {
                    if model.sidebarSelection == .overview {
                        OverviewView()
                    } else {
                        FindingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .overlay(Color.white.opacity(0.06))

                InspectorView()
                    .frame(width: 310)
            }

            if !model.selectedIDs.isEmpty {
                VStack {
                    Spacer()
                    CleanupBar(
                        onTrash: { pendingCleanupMode = .trash },
                        onPermanent: { pendingCleanupMode = .permanent }
                    )
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if model.isCleaning {
                CleaningOverlay()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.selectedIDs)
        .confirmationDialog(
            cleanupTitle,
            isPresented: Binding(
                get: { pendingCleanupMode != nil },
                set: { if !$0 { pendingCleanupMode = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let mode = pendingCleanupMode {
                Button(mode == .trash ? "移到废纸篓" : "永久删除", role: .destructive) {
                    pendingCleanupMode = nil
                    model.performCleanup(mode: mode)
                }
            }
            Button("取消", role: .cancel) {
                pendingCleanupMode = nil
            }
        } message: {
            Text(cleanupMessage)
        }
        .onChange(of: model.cleanupMessage) { value in
            showCleanupResult = value != nil
        }
        .alert(
            model.cleanupHadFailures ? "部分项目未完成" : "清理完成",
            isPresented: $showCleanupResult
        ) {
            Button("好") {
                model.cleanupMessage = nil
            }
        } message: {
            Text(model.cleanupMessage ?? "")
        }
        .onAppear {
            SnapshotSupport.captureIfRequested()
        }
    }

    private var cleanupTitle: String {
        guard let mode = pendingCleanupMode else { return "" }
        switch mode {
        case .trash:
            return "将 \(model.selectedFindings.count) 项移到废纸篓？"
        case .permanent:
            return "永久删除 \(model.selectedFindings.count) 项？"
        }
    }

    private var cleanupMessage: String {
        guard let mode = pendingCleanupMode else { return "" }
        let adminCount = model.selectedFindings.filter(\.requiresAdmin).count
        var message = "预计释放 \(model.selectedSizeText)。"
        if mode == .trash {
            message += " 文件可从废纸篓恢复。"
            if adminCount > 0 {
                message += " 其中 \(adminCount) 个系统项目无法移到用户废纸篓。"
            }
        } else {
            message += " 此操作不可撤销。"
            if adminCount > 0 {
                message += " 系统会请求一次管理员认证。"
            }
        }
        return message
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x0D1118)
            LinearGradient(
                colors: [
                    Color(hex: 0x17202C).opacity(0.72),
                    Color(hex: 0x0D1118).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color(hex: 0x65D5B2).opacity(0.09),
                    .clear
                ],
                center: UnitPoint(x: 0.54, y: 0.06),
                startRadius: 20,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandView()
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 22)

            sidebarButton(
                title: "总览",
                symbol: "scope",
                badge: model.findings.count.description,
                selection: .overview,
                color: Color(hex: 0x64D9B7)
            )

            Text("扫描分类")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 3) {
                    ForEach(model.summaries) { summary in
                        sidebarButton(
                            title: summary.category.title,
                            symbol: summary.category.symbol,
                            badge: summary.count.description,
                            selection: .category(summary.category),
                            color: summary.category.color,
                            secondary: summary.sizeText
                        )
                    }
                }
            }

            Spacer(minLength: 12)

            PermissionCard()
                .padding(.horizontal, 14)

            HStack {
                Circle()
                    .fill(model.isScanning ? Color(hex: 0xF4C95D) : Color(hex: 0x58C79A))
                    .frame(width: 7, height: 7)
                Text(model.scanStatus)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Color.black.opacity(0.13))
    }

    private func sidebarButton(
        title: String,
        symbol: String,
        badge: String,
        selection: SidebarSelection,
        color: Color,
        secondary: String? = nil
    ) -> some View {
        let active = model.sidebarSelection == selection
        return Button {
            model.sidebarSelection = selection
            model.focusedID = model.filteredFindings.first?.id
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(active ? color.opacity(0.17) : Color.white.opacity(0.035))
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? color : Color.white.opacity(0.48))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? .primary : .secondary)
                    if let secondary {
                        Text(secondary)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(active ? color : Color.white.opacity(0.34))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(active ? color.opacity(0.12) : Color.white.opacity(0.035))
                    )
            }
            .padding(.horizontal, 10)
            .frame(height: secondary == nil ? 42 : 48)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(active ? Color.white.opacity(0.065) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(active ? color.opacity(0.16) : .clear, lineWidth: 1)
            )
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct BrandView: View {
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x65D5B2), Color(hex: 0x65AEE8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "scope")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x0B1618))
            }
            .frame(width: 38, height: 38)
            .shadow(color: Color(hex: 0x65D5B2).opacity(0.22), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text("CleanScope")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Mac 空间侦察与清理")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct PermissionCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "lock.open.display")
                    .foregroundStyle(Color(hex: 0x72C7F4))
                Text("扫描权限")
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer()
                if !model.inaccessiblePaths.isEmpty {
                    Text("\(model.inaccessiblePaths.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF4C95D))
                }
            }
            Text(
                model.inaccessiblePaths.isEmpty
                    ? "当前未发现权限阻塞"
                    : "部分目录无法读取，完整扫描需要完全磁盘访问。"
            )
            .font(.system(size: 9.5))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)

            Button("打开系统设置") {
                model.openFullDiskAccessSettings()
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopToolbar(title: "空间总览", subtitle: "软件、残留与 AI 工具链的一张清理地图")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeroCard()
                    MetricGrid()
                    HStack(alignment: .top, spacing: 16) {
                        DistributionPanel()
                        PriorityPanel()
                    }
                }
                .padding(22)
                .padding(.bottom, model.selectedIDs.isEmpty ? 0 : 76)
            }
        }
    }
}

private struct TopToolbar: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer()

            SearchField(text: $model.query)
                .frame(width: 235)

            Menu {
                ForEach([50, 100, 250, 500], id: \.self) { threshold in
                    Button {
                        model.largeFileThresholdMB = threshold
                        model.startScan()
                    } label: {
                        if model.largeFileThresholdMB == threshold {
                            Label("\(threshold) MB", systemImage: "checkmark")
                        } else {
                            Text("\(threshold) MB")
                        }
                    }
                }
            } label: {
                Label("大文件 \(model.largeFileThresholdMB) MB", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                model.startScan()
            } label: {
                HStack(spacing: 7) {
                    if model.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(model.isScanning ? "扫描中" : "重新扫描")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(model.isScanning)
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
        .background(Color.black.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 1)
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
            TextField("搜索名称或路径", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct HeroCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Text("你的 Mac，不该是一堆看不懂的缓存。")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("CleanScope 把软件本体、卸载残留、Skills、模型权重与第三方运行时拆开呈现，让每一次删除都有上下文。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: 560, alignment: .leading)

                HStack(spacing: 14) {
                    Label(model.scanStatus, systemImage: "waveform.path.ecg")
                    if let date = model.lastScanAt {
                        Label(date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    }
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 16)
                Circle()
                    .trim(from: 0.06, to: 0.78)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: 0x64D9B7),
                                Color(hex: 0x72C7F4),
                                Color(hex: 0x9B8CFF)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(model.totalIndexedText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("已索引")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 116, height: 116)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x1B2932).opacity(0.92),
                            Color(hex: 0x17202C).opacity(0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: 0x64D9B7).opacity(0.13), lineWidth: 1)
        )
    }
}

private struct MetricGrid: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            MetricCard(
                title: "可再生缓存",
                value: model.safeBytesText,
                caption: "优先清理候选",
                symbol: "arrow.triangle.2.circlepath",
                color: Color(hex: 0x58C79A)
            )
            MetricCard(
                title: "卸载残留",
                value: "\(model.findings.filter { $0.category == .residuals }.count)",
                caption: "处路径待判断",
                symbol: "app.badge.checkmark",
                color: Color(hex: 0xFF9D6C)
            )
            MetricCard(
                title: "模型权重",
                value: ByteCountFormatter.string(
                    fromByteCount: model.findings
                        .filter { $0.category == .models }
                        .reduce(0) { $0 + $1.sizeBytes },
                    countStyle: .file
                ),
                caption: "本地模型空间",
                symbol: "brain.head.profile",
                color: Color(hex: 0x64D9B7)
            )
            MetricCard(
                title: "Skills / 插件",
                value: "\(model.findings.filter { $0.category == .skills }.count)",
                caption: "个本地能力包",
                symbol: "puzzlepiece.extension",
                color: Color(hex: 0xF4C95D)
            )
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(color.opacity(0.12))
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                Text(caption)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.quaternary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(PanelBackground(cornerRadius: 14))
    }
}

private struct DistributionPanel: View {
    @EnvironmentObject private var model: AppModel

    private var maxBytes: Int64 {
        max(model.summaries.map(\.sizeBytes).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            PanelTitle(title: "空间分布", caption: "按扫描类别统计，不代表可全部清理", symbol: "chart.bar.xaxis")
            ForEach(model.summaries.filter { $0.count > 0 }) { summary in
                VStack(spacing: 6) {
                    HStack {
                        Label(summary.category.shortTitle, systemImage: summary.category.symbol)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(summary.sizeText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.04))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            summary.category.color.opacity(0.9),
                                            summary.category.color.opacity(0.42)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(
                                        6,
                                        proxy.size.width * CGFloat(summary.sizeBytes) / CGFloat(maxBytes)
                                    )
                                )
                        }
                    }
                    .frame(height: 5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .top)
        .background(PanelBackground(cornerRadius: 16))
    }
}

private struct PriorityPanel: View {
    @EnvironmentObject private var model: AppModel

    private var items: [ScanFinding] {
        Array(
            model.findings
                .filter { $0.category != .installedApps && $0.canClean }
                .sorted { $0.sizeBytes > $1.sizeBytes }
                .prefix(7)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            PanelTitle(title: "优先关注", caption: "当前扫描中占用最大的项目", symbol: "scope")
            ForEach(items) { finding in
                Button {
                    model.sidebarSelection = .category(finding.category)
                    model.focusedID = finding.id
                } label: {
                    HStack(spacing: 10) {
                        CategoryGlyph(category: finding.category, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(finding.name)
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                            Text(finding.reason)
                                .font(.system(size: 8.5))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(finding.sizeText)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(width: 320)
        .frame(minHeight: 310, alignment: .top)
        .background(PanelBackground(cornerRadius: 16))
    }
}

private struct PanelTitle: View {
    let title: String
    let caption: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0x64D9B7))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: 0x64D9B7).opacity(0.1))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(caption)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}

private struct FindingsView: View {
    @EnvironmentObject private var model: AppModel

    private var currentCategory: FindingCategory? {
        guard case .category(let category) = model.sidebarSelection else { return nil }
        return category
    }

    var body: some View {
        VStack(spacing: 0) {
            TopToolbar(
                title: currentCategory?.title ?? "扫描结果",
                subtitle: categorySubtitle
            )
            FindingsControlBar()
            if model.filteredFindings.isEmpty {
                EmptyFindingsView()
            } else {
                FindingsHeader()
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(model.filteredFindings) { finding in
                            FindingRow(finding: finding)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .padding(.bottom, model.selectedIDs.isEmpty ? 8 : 78)
                }
            }
        }
    }

    private var categorySubtitle: String {
        guard let category = currentCategory else { return "按容量排序的扫描结果" }
        switch category {
        case .installedApps: return "应用本体，可移到废纸篓卸载"
        case .residuals: return "主程序已不在，但数据或服务仍然存在"
        case .aiTools: return "Codex、Claude、Trae、WorkBuddy 等内部数据"
        case .skills: return "本地 Skills、插件包和能力缓存"
        case .models: return "Hugging Face、Ollama、LM Studio 等模型库"
        case .components: return "FFmpeg、Python、Node、浏览器和运行时"
        case .largeFiles: return "超过 \(model.largeFileThresholdMB) MB 的模型或组件文件"
        }
    }
}

private struct FindingsControlBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button("选择可再生缓存") {
                model.selectSafeItems()
            }
            .buttonStyle(QuietButtonStyle())

            if !model.selectedIDs.isEmpty {
                Button("取消选择") {
                    model.clearSelection()
                }
                .buttonStyle(QuietButtonStyle())
            }

            Spacer()

            Picker("风险", selection: $model.riskFilter) {
                Text("全部风险").tag(RiskLevel?.none)
                ForEach(RiskLevel.allCases, id: \.self) { risk in
                    Text(risk.title).tag(RiskLevel?.some(risk))
                }
            }
            .labelsHidden()
            .frame(width: 130)

            Text("\(model.filteredFindings.count) 项")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Color.black.opacity(0.045))
    }
}

private struct FindingsHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 22)
            Text("项目")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("风险")
                .frame(width: 104, alignment: .leading)
            Text("修改时间")
                .frame(width: 82, alignment: .leading)
            Text("容量")
                .frame(width: 78, alignment: .trailing)
            Color.clear.frame(width: 22)
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .frame(height: 28)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.045)).frame(height: 1)
        }
    }
}

private struct FindingRow: View {
    @EnvironmentObject private var model: AppModel
    let finding: ScanFinding

    private var isFocused: Bool { model.focusedID == finding.id }
    private var isSelected: Bool { model.selectedIDs.contains(finding.id) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.toggleSelection(finding)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        finding.canClean
                            ? (isSelected ? Color(hex: 0x64D9B7) : Color.white.opacity(0.26))
                            : Color.white.opacity(0.09)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!finding.canClean)
            .frame(width: 22)

            CategoryGlyph(category: finding.category, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(finding.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    if finding.requiresAdmin {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(hex: 0xE66A77))
                    }
                }
                Text(finding.pathAbbreviated)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RiskPill(risk: finding.risk)
                .frame(width: 104, alignment: .leading)

            Text(finding.modifiedAt?.formatted(.dateTime.month().day()) ?? "—")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .frame(width: 82, alignment: .leading)

            Text(finding.sizeText)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.quaternary)
                .frame(width: 22)
        }
        .padding(.horizontal, 8)
        .frame(height: 57)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isFocused
                        ? finding.category.color.opacity(0.09)
                        : Color.white.opacity(0.022)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isFocused
                        ? finding.category.color.opacity(0.2)
                        : Color.white.opacity(0.035),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.focusedID = finding.id
        }
        .contextMenu {
            Button("在 Finder 中显示") {
                model.reveal(finding)
            }
            if finding.canClean {
                Button(isSelected ? "取消选择" : "加入清理") {
                    model.toggleSelection(finding)
                }
            }
        }
    }
}

private struct CategoryGlyph: View {
    let category: FindingCategory
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29)
                .fill(category.color.opacity(0.11))
            Image(systemName: category.symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(category.color)
        }
        .frame(width: size, height: size)
    }
}

private struct RiskPill: View {
    let risk: RiskLevel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: risk.symbol)
                .font(.system(size: 8))
            Text(risk.title)
                .font(.system(size: 8.5, weight: .semibold))
        }
        .foregroundStyle(risk.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(risk.color.opacity(0.09)))
    }
}

private struct EmptyFindingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: 0x64D9B7).opacity(0.09))
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: 0x64D9B7))
            }
            .frame(width: 62, height: 62)
            Text(model.isScanning ? "正在扫描…" : "这一类暂时没有发现")
                .font(.system(size: 14, weight: .semibold))
            Text("可以调整搜索或风险筛选，也可以重新扫描。")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("项目详情")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if let finding = model.focusedFinding {
                    Button {
                        model.reveal(finding)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(QuietIconButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.055)).frame(height: 1)
            }

            if let finding = model.focusedFinding {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            CategoryGlyph(category: finding.category, size: 46)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(finding.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(2)
                                Text(finding.category.title)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(finding.category.color)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            InspectorValue(label: "容量", value: finding.sizeText)
                            InspectorValue(label: "风险", value: finding.risk.title)
                            InspectorValue(
                                label: "权限",
                                value: finding.requiresAdmin ? "需要管理员认证" : "当前用户可处理"
                            )
                            InspectorValue(
                                label: "修改时间",
                                value: finding.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未知"
                            )
                        }
                        .padding(13)
                        .background(PanelBackground(cornerRadius: 12))

                        InspectorSection(title: "识别依据", text: finding.reason)
                        if !finding.detail.isEmpty {
                            InspectorSection(title: "删除影响", text: finding.detail)
                        }
                        InspectorSection(title: "完整路径", text: finding.pathAbbreviated, monospaced: true)

                        if finding.canClean {
                            Button {
                                model.toggleSelection(finding)
                            } label: {
                                Label(
                                    model.selectedIDs.contains(finding.id) ? "已加入清理" : "加入清理列表",
                                    systemImage: model.selectedIDs.contains(finding.id)
                                        ? "checkmark.circle.fill"
                                        : "plus.circle"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AccentButtonStyle())
                        }

                        if finding.requiresAdmin {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "lock.shield")
                                    .foregroundStyle(Color(hex: 0xE66A77))
                                Text("处理系统级残留时，macOS 会弹出管理员认证。CleanScope 不保存密码。")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(Color(hex: 0xE66A77).opacity(0.07))
                            )
                        }
                    }
                    .padding(18)
                    .padding(.bottom, model.selectedIDs.isEmpty ? 0 : 78)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 25))
                        .foregroundStyle(.tertiary)
                    Text("选择一项查看详情")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black.opacity(0.1))
    }
}

private struct InspectorValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 9.5))
    }
}

private struct InspectorSection: View {
    let title: String
    let text: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(text)
                .font(.system(size: 10.5, design: monospaced ? .monospaced : .default))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CleanupBar: View {
    @EnvironmentObject private var model: AppModel
    let onTrash: () -> Void
    let onPermanent: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: 0x64D9B7).opacity(0.12))
                    Text("\(model.selectedFindings.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x64D9B7))
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("已选择 \(model.selectedSizeText)")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("建议优先移到废纸篓")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider().frame(height: 28)

            Button("清空选择") {
                model.clearSelection()
            }
            .buttonStyle(QuietButtonStyle())

            Button {
                onTrash()
            } label: {
                Label("移到废纸篓", systemImage: "trash")
            }
            .buttonStyle(QuietButtonStyle())

            Button {
                onPermanent()
            } label: {
                Label("永久删除", systemImage: "delete.left.fill")
            }
            .buttonStyle(DangerButtonStyle())
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.38), radius: 25, y: 12)
    }
}

private struct CleaningOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("正在安全处理所选项目")
                    .font(.system(size: 14, weight: .semibold))
                Text("管理员项目可能弹出系统认证窗口")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
        }
    }
}

private struct PanelBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.033))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            )
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Color(hex: 0x0B1618))
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x69DCB8),
                                Color(hex: 0x62C9B1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct QuietIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
    }
}

private struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: 0xD95F70).opacity(configuration.isPressed ? 0.72 : 0.92))
            )
    }
}
