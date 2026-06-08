import Foundation

public actor CorrectionService {
    public static let shared = CorrectionService()

    public func applyCorrections(to text: String, rules: [CorrectionRule]) -> String {
        guard !rules.isEmpty else { return text }
        var result = text
        for rule in rules {
            if rule.isRegex {
                result = result.replacingOccurrences(
                    of: rule.pattern,
                    with: rule.replacement,
                    options: .regularExpression
                )
            } else {
                result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement)
            }
        }
        return result
    }
}
