import SwiftUI
import AcMindKit

// MARK: - Tools View

/// 工具台页面
/// 功能：文件转换、OCR、ZTools、Agent 任务管理
struct ToolsView: View {
    @StateObject private var viewModel = ToolsViewModel()

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    loadingState
                } else {
                    readyState
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载工具...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ready State

    private var readyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 文件转换
                fileConversionSection

                // OCR 工具
                ocrSection

                // 任务管理
                taskManagementSection

                // 系统工具
                systemToolsSection
            }
            .padding(32)
            .frame(maxWidth: 800, alignment: .leading)
        }
    }

    // MARK: - File Conversion

    private var fileConversionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文件转换")
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                ToolCard(
                    title: "PDF 转文本",
                    icon: "doc.text",
                    description: "提取 PDF 中的文字内容"
                ) {
                    viewModel.showPDFToText = true
                }

                ToolCard(
                    title: "图片转 Markdown",
                    icon: "photo",
                    description: "OCR 识别并生成 Markdown"
                ) {
                    viewModel.showImageToMarkdown = true
                }

                ToolCard(
                    title: "批量重命名",
                    icon: "textformat.abc",
                    description: "按规则批量重命名文件"
                ) {
                    viewModel.showBatchRename = true
                }
            }
        }
    }

    // MARK: - OCR Section

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OCR 识别")
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                ToolCard(
                    title: "截图 OCR",
                    icon: "camera.viewfinder",
                    description: "截图并识别文字"
                ) {
                    Task { await viewModel.captureAndOCR() }
                }

                ToolCard(
                    title: "图片 OCR",
                    icon: "photo.on.rectangle",
                    description: "选择图片识别文字"
                ) {
                    viewModel.showImageOCR = true
                }

                ToolCard(
                    title: "批量 OCR",
                    icon: "square.stack.3d.up",
                    description: "批量处理图片"
                ) {
                    viewModel.showBatchOCR = true
                }
            }
        }
    }

    // MARK: - Task Management

    private var taskManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("任务队列")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                if viewModel.runningTasks > 0 {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("\(viewModel.runningTasks) 个任务运行中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if viewModel.recentTasks.isEmpty {
                Text("暂无任务")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentTasks.prefix(5)) { task in
                        TaskRow(task: task)
                    }
                }
            }
        }
    }

    // MARK: - System Tools

    private var systemToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统工具")
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                ToolCard(
                    title: "清理缓存",
                    icon: "trash",
                    description: "清理临时文件和缓存"
                ) {
                    Task { await viewModel.clearCache() }
                }

                ToolCard(
                    title: "导出数据",
                    icon: "square.and.arrow.up",
                    description: "导出所有数据为 JSON"
                ) {
                    Task { await viewModel.exportData() }
                }

                ToolCard(
                    title: "系统信息",
                    icon: "info.circle",
                    description: "查看应用和系统信息"
                ) {
                    viewModel.showSystemInfo = true
                }
            }
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let title: String
    let icon: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.accent)
                    Spacer()
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: ProcessJob

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(taskTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let progress = task.progress {
                    ProgressView(value: progress)
                        .frame(width: 100)
                }
            }

            Spacer()

            Text(task.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusBackground)
                .cornerRadius(4)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusIcon: some View {
        switch task.status {
        case .queued:
            return Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .running:
            return Image(systemName: "play.circle.fill")
                .foregroundStyle(.blue)
        case .completed:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            return Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .cancelled:
            return Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private var statusBackground: Color {
        switch task.status {
        case .queued: return Color.gray.opacity(0.2)
        case .running: return Color.blue.opacity(0.2)
        case .completed: return Color.green.opacity(0.2)
        case .failed: return Color.red.opacity(0.2)
        case .cancelled: return Color.gray.opacity(0.2)
        }
    }

    private var taskTitle: String {
        switch task.jobType {
        case .distill: return "蒸馏"
        case .export: return "导出"
        case .ocr: return "OCR"
        case .imported: return "导入"
        case .custom: return "自定义任务"
        }
    }
}

// MARK: - View Model

@MainActor
class ToolsViewModel: ObservableObject {
    @Published var isLoading = false

    @Published var runningTasks = 0
    @Published var recentTasks: [ProcessJob] = []

    // Sheet 状态
    @Published var showPDFToText = false
    @Published var showImageToMarkdown = false
    @Published var showBatchRename = false
    @Published var showImageOCR = false
    @Published var showBatchOCR = false
    @Published var showSystemInfo = false

    private let taskQueue: TaskQueue
    private let captureService: CaptureService

    init(
        taskQueue: TaskQueue = TaskQueue(),
        captureService: CaptureService = ServiceContainer.shared.captureService
    ) {
        self.taskQueue = taskQueue
        self.captureService = captureService
    }

    func captureAndOCR() async {
        do {
            _ = try await captureService.captureScreenshot(mode: .fullscreen)
            // 触发 OCR 任务
        } catch {
            print("截图失败: \(error)")
        }
    }

    func clearCache() async {
        // 清理缓存逻辑
    }

    func exportData() async {
        // 导出数据逻辑
    }
}
