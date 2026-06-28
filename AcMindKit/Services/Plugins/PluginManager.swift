import Foundation

// MARK: - Plugin Status

public enum PluginStatus: String, Codable, Sendable, CaseIterable {
    case discovered
    case loading
    case active
    case inactive
    case error

    public var displayName: String {
        switch self {
        case .discovered: return "已发现"
        case .loading: return "加载中"
        case .active: return "运行中"
        case .inactive: return "已停用"
        case .error: return "错误"
        }
    }
}

// MARK: - Plugin Descriptor

public struct PluginDescriptor: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let author: String?
    public let description: String?
    public let capabilities: [PluginCapability]
    public let entryPoint: String?
    public let configPath: String

    public init(
        id: String,
        name: String,
        version: String,
        author: String? = nil,
        description: String? = nil,
        capabilities: [PluginCapability] = [],
        entryPoint: String? = nil,
        configPath: String
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.capabilities = capabilities
        self.entryPoint = entryPoint
        self.configPath = configPath
    }
}

// MARK: - Plugin Management Summary

public struct PluginManagementSummary: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let author: String?
    public let description: String?
    public let status: PluginStatus
    public let capabilities: [PluginCapability]
    public let capabilityLabels: [String]
    public let policy: PluginSandboxPolicySnapshot
    public let errorMessage: String?

    public init(
        id: String,
        name: String,
        version: String,
        author: String?,
        description: String?,
        status: PluginStatus,
        capabilities: [PluginCapability],
        capabilityLabels: [String],
        policy: PluginSandboxPolicySnapshot,
        errorMessage: String?
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.status = status
        self.capabilities = capabilities
        self.capabilityLabels = capabilityLabels
        self.policy = policy
        self.errorMessage = errorMessage
    }
}

// MARK: - Plugin Manager

