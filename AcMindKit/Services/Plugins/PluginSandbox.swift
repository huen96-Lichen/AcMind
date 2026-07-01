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

public struct PluginResourceLimits: Codable, Sendable, Equatable {
    public let memoryMB: Int
    public let cpuPercent: Int

    public init(memoryMB: Int, cpuPercent: Int) {
        self.memoryMB = memoryMB
        self.cpuPercent = cpuPercent
    }
}

public struct PluginSandboxPolicySnapshot: Codable, Sendable, Equatable {
    public let permissions: Set<PluginPermission>
    public let permissionLabels: [String]
    public let resourceLimits: PluginResourceLimits

    public init(
        permissions: Set<PluginPermission>,
        permissionLabels: [String],
        resourceLimits: PluginResourceLimits
    ) {
        self.permissions = permissions
        self.permissionLabels = permissionLabels
        self.resourceLimits = resourceLimits
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
        maxCPUPercent: Int = 25,
        pluginsDirectory: URL? = nil,
        pluginDirectory: URL? = nil
    ) {
        self.pluginId = pluginId
        let root = pluginsDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AcMind/Plugins")
        let base = pluginDirectory ?? root.appendingPathComponent(pluginId, isDirectory: true)
        self.allowedPaths = [base]
        self.grantedPermissions = permissions
        self.maxMemoryMB = maxMemoryMB
        self.maxCPUPercent = maxCPUPercent
    }

    public func validateAccess(path: URL) -> Bool {
        let candidate = path.standardizedFileURL.resolvingSymlinksInPath().path
        return allowedPaths.contains { allowedPath in
            let allowed = allowedPath.standardizedFileURL.resolvingSymlinksInPath().path
            return candidate == allowed || candidate.hasPrefix(allowed + "/")
        }
    }

    private func hasPermission(_ permission: PluginPermission) -> Bool {
        grantedPermissions.contains(permission)
    }

    private func grantPermission(_ permission: PluginPermission) {
        grantedPermissions.insert(permission)
    }

    private func revokePermission(_ permission: PluginPermission) {
        grantedPermissions.remove(permission)
    }

    private func getGrantedPermissions() -> Set<PluginPermission> {
        grantedPermissions
    }

    private func getResourceLimits() -> (memoryMB: Int, cpuPercent: Int) {
        (maxMemoryMB, maxCPUPercent)
    }

    public func policySnapshot() -> PluginSandboxPolicySnapshot {
        let orderedPermissions = PluginPermission.allCases.filter { grantedPermissions.contains($0) }
        return PluginSandboxPolicySnapshot(
            permissions: grantedPermissions,
            permissionLabels: orderedPermissions.map(\.displayName),
            resourceLimits: PluginResourceLimits(memoryMB: maxMemoryMB, cpuPercent: maxCPUPercent)
        )
    }
}
