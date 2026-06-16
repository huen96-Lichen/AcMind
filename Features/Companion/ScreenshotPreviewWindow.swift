import AppKit
import SwiftUI
import AcMindKit

// MARK: - Screenshot Preview Window Controller

class ScreenshotPreviewWindowController: NSViewController {
    private let image: NSImage?
    private let captureResult: CaptureResult
    private let onPin: () -> Void
    
    init(image: NSImage?, captureResult: CaptureResult, onPin: @escaping () -> Void) {
        self.image = image
        self.captureResult = captureResult
        self.onPin = onPin
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let previewView = ScreenshotPreviewContentView(
            image: image,
            captureResult: captureResult,
            onPin: onPin
        ) { [weak self] in
            self?.dismiss(nil)
        }
        self.view = NSHostingView(rootView: previewView)
    }
}

// MARK: - Screenshot Preview Content View

struct ScreenshotPreviewContentView: View {
    private static let logger = AcMindLogger(category: .capture)
    let image: NSImage?
    let captureResult: CaptureResult
    let onPin: () -> Void
    let onDismiss: () -> Void
    
    @State private var imageSize: CGSize = .zero

    init(
        image: NSImage?,
        captureResult: CaptureResult,
        onPin: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.image = image
        self.captureResult = captureResult
        self.onPin = onPin
        self.onDismiss = onDismiss
    }
    
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
                
                HStack(spacing: 8) {
                    Button("Pin 到桌面") {
                        onPin()
                    }
                    .buttonStyle(.bordered)

                    Button("保存到收集箱") {
                        saveToInbox()
                        onDismiss()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
            
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
                .frame(minWidth: 560, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
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
                .frame(minWidth: 560, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
                .background(AppSurfaceBackdrop())
            }
        }
        .background(AppSurfaceBackdrop())
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

struct ScreenshotQuickNotePanel: View {
    private static let logger = AcMindLogger(category: .capture)
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool
    private let captureService: CaptureServiceProtocol

    init(captureService: CaptureServiceProtocol = CaptureService()) {
        self.captureService = captureService
    }
    
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
            
            AppSurfaceTextEditorShell(text: $noteText, minHeight: 200, font: .body)
                .focused($isFocused)
            
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
        .background(AppSurfaceBackdrop())
        .onAppear {
            isFocused = true
        }
    }
    
    private func saveNote() {
        guard !noteText.isEmpty else { return }
        
        Task {
            do {
                let result = try await captureService.captureFromManualText(noteText)
                NotificationCenter.default.post(
                    name: Notification.Name("AcMind.captureCompleted"),
                    object: result
                )
            } catch {
                Self.logger.error("保存笔记失败: \(error)")
            }
        }
    }
}
