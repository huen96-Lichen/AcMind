import Foundation
import AppKit

// MARK: - Companion Menu Bar Layout Configuration

/// Companion 刘海布局参数
public struct CompanionMenuBarLayout {
    // MARK: - 尺寸参数
    
    /// 收起态高度
    public static let collapsedHeight: CGFloat = 30
    
    /// 收起态最小宽度
    public static let collapsedMinWidth: CGFloat = 240
    
    /// 收起态最大宽度
    public static let collapsedMaxWidth: CGFloat = 420
    
    /// 展开态宽度
    public static let expandedWidth: CGFloat = 720
    
    /// 展开态最大高度占屏幕比例
    public static let expandedMaxHeightRatio: CGFloat = 0.6
    
    // MARK: - 定位参数
    
    /// 菜单栏顶部内边距
    public static let menuBarTopPadding: CGFloat = 2
    
    /// 菜单栏侧边内边距
    public static let menuBarSidePadding: CGFloat = 12
    
    /// 物理刘海估计宽度
    public static let hardwareNotchEstimatedWidth: CGFloat = 210
    
    /// 物理刘海避让间距
    public static let hardwareNotchAvoidanceGap: CGFloat = 16
    
    /// 左侧 App 菜单预留宽度
    public static let leftMenuReserve: CGFloat = 120
    
    /// 右侧系统状态栏预留宽度
    public static let rightSystemReserve: CGFloat = 180
    
    // MARK: - 圆角参数
    
    /// 收起态圆角
    public static let cornerRadiusCollapsed: CGFloat = 16
    
    /// 展开态圆角
    public static let cornerRadiusExpanded: CGFloat = 28
    
    // MARK: - 动画参数
    
    /// 展开动画时长
    public static let expandDuration: TimeInterval = 0.22
    
    /// 收起动画时长
    public static let collapseDuration: TimeInterval = 0.18
    
    /// 弹簧响应参数
    public static let springResponse: CGFloat = 0.28
    
    /// 弹簧阻尼参数
    public static let springDamping: CGFloat = 0.86
}

// MARK: - Companion Screen Positioning

/// Companion 屏幕定位算法
@MainActor
public struct CompanionScreenPositioning {
    /// 获取当前主屏幕
    private static var mainScreen: NSScreen {
        NSScreen.main ?? NSScreen.screens.first!
    }
    
    /// 获取菜单栏高度
    private static var menuBarHeight: CGFloat {
        let screen = mainScreen
        return max(screen.safeAreaInsets.top, 22)
    }
    
    /// 判断是否有物理刘海
    public static func hasHardwareNotch() -> Bool {
        let screen = mainScreen
        return screen.safeAreaInsets.top > 28
    }
    
    /// 获取物理刘海区域
    private static func notchRect() -> CGRect {
        let screen = mainScreen
        let centerX = screen.frame.midX
        let notchWidth = CompanionMenuBarLayout.hardwareNotchEstimatedWidth
        let menuBarY = screen.frame.maxY - menuBarHeight
        
        return CGRect(
            x: centerX - notchWidth / 2,
            y: menuBarY,
            width: notchWidth,
            height: menuBarHeight
        )
    }
    
    /// 计算收起态胶囊位置
    public static func collapsedFrame(preferredWidth: CGFloat = CompanionMenuBarLayout.collapsedMinWidth) -> CGRect {
        let screen = mainScreen
        let visibleFrame = screen.visibleFrame
        let screenFrame = screen.frame
        
        let width = min(max(preferredWidth, CompanionMenuBarLayout.collapsedMinWidth), CompanionMenuBarLayout.collapsedMaxWidth)
        
        if hasHardwareNotch() {
            return collapsedFrameWithNotch(width: width, screen: screen, visibleFrame: visibleFrame)
        } else {
            let x = visibleFrame.midX - width / 2
            let y = visibleFrame.maxY - CompanionMenuBarLayout.collapsedHeight - CompanionMenuBarLayout.menuBarTopPadding
            
            return CGRect(
                x: x,
                y: y,
                width: width,
                height: CompanionMenuBarLayout.collapsedHeight
            )
        }
    }
    
    /// 有刘海设备的收起态位置计算
    private static func collapsedFrameWithNotch(width: CGFloat, screen: NSScreen, visibleFrame: NSRect) -> CGRect {
        let screenFrame = screen.frame
        let notch = notchRect()
        
        let rightSlotWidth = screenFrame.maxX - notch.maxX - CompanionMenuBarLayout.hardwareNotchAvoidanceGap - CompanionMenuBarLayout.rightSystemReserve
        let leftSlotWidth = notch.minX - CompanionMenuBarLayout.hardwareNotchAvoidanceGap - CompanionMenuBarLayout.leftMenuReserve
        
        var x: CGFloat
        
        if rightSlotWidth >= width {
            x = notch.maxX + CompanionMenuBarLayout.hardwareNotchAvoidanceGap + (rightSlotWidth - width) / 2
        } else if leftSlotWidth >= width {
            x = CompanionMenuBarLayout.leftMenuReserve + (leftSlotWidth - width) / 2
        } else {
            x = visibleFrame.midX - width / 2
        }
        
        let y = visibleFrame.maxY - CompanionMenuBarLayout.collapsedHeight - CompanionMenuBarLayout.menuBarTopPadding
        
        return CGRect(
            x: x,
            y: y,
            width: width,
            height: CompanionMenuBarLayout.collapsedHeight
        )
    }
    
    /// 计算展开态面板位置
    public static func expandedFrame(anchorFrame: CGRect) -> CGRect {
        let screen = mainScreen
        let visibleFrame = screen.visibleFrame
        
        let width = CompanionMenuBarLayout.expandedWidth
        let maxHeight = visibleFrame.height * CompanionMenuBarLayout.expandedMaxHeightRatio
        
        let x = anchorFrame.midX - width / 2
        let clampedX = max(visibleFrame.minX + CompanionMenuBarLayout.menuBarSidePadding, min(x, visibleFrame.maxX - width - CompanionMenuBarLayout.menuBarSidePadding))
        let y = anchorFrame.minY - maxHeight - 8
        
        let clampedY = max(visibleFrame.minY, y)
        let actualHeight = maxHeight - (anchorFrame.minY - clampedY)
        
        return CGRect(
            x: clampedX,
            y: clampedY,
            width: width,
            height: max(actualHeight, 200)
        )
    }
    
    /// 更新窗口层级为菜单栏层级
    public static func configureWindowLevel(_ window: NSWindow) {
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
    }
}