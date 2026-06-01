import Foundation
import AppKit

// MARK: - Companion Menu Bar Layout Configuration

/// Companion 刘海布局参数
public struct CompanionMenuBarLayout {
    // MARK: - 尺寸参数
    
    /// 收起态高度
    public static let collapsedHeight: CGFloat = 30
    
    /// 收起态宽度
    public static let collapsedWidth: CGFloat = 220
    
    /// 收起态最小宽度
    public static let collapsedMinWidth: CGFloat = 185
    
    /// 收起态最大宽度
    public static let collapsedMaxWidth: CGFloat = 240

    public static let nonNotchCollapsedWidth: CGFloat = 220
    public static let collapsedMinHeight: CGFloat = 28
    public static let collapsedMaxHeight: CGFloat = 38
    
    /// 展开态宽度
    public static let expandedWidth: CGFloat = 880
    
    /// 展开态高度
    public static let expandedHeight: CGFloat = 440
    
    /// 展开态最大高度占屏幕比例
    public static let expandedMaxHeightRatio: CGFloat = 0.58

    /// 模块间距
    public static let moduleSpacing: CGFloat = 20

    /// 底部间隙
    public static let moduleBottomInset: CGFloat = 12
    
    // MARK: - 定位参数
    
    /// 菜单栏顶部内边距
    public static let menuBarTopPadding: CGFloat = 0
    
    /// 菜单栏侧边内边距
    public static let menuBarSidePadding: CGFloat = 0
    
    /// 物理刘海估计宽度
    public static let hardwareNotchEstimatedWidth: CGFloat = 210
    
    /// 物理刘海避让间距
    public static let hardwareNotchAvoidanceGap: CGFloat = 0
    
    /// 左侧 App 菜单预留宽度
    public static let leftMenuReserve: CGFloat = 120
    
    /// 右侧系统状态栏预留宽度
    public static let rightSystemReserve: CGFloat = 180
    
    // MARK: - 圆角参数
    
    /// 收起态圆角
    public static let cornerRadiusCollapsed: CGFloat = 18
    
    /// 展开态圆角
    public static let cornerRadiusExpanded: CGFloat = 30
    
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
    public static var menuBarHeight: CGFloat {
        let screen = mainScreen
        return max(screen.safeAreaInsets.top, 22)
    }

    /// 获取指定屏幕的菜单栏高度
    public static func menuBarHeight(on screen: NSScreen) -> CGFloat {
        max(screen.safeAreaInsets.top, 22)
    }
    
    /// 判断是否有物理刘海
    public static func hasHardwareNotch() -> Bool {
        let screen = mainScreen
        return screen.safeAreaInsets.top > 28
    }

    /// 判断指定屏幕是否有物理刘海
    public static func hasHardwareNotch(on screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 28
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

    /// 返回给定窗口最应该停靠的屏幕 frame
    public static func preferredScreenFrame(for frame: CGRect, screenFrames: [CGRect]) -> CGRect? {
        guard let first = screenFrames.first else { return nil }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let containing = screenFrames.first(where: { $0.contains(center) }) {
            return containing
        }

        func intersectionArea(_ screenFrame: CGRect) -> CGFloat {
            let overlap = screenFrame.intersection(frame)
            guard !overlap.isNull, !overlap.isEmpty else { return 0 }
            return overlap.width * overlap.height
        }

        return screenFrames.max { intersectionArea($0) < intersectionArea($1) } ?? first
    }

    /// 计算收起态胶囊位置
    public static func collapsedFrame(preferredWidth: CGFloat = CompanionMenuBarLayout.collapsedMinWidth) -> CGRect {
        let screen = mainScreen
        let settings = CompanionDisplaySettingsStore.load()
        return collapsedFrame(on: screen.frame, screen: screen, settings: settings, preferredWidth: preferredWidth)
    }

    /// 计算指定屏幕上的收起态胶囊位置
    public static func collapsedFrame(on screenFrame: CGRect, preferredWidth: CGFloat = CompanionMenuBarLayout.collapsedMinWidth) -> CGRect {
        let screen = NSScreen.screens.first(where: { $0.frame.equalTo(screenFrame) }) ?? mainScreen
        let settings = CompanionDisplaySettingsStore.load()
        return collapsedFrame(on: screenFrame, screen: screen, settings: settings, preferredWidth: preferredWidth)
    }

    public static func displayIdentifier(for screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display-\(number.intValue)"
        }
        return screen.localizedName
    }

