import XCTest
@testable import AcMindKit

final class AgentModelRouterNewFeatureTests: XCTestCase {

    var router: AgentModelRouter!

    override func setUp() async throws {
        try await super.setUp()
        router = AgentModelRouter(strategy: .automatic)
    }

    override func tearDown() async throws {
        router = nil
        try await super.tearDown()
    }

    func testRoutingHistory() async throws {
        let request = ModelRouteRequest(
            inputLength: 200,
            requiresPrivacy: false,
            complexity: .medium
        )

        _ = try await router.route(request: request)

        let history = await router.getRoutingHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.taskType, .simpleChat)
        XCTAssertNotNil(history.first?.providerId)
        XCTAssertNotNil(history.first?.modelId)
    }

    func testRoutingHistoryMultiple() async throws {
        let request1 = ModelRouteRequest(inputLength: 100, complexity: .low)
        let request2 = ModelRouteRequest(inputLength: 500, complexity: .high)

        _ = try await router.route(request: request1)
        _ = try await router.route(request: request2)

        let history = await router.getRoutingHistory()
        XCTAssertEqual(history.count, 2)
    }

    func testRoutingHistoryForTaskType() async throws {
        let chatRequest = ModelRouteRequest(inputLength: 100)
        let visionRequest = ModelRouteRequest(taskType: .vision, inputLength: 100)

        _ = try await router.route(request: chatRequest)
        _ = try await router.route(request: visionRequest)

        let chatHistory = await router.getRoutingHistory(for: .simpleChat)
        XCTAssertEqual(chatHistory.count, 1)

        let visionHistory = await router.getRoutingHistory(for: .vision)
        XCTAssertEqual(visionHistory.count, 1)
    }

    func testConfigurableCandidates() async throws {
        await router.setCandidates(
            [(providerId: "custom-provider", modelId: "custom-model", tier: .cloudLight, qualityScore: 95)],
            for: .simpleChat
        )

        let request = ModelRouteRequest(inputLength: 100)
        let route = try await router.route(request: request)

        XCTAssertEqual(route.providerId, "custom-provider")
        XCTAssertEqual(route.modelId, "custom-model")
    }

    func testClearCandidates() async throws {
        await router.setCandidates(
            [(providerId: "custom-provider", modelId: "custom-model", tier: .cloudLight, qualityScore: 95)],
            for: .simpleChat
        )
        await router.clearCandidates(for: .simpleChat)

        let request = ModelRouteRequest(inputLength: 100)
        let route = try await router.route(request: request)

        XCTAssertNotEqual(route.providerId, "custom-provider")
    }

    func testStrategyUpdate() async throws {
        await router.updateStrategy(.localPriority)
        let strategy = await router.getCurrentStrategy()
        XCTAssertEqual(strategy, .localPriority)
    }

    func testStrategyAffectsRouting() async throws {
        let request = ModelRouteRequest(inputLength: 200)

        await router.updateStrategy(.automatic)
        _ = try await router.route(request: request)

        await router.updateStrategy(.cloudPriority)
        _ = try await router.route(request: request)

        let history = await router.getRoutingHistory()
        XCTAssertEqual(history.count, 2)
    }
}
