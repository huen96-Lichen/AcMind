import SwiftUI
import AppKit
import AcMindKit

// MARK: - Quick Note Panel
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
                TextEditor(text: $viewModel.noteText)
                    .font(.system(size: 15))
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(AppSurfaceTokens.cardBackgroundSoft)
                    .cornerRadius(10)
                    .overlay(alignment: .topLeading) {
                        if viewModel.noteText.isEmpty {
                            Text("输入快速记录内容...")
                                .font(.system(size: 15))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }

                // 底部操作栏
                HStack {
                    Text("Cmd+Enter 保存  ·  Esc 关闭")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

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
        .frame(width: 400, height: 300)
        .background(AppSurfaceTokens.background)
        .onAppear {
            isFocused = true
        }
        .onReceive(viewModel.$didSave) { didSave in
            if didSave {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("快速记录")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("保存到收集箱")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - View Model

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
