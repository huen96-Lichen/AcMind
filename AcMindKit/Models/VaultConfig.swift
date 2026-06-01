import Foundation

// MARK: - VaultConfig（Vault 配置）

/// Obsidian Vault 导出配置
/// 对齐旧版 vault_config 表
public struct VaultConfig: Codable, Sendable, Hashable, Equatable {
    public var vaultPath: String
    public var defaultFolder: String
    public var template: String
    public var pathRule: VaultPathRule
    public var conflictStrategy: ConflictStrategy
    public var autoFrontmatter: Bool
    public var frontmatterTemplate: [String: String]

    public enum VaultPathRule: String, Codable, Sendable, Hashable, CaseIterable {
        case categoryDate
        case flat
        case sourceType
        case custom

        public static var allCases: [VaultPathRule] {
            [.categoryDate, .flat, .sourceType, .custom]
        }

        public var displayName: String {
            switch self {
            case .categoryDate: return "分类+日期"
            case .flat: return "扁平"
            case .sourceType: return "按来源类型"
            case .custom: return "自定义"
            }
        }
    }

    public init(
        vaultPath: String = "",
        defaultFolder: String = "Inbox",
        template: String = "",
        pathRule: VaultPathRule = .categoryDate,
        conflictStrategy: ConflictStrategy = .rename,
        autoFrontmatter: Bool = true,
        frontmatterTemplate: [String: String] = [:]
    ) {
        self.vaultPath = vaultPath
        self.defaultFolder = defaultFolder
        self.template = template
        self.pathRule = pathRule
        self.conflictStrategy = conflictStrategy
        self.autoFrontmatter = autoFrontmatter
        self.frontmatterTemplate = frontmatterTemplate
    }

    public var isValid: Bool {
        !vaultPath.isEmpty && FileManager.default.fileExists(atPath: vaultPath)
    }
}
