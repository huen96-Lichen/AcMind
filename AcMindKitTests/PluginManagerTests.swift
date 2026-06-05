import XCTest
@testable import AcMindKit

final class PluginManagerTests: XCTestCase {

    func testDiscoverPlugins() async {
        let manager = PluginManager()
        await manager.discoverPlugins()

        let descriptors = await manager.getDiscoveredDescriptors()
        let statuses = await manager.getAllStatuses()
        XCTAssertNotNil(descriptors)
        XCTAssertNotNil(statuses)
    }

    func testPluginLifecycle() async throws {
        let manager = PluginManager()
        let plugin = TestPlugin(id: "test-plugin-\(UUID().uuidString)")

        try await manager.register(plugin: plugin)

        let status = await manager.getPluginStatus(id: plugin.id)
        XCTAssertEqual(status, .active)

        let activeCount = await manager.getActivePluginCount()
        XCTAssertEqual(activeCount, 1)

        XCTAssertTrue(plugin.activateCalled)

        await manager.unregister(pluginId: plugin.id)

        let removedStatus = await manager.getPluginStatus(id: plugin.id)
        XCTAssertEqual(removedStatus, .discovered)

        let finalCount = await manager.getActivePluginCount()
        XCTAssertEqual(finalCount, 0)

        XCTAssertTrue(plugin.deactivateCalled)
    }
}

private final class TestPlugin: Plugin, @unchecked Sendable {
    let id: String
    let name: String = "Test Plugin"
    let version: String = "1.0.0"
    let capabilities: [PluginCapability] = []

    private(set) var activateCalled = false
    private(set) var deactivateCalled = false

    init(id: String) {
        self.id = id
    }

    func activate() async throws {
        activateCalled = true
    }

    func deactivate() async {
        deactivateCalled = true
    }
}
