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

    func testManagementSummariesIncludeDescriptorStatusCapabilitiesAndPolicy() async throws {
        let pluginRoot = try makePluginRoot()
        let pluginDirectory = pluginRoot.appendingPathComponent("sample-plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let descriptor = PluginDescriptor(
            id: "sample-plugin",
            name: "Sample Plugin",
            version: "1.2.3",
            author: "AcMind",
            description: "测试插件",
            capabilities: [.customASR, .customPolish],
            entryPoint: "main.swift",
            configPath: pluginDirectory.appendingPathComponent("plugin.json").path
        )
        let data = try JSONEncoder().encode(descriptor)
        try data.write(to: pluginDirectory.appendingPathComponent("plugin.json"))

        let manager = PluginManager(pluginsDirectory: pluginRoot)
        await manager.discoverPlugins()

        let summaries = await manager.getManagementSummaries()
        let summary = try XCTUnwrap(summaries.first)
        XCTAssertEqual(summary.id, "sample-plugin")
        XCTAssertEqual(summary.name, "Sample Plugin")
        XCTAssertEqual(summary.status, .discovered)
        XCTAssertEqual(summary.capabilityLabels, ["自定义 ASR", "自定义润色"])
        XCTAssertEqual(summary.policy.permissions, [.fileRead])
        XCTAssertEqual(summary.policy.resourceLimits.memoryMB, 256)
        XCTAssertEqual(summary.policy.resourceLimits.cpuPercent, 25)
        XCTAssertNil(summary.errorMessage)
    }

    func testLoadingDescriptorDoesNotClaimRuntimeIsActive() async throws {
        let pluginRoot = try makePluginRoot()
        defer { try? FileManager.default.removeItem(at: pluginRoot) }
        let pluginDirectory = pluginRoot.appendingPathComponent("metadata-only", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let descriptor = PluginDescriptor(
            id: "metadata-only",
            name: "Metadata Only",
            version: "1.0.0",
            capabilities: [.customASR],
            entryPoint: "main.swift",
            configPath: pluginDirectory.appendingPathComponent("plugin.json").path
        )
        try JSONEncoder().encode(descriptor).write(to: pluginDirectory.appendingPathComponent("plugin.json"))

        let manager = PluginManager(pluginsDirectory: pluginRoot)
        try await manager.loadPlugin(at: pluginDirectory)

        let status = await manager.getPluginStatus(id: descriptor.id)
        let activeCount = await manager.getActivePluginCount()
        let plugins = await manager.getAllPlugins()
        let asrPlugins = await manager.getASRPlugins()
        XCTAssertEqual(status, .discovered)
        XCTAssertEqual(activeCount, 0)
        XCTAssertTrue(plugins.isEmpty)
        XCTAssertTrue(asrPlugins.isEmpty)
    }

    func testPluginSandboxPolicySnapshotExposesPermissionsAndLimits() async {
        let sandbox = PluginSandbox(
            pluginId: "policy-plugin",
            permissions: [.fileRead, .clipboardAccess],
            maxMemoryMB: 128,
            maxCPUPercent: 10
        )

        let policy = await sandbox.policySnapshot()

        XCTAssertEqual(policy.permissions, [.fileRead, .clipboardAccess])
        XCTAssertEqual(policy.permissionLabels, ["文件读取", "剪贴板访问"])
        XCTAssertEqual(policy.resourceLimits.memoryMB, 128)
        XCTAssertEqual(policy.resourceLimits.cpuPercent, 10)
    }

    func testPluginSandboxRejectsSiblingWithMatchingPrefix() async throws {
        let pluginRoot = try makePluginRoot()
        defer { try? FileManager.default.removeItem(at: pluginRoot) }
        let sandbox = PluginSandbox(pluginId: "trusted", pluginsDirectory: pluginRoot)

        let trustedPath = pluginRoot.appendingPathComponent("trusted/config.json")
        let siblingPath = pluginRoot.appendingPathComponent("trusted-evil/config.json")

        let trustedAccess = await sandbox.validateAccess(path: trustedPath)
        let siblingAccess = await sandbox.validateAccess(path: siblingPath)
        XCTAssertTrue(trustedAccess)
        XCTAssertFalse(siblingAccess)
    }

    private func makePluginRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-PluginManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
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
