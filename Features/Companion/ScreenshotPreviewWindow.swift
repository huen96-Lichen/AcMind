import AppKit
import SwiftUI

// MARK: - Screenshot Preview Window Controller

class ScreenshotPreviewWindowController: NSViewController {
    private let image: NSImage?
    private let captureResult: CaptureResult
    
    init(image: NSImage?, captureResult: CaptureResult) {
        self.image = image
        self.captureResult = captureResult
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let previewView = ScreenshotPreviewContentView(
            image: image,
            captureResult: captureResult
        ) { [weak self] in
            self?.dismiss(nil)
        }
        self.view = NSHostingView(rootView: previewView)
    }
}

// MARK: - Screenshot Preview Content View

struct ScreenshotPreviewContentView: View {
    let image: NSImage?
    let captureResult: CaptureResult
    let onDismiss: () -> Void
    
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Button("关闭") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                if let size = imageSizeString {
                    Text(size)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("保存到收集箱") {
                    saveToInbox()
                    onDismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // 预览区域
            if let image = image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .onAppear {
                            imageSize = image.size
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("截图已保存")
                        .font(.headline)
                    Text("可在收集箱中查看")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
    
    private var imageSizeString: String? {
        guard imageSize.width > 0 && imageSize.height > 0 else { return nil }
        return String(format: "%.0f x %.0f px", imageSize.width, imageSize.height)
    }
    
    private func saveToInbox() {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureCompleted"),
            object: captureResult
        )
    }
}

// MARK: - Quick Note Panel

struct QuickNotePanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("快速记录")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            
            TextEditor(text: $noteText)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            HStack {
                Spacer()
                Button("保存") {
                    saveNote()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(noteText.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
        .onAppear {
            isFocused = true
        }
    }
    
    private func saveNote() {
        guard !noteText.isEmpty else { return }
        
        Task {
            do {
                let result = try await ServiceContainer.shared.captureService.captureFromManualText(noteText)
                NotificationCenter.default.post(
                    name: Notification.Name("AcMind.captureCompleted"),
                    object: result
                )
            } catch {
                print("保存笔记失败: \(error)")
            }
        }
    }
}
