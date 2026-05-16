import SwiftUI

struct ToolsView: View {
    var body: some View {
        ACSecondaryPageShell(
            header: {
                ACPageHeader(
                    title: "工具中心",
                    subtitle: "面向低频但高价值的文本、图片、文件和批量处理。",
                    trailing: {
                        ACButton("打开工具台", kind: .primary, minWidth: 104) {}
                    }
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        ToolsHeroCard(
                            title: "工具中心",
                            subtitle: "面向低频但高价值的日常处理",
                            symbol: "wrench.and.screwdriver",
                            tint: ACColors.accentBlue
                        )

                        ToolsHeroCard(
                            title: "批量整理",
                            subtitle: "拖放文件后快速处理与归档",
                            symbol: "square.grid.3x2",
                            tint: ACColors.accentPurple
                        )

                        ToolsHeroCard(
                            title: "状态",
                            subtitle: "当前工具均可用，后续接真实处理链路",
                            symbol: "checkmark.seal",
                            tint: ACColors.accentGreen
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("工具分类")
                            .font(ACTypography.sectionTitle)
                            .foregroundStyle(ACColors.primaryText)

                        Text("每个工具卡片都保留图标、标题、说明和状态。")
                            .font(ACTypography.body)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                        ForEach(toolCards) { card in
                            ToolCard(card: card)
                        }
                    }
                }
            }
        )
    }
}

private struct ToolsHeroCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ACTypeIcon(symbol, tint: tint, background: tint.opacity(0.12), size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
    }
}

private struct ToolCard: View {
    let card: ToolCardModel

    var body: some View {
        ACCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ACTypeIcon(card.symbol, tint: card.tint, background: card.tint.opacity(0.12), size: 32)
                    Spacer(minLength: 0)
                    ACBadge(card.state, kind: card.badgeKind)
                }

                Text(card.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text(card.subtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 120)
    }
}

private struct ToolCardModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let state: String
    let badgeKind: ACBadge.Kind
}

private let toolCards: [ToolCardModel] = [
    .init(title: "文本处理", subtitle: "清洗、重写、摘要与格式化", symbol: "textformat", tint: ACColors.accentBlue, state: "可用", badgeKind: .blue),
    .init(title: "图片与截图", subtitle: "裁切、注释、压缩与 OCR 预处理", symbol: "photo", tint: ACColors.accentPurple, state: "可用", badgeKind: .purple),
    .init(title: "文件转换", subtitle: "PDF、Markdown、HTML 与导出转换", symbol: "doc", tint: ACColors.accentGreen, state: "可用", badgeKind: .green),
    .init(title: "批量整理", subtitle: "批量重命名、归档和分类", symbol: "square.grid.2x2", tint: ACColors.accentOrange, state: "可用", badgeKind: .orange),
    .init(title: "OCR 图像识别", subtitle: "提取截图中的文本与结构", symbol: "viewfinder", tint: ACColors.accentRed, state: "可用", badgeKind: .red),
    .init(title: "语音转文字", subtitle: "音频转写与后续整理", symbol: "waveform.and.mic", tint: ACColors.accentTeal, state: "可用", badgeKind: .green),
    .init(title: "网页正文提取", subtitle: "清理网页噪音并提取正文", symbol: "safari", tint: ACColors.accentBlue, state: "可用", badgeKind: .blue),
    .init(title: "SRT → FCPXML", subtitle: "字幕与剪辑工作流导出", symbol: "film", tint: ACColors.accentPurple, state: "可用", badgeKind: .purple)
]
