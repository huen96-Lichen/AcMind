import Foundation
import AcMindKit

// MARK: - Service Configuration

/// 服务容器配置，用于测试时注入 Mock 实现
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
        assetStore: AssetStore? = nil
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
/// 3. 可测试性：支持配置注入 Mock 实现
/// 4. 无隐式状态：所有状态通过协议暴露
@MainActor
public final class ServiceContainer: ObservableObject, Sendable {
    // MARK: - Singleton

    private static var _shared: ServiceContainer?

    public static var shared: ServiceContainer {
        get {
            guard let instance = _shared else {
                assertionFailure("ServiceContainer accessed before setup(); returning a bootstrap container.")
                let bootstrap = ServiceContainer(configuration: .empty)
                _shared = bootstrap
                return bootstrap
            }
            return instance
        }
    }

    public static func isInitialized() -> Bool {
        _shared?.isInitialized == true
    }

    // MARK: - Services

    private let appState: AppState?

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
    public let systemMonitorService: SystemMonitorService

    // MARK: - State

    @Published public private(set) var currentPhase: InitializationPhase = .idle
    @Published public private(set) var initializationError: Error?
    @Published public private(set) var isInitialized = false

    private var initializationTask: Task<Void, Error>?

    // MARK: - Initialization

    private init(configuration: ServiceConfiguration = ServiceConfiguration(), appState: AppState? = nil) {
        self.appState = appState

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
            storage: storageService
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
        self.systemMonitorService = SystemMonitorService()
    }

    // MARK: - Setup

    /// 初始化容器，只能调用一次
    public static func setup(configuration: ServiceConfiguration = ServiceConfiguration(), appState: AppState) async throws {
        if let shared = _shared {
            if shared.isInitialized {
                throw ServiceContainerError.alreadyInitialized
            }
            try await shared.initialize()
            return
        }

        let container = ServiceContainer(configuration: configuration, appState: appState)
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
                await MainActor.run {
                    self.initializationError = nil
                    self.isInitialized = false
                    self.currentPhase = .idle
                }
                syncAppState()

                // 阶段 1: 存储层
                try await transition(to: .storage) {
                    if let storage = storageService as? StorageService {
                        try await storage.setup()
                    }
                    try await assetStore.setup()
                }

                // 阶段 2: 数据迁移（旧运行时 → Swift）
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
                }

                await MainActor.run {
                    self.currentPhase = .completed
                    self.isInitialized = true
                }
                syncAppState()

            } catch {
                await MainActor.run {
                    self.currentPhase = .failed
                    self.initializationError = error
                }
                syncAppState()
                throw error
            }
        }

        try await initializationTask?.value
    }

    private func transition(to phase: InitializationPhase, operation: () async throws -> Void) async rethrows {
        await MainActor.run {
            self.currentPhase = phase
        }
        syncAppState()
        try await operation()
    }

    // MARK: - Data Migration

    /// 检测并执行旧运行时 → Swift 数据迁移
    /// 在存储层初始化之后、其他服务初始化之前运行
    private func runDataMigrationIfNeeded() async {
        // 检查是否存在迁移源数据库
        guard storageService.checkMigrationSourceDatabase() != nil else {
            print("ℹ️ 未检测到迁移源数据库，跳过数据迁移")
            return
        }

        print("🔄 检测到迁移源数据库，开始数据迁移...")

        print("ℹ️ 数据迁移在当前构建中暂时禁用")
    }

    // MARK: - Shutdown

    public func shutdown() async {
        // 按相反顺序清理

        // 停止采集监听
        await clipboardService.stopWatching()
        systemMonitorService.stop()

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
        syncAppState()
    }

    private func syncAppState() {
        appState?.sync(with: self)
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
        issues.append("✓ SystemMonitorService")
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
        let config = ServiceConfiguration(
            storageService: StorageService(),
            settingsService: PreviewSettingsService()
        )
        // 注意：Preview 容器不调用 setup，避免副作用
        return ServiceContainer(configuration: config)
    }
}

// MARK: - Preview Mock Services

private final class PreviewSettingsService: SettingsServiceProtocol, @unchecked Sendable {
    func setup() async throws {}
    func save() async {}
    func getSettings() async -> AppSettings { AppSettings() }
    func updateSettings(_ settings: AppSettings) async throws {}
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
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
    func saveProviderAPIKey(_ apiKey: String, for providerId: String) async throws {}
    func deleteProviderAPIKey(for providerId: String) async throws {}
    func getAPIKey(for providerId: String) async -> String? { nil }
    func getAIModelCategoryPreferences() async -> [AIModelCategoryPreference] { AIModelCatalog.defaultPreferences() }
    func updateAIModelCategoryPreferences(_ preferences: [AIModelCategoryPreference]) async throws {}
}
