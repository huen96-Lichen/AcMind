import SwiftUI
import AcMindKit

struct InboxView: View {
    @StateObject private var viewModel = InboxViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // 左侧列表
            listPanel
                .frame(minWidth: 320, idealWidth: 360)

            Divider()

            // 右侧详情
            detailPanel
        }
        .onAppear {
            Task { await viewModel.loadItems() }
        }
    }

    // MARK: - 左侧列表

    private var listPanel: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("收集箱")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("管理和查看已收集的内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 采集按钮
                Menu {
                    Button {
                        Task { await captureScreenshot() }
                    } label: {
                        Label("截图", systemImage: "camera")
                    }

                    Button {
                        Task { await captureClipboard() }
                    } label: {
                        Label("剪贴板", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        Task { await captureFile() }
                    } label: {
                        Label("导入文件", systemImage: "folder")
                    }

                    Button {
                        Task { await captureWebpage() }
                    } label: {
                        Label("网页", systemImage: "link")
                    }

                    Divider()

                    Button {
                        Task { await captureManualText() }
                    } label: {
                        Label("手动输入", systemImage: "text.quote")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            // 统计卡片
            statsCards
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()
                .padding(.horizontal)

            // 筛选
            Picker("状态", selection: $viewModel.statusFilter) {
                Text("全部").tag(nil as SourceItemStatus?)
                Text("待整理").tag(SourceItemStatus.captured as SourceItemStatus?)
                Text("已整理").tag(SourceItemStatus.distilled as SourceItemStatus?)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: viewModel.statusFilter) { _, _ in
                Task { await viewModel.loadItems() }
            }

            // 列表
            List(viewModel.items) { item in
                InboxItemRow(item: item)
                    .onTapGesture {
                        viewModel.selectItem(item)
                    }
                    .contextMenu {
                        Button("生成 Mock Markdown") {
                            viewModel.selectItem(item)
                            Task { await viewModel.generateMarkdownPreview() }
                        }
                        Divider()
                        Button("删除", role: .destructive) {
                            Task { await viewModel.delete(item: item) }
                        }
                    }
            }
            .listStyle(.plain)

            // 底部
            HStack {
                Text("共 \(viewModel.items.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("刷新") { Task { await viewModel.loadItems() } }
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - 统计卡片

    private var statsCards: some View {
        HStack(spacing: 12) {
            StatCard(title: "今日新增", value: "\(viewModel.todayCount)", icon: "plus.circle.fill", color: .blue)
            StatCard(title: "待整理", value: "\(viewModel.pendingCount)", icon: "clock.fill", color: .orange)
            StatCard(title: "已整理", value: "\(viewModel.distilledCount)", icon: "checkmark.circle.fill", color: .green)
        }
    }

    // MARK: - 右侧详情

    private var detailPanel: some View {
        Group {
            if let item = viewModel.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 标题
                        Text(item.title ?? "未命名")
                            .font(.title3)
                            .fontWeight(.semibold)

                        // 元信息
                        HStack(spacing: 16) {
                            Label(item.source.displayName, systemImage: "folder")
                            Label(item.type.rawValue, systemImage: "doc")
                            InboxStatusBadge(status: item.status)
                            Text(item.createdAt, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Divider()

                        // 内容
                        if let preview = item.previewText {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("内容预览")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(preview)
                                    .font(.body)
                            }
                        }

                        Divider()

                        // Markdown 预览
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Markdown 预览")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if viewModel.markdownPreview == nil {
                                    Button("生成 Mock Markdown") {
                                        Task { await viewModel.generateMarkdownPreview() }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            if let md = viewModel.markdownPreview {
                                Text(md)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(NSColor.separatorColor))
                                    )
                            } else {
                                Text("点击上方按钮生成 Markdown 预览")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("选择一条记录查看详情")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 20))
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - InboxItemRow

private struct InboxItemRow: View {
    let item: SourceItem

    var body: some View {
        HStack(spacing: 10) {
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
                HStack(spacing: 6) {
                    InboxStatusBadge(status: item.status)
                    Text(item.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func iconForType(_ type: SourceType) -> String {
        switch type {
        case .text: return "text.quote"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.text"
        case .docx: return "doc.text.fill"
        case .screenshot: return "camera.viewfinder"
        case .webpage: return "globe"
        case .unknownFile: return "doc"
        }
    }
}

// MARK: - StatusBadge

struct InboxStatusBadge: View {
    let status: SourceItemStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForStatus(status).opacity(0.15))
            .foregroundColor(colorForStatus(status))
            .cornerRadius(4)
    }

    private func colorForStatus(_ status: SourceItemStatus) -> Color {
        switch status {
        case .inbox: return .teal
        case .pending: return .gray
        case .capturing: return .blue
        case .captured: return .green
        case .parsing: return .orange
        case .parsed: return .cyan
        case .distilling: return .purple
        case .distilled: return .indigo
        case .exporting: return .yellow
        case .exported: return .mint
        case .archived: return .secondary
        case .deleted: return .red
        }
    }
}

extension SourceOrigin {
    var displayName: String {
        switch self {
        case .manual: return "手动"
        case .clipboard: return "剪贴板"
        case .screenshot: return "截图"
        case .webpage: return "网页"
        case .file: return "文件"
        case .voice: return "语音"
        case .capsule: return "胶囊"
        case .imported: return "导入"
        }
    }
}

// MARK: - Capture Actions

extension InboxView {
    private func captureScreenshot() async {
        do {
            let captureService = ServiceContainer.shared.captureService
            let result = try await captureService.captureScreenshot(mode: .fullscreen)
            print("截图成功: \(result.sourceItem.id)")
            await viewModel.loadItems()
        } catch {
            print("截图失败: \(error)")
        }
    }

    private func captureClipboard() async {
        do {
            let captureService = ServiceContainer.shared.captureService
            if let result = try await captureService.captureFromClipboard() {
                print("剪贴板采集成功: \(result.sourceItem.id)")
                await viewModel.loadItems()
            } else {
                print("剪贴板无内容")
            }
        } catch {
            print("剪贴板采集失败: \(error)")
        }
    }

    private func captureFile() async {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false

            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }

            Task {
                do {
                    let captureService = ServiceContainer.shared.captureService
                    let result = try await captureService.captureFromFile(url: url)
                    print("文件采集成功: \(result.sourceItem.id)")
                    await viewModel.loadItems()
                } catch {
                    print("文件采集失败: \(error)")
                }
            }
        }
    }

    private func captureWebpage() async {
        // 显示输入对话框
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "输入网页地址"
            alert.informativeText = "请输入要采集的网页 URL"
            alert.alertStyle = .informational

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = "https://"
            alert.accessoryView = input

            alert.addButton(withTitle: "采集")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                let urlString = input.stringValue
                guard let url = URL(string: urlString), urlString.hasPrefix("http") else {
                    print("无效的 URL")
                    return
                }

                Task {
                    do {
                        let captureService = ServiceContainer.shared.captureService
                        let result = try await captureService.captureFromWebpage(url: url)
                        print("网页采集成功: \(result.sourceItem.id)")
                        await viewModel.loadItems()
                    } catch {
                        print("网页采集失败: \(error)")
                    }
                }
            }
        }
    }

    private func captureManualText() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "手动输入文本"
            alert.informativeText = "请输入要保存的文本内容"
            alert.alertStyle = .informational

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
            let textView = NSTextView(frame: scrollView.bounds)
            textView.isRichText = false
            textView.font = NSFont.systemFont(ofSize: 13)
            scrollView.documentView = textView
            alert.accessoryView = scrollView

            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                let text = textView.string
                guard !text.isEmpty else { return }

                Task {
                    do {
                        let captureService = ServiceContainer.shared.captureService
                        let result = try await captureService.captureFromManualText(text)
                        print("文本采集成功: \(result.sourceItem.id)")
                        await viewModel.loadItems()
                    } catch {
                        print("文本采集失败: \(error)")
                    }
                }
            }
        }
    }
}
