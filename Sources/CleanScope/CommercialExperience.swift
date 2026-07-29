import AppKit
import SwiftUI

struct CommercialSidebarCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.showsUpgrade = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: model.isPro ? "checkmark.seal.fill" : "sparkles")
                        .foregroundStyle(Color(hex: 0x69D7B4))
                    Text(model.isPro ? "CleanScope Pro" : "解锁 CleanScope Pro")
                        .font(.system(size: 10.5, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.38))
                }
                Text(
                    model.isPro
                        ? model.licenseState.accountLabel
                        : "智能方案、历史与无限批量"
                )
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(1)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0x69D7B4).opacity(model.isPro ? 0.07 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: 0x69D7B4).opacity(0.13), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isPro ? "CleanScope Pro 已激活" : "升级 CleanScope Pro")
    }
}

struct SmartPlanView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            CommercialToolbar(
                title: "智能方案",
                subtitle: "把重复判断，交给可信的规则"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    smartPlanHero
                    HStack(alignment: .top, spacing: 14) {
                        candidatePanel
                        rulePanel
                    }
                }
                .padding(22)
                .padding(.bottom, model.selectedIDs.isEmpty ? 0 : 76)
            }
        }
    }

    private var smartPlanHero: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(model.isPro ? "PRO 方案已就绪" : "PRO 方案预览")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color(hex: 0x69D7B4))
                    if !model.isPro {
                        Text("一次买断")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xE9B85C))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: 0xE9B85C).opacity(0.1)))
                    }
                }

                Text("预计可安全释放 \(model.smartPlanSizeText)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .textSelection(.enabled)

                Text(
                    "仅包含标记为“可重新生成”、允许清理且未被排除的项目。" +
                    "CleanScope 不会把受保护内容塞进自动方案。"
                )
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.66))
                .lineSpacing(3)
                .frame(maxWidth: 600, alignment: .leading)

                Button {
                    model.applySmartPlan()
                } label: {
                    Label(
                        model.isPro ? "选中完整方案" : "解锁完整方案",
                        systemImage: model.isPro ? "checkmark.circle.fill" : "sparkles"
                    )
                    .frame(minWidth: 150)
                }
                .buttonStyle(CommercialPrimaryButtonStyle())
                .disabled(model.smartPlanFindings.isEmpty)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 14)
                Circle()
                    .trim(from: 0.02, to: planProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: 0x69D7B4),
                                Color(hex: 0x72C7F4),
                                Color(hex: 0x69D7B4)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(model.smartPlanFindings.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("个候选")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .frame(width: 126, height: 126)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(model.smartPlanFindings.count) 个智能方案候选")
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: 0x141E26))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: 0x69D7B4).opacity(0.18), lineWidth: 1)
        )
    }

    private var candidatePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommercialPanelHeader(
                title: "建议处理",
                caption: "按可再生成本、更新时间与容量排序",
                symbol: "list.bullet.rectangle"
            )
            .padding(16)

            if model.smartPlanFindings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: 0x69D7B4))
                    Text(model.isScanning ? "正在建立方案…" : "暂时没有安全候选")
                        .font(.system(size: 12, weight: .semibold))
                    Text("受保护和需要人工判断的项目不会出现在这里。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                VStack(spacing: 3) {
                    ForEach(Array(model.smartPlanFindings.prefix(7))) { finding in
                        SmartCandidateRow(finding: finding)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .top)
        .background(CommercialPanelBackground())
    }

    private var rulePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            CommercialPanelHeader(
                title: "方案边界",
                caption: "先排除风险，再考虑容量",
                symbol: "checkmark.shield"
            )

            CommercialRuleRow(
                title: "只收录可再生成内容",
                detail: "缓存、下载包和能够重新安装的运行组件",
                color: Color(hex: 0x69D7B4),
                symbol: "arrow.triangle.2.circlepath"
            )
            CommercialRuleRow(
                title: "尊重自定义排除",
                detail: "\(model.excludedPaths.count) 条路径不会进入方案",
                color: Color(hex: 0x72C7F4),
                symbol: "eye.slash"
            )
            CommercialRuleRow(
                title: "不碰受保护项目",
                detail: "会话、任务、账户数据与系统级内容需人工判断",
                color: Color(hex: 0xE9B85C),
                symbol: "lock.shield"
            )

            Divider().overlay(Color.white.opacity(0.06))

            Text("Free 仍可逐项处理")
                .font(.system(size: 10.5, weight: .semibold))
            Text("免费版保留完整扫描和证据说明，每次最多选择 3 项。Pro 解锁完整方案与无限批量。")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.56))
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(width: 310)
        .frame(minHeight: 360, alignment: .top)
        .background(CommercialPanelBackground())
    }

    private var planProgress: CGFloat {
        let safe = max(model.safeBytes, 1)
        let ratio = Double(model.smartPlanSizeBytes) / Double(safe)
        return CGFloat(min(max(ratio, 0.12), 0.88))
    }
}

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            CommercialToolbar(
                title: "清理记录",
                subtitle: "看见长期释放的空间，而不是一次性的庆祝数字"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    activityMetrics
                    historyPanel
                }
                .padding(22)
            }
        }
    }

    private var activityMetrics: some View {
        HStack(spacing: 10) {
            CommercialMetric(
                title: "累计释放",
                value: model.totalReclaimedText,
                caption: "本机历史记录",
                color: Color(hex: 0x69D7B4)
            )
            CommercialMetric(
                title: "清理次数",
                value: "\(model.cleanupHistory.count)",
                caption: "最多保留 100 条",
                color: Color(hex: 0x72C7F4)
            )
            CommercialMetric(
                title: "最近一次",
                value: model.cleanupHistory.first?.sizeText ?? "—",
                caption: model.cleanupHistory.first?.date.formatted(
                    date: .abbreviated,
                    time: .shortened
                ) ?? "尚无记录",
                color: Color(hex: 0xE9B85C)
            )
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommercialPanelHeader(
                title: "操作时间线",
                caption: model.isPro ? "所有记录仅保存在本机" : "Pro 解锁完整历史",
                symbol: "clock.arrow.circlepath"
            )
            .padding(16)

            if model.cleanupHistory.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: 0x72C7F4))
                    Text("清理完成后，记录会出现在这里")
                        .font(.system(size: 12, weight: .semibold))
                    Text("只记录时间、项目数、方式与释放容量，不记录文件内容。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleHistory) { entry in
                        HStack(spacing: 13) {
                            ZStack {
                                Circle().fill(Color(hex: 0x69D7B4).opacity(0.1))
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(hex: 0x69D7B4))
                            }
                            .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.mode)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(
                                    entry.date.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.48))
                            }
                            Spacer()
                            Text("\(entry.itemCount) 项")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color.white.opacity(0.52))
                            Text(entry.sizeText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .frame(width: 90, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.045))
                                .frame(height: 1)
                        }
                    }
                }

                if !model.isPro && model.cleanupHistory.count > 1 {
                    Button("升级 Pro 查看完整历史") {
                        model.showsUpgrade = true
                    }
                    .buttonStyle(CommercialSecondaryButtonStyle())
                    .padding(16)
                }
            }
        }
        .background(CommercialPanelBackground())
    }

    private var visibleHistory: [CleanupHistoryEntry] {
        model.isPro ? model.cleanupHistory : Array(model.cleanupHistory.prefix(1))
    }
}

