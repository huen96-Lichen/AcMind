import SwiftUI
import AppKit
import AcMindKit

// MARK: - 快速记录面板
// 快速记录面板 - 轻量文本输入，保存到收集箱

struct QuickNotePanel: View {
    @StateObject private var viewModel = QuickNoteViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            Divider()

            // 输入区
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    AppSurfaceTextEditorShell(text: $viewModel.noteText, minHeight: 170, font: .system(size: 15))
                        .focused($isFocused)

                    if viewModel.noteText.isEmpty {
                        Text("输入快速记录内容...")
                            .font(.system(size: AppSurfaceTokens.Typography.bodyLarge))
                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                }

                // 底部操作栏
                HStack {
                    Text("Cmd+Enter 保存  ·  Esc 关闭")
                        .font(.system(size: AppSurfaceTokens.Typography.caption))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)

                    Spacer()

                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    }

                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondary)
                    .keyboardShortcut(.escape, modifiers: [])

                    Button("保存") {
                        viewModel.save()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 400, height: 320)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
                )
        )
        .onAppear {
            isFocused = true
        }
        .onReceive(viewModel.$didSave) { didSave in
            if didSave {
                dismiss()
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("快速记录")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))

                Text("保存到收集箱")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            AppSurfaceTokens.cardBackgroundSoft
        )
    }
}

// MARK: - 视图模型

@MainActor
final class QuickNoteViewModel: ObservableObject {
    @Published var noteText: String = ""
    @Published var isSaving = false
    @Published var didSave = false

    private let storage: StorageServiceProtocol

    init(storage: StorageServiceProtocol = StorageService()) {
        self.storage = storage
    }

    func save() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSaving = true

        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: String(text.prefix(50)),
            previewText: String(text.prefix(200)),
            metadata: ["source": "quickNote"]
        )

        Task {
            do {
                try await storage.insertSourceItem(item)
                await MainActor.run {
                    isSaving = false
                    didSave = true
                    ToastManager.shared.show(.success, "已保存到收集箱")

                    // 通知刘海面板刷新
                    NotificationCenter.default.post(
                        name: .companionQuickNoteSaved,
                        object: item
                    )
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    ToastManager.shared.show(.error, "保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
