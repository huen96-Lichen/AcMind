import Foundation
import AcMindKit

// MARK: - Service Configuration

/// 服务容器配置，用于测试时注入可替换实现
public struct ServiceConfiguration {
    var storageService: StorageServiceProtocol?
    var captureService: CaptureServiceProtocol?
    var clipboardService: ClipboardServiceProtocol?
    var distillService: DistillServiceProtocol?
    var exportService: ExportServiceProtocol?
    var aiRuntime: AIRuntimeProtocol?
    var knowledgeService: KnowledgeServiceProtocol?
    var voiceService: VoiceServiceProtocol?
    var settingsService: SettingsServiceProtocol?
    var assetStore: AssetStore?
    var scheduleService: ScheduleServiceProtocol?
    var agentMemoryService: AgentMemoryServiceProtocol?
    var agentSkillService: AgentSkillServiceProtocol?
    var agentTaskBoardService: AgentTaskBoardServiceProtocol?

    public init(
        storageService: StorageServiceProtocol? = nil,
        captureService: CaptureServiceProtocol? = nil,
        clipboardService: ClipboardServiceProtocol? = nil,
        distillService: DistillServiceProtocol? = nil,
        exportService: ExportServiceProtocol? = nil,
        aiRuntime: AIRuntimeProtocol? = nil,
        knowledgeService: KnowledgeServiceProtocol? = nil,
        voiceService: VoiceServiceProtocol? = nil,
        settingsService: SettingsServiceProtocol? = nil,
        assetStore: AssetStore? = nil,
        scheduleService: ScheduleServiceProtocol? = nil,
        agentMemoryService: AgentMemoryServiceProtocol? = nil,
        agentSkillService: AgentSkillServiceProtocol? = nil,
        agentTaskBoardService: AgentTaskBoardServiceProtocol? = nil
    ) {
        self.storageService = storageService
        self.captureService = captureService
        self.clipboardService = clipboardService
        self.distillService = distillService
        self.exportService = exportService
        self.aiRuntime = aiRuntime
        self.knowledgeService = knowledgeService
        self.voiceService = voiceService
        self.settingsService = settingsService
        self.assetStore = assetStore
        self.scheduleService = scheduleService
        self.agentMemoryService = agentMemoryService
        self.agentSkillService = agentSkillService
        self.agentTaskBoardService = agentTaskBoardService
    }

    /// 空配置，用于完全自定义注入
    public static var empty: ServiceConfiguration { ServiceConfiguration() }
}

// MARK: - Initialization Phase

/// 初始化阶段，用于跟踪启动进度
public enum InitializationPhase: String, Sendable, CaseIterable {
    case idle = "空闲"
    case storage = "存储层"
    case dataMigration = "数据迁移"
    case settings = "设置"
    case permissions = "权限"
    case capture = "采集"
    case ai = "AI 运行时"
    case ui = "UI"
    case completed = "完成"
    case failed = "失败"

    public var order: Int {
        switch self {
        case .idle: return 0
        case .storage: return 1
        case .dataMigration: return 2
        case .settings: return 3
        case .permissions: return 4
        case .capture: return 5
        case .ai: return 6
        case .ui: return 7
        case .completed: return 8
        case .failed: return -1
        }
    }
}

// MARK: - Service Container

/// 依赖注入容器，管理服务生命周期和初始化顺序
/// 设计原则：
/// 1. 显式依赖：所有依赖通过构造函数注入
/// 2. 阶段初始化：按固定顺序初始化服务
    /// 3. 可测试性：支持配置注入可替换实现
/// 4. 无隐式状态：所有状态通过协议暴露
@MainActor
public final class ServiceContainer: ObservableObject, Sendable {
    // MARK: - Singleton

    private static var _shared: ServiceContainer?

    public static var shared: ServiceContainer {
        get {
            guard let instance = _shared else {
                fatalError("ServiceContainer must be initialized before use. Call setup() first.")
            }
            return instance
        }
    }

    public static func isInitialized() -> Bool {
        _shared != nil
    }

    // MARK: - Services

    public let permissionManager: PermissionManager
    public let storageService: StorageServiceProtocol
    public let captureService: CaptureServiceProtocol
    public let clipboardService: ClipboardServiceProtocol
    public let distillService: DistillServiceProtocol
    public let exportService: ExportServiceProtocol
    public let aiRuntime: AIRuntimeProtocol
    public let knowledgeService: KnowledgeServiceProtocol
    public let voiceService: VoiceServiceProtocol
    public let settingsService: SettingsServiceProtocol
    public let assetStore: AssetStore
    public let scheduleService: ScheduleServiceProtocol
    public let agentMemoryService: AgentMemoryServiceProtocol
    public let agentSkillService: AgentSkillServiceProtocol
    public let agentTaskBoardService: AgentTaskBoardServiceProtocol

