import XCTest
@testable import AcMindKit

final class CorrectionServiceTests: XCTestCase {
    let service = CorrectionService()

    func testPlainTextReplacement() async {
        let rules = [CorrectionRule(pattern: "世界", replacement: "Swift")]
        let result = await service.applyCorrections(to: "你好世界", rules: rules)
        XCTAssertEqual(result, "你好Swift")
    }

    func testRegexReplacement() async {
        let rules = [CorrectionRule(pattern: "\\d{4,}", replacement: "****", isRegex: true)]
        let result = await service.applyCorrections(to: "电话12345678", rules: rules)
        XCTAssertEqual(result, "电话****")
    }

    func testMultipleRules() async {
        let rules = [
            CorrectionRule(pattern: "世界", replacement: "Swift"),
            CorrectionRule(pattern: "你好", replacement: "Hello"),
        ]
        let result = await service.applyCorrections(to: "你好世界", rules: rules)
        XCTAssertEqual(result, "HelloSwift")
    }

    func testEmptyRules() async {
        let result = await service.applyCorrections(to: "你好世界", rules: [])
        XCTAssertEqual(result, "你好世界")
    }

    func testNoMatch() async {
        let rules = [CorrectionRule(pattern: "不存在", replacement: "替换")]
        let result = await service.applyCorrections(to: "你好世界", rules: rules)
        XCTAssertEqual(result, "你好世界")
    }

    func testSpecialCharacters() async {
        let rules = [CorrectionRule(pattern: "🎉", replacement: "🎊")]
        let result = await service.applyCorrections(to: "完成🎉", rules: rules)
        XCTAssertEqual(result, "完成🎊")
    }
}
