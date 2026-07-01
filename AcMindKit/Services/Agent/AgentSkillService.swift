import Foundation

// MARK: - AgentSkillService

/// Agent 技能服务协议
public protocol AgentSkillServiceProtocol: Sendable {
    func saveSkill(_ skill: AgentSkill) async throws
    func getSkill(id: String) async throws -> AgentSkill?
    func listSkills(filter: SkillFilter?) async throws -> [AgentSkill]
    func updateSkill(_ skill: AgentSkill) async throws
    func deleteSkill(id: String) async throws
    func getSkillContext(taskDescription: String?) async throws -> SkillContext
    func incrementUseCount(skillId: String) async throws
    func incrementViewCount(skillId: String) async throws
    func initializeBuiltinSkills() async throws
}

/// Agent 技能服务
public actor AgentSkillService: AgentSkillServiceProtocol {
    private let storage: any StorageServiceProtocol

    public init(storage: any StorageServiceProtocol = StorageService()) {
        self.storage = storage
    }

    public func saveSkill(_ skill: AgentSkill) async throws {
        try await storage.setSetting(key: "skill_\(skill.id)", value: encodeSkill(skill))
        await updateSkillIndex(skillId: skill.id, add: true)
    }

    public func getSkill(id: String) async throws -> AgentSkill? {
        guard let data = try await storage.getSetting(key: "skill_\(id)") else {
            return nil
        }
        return decodeSkill(from: data)
    }

    public func listSkills(filter: SkillFilter?) async throws -> [AgentSkill] {
        let allSkills = try await loadAllSkills()
        guard let filter = filter else { return allSkills }

        return allSkills.filter { skill in
            if let categories = filter.categories, !categories.contains(skill.category) {
                return false
            }
            if let statuses = filter.statuses, !statuses.contains(skill.status) {
                return false
            }
            if let tags = filter.tags, !tags.isEmpty {
                let hasTag = tags.contains { skill.tags.contains($0) }
                if !hasTag { return false }
            }
            if let searchText = filter.searchText, !searchText.isEmpty {
                let lowercased = searchText.lowercased()
                let matches = skill.name.lowercased().contains(lowercased) ||
                             skill.description.lowercased().contains(lowercased) ||
                             skill.content.lowercased().contains(lowercased)
                if !matches { return false }
            }
            return true
        }
        .prefix(filter.limit ?? 50)
        .map { $0 }
    }

    public func updateSkill(_ skill: AgentSkill) async throws {
        var updated = skill
        updated.updatedAt = Date()
        try await saveSkill(updated)
    }

    public func deleteSkill(id: String) async throws {
        try await storage.setSetting(key: "skill_\(id)", value: "")
        await updateSkillIndex(skillId: id, add: false)
    }

    public func getSkillContext(taskDescription: String?) async throws -> SkillContext {
        let allSkills = try await listSkills(filter: SkillFilter(statuses: [.active]))
        guard let description = taskDescription, !description.isEmpty else {
            return SkillContext(skills: allSkills)
        }

        let lowercasedDesc = description.lowercased()
        let matchedSkills = allSkills.filter { skill in
            skill.triggerKeywords.contains { lowercasedDesc.contains($0.lowercased()) } ||
            skill.name.lowercased().contains(lowercasedDesc) ||
            skill.tags.contains { lowercasedDesc.contains($0.lowercased()) }
        }

        if matchedSkills.isEmpty {
            return SkillContext(skills: allSkills.prefix(5).map { $0 }, matchedBy: "default")
        }

        return SkillContext(skills: Array(matchedSkills), matchedBy: "keywords")
    }

    public func incrementUseCount(skillId: String) async throws {
        guard var skill = try await getSkill(id: skillId) else { return }
        skill.useCount += 1
        skill.lastUsedAt = Date()
        try await saveSkill(skill)
    }

    public func incrementViewCount(skillId: String) async throws {
        guard var skill = try await getSkill(id: skillId) else { return }
        skill.viewCount += 1
        try await saveSkill(skill)
    }

    public func initializeBuiltinSkills() async throws {
        for skill in AgentSkill.builtinSkills {
            if try await getSkill(id: skill.id) == nil {
                try await saveSkill(skill)
            }
        }
    }

    private func loadAllSkills() async throws -> [AgentSkill] {
        var skills: [AgentSkill] = []
        var index = 0
        while true {
            guard let data = try await storage.getSetting(key: "skill_index_\(index)") else {
                break
            }
            let ids = data.components(separatedBy: ",").filter { !$0.isEmpty }
            for id in ids {
                if let skill = try await getSkill(id: id) {
                    skills.append(skill)
                }
            }
            index += 1
        }
        return skills
    }

    private func updateSkillIndex(skillId: String, add: Bool) async {
        let indexKey = "skill_index_0"
        let currentIndex = (try? await storage.getSetting(key: indexKey)) ?? ""
        var skillIds = currentIndex
            .split(separator: ",")
            .map(String.init)
            .filter { $0.isEmpty == false }

        if add {
            if skillIds.contains(skillId) == false {
                skillIds.append(skillId)
            }
        } else {
            skillIds.removeAll { $0 == skillId }
        }

        let serializedIndex = skillIds.joined(separator: ",")
        try? await storage.setSetting(key: indexKey, value: serializedIndex)
    }

    private func encodeSkill(_ skill: AgentSkill) -> String {
        guard let data = try? JSONEncoder().encode(skill),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func decodeSkill(from string: String) -> AgentSkill? {
        guard let data = string.data(using: .utf8),
              let skill = try? JSONDecoder().decode(AgentSkill.self, from: data) else {
            return nil
        }
        return skill
    }
}