    public var hotCornerSettingsStore: HotCornerSettingsStore? {
        settingsService as? HotCornerSettingsStore
    }

    // MARK: - State

    @Published public private(set) var currentPhase: InitializationPhase = .idle
    @Published public private(set) var initializationError: Error?
    @Published public private(set) var isInitialized = false

    private var initializationTask: Task<Void, Error>?

    // MARK: - Initialization

    private init(configuration: ServiceConfiguration = ServiceConfiguration()) {
        // 阶段 0: 权限管理器（最底层，所有权限检测基础）
        self.permissionManager = PermissionManager()

        // 阶段 1: 存储层（最底层，无依赖）
        self.storageService = configuration.storageService ?? StorageService()
        self.assetStore = configuration.assetStore ?? AssetStore()

        // 阶段 2: 设置服务（依赖存储层、权限管理器）
        self.settingsService = configuration.settingsService ?? SettingsService(
            storage: storageService,
            permissionManager: permissionManager
        )

        // 阶段 3: AI 运行时（依赖设置服务获取 Provider 配置）
        self.aiRuntime = configuration.aiRuntime ?? AIRuntimeService(
            storage: storageService,
            modelRouter: AgentModelRouter()
        )

        // 阶段 4: 语音服务（依赖 AI 运行时、存储层、AssetStore、权限管理器）
        self.voiceService = configuration.voiceService ?? VoiceService(
            storage: storageService,
            assetStore: assetStore,
            aiRuntime: aiRuntime,
            permissionManager: permissionManager
        )

        // 阶段 5: 采集服务（依赖存储层、AssetStore、语音服务）
        let capture = configuration.captureService ?? CaptureService(
            storage: storageService,
            assetStore: assetStore,
            voiceService: voiceService
        )
        self.captureService = capture
        
        self.clipboardService = configuration.clipboardService ?? ClipboardService(
            storage: storageService,
            assetStore: assetStore
        )

        // 阶段 6: 业务服务（依赖 AI 运行时和存储层）
        self.distillService = configuration.distillService ?? DistillService(
            aiRuntime: aiRuntime,
            storage: storageService
        )
        self.exportService = configuration.exportService ?? ExportService(
            storage: storageService
        )
        self.knowledgeService = configuration.knowledgeService ?? KnowledgeService(
            storage: storageService
        )

        // 阶段 7: 日程服务（依赖存储层）
        self.scheduleService = configuration.scheduleService ?? ScheduleService(storage: storageService)

        // 阶段 8: Agent 子服务（依赖存储层）
        self.agentMemoryService = configuration.agentMemoryService ?? AgentMemoryService(storage: storageService)
        self.agentSkillService = configuration.agentSkillService ?? AgentSkillService(storage: storageService)
        self.agentTaskBoardService = configuration.agentTaskBoardService ?? AgentTaskBoardService(storage: storageService)
    }

    // MARK: - Setup

    /// 初始化容器，只能调用一次
    public static func setup(configuration: ServiceConfiguration = ServiceConfiguration()) async throws {
        guard _shared == nil else {
            throw ServiceContainerError.alreadyInitialized
        }

        let container = ServiceContainer(configuration: configuration)
        _shared = container

        try await container.initialize()
    }

    /// 重置容器（主要用于测试）
    public static func reset() async {
        if let container = _shared {
            await container.shutdown()
        }
        _shared = nil
    }

    // MARK: - Initialization Phases

    private func initialize() async throws {
        initializationTask = Task {
            do {
                // 阶段 1: 存储层
                try await transition(to: .storage) {
                    if let storage = storageService as? StorageService {
                        try await storage.setup()
                    }
                    try await assetStore.setup()
                }

                // 阶段 2: 数据迁移（旧桌面版 → Swift）
                await transition(to: .dataMigration) {
                    await runDataMigrationIfNeeded()
                }

                // 阶段 3: 设置
                try await transition(to: .settings) {
                    if let settings = settingsService as? SettingsService {
                        try await settings.setup()
                    }
                }

                // 阶段 3: 权限（检查但不阻塞）
                await transition(to: .permissions) {
                    _ = await settingsService.checkPermission(.microphone)
                    _ = await settingsService.checkPermission(.screenRecording)
                }

                // 阶段 4: 采集
                await transition(to: .capture) {
                    await clipboardService.startWatching()
                }

                // 阶段 5: AI 运行时
                await transition(to: .ai) {
                    _ = aiRuntime
                    // 加载知识卡片历史
                    if let knowledge = knowledgeService as? KnowledgeService {
                        try? await knowledge.setup()
                    }
                }

                // 阶段 6: UI（标记完成）
                await transition(to: .ui) {
                    // UI 初始化在 SwiftUI 层完成
                    if let schedule = scheduleService as? ScheduleService {
                        try? await schedule.setup()
                    }
                    if let skillService = agentSkillService as? AgentSkillService {
                        try? await skillService.initializeBuiltinSkills()
                    }
                }

                await MainActor.run {
                    self.currentPhase = .completed
                    self.isInitialized = true
                }

            } catch {
                await MainActor.run {
                    self.currentPhase = .failed
                    self.initializationError = error
                }
                throw error
            }
        }

        try await initializationTask?.value
    }

