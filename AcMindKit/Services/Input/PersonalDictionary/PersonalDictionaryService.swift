import Foundation

// MARK: - Personal Dictionary Service

/// 个人词典服务
/// 职责：
/// 1. 管理用户自定义词汇
/// 2. 提供热词列表给 ASR 和润色服务
/// 3. 支持词频统计和智能排序
public actor PersonalDictionaryService {
    
    // MARK: - Singleton
    
    public static let shared = PersonalDictionaryService()
    
    // MARK: - Properties
    
    private let storage: StorageServiceProtocol
    private var words: [PersonalWord] = []
    private var isLoaded = false
    
    // MARK: - Initialization
    
    public init(storage: StorageServiceProtocol? = nil) {
        self.storage = storage ?? StorageService()
    }
    
    // MARK: - Public Methods
    
    /// 加载个人词典
    public func loadDictionary() async throws {
        guard !isLoaded else { return }
        
        // 从存储加载
        let savedWords = try await storage.getPersonalWords()
        words = savedWords
        isLoaded = true
    }
    
    /// 保存个人词典
    public func saveDictionary() async throws {
        try await storage.savePersonalWords(words)
    }
    
    /// 添加单词
    public func addWord(_ word: String, category: WordCategory = .custom, priority: WordPriority = .normal) async throws {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedWord.isEmpty else { return }
        
        // 检查是否已存在
        if let index = words.firstIndex(where: { $0.word.lowercased() == normalizedWord }) {
            // 更新使用次数
            words[index].usageCount += 1
            words[index].lastUsed = Date()
        } else {
            // 添加新单词
            let newWord = PersonalWord(
                word: word.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                priority: priority,
                usageCount: 1,
                lastUsed: Date(),
                createdAt: Date()
            )
            words.append(newWord)
        }
        
        try await saveDictionary()
    }
    
    /// 删除单词
    public func removeWord(_ word: String) async throws {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        words.removeAll { $0.word.lowercased() == normalizedWord }
        try await saveDictionary()
    }
    
    /// 获取所有单词
    public func getAllWords() -> [PersonalWord] {
        return words
    }
    
    /// 获取热词列表（按优先级和使用频率排序）
    public func getHotwords(limit: Int = 50) -> [String] {
        let sortedWords = words.sorted { lhs, rhs in
            // 先按优先级排序
            if lhs.priority != rhs.priority {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            // 再按使用次数排序
            return lhs.usageCount > rhs.usageCount
        }
        
        return Array(sortedWords.prefix(limit)).map { $0.word }
    }
    
    /// 按类别获取单词
    public func getWords(by category: WordCategory) -> [PersonalWord] {
        return words.filter { $0.category == category }
    }
    
    /// 搜索单词
    public func searchWords(query: String) -> [PersonalWord] {
        let normalizedQuery = query.lowercased()
        return words.filter { 
            $0.word.lowercased().contains(normalizedQuery) ||
            $0.category.displayName.lowercased().contains(normalizedQuery)
        }
    }
    
    /// 记录单词使用
    public func recordUsage(_ word: String) async throws {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let index = words.firstIndex(where: { $0.word.lowercased() == normalizedWord }) {
            words[index].usageCount += 1
            words[index].lastUsed = Date()
            try await saveDictionary()
        }
    }
    
    /// 批量导入单词
    public func importWords(_ newWords: [String], category: WordCategory = .custom) async throws {
        for word in newWords {
            try await addWord(word, category: category)
        }
    }
    
    /// 导出单词列表
    public func exportWords() -> [String] {
        return words.map { $0.word }
    }
    
    /// 清空词典
    public func clearDictionary() async throws {
        words.removeAll()
        try await saveDictionary()
    }

    /// Replaces the dictionary without rebuilding entries, preserving sync metadata.
    public func replaceWords(_ newWords: [PersonalWord]) async throws {
        words = newWords
        isLoaded = true
        try await saveDictionary()
    }
}

// MARK: - Personal Word

/// 个人词汇
public struct PersonalWord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let word: String
    public let category: WordCategory
    public let priority: WordPriority
    public var usageCount: Int
    public var lastUsed: Date?
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        word: String,
        category: WordCategory = .custom,
        priority: WordPriority = .normal,
        usageCount: Int = 0,
        lastUsed: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.category = category
        self.priority = priority
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
    }
}

// MARK: - Word Category

/// 词汇类别
public enum WordCategory: String, Codable, Sendable, CaseIterable {
    case person = "person"          // 人名
    case company = "company"        // 公司名
    case product = "product"        // 产品名
    case location = "location"      // 地名
    case technical = "technical"    // 技术术语
    case custom = "custom"          // 自定义
    case abbreviation = "abbreviation" // 缩写
    case slang = "slang"            // 俚语
    
    public var displayName: String {
        switch self {
        case .person: return "人名"
        case .company: return "公司名"
        case .product: return "产品名"
        case .location: return "地名"
        case .technical: return "技术术语"
        case .custom: return "自定义"
        case .abbreviation: return "缩写"
        case .slang: return "俚语"
        }
    }
    
    public var icon: String {
        switch self {
        case .person: return "person.fill"
        case .company: return "building.2.fill"
        case .product: return "cube.fill"
        case .location: return "mappin.circle.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .custom: return "tag.fill"
        case .abbreviation: return "textformat.abc"
        case .slang: return "text.bubble.fill"
        }
    }
}

// MARK: - Word Priority

/// 词汇优先级
public enum WordPriority: Int, Codable, Sendable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public var displayName: String {
        switch self {
        case .low: return "低"
        case .normal: return "普通"
        case .high: return "高"
        case .critical: return "关键"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "gray"
        case .normal: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Storage Service Extension

public extension StorageServiceProtocol {
    func getPersonalWords() async throws -> [PersonalWord] {
        guard let json = try? await getSetting(key: "personalDictionary.words"),
              let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([PersonalWord].self, from: data)) ?? []
    }
    
    func savePersonalWords(_ words: [PersonalWord]) async throws {
        guard let data = try? JSONEncoder().encode(words),
              let json = String(data: data, encoding: .utf8) else { return }
        try await setSetting(key: "personalDictionary.words", value: json)
    }
}

// MARK: - Polish Service Extension

public extension PolishService {
    /// 使用个人词典进行润色
    func polishWithPersonalDictionary(
        text: String,
        mode: VoicePolishMode,
        personalDictionary: PersonalDictionaryService
    ) async throws -> String {
        let hotwords = await personalDictionary.getHotwords()
        return try await polish(text: text, mode: mode, hotwords: hotwords)
    }
}

// MARK: - STT Router Extension

public extension STTRouter {
    /// 使用个人词典进行转写
    func transcribeWithPersonalDictionary(
        audioFile: AudioFile,
        personalDictionary: PersonalDictionaryService
    ) async throws -> String {
        return try await transcribe(audioFile: audioFile)
    }
}
