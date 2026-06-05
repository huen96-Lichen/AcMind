import Foundation

// MARK: - Plugin Permission

public enum PluginPermission: String, Codable, Sendable, CaseIterable {
    case fileRead
    case fileWrite
    case networkAccess
    case clipboardAccess
    case aiAccess

    public var displayName: String {
        switch self {
        case .fileRead: return "文件读取"
        case .fileWrite: return "文件写入"
        case .networkAccess: return "网络访问"
        case .clipboardAccess: return "剪贴板访问"
        case .aiAccess: return "AI 服务访问"
        }
    }
}

// MARK: - Plugin Sandbox

public actor PluginSandbox {
    private let pluginId: String
    private let allowedPaths: [URL]
    private var grantedPermissions: Set<PluginPermission>
    private let maxMemoryMB: Int
    private let maxCPUPercent: Int

    public init(
        pluginId: String,
        permissions: Set<PluginPermission> = [.fileRead],
        maxMemoryMB: Int = 256,
        maxCPUPercent: Int = 25
    ) {
        self.pluginId = pluginId
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AcMind/Plugins/\(pluginId)")
        self.allowedPaths = [base]
        self.grantedPermissions = permissions
        self.maxMemoryMB = maxMemoryMB
        self.maxCPUPercent = maxCPUPercent
    }

    public func validateAccess(path: URL) -> Bool {
        return allowedPaths.contains { path.path.hasPrefix($0.path) }
    }

    public func hasPermission(_ permission: PluginPermission) -> Bool {
        grantedPermissions.contains(permission)
    }

    public func grantPermission(_ permission: PluginPermission) {
        grantedPermissions.insert(permission)
    }

    public func revokePermission(_ permission: PluginPermission) {
        grantedPermissions.remove(permission)
    }

    public func getGrantedPermissions() -> Set<PluginPermission> {
        grantedPermissions
    }

    public func getResourceLimits() -> (memoryMB: Int, cpuPercent: Int) {
        (maxMemoryMB, maxCPUPercent)
    }
}