    private func transition(to phase: InitializationPhase, operation: () async throws -> Void) async rethrows {
        await MainActor.run {
            self.currentPhase = phase
        }
        try await operation()
    }

    // MARK: - Data Migration

    /// 检测并执行旧桌面版 → Swift 数据迁移
    /// 在存储层初始化之后、其他服务初始化之前运行
    private func runDataMigrationIfNeeded() async {
        // 检查是否存在旧版数据库
        guard storageService.checkLegacyDatabase() != nil else {
            print("ℹ️ 未检测到旧版数据库，跳过数据迁移")
            return
        }

        print("🔄 检测到旧版数据库，开始数据迁移...")
        do {
            let migrationService = DataMigrationService(swiftDBPath: URL(fileURLWithPath: storageService.getDatabasePath()))
            let result = try await migrationService.runIfNeeded()
            if result.migrated {
                print("✅ 数据迁移完成，耗时 \(String(format: "%.2f", result.duration)) 秒")
                if result.tables.isEmpty == false {
                    print("📦 迁移表: \(result.tables)")
                }
                if result.errors.isEmpty == false {
                    print("⚠️ 迁移过程中出现问题: \(result.errors)")
                }
            }
        } catch let migrationError as DataMigrationService.MigrationError {
            switch migrationError {
            case .migrationAlreadyCompleted:
                print("ℹ️ 旧数据迁移已完成，跳过")
            default:
                print("⚠️ 数据迁移失败: \(migrationError.localizedDescription)")
            }
        } catch {
            print("⚠️ 数据迁移失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Shutdown

    public func shutdown() async {
        // 按相反顺序清理

        // 停止采集监听
        await clipboardService.stopWatching()

        // 取消正在进行的 AI 任务
        // 持久化设置
        if let settings = settingsService as? SettingsService {
            await settings.save()
        }

        initializationTask?.cancel()
        initializationTask = nil

        await MainActor.run {
            self.isInitialized = false
            self.currentPhase = .idle
        }
    }

    // MARK: - Dependency Validation

    /// 验证依赖图完整性（调试用）
    public func validateDependencies() -> [String] {
        var issues: [String] = []

        // 检查关键服务非空
        if storageService is StorageService { issues.append("✓ StorageService") }
        if settingsService is SettingsService { issues.append("✓ SettingsService") }
        if captureService is CaptureService { issues.append("✓ CaptureService") }
        if clipboardService is ClipboardService { issues.append("✓ ClipboardService") }
        if aiRuntime is AIRuntimeService { issues.append("✓ AIRuntimeService") }
        if distillService is DistillService { issues.append("✓ DistillService") }
        if exportService is ExportService { issues.append("✓ ExportService") }
        if knowledgeService is KnowledgeService { issues.append("✓ KnowledgeService") }
        if scheduleService is ScheduleService { issues.append("✓ ScheduleService") }
        if agentMemoryService is AgentMemoryService { issues.append("✓ AgentMemoryService") }
        if agentSkillService is AgentSkillService { issues.append("✓ AgentSkillService") }
        if agentTaskBoardService is AgentTaskBoardService { issues.append("✓ AgentTaskBoardService") }
        issues.append("✓ VoiceService")

        return issues
    }
}

// MARK: - Errors

public enum ServiceContainerError: Error, LocalizedError {
    case alreadyInitialized
    case initializationFailed(InitializationPhase, Error)
    case serviceNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyInitialized:
            return "ServiceContainer 已经初始化"
        case .initializationFailed(let phase, let error):
            return "初始化失败在阶段 \(phase.rawValue): \(error.localizedDescription)"
        case .serviceNotFound(let name):
            return "服务未找到: \(name)"
        }
    }
}

// MARK: - Preview Support

extension ServiceContainer {
    /// 创建用于 SwiftUI Preview 的容器
    public static func preview() -> ServiceContainer {
        let storage = StorageService()
        let config = ServiceConfiguration(
            storageService: storage,
            settingsService: PreviewSettingsService(),
            scheduleService: ScheduleService(storage: storage),
            agentMemoryService: PreviewAgentMemoryService(),
            agentSkillService: PreviewAgentSkillService(),
            agentTaskBoardService: PreviewAgentTaskBoardService()
        )
        // 注意：Preview 容器不调用 setup，避免副作用
        return ServiceContainer(configuration: config)
    }
}

// MARK: - Preview Services

private final class PreviewSettingsService: SettingsServiceProtocol, @unchecked Sendable {
    func setup() async throws {}
    func save() async {}
    func getSettings() async -> AppSettings { AppSettings() }
    func updateSettings(_ settings: AppSettings) async throws {}
    func getHotCornerSettings() async -> HotCornerSettings { .defaultSettings }
    func updateHotCornerSettings(_ settings: HotCornerSettings) async throws {}
    func getVoiceSettings() async -> VoiceSettings { VoiceSettings() }
    func updateVoiceSettings(_ settings: VoiceSettings) async throws {}
    func getVaultConfig() async -> VaultConfig { VaultConfig() }
    func updateVaultConfig(_ config: VaultConfig) async throws {}
    func validateVaultPath(_ path: String) async -> Bool { true }
    func selectVaultPath() async -> String? { nil }
    func checkPermission(_ permission: SystemPermission) async -> PermissionStatus { .notDetermined }
    func requestPermission(_ permission: SystemPermission) async throws {}
    func openSystemPreferences(for permission: SystemPermission) async {}
    func checkPermissionKind(_ kind: AppPermissionKind) async -> AppPermissionStatus { .notDetermined }
    func requestPermissionKind(_ kind: AppPermissionKind) async {}
    func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping @Sendable () -> Void) async throws {}
    func unregisterShortcut(_ shortcut: KeyboardShortcut) async throws {}
    func getRegisteredShortcuts() async -> [KeyboardShortcut] { [] }
    func unregisterAllShortcuts() async {}
    func listProviders() async throws -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig, apiKey: String?) async throws {}
    func updateProvider(_ config: ProviderConfig, apiKey: String?) async throws {}
    func removeProvider(id: String) async throws {}
    func getAPIKey(for providerId: String) async -> String? { nil }
}