    public static func resolvedCollapsedWidth(
        screenWidth: CGFloat,
        auxiliaryTopLeftWidth: CGFloat,
        auxiliaryTopRightWidth: CGFloat,
        hasHardwareNotch: Bool,
        preferredNonNotchWidth: CGFloat
    ) -> CGFloat {
        if hasHardwareNotch {
            let resolved = screenWidth - auxiliaryTopLeftWidth - auxiliaryTopRightWidth
            return min(max(resolved, CompanionMenuBarLayout.collapsedMinWidth), CompanionMenuBarLayout.collapsedMaxWidth)
        }

        let requested = max(preferredNonNotchWidth, CompanionMenuBarLayout.collapsedMinWidth)
        return min(requested, CompanionMenuBarLayout.collapsedMaxWidth)
    }

    public static func resolvedCollapsedHeight(
        safeAreaTop: CGFloat,
        menuBarHeight: CGFloat,
        hasHardwareNotch: Bool,
        notchHeightMode: CompanionCollapsedHeightMode,
        notchCustomHeight: CGFloat,
        nonNotchHeightMode: CompanionNonNotchHeightMode,
        nonNotchCustomHeight: CGFloat
    ) -> CGFloat {
        let resolved: CGFloat
        if hasHardwareNotch {
            switch notchHeightMode {
            case .matchHardwareNotch:
                resolved = max(safeAreaTop, 30)
            case .matchMenuBar:
                resolved = menuBarHeight
            case .custom:
                resolved = notchCustomHeight
            }
        } else {
            switch nonNotchHeightMode {
            case .matchMenuBar:
                resolved = max(menuBarHeight, CompanionMenuBarLayout.collapsedHeight)
            case .matchNotchReference:
                resolved = 30
            case .custom:
                resolved = nonNotchCustomHeight
            }
        }

        return min(max(resolved, CompanionMenuBarLayout.collapsedMinHeight), CompanionMenuBarLayout.collapsedMaxHeight)
    }

    /// 计算展开态面板位置
    public static func expandedFrame(anchorFrame _: CGRect) -> CGRect {
        let screen = mainScreen
        let width = CompanionMenuBarLayout.expandedWidth
        let height = CompanionMenuBarLayout.expandedHeight
        let x = screen.frame.midX - width / 2
        let clampedX = max(screen.frame.minX, min(x, screen.frame.maxX - width))
        let y = screen.frame.maxY - height

        return CGRect(
            x: clampedX,
            y: y,
            width: width,
            height: height
        )
    }

    /// 计算指定屏幕上的展开态面板位置
    public static func expandedFrame(on screenFrame: CGRect) -> CGRect {
        let width = CompanionMenuBarLayout.expandedWidth
        let height = CompanionMenuBarLayout.expandedHeight
        let x = screenFrame.midX - width / 2
        let clampedX = max(screenFrame.minX, min(x, screenFrame.maxX - width))
        let y = screenFrame.maxY - height

        return CGRect(
            x: clampedX,
            y: y,
            width: width,
            height: height
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

    private static func collapsedFrame(
        on screenFrame: CGRect,
        screen: NSScreen,
        settings: CompanionDisplaySettings,
        preferredWidth: CGFloat
    ) -> CGRect {
        let hasNotch = hasHardwareNotch(on: screen)
        let width = resolvedCollapsedWidth(
            screenWidth: screen.frame.width,
            auxiliaryTopLeftWidth: screen.auxiliaryTopLeftArea?.width ?? 0,
            auxiliaryTopRightWidth: screen.auxiliaryTopRightArea?.width ?? 0,
            hasHardwareNotch: hasNotch,
            preferredNonNotchWidth: max(preferredWidth, settings.nonNotchCollapsedWidth)
        )
        let height = resolvedCollapsedHeight(
            safeAreaTop: screen.safeAreaInsets.top,
            menuBarHeight: menuBarHeight(on: screen),
            hasHardwareNotch: hasNotch,
            notchHeightMode: settings.notchHeightMode,
            notchCustomHeight: settings.notchCustomHeight,
            nonNotchHeightMode: settings.nonNotchHeightMode,
            nonNotchCustomHeight: settings.nonNotchCustomHeight
        )

        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
