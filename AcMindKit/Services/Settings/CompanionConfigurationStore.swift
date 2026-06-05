import Foundation

public enum CompanionConfigurationStore {
    private static let key = "companion_config"

    public static func load(from storage: StorageServiceProtocol) async -> CompanionConfiguration {
        do {
            if let jsonString = try await storage.getSetting(key: key),
               let jsonData = jsonString.data(using: .utf8),
               let config = try? JSONDecoder().decode(CompanionConfiguration.self, from: jsonData) {
                return config
            }
        } catch {
            // fall through to default
        }

        return .default
    }

    public static func save(_ configuration: CompanionConfiguration, to storage: StorageServiceProtocol) async throws {
        let jsonData = try JSONEncoder().encode(configuration)
        let jsonString = String(decoding: jsonData, as: UTF8.self)
        try await storage.setSetting(key: key, value: jsonString)
    }
}