private final class PreviewAgentMemoryService: AgentMemoryServiceProtocol, @unchecked Sendable {
    func saveMemory(_ memory: AgentMemory) async throws {}
    func getMemory(id: String) async throws -> AgentMemory? { nil }
    func listMemories(filter: MemoryFilter?) async throws -> [AgentMemory] { [] }
    func updateMemory(_ memory: AgentMemory) async throws {}
    func deleteMemory(id: String) async throws {}
    func getMemoryContext(types: [MemoryType]?, query: String?) async throws -> MemoryContext { MemoryContext() }
    func recordAccess(memoryId: String) async throws {}
}

private final class PreviewAgentSkillService: AgentSkillServiceProtocol, @unchecked Sendable {
    func saveSkill(_ skill: AgentSkill) async throws {}
    func getSkill(id: String) async throws -> AgentSkill? { nil }
    func listSkills(filter: SkillFilter?) async throws -> [AgentSkill] { [] }
    func updateSkill(_ skill: AgentSkill) async throws {}
    func deleteSkill(id: String) async throws {}
    func getSkillContext(taskDescription: String?) async throws -> SkillContext { SkillContext() }
    func incrementUseCount(skillId: String) async throws {}
    func incrementViewCount(skillId: String) async throws {}
    func initializeBuiltinSkills() async throws {}
}

private final class PreviewAgentTaskBoardService: AgentTaskBoardServiceProtocol, @unchecked Sendable {
    func createTask(_ task: AgentTask) async throws -> AgentTask { task }
    func getTask(id: String) async throws -> AgentTask? { nil }
    func listTasks(filter: TaskFilter?) async throws -> [AgentTask] { [] }
    func updateTask(_ task: AgentTask) async throws {}
    func deleteTask(id: String) async throws {}
    func startTask(id: String) async throws {}
    func completeTask(id: String) async throws {}
    func failTask(id: String, error: String) async throws {}
    func retryTask(id: String) async throws {}
    func addStep(taskId: String, step: TaskStep) async throws {}
    func updateStep(taskId: String, step: TaskStep) async throws {}
    func archiveTask(id: String) async throws {}
}
