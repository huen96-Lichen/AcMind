import Foundation

// MARK: - WebView Page (DEPRECATED)

/// ⚠️ WebView 过渡页面枚举
/// 
/// 【重要】WebView 仅作为临时过渡方案，所有页面都应迁移到原生 SwiftUI。
/// 禁止在此添加新的 WebView 页面。
/// 
/// 迁移状态：
/// - ✅ 已完成：Agent, Inbox, Clipboard, Schedule, Workbench, Tools, Settings
/// - 🚧 过渡中：Shelf (复杂交互待迁移)
/// - ⛔ 已禁用：Capture, Distill, Export, Knowledge, Voice (已原生实现)
///
/// 预计完全移除 WebView：2025 Q2
enum WebViewPage: String, CaseIterable {
    
    // MARK: - 已迁移到原生 (保留用于兼容性检查)
    
    /// ✅ 已迁移到 AgentView.swift
    /// 退场条件：AgentView 功能完整
    /// 验收标准：聊天、蒸馏、语音输入全部可用
    @available(*, deprecated, message: "已迁移到原生 AgentView，请勿使用")
    case agent = "agent"
    
    /// ✅ 已迁移到 InboxView.swift
    /// 退场条件：InboxView 功能完整
    /// 验收标准：列表、搜索、蒸馏、导出全部可用
    @available(*, deprecated, message: "已迁移到原生 InboxView，请勿使用")
    case inbox = "inbox"
    
    /// ✅ 已迁移到 ClipboardView.swift
    /// 退场条件：ClipboardView 功能完整
    /// 验收标准：历史、搜索、pin/unpin、保存到 Inbox 全部可用
    @available(*, deprecated, message: "已迁移到原生 ClipboardView，请勿使用")
    case clipboard = "clipboard"
    
    /// ✅ 已迁移到 ScheduleNativeView.swift
    /// 退场条件：ScheduleNativeView 功能完整
    /// 验收标准：日历视图、事件列表、提醒功能全部可用
    @available(*, deprecated, message: "已迁移到原生 ScheduleNativeView，请勿使用")
    case schedule = "schedule"
    
    /// ✅ 已迁移到 WorkbenchView.swift
    /// 退场条件：WorkbenchView 功能完整
    /// 验收标准：统计、快速操作、知识卡片预览全部可用
    @available(*, deprecated, message: "已迁移到原生 WorkbenchView，请勿使用")
    case workbench = "workbench"
    
    /// ✅ 已迁移到 ToolsView.swift
    /// 退场条件：ToolsView 功能完整
    /// 验收标准：文件转换、OCR、任务管理全部可用
    @available(*, deprecated, message: "已迁移到原生 ToolsView，请勿使用")
    case tools = "tools"
    
    /// ✅ 已迁移到 SettingsView.swift
    /// 退场条件：SettingsView 功能完整
    /// 验收标准：所有设置项可配置、权限管理、快捷键设置全部可用
    @available(*, deprecated, message: "已迁移到原生 SettingsView，请勿使用")
    case settings = "settings"
    
    // MARK: - 已禁用 (原生实现已替代)
    
    /// ⛔ 已禁用 - CaptureService 已原生实现
    @available(*, unavailable, message: "CaptureService 已原生实现，请使用原生 API")
    case capture = "capture"
    
    /// ⛔ 已禁用 - DistillService 已原生实现
    @available(*, unavailable, message: "DistillService 已原生实现，请使用原生 API")
    case distill = "distill"
    
    /// ⛔ 已禁用 - ExportService 已原生实现
    @available(*, unavailable, message: "ExportService 已原生实现，请使用原生 API")
    case export = "export"
    
    /// ⛔ 已禁用 - KnowledgeService 已原生实现
    @available(*, unavailable, message: "KnowledgeService 已原生实现，请使用原生 API")
    case knowledge = "knowledge"
    
    /// ⛔ 已禁用 - VoiceService 已原生实现
    @available(*, unavailable, message: "VoiceService 已原生实现，请使用原生 API")
    case voice = "voice"
    
