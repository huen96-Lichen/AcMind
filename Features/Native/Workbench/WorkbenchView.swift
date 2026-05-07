import SwiftUI
import AcMindKit

// MARK: - Workbench View

/// 工作台页面
/// 功能：今日统计、快速入库、知识沉淀
struct WorkbenchView: View {
    @StateObject private var viewModel = WorkbenchViewModel()

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    loadingState
                } else if let error = viewModel.errorMessage {
                    errorState(error)
                } else {
                    readyState
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadData() }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载工作台...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("加载失败")
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)

            Button("重试") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ready State

    private var readyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 今日统计卡片
                statsSection

                // 快速操作
                quickActionsSection

                // 待处理项
                if !viewModel.pendingItems.isEmpty {
                    pendingSection
                }

                // 最近知识卡片
                if !viewModel.recentCards.isEmpty {
                    recentCardsSection
                }
            }
            .padding(32)
            .frame(maxWidth: 800, alignment: .leading)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日概览")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                StatCard(
                    title: "新采集",
                    value: "\(viewModel.todayCaptured)",
                    icon: "tray.and.arrow.down",
                    color: .blue
                )

                StatCard(
                    title: "待处理",
                    value: "\(viewModel.pendingCount)",
                    icon: "clock",
                    color: .orange
                )

                StatCard(
                    title: "已蒸馏",
                    value: "\(viewModel.distilledCount)",
                    icon: "sparkles",
                    color: .purple
                )

                StatCard(
                    title: "知识卡片",
                    value: "\(viewModel.totalCards)",
                    icon: "square.grid.2x2",
                    color: .green
                )
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速操作")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "快速记录",
                    icon: "square.and.pencil",
                    color: .blue
                ) {
                    // 打开快速输入
                }

                QuickActionButton(
                    title: "截图",
                    icon: "camera",
                    color: .green
                ) {
                    Task { await viewModel.captureScreenshot() }
                }

                QuickActionButton(
                    title: "语音",
                    icon: "mic",
                    color: .orange
                ) {
                    // 开始录音
                }

                QuickActionButton(
                    title: "导入文件",
                    icon: "doc.badge.plus",
                    color: .purple
                ) {
                    Task { await viewModel.importFile() }
                }
            }
        }
    }

    // MARK: - Pending Section

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("待处理")
                    .font(.headline)

                Spacer()

                Button("查看全部") {
                    // 跳转到 Inbox
                }
                .font(.caption)
                .buttonStyle(.plain)
            }

            ForEach(viewModel.pendingItems.prefix(5)) { item in
                PendingItemRow(item: item)
            }
        }
    }

    // MARK: - Recent Cards Section

    private var recentCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近知识卡片")
                    .font(.headline)

                Spacer()

                Button("查看全部") {
                    // 跳转到知识库
                }
                .font(.caption)
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                ForEach(viewModel.recentCards.prefix(6)) { card in
                    KnowledgeCardPreview(card: card)
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pending Item Row

struct PendingItemRow: View {
    let item: SourceItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(item.type))
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "未命名")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: item.status)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func iconForType(_ type: SourceType) -> String {
        switch type {
        case .text: return "text.quote"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.text"
        case .docx: return "doc.text.fill"
        case .screenshot: return "camera"
        case .webpage: return "link"
        case .unknownFile: return "doc"
        }
    }
}

// MARK: - Knowledge Card Preview

struct KnowledgeCardPreview: View {
    let card: KnowledgeCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.canonicalTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            if let summary = card.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack {
                if let category = card.category {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                if let score = card.valueScore {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f", score))
                            .font(.caption2)
                    }
                    .foregroundStyle(score >= 0.7 ? .orange : .secondary)
                }
            }
        }
        .padding(12)
        .frame(height: 120)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - View Model

@MainActor
class WorkbenchViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var todayCaptured = 0
    @Published var pendingCount = 0
    @Published var distilledCount = 0
    @Published var totalCards = 0

    @Published var pendingItems: [SourceItem] = []
    @Published var recentCards: [KnowledgeCard] = []

    private let storage: StorageServiceProtocol
    private let knowledgeService: KnowledgeService
    private let captureService: CaptureService

    init(
        storage: StorageServiceProtocol = ServiceContainer.shared.storageService,
        knowledgeService: KnowledgeService = ServiceContainer.shared.knowledgeService,
        captureService: CaptureService = ServiceContainer.shared.captureService
    ) {
        self.storage = storage
        self.knowledgeService = knowledgeService
        self.captureService = captureService
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 加载今日统计
            let allItems = try await storage.listSourceItems(filter: nil)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            todayCaptured = allItems.filter {
                calendar.isDate($0.createdAt, inSameDayAs: today)
            }.count

            pendingCount = allItems.filter {
                $0.status == .pending || $0.status == .captured
            }.count

            distilledCount = allItems.filter { $0.status == .distilled }.count

            // 待处理项
            pendingItems = allItems
                .filter { $0.status == .pending || $0.status == .captured }
                .sorted { $0.createdAt > $1.createdAt }

            // 知识卡片
            let cards = try await knowledgeService.listCards(status: .active)
            totalCards = cards.count
            recentCards = cards.prefix(6).map { $0 }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func captureScreenshot() async {
        do {
            _ = try await captureService.captureScreenshot(mode: .fullscreen)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importFile() async {
        // 文件导入逻辑
    }
}
