import XCTest
@testable import AcMindKit

final class AcMindLoggerTests: XCTestCase {
    func testFormatIncludesFileFunctionLineAndMessage() {
        let formatted = AcMindLogger.format(
            "hello world",
            file: "SomeFile.swift",
            function: "someFunction()",
            line: 42
        )

        XCTAssertEqual(formatted, "[SomeFile.swift:42 someFunction()] hello world")
    }
}
