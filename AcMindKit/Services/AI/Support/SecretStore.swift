import Foundation
import Security

// MARK: - Secret Store

/// 安全存储服务
/// 使用 macOS Keychain 存储 API Key 等敏感信息
/// 特点：
/// 1. 密钥不落明文
/// 2. 设备锁定时不可访问 (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
/// 3. 支持增删改查操作
public actor SecretStore {
    
    public static let shared = SecretStore()
    
    private let serviceIdentifier = "com.acmind.secrets"
    
    private init() {}
    
    // MARK: - Save API Key
    
    public func saveAPIKey(_ key: String, for providerId: String) throws {
        let account = "acmind.provider.\(providerId)"
        guard let keyData = key.data(using: .utf8) else {
            throw SecretError.invalidData
        }
        
        // 先删除旧的
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 添加新的
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrLabel as String: "AcMind Provider: \(providerId)"
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretError.saveFailed(status)
        }
    }
    
    // MARK: - Get API Key
    
    public func getAPIKey(for providerId: String) -> String? {
        let account = "acmind.provider.\(providerId)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    // MARK: - Delete API Key
    
    public func deleteAPIKey(for providerId: String) throws {
        let account = "acmind.provider.\(providerId)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretError.deleteFailed(status)
        }
    }
    
    // MARK: - List All Keys
    
    public func listStoredProviderIds() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        let prefix = "acmind.provider."
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(prefix) else {
                return nil
            }
            return String(account.dropFirst(prefix.count))
        }
    }
    
    // MARK: - Check Key Exists
    
    public func hasAPIKey(for providerId: String) -> Bool {
        return getAPIKey(for: providerId) != nil
    }
    
    // MARK: - Update API Key
    
    public func updateAPIKey(_ key: String, for providerId: String) throws {
        let account = "acmind.provider.\(providerId)"
        guard let keyData = key.data(using: .utf8) else {
            throw SecretError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: keyData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // 如果不存在，则创建
            try saveAPIKey(key, for: providerId)
        } else if status != errSecSuccess {
            throw SecretError.updateFailed(status)
        }
    }
    
    // MARK: - Clear All
    
    public func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretError.deleteFailed(status)
        }
    }
}

// MARK: - Errors

public enum SecretError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)
    case notFound
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "保存密钥失败 (错误码: \(status))"
        case .deleteFailed(let status):
            return "删除密钥失败 (错误码: \(status))"
        case .updateFailed(let status):
            return "更新密钥失败 (错误码: \(status))"
        case .notFound:
            return "密钥未找到"
        case .invalidData:
            return "密钥数据无效"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .deleteFailed, .updateFailed:
            return "请检查钥匙串权限或重试"
        case .notFound:
            return "请先配置 API Key"
        case .invalidData:
            return "请重新输入密钥"
        }
    }
}
