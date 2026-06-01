import Foundation

public struct WorkbenchProjectSnapshot: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var noteCount: Int
    public var lastUpdated: Date
    public var sortOrder: Int

    public init(id: String, name: String, noteCount: Int, lastUpdated: Date, sortOrder: Int) {
        self.id = id
        self.name = name
        self.noteCount = noteCount
        self.lastUpdated = lastUpdated
        self.sortOrder = sortOrder
    }
}

public enum WorkbenchProjectStore {
    private static let projectsKey = "workbench.projects.v1"
    private static let selectedProjectIDKey = "workbench.selectedProjectID.v1"

    public static func loadProjects(from storage: StorageServiceProtocol) async throws -> [WorkbenchProjectSnapshot] {
        guard let raw = try await storage.getSetting(key: projectsKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([WorkbenchProjectSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func saveProjects(_ projects: [WorkbenchProjectSnapshot], to storage: StorageServiceProtocol) async throws {
        let data = try JSONEncoder().encode(projects)
        let raw = String(decoding: data, as: UTF8.self)
        try await storage.setSetting(key: projectsKey, value: raw)
    }

    public static func loadSelectedProjectID(from storage: StorageServiceProtocol) async throws -> String? {
        guard let raw = try await storage.getSetting(key: selectedProjectIDKey),
              raw.isEmpty == false else {
            return nil
        }
        return raw
    }

    public static func saveSelectedProjectID(_ projectID: String?, to storage: StorageServiceProtocol) async throws {
        guard let projectID else {
            try await storage.setSetting(key: selectedProjectIDKey, value: "")
            return
        }
        try await storage.setSetting(key: selectedProjectIDKey, value: projectID)
    }
}
