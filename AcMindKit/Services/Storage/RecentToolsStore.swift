import Foundation

public struct RecentToolRecord: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var toolId: UUID
    public var name: String
    public var description: String
    public var icon: String
    public var category: String
    public var route: String
    public var lastUsedDate: Date

    public init(
        id: UUID,
        toolId: UUID,
        name: String,
        description: String,
        icon: String,
        category: String,
        route: String,
        lastUsedDate: Date
    ) {
        self.id = id
        self.toolId = toolId
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.route = route
        self.lastUsedDate = lastUsedDate
    }
}

public enum RecentToolsStore {
    private static let storageKey = "tools.recentTools.v1"

    public static func load(from defaults: UserDefaults = .standard) -> [RecentToolRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([RecentToolRecord].self, from: data) else {
            return []
        }
        return records
    }

    public static func save(_ records: [RecentToolRecord], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