public actor PluginManager {
    public static let shared = PluginManager()

    private var plugins: [String: Plugin] = [:]
    private var asrPlugins: [String: ASRPlugin] = [:]
    private var polishPlugins: [String: PolishPlugin] = [:]
    private var injectionPlugins: [String: InjectionPlugin] = [:]
    private var pluginStatuses: [String: PluginStatus] = [:]
    private var discoveredDescriptors: [String: PluginDescriptor] = [:]
    private var pluginErrors: [String: String] = [:]

    private let pluginsDirectory: URL
    private let fileManager = FileManager.default

    public init(pluginsDirectory: URL? = nil) {
        let defaultPluginsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AcMind/Plugins")
        self.pluginsDirectory = pluginsDirectory ?? defaultPluginsDirectory
    }

    // MARK: - Discovery

    public func discoverPlugins() async {
        guard fileManager.fileExists(atPath: pluginsDirectory.path) else {
            try? fileManager.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
            return
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for itemURL in contents {
            let configURL = itemURL.appendingPathComponent("plugin.json")
            guard fileManager.fileExists(atPath: configURL.path) else { continue }

            do {
                let data = try Data(contentsOf: configURL)
                let descriptor = try JSONDecoder().decode(PluginDescriptor.self, from: data)
                discoveredDescriptors[descriptor.id] = descriptor
                if pluginStatuses[descriptor.id] == nil {
                    pluginStatuses[descriptor.id] = .discovered
                }
            } catch {
                let pluginId = itemURL.lastPathComponent
                pluginStatuses[pluginId] = .error
                pluginErrors[pluginId] = "配置文件解析失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Lifecycle

    public func loadPlugin(at url: URL) async throws {
        let configURL = url.appendingPathComponent("plugin.json")
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw PluginError.configNotFound
        }

        let data = try Data(contentsOf: configURL)
        let descriptor = try JSONDecoder().decode(PluginDescriptor.self, from: data)

        pluginStatuses[descriptor.id] = .loading
        discoveredDescriptors[descriptor.id] = descriptor

        let sandbox = PluginSandbox(pluginId: descriptor.id, pluginsDirectory: pluginsDirectory)
        guard await sandbox.validateAccess(path: url) else {
            pluginStatuses[descriptor.id] = .error
            pluginErrors[descriptor.id] = "路径不在沙盒允许范围内"
            throw PluginError.sandboxViolation
        }

        // A descriptor on disk is metadata, not an executable Plugin instance.
        // AcMind currently has no dynamic entry-point loader, so claiming the
        // plugin is active here would make the management UI report a capability
        // that cannot actually be called. Runtime plugins become active only via
        // register(plugin:), where a concrete Plugin is activated and registered
        // in the capability maps below.
        pluginStatuses[descriptor.id] = .discovered
        pluginErrors.removeValue(forKey: descriptor.id)
    }

    public func unloadPlugin(id: String) async throws {
        guard plugins[id] != nil || discoveredDescriptors[id] != nil else {
            throw PluginError.pluginNotFound(id)
        }

        if let plugin = plugins.removeValue(forKey: id) {
            await plugin.deactivate()
        }
        asrPlugins.removeValue(forKey: id)
        polishPlugins.removeValue(forKey: id)
        injectionPlugins.removeValue(forKey: id)
        pluginStatuses[id] = .inactive
    }

    public func reloadPlugin(id: String) async throws {
        guard discoveredDescriptors[id] != nil else {
            throw PluginError.pluginNotFound(id)
        }

        try await unloadPlugin(id: id)

        let pluginURL = pluginsDirectory.appendingPathComponent(id)
        try await loadPlugin(at: pluginURL)
    }

    public func getPluginStatus(id: String) async -> PluginStatus {
        pluginStatuses[id] ?? .discovered
    }

    // MARK: - Register/Unregister

    public func register(plugin: Plugin) async throws {
        let sandbox = PluginSandbox(pluginId: plugin.id, pluginsDirectory: pluginsDirectory)
        let pluginURL = pluginsDirectory.appendingPathComponent(plugin.id)
        guard await sandbox.validateAccess(path: pluginURL) else {
            throw PluginError.sandboxViolation
        }

        plugins[plugin.id] = plugin
        if let asrPlugin = plugin as? ASRPlugin {
            asrPlugins[plugin.id] = asrPlugin
        }
        if let polishPlugin = plugin as? PolishPlugin {
            polishPlugins[plugin.id] = polishPlugin
        }
        if let injectionPlugin = plugin as? InjectionPlugin {
            injectionPlugins[plugin.id] = injectionPlugin
        }
        pluginStatuses[plugin.id] = .active
        pluginErrors.removeValue(forKey: plugin.id)
        try await plugin.activate()
    }

    public func unregister(pluginId: String) async {
        if let plugin = plugins.removeValue(forKey: pluginId) {
            await plugin.deactivate()
        }
        asrPlugins.removeValue(forKey: pluginId)
        polishPlugins.removeValue(forKey: pluginId)
        injectionPlugins.removeValue(forKey: pluginId)
        pluginStatuses.removeValue(forKey: pluginId)
        pluginErrors.removeValue(forKey: pluginId)
    }

    // MARK: - Query

    public func getASRPlugins() -> [String: ASRPlugin] { asrPlugins }
    public func getPolishPlugins() -> [String: PolishPlugin] { polishPlugins }
    public func getInjectionPlugins() -> [String: InjectionPlugin] { injectionPlugins }
    public func getAllPlugins() -> [String: Plugin] { plugins }
    public func getDiscoveredDescriptors() -> [String: PluginDescriptor] { discoveredDescriptors }
    public func getAllStatuses() -> [String: PluginStatus] { pluginStatuses }
    public func getPluginError(id: String) -> String? { pluginErrors[id] }
    public func getActivePluginCount() -> Int { plugins.count }

    public func getManagementSummaries() async -> [PluginManagementSummary] {
        var summaries: [PluginManagementSummary] = []
        for descriptor in discoveredDescriptors.values {
            let sandbox = PluginSandbox(pluginId: descriptor.id, pluginsDirectory: pluginsDirectory)
            let policy = await sandbox.policySnapshot()
            summaries.append(
                PluginManagementSummary(
                    id: descriptor.id,
                    name: descriptor.name,
                    version: descriptor.version,
                    author: descriptor.author,
                    description: descriptor.description,
                    status: pluginStatuses[descriptor.id] ?? .discovered,
                    capabilities: descriptor.capabilities,
                    capabilityLabels: descriptor.capabilities.map(\.displayName),
                    policy: policy,
                    errorMessage: pluginErrors[descriptor.id]
                )
            )
        }

        for plugin in plugins.values where discoveredDescriptors[plugin.id] == nil {
            let sandbox = PluginSandbox(pluginId: plugin.id, pluginsDirectory: pluginsDirectory)
            let policy = await sandbox.policySnapshot()
            summaries.append(
                PluginManagementSummary(
                    id: plugin.id,
                    name: plugin.name,
                    version: plugin.version,
                    author: nil,
                    description: nil,
                    status: pluginStatuses[plugin.id] ?? .active,
                    capabilities: plugin.capabilities,
                    capabilityLabels: plugin.capabilities.map(\.displayName),
                    policy: policy,
                    errorMessage: pluginErrors[plugin.id]
                )
            )
        }

        return summaries.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status.sortOrder < rhs.status.sortOrder
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

private extension PluginStatus {
    var sortOrder: Int {
        switch self {
        case .active:
            return 0
        case .loading:
            return 1
        case .error:
            return 2
        case .discovered:
            return 3
        case .inactive:
            return 4
        }
    }
}

// MARK: - Plugin Errors

public enum PluginError: Error, LocalizedError {
    case configNotFound
    case sandboxViolation
    case pluginNotFound(String)
    case loadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .configNotFound:
            return "插件配置文件 plugin.json 未找到"
        case .sandboxViolation:
            return "插件路径不在沙盒允许范围内"
        case .pluginNotFound(let id):
            return "插件未找到: \(id)"
        case .loadFailed(let reason):
            return "插件加载失败: \(reason)"
        }
    }
}
