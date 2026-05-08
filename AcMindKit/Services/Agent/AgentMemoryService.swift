import Foundation

// MARK: - AgentMemoryService

/// Agent 记忆服务协议
public protocol AgentMemoryServiceProtocol: Sendable {
    func saveMemory(_ memory: AgentMemory) async throws
    func getMemory(id: String) async throws -> AgentMemory?
    func listMemories(filter: MemoryFilter?) async throws -> [AgentMemory]
    func updateMemory(_ memory: AgentMemory) async throws
    func deleteMemory(id: String) async throws
    func getMemoryContext(types: [MemoryType]?, query: String?) async throws -> MemoryContext
    func recordAccess(memoryId: String) async throws
}

/// Agent 记忆服务
public actor AgentMemoryService: AgentMemoryServiceProtocol {
    private let storage: any StorageServiceProtocol

    public init(storage: any StorageServiceProtocol = StorageService()) {
        self.storage = storage
    }

    public func saveMemory(_ memory: AgentMemory) async throws {
        try await storage.setSetting(key: "memory_\(memory.id)", value: encodeMemory(memory))
    }

    public func getMemory(id: String) async throws -> AgentMemory? {
        guard let data = try await storage.getSetting(key: "memory_\(id)") else {
            return nil
        }
        return decodeMemory(from: data)
    }

    public func listMemories(filter: MemoryFilter?) async throws -> [AgentMemory] {
        let allMemories = try await loadAllMemories()
        guard let filter = filter else { return allMemories }

        return allMemories.filter { memory in
            if let types = filter.types, !types.contains(memory.type) {
                return false
            }
            if let tags = filter.tags, !tags.isEmpty {
                let hasTag = tags.contains { memory.tags.contains($0) }
                if !hasTag { return false }
            }
            if let searchText = filter.searchText, !searchText.isEmpty {
                let lowercased = searchText.lowercased()
                let matches = memory.key.lowercased().contains(lowercased) ||
                             memory.value.lowercased().contains(lowercased)
                if !matches { return false }
            }
            if let minRelevance = filter.minRelevance, memory.relevanceScore < minRelevance {
                return false
            }
            return true
        }
        .sorted { $0.relevanceScore > $1.relevanceScore }
        .prefix(filter.limit ?? 50)
        .map { $0 }
    }

    public func updateMemory(_ memory: AgentMemory) async throws {
        var updated = memory
        updated.updatedAt = Date()
        try await saveMemory(updated)
    }

    public func deleteMemory(id: String) async throws {
        try await storage.setSetting(key: "memory_\(id)", value: "")
    }

    public func getMemoryContext(types: [MemoryType]?, query: String?) async throws -> MemoryContext {
        let memories = try await listMemories(filter: MemoryFilter(types: types, searchText: query))

        var preferenceMemories: [AgentMemory] = []
        var projectMemories: [AgentMemory] = []
        var taskMemories: [AgentMemory] = []
        var skillMemories: [AgentMemory] = []

        for memory in memories {
            switch memory.type {
            case .preference: preferenceMemories.append(memory)
            case .project: projectMemories.append(memory)
            case .task: taskMemories.append(memory)
            case .skill: skillMemories.append(memory)
            }
        }

        return MemoryContext(
            preferenceMemories: preferenceMemories,
            projectMemories: projectMemories,
            taskMemories: taskMemories,
            skillMemories: skillMemories
        )
    }

    public func recordAccess(memoryId: String) async throws {
        guard var memory = try await getMemory(id: memoryId) else { return }
        memory.accessCount += 1
        memory.lastAccessedAt = Date()
        try await saveMemory(memory)
    }

    private func loadAllMemories() async throws -> [AgentMemory] {
        var memories: [AgentMemory] = []
        var index = 0
        while true {
            guard let data = try await storage.getSetting(key: "memory_index_\(index)") else {
                break
            }
            let ids = data.components(separatedBy: ",").filter { !$0.isEmpty }
            for id in ids {
                if let memory = try await getMemory(id: id) {
                    memories.append(memory)
                }
            }
            index += 1
        }
        return memories
    }

    private func encodeMemory(_ memory: AgentMemory) -> String {
        guard let data = try? JSONEncoder().encode(memory),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func decodeMemory(from string: String) -> AgentMemory? {
        guard let data = string.data(using: .utf8),
              let memory = try? JSONDecoder().decode(AgentMemory.self, from: data) else {
            return nil
        }
        return memory
    }
}
