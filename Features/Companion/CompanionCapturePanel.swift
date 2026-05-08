import SwiftUI
import AppKit
import AcMindKit

// MARK: - Companion Capture Panel
// 随身捕获面板 - 快速捕获能力展示

struct CompanionCapturePanel: View {
    @StateObject private var viewModel = CompanionCaptureViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            Divider()

            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 捕获类型网格
                    captureTypesGrid

                    // 最近捕获
                    if !viewModel.recentCaptures.isEmpty {
                        recentCapturesSection
                    }

                    // 快速设置
                    quickSettingsSection
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随身捕获")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("快速保存当前内容到收集箱")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    // MARK: - Capture Types Grid

    private var captureTypesGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("捕获方式")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CompanionCaptureType.allCases) { type in
                    CaptureTypeCard(
                        type: type,
                        action: { viewModel.performCapture(type: type) }
                    )
                }
            }
        }
    }

    // MARK: - Recent Captures Section

    private var recentCapturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近捕获")
                    .font(.headline)

                Spacer()

                Button("查看全部") {
                    viewModel.showAllCaptures()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.recentCaptures.prefix(3)) { capture in
                    RecentCaptureRow(capture: capture)
                }
            }
        }
    }

    // MARK: - Quick Settings Section

    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速设置")
                .font(.headline)

            VStack(spacing: 12) {
                Toggle("自动保存到收集箱", isOn: $viewModel.autoSaveToInbox)
                    .toggleStyle(.switch)

                Toggle("捕获后打开详情", isOn: $viewModel.openDetailAfterCapture)
                    .toggleStyle(.switch)

                Toggle("显示捕获通知", isOn: $viewModel.showCaptureNotification)
                    .toggleStyle(.switch)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

// MARK: - Capture Type Card

struct CaptureTypeCard: View {
    let type: CompanionCaptureType
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: type.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(descriptionForType(type))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func descriptionForType(_ type: CompanionCaptureType) -> String {
        switch type {
        case .screenshot: return "⌥ S"
        case .clipboard: return "⌥ C"
        case .selectedText: return "自动检测"
        case .webpage: return "浏览器中"
        }
    }
}

// MARK: - Recent Capture Row

struct RecentCaptureRow: View {
    let capture: MockCapture
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(colorForType(capture.type).opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: iconForType(capture.type))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colorForType(capture.type))
            }

            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(capture.title)
                    .font(.body)
                    .lineLimit(1)

                Text(formatTime(capture.timestamp))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // 状态
            CompanionCaptureStatusBadge(status: capture.status)

            // 悬停操作
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)

                    Button(action: {}) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func iconForType(_ type: CompanionCaptureType) -> String {
        switch type {
        case .screenshot: return "camera.viewfinder"
        case .clipboard: return "doc.on.clipboard"
        case .selectedText: return "text.quote"
        case .webpage: return "globe"
        }
    }

    private func colorForType(_ type: CompanionCaptureType) -> Color {
        switch type {
        case .screenshot: return .blue
        case .clipboard: return .green
        case .selectedText: return .orange
        case .webpage: return .purple
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Status Badge

struct CompanionCaptureStatusBadge: View {
    let status: CaptureStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Mock Types

enum CaptureStatus {
    case success
    case pending
    case error

    var color: Color {
        switch self {
        case .success: return .green
        case .pending: return .orange
        case .error: return .red
        }
    }
}

/// CapturePreview - renamed from MockCapture
struct MockCapture: Identifiable {
    let id = UUID()
    let type: CompanionCaptureType
    let title: String
    let timestamp: Date
    let status: CaptureStatus
}

// MARK: - View Model

@MainActor
class CompanionCaptureViewModel: ObservableObject {
    // MARK: - Dependencies

    private let captureService: CaptureServiceProtocol
    private let storage: StorageServiceProtocol

    @Published var recentCaptures: [MockCapture] = []
    @Published var autoSaveToInbox = true
    @Published var openDetailAfterCapture = false
    @Published var showCaptureNotification = true

    init(
        captureService: CaptureServiceProtocol = CaptureService(),
        storage: StorageServiceProtocol = StorageService()
    ) {
        self.captureService = captureService
        self.storage = storage
        loadRecentCaptures()
    }

    // MARK: - Data Loading

    private func loadRecentCaptures() {
        Task {
            do {
                let items = try await storage.listSourceItems(
                    filter: SourceItemFilter(limit: 10)
                )
                // 按创建时间倒序，取最近 10 条
                recentCaptures = items
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(10)
                    .map { item in
                        MockCapture(
                            type: mapSourceTypeToCaptureType(item.type),
                            title: item.title ?? "未命名捕获",
                            timestamp: item.createdAt,
                            status: mapStatusToCaptureStatus(item.status)
                        )
                    }
            } catch {
                print("⚠️ 加载最近捕获失败: \(error.localizedDescription)")
            }
        }
    }

    /// 将 SourceType 映射到 CompanionCaptureType
    private func mapSourceTypeToCaptureType(_ type: SourceType) -> CompanionCaptureType {
        switch type {
        case .screenshot: return .screenshot
        case .webpage: return .webpage
        case .text: return .selectedText
        default: return .clipboard
        }
    }

    /// 将 SourceItemStatus 映射到 CaptureStatus
    private func mapStatusToCaptureStatus(_ status: SourceItemStatus) -> CaptureStatus {
        switch status {
        case .inbox, .captured, .parsed, .distilled, .exported, .archived:
            return .success
        case .pending, .capturing, .parsing, .distilling, .exporting:
            return .pending
        case .deleted:
            return .error
        }
    }

    // MARK: - Actions

    func performCapture(type: CompanionCaptureType) {
        Task {
            do {
                let result: CaptureResult
                switch type {
                case .screenshot:
                    result = try await captureService.captureScreenshot(mode: .fullscreen)
                case .clipboard:
                    guard let clipboardResult = try await captureService.captureFromClipboard() else {
                        print("⚠️ 剪贴板为空")
                        return
                    }
                    result = clipboardResult
                case .selectedText:
                    result = try await captureService.captureFromManualText("")
                case .webpage:
                    // TODO: 获取当前浏览器 URL
                    result = try await captureService.captureFromManualText("")
                }
                _ = result

                // 刷新列表
                loadRecentCaptures()

                // 发送通知
                NotificationCenter.default.post(
                    name: .companionCaptureCompleted,
                    object: nil,
                    userInfo: ["type": type]
                )
            } catch {
                print("⚠️ 捕获失败: \(error.localizedDescription)")
            }
        }
    }

    func showAllCaptures() {
        NotificationCenter.default.post(name: .companionShowInbox, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let companionCaptureCompleted = Notification.Name("companion.captureCompleted")
}
