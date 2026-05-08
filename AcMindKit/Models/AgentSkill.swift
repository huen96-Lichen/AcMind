import Foundation

// MARK: - AgentSkill（Agent 技能模型）

/// 技能分类
public enum SkillCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case execution   // 执行技能
    case workflow   // 工作流技能
    case project    // 项目技能库

    public var displayName: String {
        switch self {
        case .execution: return "执行技能"
        case .workflow: return "工作流技能"
        case .project: return "项目技能"
        }
    }

    public var description: String {
        switch self {
        case .execution: return "用于执行特定类型任务的技能"
        case .workflow: return "用于串联多个步骤的工作流技能"
        case .project: return "与特定项目相关的技能"
        }
    }
}

/// 技能来源
public enum SkillSource: String, Codable, Sendable, Hashable {
    case builtin       // 内置技能
    case userCreated   // 用户创建
    case agentGenerated // Agent 自动生成
    case imported      // 从 Hermes/Skill Hub 导入

    public var displayName: String {
        switch self {
        case .builtin: return "内置"
        case .userCreated: return "用户创建"
        case .agentGenerated: return "AI 生成"
        case .imported: return "导入"
        }
    }
}

/// 技能状态
public enum SkillStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case active
    case disabled
    case archived

    public var displayName: String {
        switch self {
        case .active: return "启用"
        case .disabled: return "禁用"
        case .archived: return "归档"
        }
    }
}

/// Agent 技能
public struct AgentSkill: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var category: SkillCategory
    public var description: String
    public var content: String
    public var source: SkillSource
    public var status: SkillStatus
    public var tags: [String]
    public var triggerKeywords: [String]
    public var promptTemplate: String?
    public var useCount: Int
    public var viewCount: Int
    public var lastUsedAt: Date?
    public var provenance: SkillProvenance?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: SkillCategory,
        description: String = "",
        content: String = "",
        source: SkillSource = .userCreated,
        status: SkillStatus = .active,
        tags: [String] = [],
        triggerKeywords: [String] = [],
        promptTemplate: String? = nil,
        useCount: Int = 0,
        viewCount: Int = 0,
        lastUsedAt: Date? = nil,
        provenance: SkillProvenance? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.content = content
        self.source = source
        self.status = status
        self.tags = tags
        self.triggerKeywords = triggerKeywords
        self.promptTemplate = promptTemplate
        self.useCount = useCount
        self.viewCount = viewCount
        self.lastUsedAt = lastUsedAt
        self.provenance = provenance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 技能溯源信息
public struct SkillProvenance: Codable, Sendable, Equatable {
    public var originType: OriginType
    public var originId: String?
    public var sourceSkillId: String?
    public var parentSkillId: String?
    public var version: Int

    public enum OriginType: String, Codable, Sendable {
        case created
        case derived
        case imported
        case migrated
    }

    public init(
        originType: OriginType,
        originId: String? = nil,
        sourceSkillId: String? = nil,
        parentSkillId: String? = nil,
        version: Int = 1
    ) {
        self.originType = originType
        self.originId = originId
        self.sourceSkillId = sourceSkillId
        self.parentSkillId = parentSkillId
        self.version = version
    }
}

// MARK: - SkillFilter

public struct SkillFilter: Codable, Sendable, Equatable {
    public var categories: [SkillCategory]?
    public var statuses: [SkillStatus]?
    public var tags: [String]?
    public var searchText: String?
    public var limit: Int?

    public init(
        categories: [SkillCategory]? = nil,
        statuses: [SkillStatus]? = nil,
        tags: [String]? = nil,
        searchText: String? = nil,
        limit: Int? = 50
    ) {
        self.categories = categories
        self.statuses = statuses
        self.tags = tags
        self.searchText = searchText
        self.limit = limit
    }
}

// MARK: - SkillContext

public struct SkillContext: Codable, Sendable, Equatable {
    public var skills: [AgentSkill]
    public var matchedBy: String?

    public init(skills: [AgentSkill] = [], matchedBy: String? = nil) {
        self.skills = skills
        self.matchedBy = matchedBy
    }

    public var isEmpty: Bool { skills.isEmpty }