struct ProUpgradeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var licenseValue = ""

    var body: some View {
        ZStack {
            Color(hex: 0x0B1016).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("CleanScope Pro")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .frame(height: 62)

                Divider().overlay(Color.white.opacity(0.06))

                if model.isPro {
                    activatedContent
                } else {
                    purchaseContent
                }
            }
        }
        .frame(width: 760, height: 600)
        .preferredColorScheme(.dark)
    }

    private var purchaseContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("把反复判断，\n交给可信的规则。")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .textSelection(.enabled)

                Text("完整扫描与安全解释永远免费。Pro 为智能方案、长期历史和批量效率收费。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.64))
                    .lineSpacing(4)

                VStack(spacing: 12) {
                    ProFeatureRow(title: "智能清理方案", detail: "只选择可再生成且未排除的项目")
                    ProFeatureRow(title: "无限批量处理", detail: "一次应用完整计划")
                    ProFeatureRow(title: "清理历史", detail: "累计释放与本地操作时间线")
                    ProFeatureRow(title: "自定义排除", detail: "让重要路径永远不进自动方案")
                }

                Spacer()
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(Color.white.opacity(0.06))

            VStack(alignment: .leading, spacing: 14) {
                Text("创始版终身授权")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: 0x69D7B4))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("¥128")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("一次买断")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                Text("3 台个人 Mac · 2.x 更新")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.56))

                Button("前往官网购买") {
                    if let url = URL(
                        string: "https://cleanscope-website.oasiswks.workers.dev/pricing"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(CommercialPrimaryButtonStyle())

                HStack {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    Text("已有许可证")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }

                TextEditor(text: $licenseValue)
                    .font(.system(size: 9.5, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 92)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Button("激活许可证") {
                    model.activateLicense(licenseValue)
                }
                .buttonStyle(CommercialSecondaryButtonStyle())
                .disabled(licenseValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let message = model.licenseMessage {
                    Text(message)
                        .font(.system(size: 9))
                        .foregroundStyle(
                            model.isPro
                                ? Color(hex: 0x69D7B4)
                                : Color(hex: 0xE97B75)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(26)
            .frame(width: 300, alignment: .topLeading)
            .background(Color.white.opacity(0.018))
        }
    }

    private var activatedContent: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color(hex: 0x69D7B4).opacity(0.1))
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(hex: 0x69D7B4))
            }
            .frame(width: 78, height: 78)

            Text("CleanScope Pro 已激活")
                .font(.system(size: 23, weight: .bold, design: .rounded))
            Text(model.licenseState.accountLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.58))
                .textSelection(.enabled)

            Text("智能方案、无限批量、完整历史与自定义排除现已可用。")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.58))

            Button("开始使用智能方案") {
                model.sidebarSelection = .smartPlan
                dismiss()
            }
            .buttonStyle(CommercialPrimaryButtonStyle())

            Button("移除这台 Mac 的许可证") {
                model.deactivateLicense()
            }
            .buttonStyle(.plain)
            .font(.system(size: 9.5))
            .foregroundStyle(Color(hex: 0xE97B75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CommercialToolbar: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            if !model.isPro {
                Button("升级 Pro · ¥128") {
                    model.showsUpgrade = true
                }
                .buttonStyle(CommercialSecondaryButtonStyle())
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("PRO")
                }
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color(hex: 0x69D7B4))
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
        .background(Color.black.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.055)).frame(height: 1)
        }
    }
}

