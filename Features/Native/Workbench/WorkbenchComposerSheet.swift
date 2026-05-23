import SwiftUI

struct WorkbenchComposerSheet: View {
    @Binding var title: String
    @Binding var content: String
    let onCancel: () -> Void
    let onSave: (_ title: String, _ content: String) -> Void
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { onCancel() }
                Spacer()
                Text("新建本地笔记")
                    .font(.headline)
                Spacer()
                Button("保存") {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedContent.isEmpty else {
                        toastManager.show(.warning, "内容不能为空")
                        return
                    }

                    let resolvedTitle = trimmedTitle.isEmpty ? "未命名笔记" : trimmedTitle
                    onSave(resolvedTitle, trimmedContent)
                    toastManager.show(.success, "已创建本地笔记")
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                TextField("标题", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $content)
                    .font(.system(size: 14))
                    .frame(minHeight: 260)
            }
            .padding()
        }
        .frame(width: 700, height: 460)
    }
}