    public func toPromptString() -> String {
        guard !skills.isEmpty else { return "" }

        var parts: [String] = ["## 当前可用技能\n"]
        for skill in skills {
            parts.append("### \(skill.name) (\(skill.category.displayName))")
            parts.append(skill.content)
            parts.append("")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Built-in Skills

extension AgentSkill {
    public static let swiftEngineeringSkill = AgentSkill(
        id: "builtin-swift-engineering",
        name: "Swift 原生工程规范",
        category: .execution,
        description: "AcMind Swift 原生工程开发规范和最佳实践",
        content: """
        # Swift 原生工程规范

        ## 项目结构
        - AcMindKit: 核心框架
        - App: 主应用入口
        - Features: 功能模块
        - Design: 设计系统

        ## 命名规范
        - 类型: PascalCase (AgentViewModel)
        - 函数/变量: camelCase (agentViewModel)
        - 常量: kCamelCase 或 UPPER_SNAKE_CASE

        ## SwiftUI 规范
        - View 文件名: FeatureNameView.swift
        - ViewModel: FeatureNameViewModel.swift
        - 使用 @StateObject / @ObservedObject / @EnvironmentObject 正确管理状态

        ## 状态管理
        - 简单状态: @State
        - 视图模型: @StateObject
        - 共享状态: @EnvironmentObject
        - 持久状态: @AppStorage / UserDefaults / SQLite

        ## 错误处理
        - 使用 Result<T, Error>
        - 优先使用 do-catch
        - 自定义错误类型实现 LocalizedError

        ## 异步
        - 优先使用 async/await
        - 后台任务使用 Task
        - 取消使用 Task.checkCancellation()
        """,
        source: .builtin,
        tags: ["swift", "ios", "engineering", "规范"]
    )

    public static let acmindUISkill = AgentSkill(
        id: "builtin-acmind-ui",
        name: "AcMind UI 规范",
        category: .execution,
        description: "AcMind 界面设计规范和组件使用指南",
        content: """
        # AcMind UI 规范

        ## 设计原则
        - 简洁: 去除多余装饰
        - 高效: 减少操作步骤
        - 一致: 统一视觉语言
        - 可访问: 支持键盘/VoiceOver

        ## 颜色系统
        - Primary: accentColor
        - Secondary: secondary 颜色
        - Background: NSColor.windowBackgroundColor
        - Surface: NSColor.controlBackgroundColor

        ## 字体
        - 标题: .system(size:, weight: .semibold)
        - 正文: .system(size:, weight: .regular)
        - 辅助: .system(size:, weight: .light)

        ## 间距
        - 组件内: 8pt
        - 组件间: 16pt
        - 分组间: 24pt

        ## 动画
        - 过渡: .easeInOut(duration: 0.25)
        - 弹簧: .spring(response: 0.3, dampingFraction: 0.7)
        - 入场: .opacity.combined(with: .move(edge:))
        """,
        source: .builtin,
        tags: ["ui", "design", "规范"]
    )

    public static let traeTaskSkill = AgentSkill(
        id: "builtin-trae-task",
        name: "Trae 任务单生成",
        category: .workflow,
        description: "生成 Trae Codex 任务拆解的规范格式",
        content: """
        # Trae 任务单生成规范

        ## 任务结构
        每个任务包含:
        - id: 唯一标识
        - content: 任务描述
        - priority: high/medium/low
        - status: pending/in_progress/completed
        - dependsOn: 依赖任务 ID 列表

        ## 任务单格式
        ```
        # Tasks

        - [ ] Task 1: [任务名称]
          - [ ] SubTask 1.1: [子任务]
          - [ ] SubTask 1.2: [子任务]

        - [ ] Task 2: [任务名称]
          - [ ] SubTask 2.1: [子任务]
        ```

        ## 生成原则
        - 每个任务可独立完成
        - 明确依赖关系
        - 包含验证方式
        - 小步提交，每次完成一个任务
        """,
        source: .builtin,
        tags: ["trae", "task", "workflow"]
    )

    public static let codexReviewSkill = AgentSkill(
        id: "builtin-codex-review",
        name: "Codex 核验",
        category: .execution,
        description: "Codex 代码审查和核验的检查清单",
        content: """
        # Codex 核验规范

        ## 代码审查要点
        - 功能正确性: 代码是否实现了需求
        - 边界处理: 错误情况是否正确处理
        - 性能影响: 是否有性能问题
        - 安全漏洞: 是否有安全隐患
        - 编码规范: 是否符合项目规范

        ## 核验流程
        1. 理解需求变更
        2. 检查实现逻辑
        3. 运行测试
        4. 检查边界情况
        5. 验证 UI/UX
        6. 确认无 lint/typecheck 错误

        ## 反馈格式
        - 严重问题: 需要立即修复
        - 次要问题: 建议修复
        - 改进建议: 可选优化
        """,
        source: .builtin,
        tags: ["codex", "review", "核验"]
    )

    public static var builtinSkills: [AgentSkill] {
        [
            swiftEngineeringSkill,
            acmindUISkill,
            traeTaskSkill,
            codexReviewSkill
        ]
    }
}