private struct SmartCandidateRow: View {
    @EnvironmentObject private var model: AppModel
    let finding: ScanFinding

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(finding.category.color.opacity(0.1))
                Image(systemName: finding.category.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(finding.category.color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(finding.name)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                Text(recommendation)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .lineLimit(1)
            }

            Spacer()

            Text(finding.sizeText)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))

            Button {
                model.toggleSelection(finding)
            } label: {
                Image(
                    systemName: model.selectedIDs.contains(finding.id)
                        ? "checkmark.circle.fill"
                        : "plus.circle"
                )
                .foregroundStyle(Color(hex: 0x69D7B4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.025))
        )
    }

    private var recommendation: String {
        guard let date = finding.modifiedAt else {
            return "\(finding.category.shortTitle) · \(finding.reason)"
        }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days >= 90 {
            return "\(finding.category.shortTitle) · \(days) 天未更新 · 可重新生成"
        }
        if days >= 30 {
            return "\(finding.category.shortTitle) · \(days) 天未更新"
        }
        return "\(finding.category.shortTitle) · \(finding.reason)"
    }
}

private struct CommercialRuleRow: View {
    let title: String
    let detail: String
    let color: Color
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(0.09))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 8.8))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CommercialMetric: View {
    let title: String
    let value: String
    let caption: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 8.8))
                .foregroundStyle(Color.white.opacity(0.42))
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CommercialPanelBackground())
    }
}

private struct CommercialPanelHeader: View {
    let title: String
    let caption: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x69D7B4))
                .frame(width: 27, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: 0x69D7B4).opacity(0.09))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(caption)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Spacer()
        }
    }
}

private struct ProFeatureRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: 0x69D7B4))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 8.8))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }
}

private struct CommercialPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.white.opacity(0.033))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct CommercialPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(Color(hex: 0x081310))
            .padding(.horizontal, 15)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: 0x69D7B4).opacity(configuration.isPressed ? 0.72 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct CommercialSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.09 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}
