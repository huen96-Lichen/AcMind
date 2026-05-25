import SwiftUI
import AppKit

// MARK: - Screenshot Selection View

/// 截图区域选择视图
public struct ScreenshotSelectionView: NSViewRepresentable {
    @Binding var selectedRect: CGRect
    @Binding var isSelecting: Bool
    let onComplete: (CGRect) -> Void
    let onCancel: () -> Void
    
    public func makeNSView(context: Context) -> ScreenshotSelectionNSView {
        let view = ScreenshotSelectionNSView(
            selectedRect: $selectedRect,
            isSelecting: $isSelecting,
            onComplete: onComplete,
            onCancel: onCancel
        )
        return view
    }
    
    public func updateNSView(_ nsView: ScreenshotSelectionNSView, context: Context) {
        nsView.selectedRect = selectedRect
        nsView.isSelecting = isSelecting
    }
}

public class ScreenshotSelectionNSView: NSView {
    var selectedRect: CGRect = .zero {
        didSet {
            needsDisplay = true
        }
    }
    var isSelecting: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private let onComplete: (CGRect) -> Void
    private let onCancel: () -> Void
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    
    init(
        selectedRect: Binding<CGRect>,
        isSelecting: Binding<Bool>,
        onComplete: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: NSScreen.main?.frame ?? .zero)
        self.selectedRect = selectedRect.wrappedValue
        self.isSelecting = isSelecting.wrappedValue
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        window?.level = .screenSaver
        window?.makeKeyAndOrderFront(nil)
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override public func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isSelecting = true
    }
    
    override public func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        updateSelectedRect()
    }
    
    override public func mouseUp(with event: NSEvent) {
        if selectedRect.width > 10 && selectedRect.height > 10 {
            onComplete(selectedRect)
        }
        isSelecting = false
        selectedRect = .zero
    }
    
    private func updateSelectedRect() {
        let x = min(startPoint.x, currentPoint.x)
        let y = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        selectedRect = CGRect(x: x, y: y, width: width, height: height)
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制遮罩
        NSColor.black.withAlphaComponent(0.5).setFill()
        bounds.fill()
        
        // 清除选中区域的遮罩
        if isSelecting && !selectedRect.isEmpty {
            NSColor.clear.setFill()
            selectedRect.fill()
            
            // 绘制选中区域边框
            NSColor.accentColor.setStroke()
            let borderPath = NSBezierPath(rect: selectedRect)
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // 绘制尺寸标签
            let sizeString = String(format: "%.0fx%.0f", selectedRect.width, selectedRect.height)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.accentColor
            ]
            let sizeText = NSAttributedString(string: sizeString, attributes: attributes)
            let textSize = sizeText.size()
            
            var textRect = CGRect(
                x: selectedRect.origin.x + 8,
                y: selectedRect.origin.y + selectedRect.height + 8,
                width: textSize.width + 12,
                height: textSize.height + 6
            )
            
            // 确保标签不超出屏幕
            if textRect.origin.y + textRect.height > bounds.height {
                textRect.origin.y = selectedRect.origin.y - textRect.height - 8
            }
            if textRect.origin.x + textRect.width > bounds.width {
                textRect.origin.x = selectedRect.origin.x + selectedRect.width - textRect.width - 8
            }
            
            NSColor.accentColor.setFill()
            textRect.fill()
            sizeText.draw(at: CGPoint(x: textRect.origin.x + 6, y: textRect.origin.y + 3))
        }
    }
    
    override public func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel()
        }
    }
}

// MARK: - Screenshot Preview View

/// 截图预览视图
public struct ScreenshotPreviewView: View {
    let image: NSImage
    let originalRect: CGRect
    let onConfirm: () -> Void
    let onRetake: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var position = CGPoint.zero
    @State private var isDragging = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Button("重新截取") {
                    onRetake()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Text(String(format: "%.0fx%.0f", originalRect.width, originalRect.height))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("确认") {
                    onConfirm()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            .background(AppSurfaceTokens.cardBackgroundSoft)
            
            // 预览区域
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(x: position.x, y: position.y)
                    .onHover { hovering in
                        NSCursor.push(hovering ? .openHand : .arrow)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                position = CGPoint(
                                    x: position.x + value.translation.width,
                                    y: position.y + value.translation.height
                                )
                            }
                    )
            }
            .background(Color.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Screenshot Toolbar View

/// 截图工具栏
public struct ScreenshotToolbarView: View {
    let onFullscreen: () -> Void
    let onArea: () -> Void
    let onWindow: () -> Void
    let onCancel: () -> Void
    
    public var body: some View {
        HStack(spacing: 16) {
            ToolbarButton(
                icon: "monitor",
                label: "全屏",
                action: onFullscreen
            )
            
            ToolbarButton(
                icon: "square.on.square",
                label: "区域",
                action: onArea
            )
            
            ToolbarButton(
                icon: "window",
                label: "窗口",
                action: onWindow
            )
            
            Divider()
            
            ToolbarButton(
                icon: "xmark",
                label: "取消",
                action: onCancel,
                isDestructive: true
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .shadow(radius: 8)
        )
    }
}

private struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    let isDestructive: Bool
    
    init(
        icon: String,
        label: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) {
        self.icon = icon
        self.label = label
        self.action = action
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}