    // MARK: - 过渡中 (允许临时使用)
    
    /// 🚧 过渡中 - Shelf 页面
    /// 保留原因：复杂拖拽交互需要更多时间迁移
    /// 迁移计划：Task 14 完成 Shelf 原生实现
    /// 退场条件：ShelfView 实现拖拽、多选、批量操作
    /// 预计完成：2025-05-15
    case shelf = "shelf"

    static var allCases: [WebViewPage] {
        ["agent", "inbox", "clipboard", "schedule", "workbench", "tools", "settings", "shelf"]
            .compactMap(WebViewPage.init(rawValue:))
    }
    
    // MARK: - Properties
    
    var htmlFile: String {
        switch self {
        case .shelf:
            return "index"
        default:
            // 已迁移/禁用的页面返回空页面
            return "deprecated"
        }
    }
    
    var queryParams: [String: String] {
        switch self {
        case .shelf:
            return ["view": "shelf"]
        default:
            return [:]
        }
    }
    
    /// 检查是否允许使用 WebView
    var isAllowed: Bool {
        switch self {
        case .shelf:
            return true
        default:
            return false
        }
    }
    
    /// 获取迁移提示信息
    var migrationMessage: String {
        switch self {
        case .agent:
            return "请使用 AgentView 替代"
        case .inbox:
            return "请使用 InboxView 替代"
        case .clipboard:
            return "请使用 ClipboardView 替代"
        case .schedule:
            return "请使用 ScheduleNativeView 替代"
        case .workbench:
            return "请使用 WorkbenchView 替代"
        case .tools:
            return "请使用 ToolsView 替代"
        case .settings:
            return "请使用 SettingsView 替代"
        case .shelf:
            return "Shelf 正在迁移中，预计 2025-05-15 完成"
        default:
            return "该页面已完全迁移到原生实现"
        }
    }
}

// MARK: - WebView 使用检查

/// WebView 使用检查器
/// 用于在编译期和运行期阻止新业务使用 WebView
enum WebViewGuard {
    
    /// 检查页面是否允许使用 WebView
    /// - Parameter page: 要检查的页面
    /// - Returns: 如果允许返回 true，否则触发断言失败
    static func check(_ page: WebViewPage) -> Bool {
        guard page.isAllowed else {
            #if DEBUG
            fatalError("⛔ WebView 页面 '\(page)' 已被禁用。\(page.migrationMessage)")
            #else
            print("⚠️ WebView 页面 '\(page)' 已被禁用，自动切换到原生实现")
            return false
            #endif
        }
        return true
    }
    
    /// 获取允许使用的 WebView 页面列表
    static var allowedPages: [WebViewPage] {
        WebViewPage.allCases.filter { $0.isAllowed }
    }
    
    /// 打印迁移状态报告
    static func printMigrationReport() {
        print("=" * 50)
        print("📋 WebView 迁移状态报告")
        print("=" * 50)
        
        let allPages = WebViewPage.allCases
        let allowed = allPages.filter { $0.isAllowed }
        let deprecated = allPages.filter { !$0.isAllowed && !$0.isUnavailable }
        let unavailable = allPages.filter { $0.isUnavailable }
        
        print("\n✅ 允许使用 (\(allowed.count)):")
        allowed.forEach { print("  - \($0.rawValue): \($0.migrationMessage)") }
        
        print("\n⚠️ 已弃用 (\(deprecated.count)):")
        deprecated.forEach { print("  - \($0.rawValue): \($0.migrationMessage)") }
        
        print("\n⛔ 已禁用 (\(unavailable.count)):")
        unavailable.forEach { print("  - \($0.rawValue): \($0.migrationMessage)") }
        
        print("\n" + "=" * 50)
        print("预计完全移除 WebView: 2025 Q2")
        print("=" * 50)
    }
}

// MARK: - String Extension

private extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}

// MARK: - WebViewPage Extension

extension WebViewPage {
    /// 检查是否不可用 (unavailable)
    var isUnavailable: Bool {
        ["capture", "distill", "export", "knowledge", "voice"].contains(rawValue)
    }
}
