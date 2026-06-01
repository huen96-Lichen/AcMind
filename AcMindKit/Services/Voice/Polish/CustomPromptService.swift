import Foundation

// MARK: - Custom Prompt Service

/// 自定义 Prompt 服务
/// 职责：
/// 1. 管理用户自定义的 System Prompt
/// 2. 支持按模式分类存储
/// 3. 提供默认 Prompt 和自定义 Prompt 的切换
public actor CustomPromptService {
    
    // MARK: - Singleton
    
    public static let shared = CustomPromptService()
    
    // MARK: - Properties
    
    private let storage: StorageServiceProtocol
    private var customPrompts: [VoicePolishMode: String] = [:]
    private var isLoaded = false
    
    // MARK: - Initialization
    
    public init(storage: StorageServiceProtocol? = nil) {
        self.storage = storage ?? StorageService()
    }
    
    // MARK: - Public Methods
    
    /// 加载自定义 Prompt
    public func loadCustomPrompts() async throws {
        guard !isLoaded else { return }
        
        // 从存储加载
        let savedPrompts = try await storage.getCustomPrompts()
        customPrompts = savedPrompts
        isLoaded = true
    }
    
    /// 保存自定义 Prompt
    public func saveCustomPrompts() async throws {
        try await storage.saveCustomPrompts(customPrompts)
    }
    
    /// 获取指定模式的 Prompt
    public func getPrompt(for mode: VoicePolishMode, useCustom: Bool = true) -> String {
        if useCustom, let customPrompt = customPrompts[mode] {
            return customPrompt
        }
        
        // 返回默认 Prompt
        return PolishPrompts.systemPrompt(for: mode)
    }
    
    /// 设置自定义 Prompt
    public func setCustomPrompt(_ prompt: String, for mode: VoicePolishMode) async throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedPrompt.isEmpty {
            // 如果为空，删除自定义 Prompt
            customPrompts.removeValue(forKey: mode)
        } else {
            customPrompts[mode] = trimmedPrompt
        }
        
        try await saveCustomPrompts()
    }
    
    /// 删除自定义 Prompt
    public func removeCustomPrompt(for mode: VoicePolishMode) async throws {
        customPrompts.removeValue(forKey: mode)
        try await saveCustomPrompts()
    }
    
    /// 获取所有自定义 Prompt
    public func getAllCustomPrompts() -> [VoicePolishMode: String] {
        return customPrompts
    }
    
    /// 检查是否有自定义 Prompt
    public func hasCustomPrompt(for mode: VoicePolishMode) -> Bool {
        return customPrompts[mode] != nil
    }
    
    /// 重置为默认 Prompt
    public func resetToDefault(for mode: VoicePolishMode) async throws {
        customPrompts.removeValue(forKey: mode)
        try await saveCustomPrompts()
    }
    
    /// 重置所有为默认 Prompt
    public func resetAllToDefault() async throws {
        customPrompts.removeAll()
        try await saveCustomPrompts()
    }
    
    /// 导出自定义 Prompt
    public func exportCustomPrompts() -> [String: String] {
        var exports: [String: String] = [:]
        for (mode, prompt) in customPrompts {
            exports[mode.rawValue] = prompt
        }
        return exports
    }
    
    /// 导入自定义 Prompt
    public func importCustomPrompts(_ imports: [String: String]) async throws {
        for (modeRaw, prompt) in imports {
            if let mode = VoicePolishMode(rawValue: modeRaw) {
                customPrompts[mode] = prompt
            }
        }
        try await saveCustomPrompts()
    }
}

// MARK: - Storage Service Extension

public extension StorageServiceProtocol {
    func getCustomPrompts() async throws -> [VoicePolishMode: String] {
        guard let json = try? await getSetting(key: "customPrompts.prompts"),
              let data = json.data(using: .utf8) else {
            return [:]
        }
        let raw = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        var result: [VoicePolishMode: String] = [:]
        for (key, value) in raw {
            if let mode = VoicePolishMode(rawValue: key) {
                result[mode] = value
            }
        }
        return result
    }
    
    func saveCustomPrompts(_ prompts: [VoicePolishMode: String]) async throws {
        var raw: [String: String] = [:]
        for (mode, prompt) in prompts {
            raw[mode.rawValue] = prompt
        }
        guard let data = try? JSONEncoder().encode(raw),
              let json = String(data: data, encoding: .utf8) else { return }
        try await setSetting(key: "customPrompts.prompts", value: json)
    }
}

// MARK: - Polish Service Extension

public extension PolishService {
    /// 使用自定义 Prompt 进行润色
    func polishWithCustomPrompt(
        text: String,
        mode: VoicePolishMode,
        customPromptService: CustomPromptService,
        useCustom: Bool = true
    ) async throws -> String {
        let systemPrompt = await customPromptService.getPrompt(for: mode, useCustom: useCustom)
        return try await polish(text: text, mode: mode, customSystemPrompt: systemPrompt)
    }
}

// MARK: - Prompt Template

/// Prompt 模板
public struct PromptTemplate: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let mode: VoicePolishMode
    public let template: String
    public let isDefault: Bool
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        mode: VoicePolishMode,
        template: String,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.mode = mode
        self.template = template
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

// MARK: - Prompt Template Service

/// Prompt 模板服务
public actor PromptTemplateService {
    
    // MARK: - Singleton
    
    public static let shared = PromptTemplateService()
    
    // MARK: - Properties
    
    private var templates: [PromptTemplate] = []
    private var isLoaded = false
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 加载模板
    public func loadTemplates() {
        guard !isLoaded else { return }
        
        // 添加默认模板
        templates = [
            PromptTemplate(
                name: "默认轻度润色",
                description: "去掉口癖、重复、停顿，补充标点",
                mode: .light,
                template: PolishPrompts.systemPrompt(for: .light),
                isDefault: true
            ),
            PromptTemplate(
                name: "默认原文整理",
                description: "仅补全标点，保留原话",
                mode: .raw,
                template: PolishPrompts.systemPrompt(for: .raw),
                isDefault: true
            ),
            PromptTemplate(
                name: "默认结构化",
                description: "按语义归类，适合任务清单",
                mode: .structured,
                template: PolishPrompts.systemPrompt(for: .structured),
                isDefault: true
            ),
            PromptTemplate(
                name: "默认正式表达",
                description: "适合工作沟通和邮件",
                mode: .formal,
                template: PolishPrompts.systemPrompt(for: .formal),
                isDefault: true
            )
        ]
        
        isLoaded = true
    }
    
    /// 获取所有模板
    public func getAllTemplates() -> [PromptTemplate] {
        return templates
    }
    
    /// 获取指定模式的模板
    public func getTemplates(for mode: VoicePolishMode) -> [PromptTemplate] {
        return templates.filter { $0.mode == mode }
    }
    
    /// 添加模板
    public func addTemplate(_ template: PromptTemplate) {
        templates.append(template)
    }
    
    /// 删除模板
    public func removeTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
    }
    
    /// 获取默认模板
    public func getDefaultTemplate(for mode: VoicePolishMode) -> PromptTemplate? {
        return templates.first { $0.mode == mode && $0.isDefault }
    }
}
