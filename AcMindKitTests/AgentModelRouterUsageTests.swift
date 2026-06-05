import XCTest
@testable import AcMindKit

final class AgentModelRouterUsageTests: XCTestCase {

    var router: AgentModelRouter!

    override func setUp() async throws {
        try await super.setUp()
        router = AgentModelRouter(strategy: .automatic)
    }

    override func tearDown() async throws {
        router = nil
        try await super.tearDown()
    }

    func testRecordUsage() async throws {
        let usage = ModelUsage(
            providerId: "openai",
            modelId: "gpt-4o",
            promptTokens: 100,
            completionTokens: 50,
            totalTokens: 150,
            costUSD: 0.002,
            costCNY: 0.014,
            latencyMs: 200,
            success: true
        )

        await router.recordUsage(usage)

        let summary = await router.getUsageSummary(sessionId: nil)
        XCTAssertEqual(summary.totalTokens, 150)
        XCTAssertEqual(summary.totalRequests, 1)
        XCTAssertEqual(summary.successRequests, 1)
        XCTAssertEqual(summary.failedRequests, 0)
        XCTAssertEqual(summary.totalPromptTokens, 100)
        XCTAssertEqual(summary.totalCompletionTokens, 50)
    }

    func testGetUsageSummary() async throws {
        let usage1 = ModelUsage(
            providerId: "openai",
            modelId: "gpt-4o",
            promptTokens: 200,
            completionTokens: 100,
            totalTokens: 300,
            costUSD: 0.005,
            costCNY: 0.036,
            latencyMs: 300,
            success: true
        )

        let usage2 = ModelUsage(
            providerId: "deepseek",
            modelId: "deepseek-chat",
            promptTokens: 500,
            completionTokens: 200,
            totalTokens: 700,
            costUSD: 0.001,
            costCNY: 0.007,
            latencyMs: 150,
            success: false,
            errorMessage: "timeout"
        )

        let usage3 = ModelUsage(
            providerId: "anthropic",
            modelId: "claude-sonnet-4-20250514",
            promptTokens: 300,
            completionTokens: 150,
            totalTokens: 450,
            costUSD: 0.01,
            costCNY: 0.072,
            latencyMs: 400,
            success: true
        )

        await router.recordUsage(usage1)
        await router.recordUsage(usage2)
        await router.recordUsage(usage3)

        let summary = await router.getUsageSummary(sessionId: nil)
        XCTAssertEqual(summary.totalRequests, 3)
        XCTAssertEqual(summary.totalPromptTokens, 1000)
        XCTAssertEqual(summary.totalCompletionTokens, 450)
        XCTAssertEqual(summary.totalTokens, 1450)
        XCTAssertEqual(summary.successRequests, 2)
        XCTAssertEqual(summary.failedRequests, 1)
        XCTAssertEqual(summary.avgLatencyMs, 283)
    }

    func testGetCurrentSessionUsage() async throws {
        let usage1 = ModelUsage(
            providerId: "openai",
            modelId: "gpt-4o-mini",
            promptTokens: 80,
            completionTokens: 40,
            totalTokens: 120,
            costUSD: 0.001,
            costCNY: 0.007,
            latencyMs: 100,
            success: true
        )

        let usage2 = ModelUsage(
            providerId: "openai",
            modelId: "gpt-4o",
            promptTokens: 200,
            completionTokens: 100,
            totalTokens: 300,
            costUSD: 0.005,
            costCNY: 0.036,
            latencyMs: 250,
            success: true
        )

        await router.recordUsage(usage1)
        await router.recordUsage(usage2)

        let current = await router.getCurrentSessionUsage()
        XCTAssertEqual(current.sessionUsages.count, 2)
        XCTAssertEqual(current.sessionSummary.totalTokens, 420)
        XCTAssertEqual(current.sessionSummary.totalRequests, 2)
        XCTAssertEqual(current.currentCall?.modelId, "gpt-4o")
    }
}
