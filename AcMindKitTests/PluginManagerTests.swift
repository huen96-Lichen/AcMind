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

    func testFailedActivationDoesNotRegisterPluginAsActive() async {
        let manager = PluginManager()
        let plugin = FailingPlugin(id: "failing-plugin-\(UUID().uuidString)")

        do {
            try await manager.register(plugin: plugin)
            XCTFail("activation failure should be propagated")
        } catch {
            let status = await manager.getPluginStatus(id: plugin.id)
            let activeCount = await manager.getActivePluginCount()
            let registered = await manager.getAllPlugins()[plugin.id]
            XCTAssertEqual(status, .error)
            XCTAssertEqual(activeCount, 0)
            XCTAssertNil(registered)
        }
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

    func testLoadingExecutablePolishPluginActivatesAndRuns() async throws {
        let pluginRoot = try makePluginRoot()
        defer { try? FileManager.default.removeItem(at: pluginRoot) }
        let pluginDirectory = pluginRoot.appendingPathComponent("disk-polish", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let descriptor = PluginDescriptor(
            id: "disk-polish",
            name: "Disk Polish",
            version: "1.0.0",
            capabilities: [.customPolish],
            entryPoint: "plugin.sh",
            configPath: pluginDirectory.appendingPathComponent("plugin.json").path
        )
        try JSONEncoder().encode(descriptor).write(to: pluginDirectory.appendingPathComponent("plugin.json"))
        let script = """
        #!/bin/sh
        input=$(cat)
        case "$input" in
          *'\"action\":\"polish\"'*) printf '{"success":true,"text":"来自磁盘插件"}' ;;
          *) printf '{"success":true}' ;;
        esac
        """
        let executable = pluginDirectory.appendingPathComponent("plugin.sh")
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let manager = PluginManager(pluginsDirectory: pluginRoot)
        try await manager.loadPlugin(at: pluginDirectory)

        let status = await manager.getPluginStatus(id: descriptor.id)
        let activeCount = await manager.getActivePluginCount()
        let polishPlugin = await manager.getPolishPlugins()[descriptor.id]
        let result = try await polishPlugin?.polish(text: "原文", mode: .light)
        XCTAssertEqual(status, .active)
        XCTAssertEqual(activeCount, 1)
        XCTAssertEqual(result, "来自磁盘插件")
    }

    func testLoadingExecutableASRPluginActivatesAndTranscribes() async throws {
        let pluginRoot = try makePluginRoot()
        defer { try? FileManager.default.removeItem(at: pluginRoot) }
        let pluginDirectory = pluginRoot.appendingPathComponent("disk-asr", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let descriptor = PluginDescriptor(
            id: "disk-asr",
            name: "Disk ASR",
            version: "1.0.0",
            capabilities: [.customASR],
            entryPoint: "plugin.sh",
            configPath: pluginDirectory.appendingPathComponent("plugin.json").path
        )
        try JSONEncoder().encode(descriptor).write(to: pluginDirectory.appendingPathComponent("plugin.json"))
        let script = """
        #!/bin/sh
        input=$(cat)
        case "$input" in
          *'\"action\":\"transcribe\"'*)
            case "$input" in
              *'\"audioPath\":'*'.wav'*) printf '{"success":true,"text":"磁盘 ASR 结果"}' ;;
              *) printf '{"success":false,"error":"missing audio path"}' ;;
            esac
            ;;
          *) printf '{"success":true}' ;;
        esac
        """
        let executable = pluginDirectory.appendingPathComponent("plugin.sh")
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let audioURL = pluginRoot.appendingPathComponent("sample.wav")
        try Data().write(to: audioURL)

        let manager = PluginManager(pluginsDirectory: pluginRoot)
        try await manager.loadPlugin(at: pluginDirectory)
        let asrPlugins = await manager.getASRPlugins()
        let plugin = try XCTUnwrap(asrPlugins[descriptor.id])
        let transcriber = try plugin.createTranscriber()
        let result = try await transcriber.transcribe(
            audioFile: AudioFile(url: audioURL, sampleRate: 16_000, channels: 1)
        )

        XCTAssertEqual(result, "磁盘 ASR 结果")
        let activeCount = await manager.getActivePluginCount()
        XCTAssertEqual(activeCount, 1)
    }

    func testLoadingExecutableInjectionPluginActivatesAndRuns() async throws {
        let pluginRoot = try makePluginRoot()
        defer { try? FileManager.default.removeItem(at: pluginRoot) }
        let pluginDirectory = pluginRoot.appendingPathComponent("disk-injection", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let descriptor = PluginDescriptor(
            id: "disk-injection",
            name: "Disk Injection",
            version: "1.0.0",
            capabilities: [.customInjection],
            entryPoint: "plugin.sh",
            configPath: pluginDirectory.appendingPathComponent("plugin.json").path
        )
        try JSONEncoder().encode(descriptor).write(to: pluginDirectory.appendingPathComponent("plugin.json"))
        let script = """
        #!/bin/sh
        input=$(cat)
        printf '%s\n' "$input" >> calls.log
        case "$input" in
          *'\"action\":\"selectionSnapshot\"'*) printf '{"success":true,"selection":{"selectedText":"旧文本","selectedRange":{"location":2,"length":3},"source":"plugin","isEditable":true,"isFocusedTarget":true}}' ;;
          *'\"action\":\"currentInputSnapshot\"'*) printf '{"success":true,"currentInput":{"text":"全文","isEditable":true,"isFocusedTarget":true,"textSource":"plugin"}}' ;;
          *) printf '{"success":true}' ;;
        esac
        """
        let executable = pluginDirectory.appendingPathComponent("plugin.sh")
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let manager = PluginManager(pluginsDirectory: pluginRoot)
        try await manager.loadPlugin(at: pluginDirectory)
        let injectionPlugins = await manager.getInjectionPlugins()
        let plugin = try XCTUnwrap(injectionPlugins[descriptor.id])
        let injector = try plugin.createInjector()
        let selection = await injector.getSelectionSnapshot()
        let currentInput = await injector.currentInputTextSnapshot()
        try await injector.insert(text: "新文本")
        try await injector.replaceSelection(text: "替换文本")

        XCTAssertEqual(selection.selectedText, "旧文本")
        XCTAssertEqual(selection.selectedRange?.location, 2)
        XCTAssertEqual(selection.selectedRange?.length, 3)
        XCTAssertTrue(selection.canReplaceSelection)
        XCTAssertEqual(currentInput.text, "全文")
        XCTAssertTrue(currentInput.isFocusedTarget)
        let calls = try String(contentsOf: pluginDirectory.appendingPathComponent("calls.log"), encoding: .utf8)
        XCTAssertTrue(calls.contains("新文本"))
        XCTAssertTrue(calls.contains("替换文本"))
        let activeCount = await manager.getActivePluginCount()
        XCTAssertEqual(activeCount, 1)
    }

    func testDiskPluginRejectsEntryPointSymlinkOutsidePluginDirectory() async throws {
        let pluginRoot = try makePluginRoot()
        defer { try? FileManager.default.removeItem(at: pluginRoot) }
        let pluginDirectory = pluginRoot.appendingPathComponent("escaped-polish", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let descriptor = PluginDescriptor(
            id: "escaped-polish",
            name: "Escaped Polish",
            version: "1.0.0",
            capabilities: [.customPolish],
            entryPoint: "plugin",
            configPath: pluginDirectory.appendingPathComponent("plugin.json").path
        )
        try JSONEncoder().encode(descriptor).write(to: pluginDirectory.appendingPathComponent("plugin.json"))
        try FileManager.default.createSymbolicLink(
            at: pluginDirectory.appendingPathComponent("plugin"),
            withDestinationURL: URL(fileURLWithPath: "/bin/sh")
        )

        let manager = PluginManager(pluginsDirectory: pluginRoot)
        do {
            try await manager.loadPlugin(at: pluginDirectory)
            XCTFail("entry point outside the plugin directory should fail")
        } catch PluginError.sandboxViolation {
            let status = await manager.getPluginStatus(id: descriptor.id)
            XCTAssertEqual(status, .error)
        }
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

private struct FailingPlugin: Plugin {
    let id: String
    let name = "Failing Plugin"
    let version = "1.0.0"
    let capabilities: [PluginCapability] = []

    func activate() async throws {
        throw PluginError.loadFailed("activation failed")
    }

    func deactivate() async {}
}
