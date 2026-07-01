import Foundation

public enum CleaningResult: Sendable {
    case ignore
    case clean(cleanedText: String)
    case pass(text: String)
}

final class CleaningRulesStore: @unchecked Sendable {

    private var rules: [CleaningRule] = []
    private let storage: StorageServiceProtocol
    private let storageKey = "clipboard_cleaning_rules"

    init(storage: StorageServiceProtocol) {
        self.storage = storage
    }

    func loadRules() async {
        if let stored = try? await storage.getSetting(key: storageKey),
           let data = stored.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CleaningRule].self, from: data) {
            rules = decoded
        }
    }

    func saveRules() async {
        let data = try? JSONEncoder().encode(rules)
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        try? await storage.setSetting(key: storageKey, value: json)
    }

    func getRules() -> [CleaningRule] {
        rules
    }

    func addRule(_ rule: CleaningRule) async {
        rules.append(rule)
        await saveRules()
    }

    func updateRule(_ rule: CleaningRule) async {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            await saveRules()
        }
    }

    func deleteRule(id: String) async {
        rules.removeAll { $0.id == id }
        await saveRules()
    }

    func toggleRule(id: String) async {
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            await saveRules()
        }
    }

    func evaluate(text: String, sourceApp: String?) -> CleaningResult {
        for rule in rules where rule.isEnabled {
            let matches: Bool

            switch rule.matchType {
            case .contains:
                matches = text.localizedCaseInsensitiveContains(rule.pattern)
            case .regex:
                matches = (try? NSRegularExpression(pattern: rule.pattern))
                    .flatMap { $0.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) } != nil
            case .appName:
                matches = sourceApp?.localizedCaseInsensitiveContains(rule.pattern) ?? false
            case .appBundle:
                matches = false
            }

            if matches {
                switch rule.action {
                case .ignore:
                    return .ignore
                case .clean:
                    return .clean(cleanedText: cleanText(text, pattern: rule.pattern, matchType: rule.matchType))
                case .replace:
                    return .clean(cleanedText: rule.replacement ?? "")
                }
            }
        }

        return .pass(text: text)
    }

    private func cleanText(_ text: String, pattern: String, matchType: CleaningRule.MatchType) -> String {
        switch matchType {
        case .contains:
            return text.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
            return regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        case .appName, .appBundle:
            return text
        }
    }
}
