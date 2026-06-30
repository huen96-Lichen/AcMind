import Foundation

/// JSON-over-stdio runtime for plugins installed on disk.
///
/// Each invocation starts the manifest's executable, sends one JSON request on
/// stdin and expects one JSON response on stdout. Keeping the executable out of
/// the AcMind address space means a plugin cannot corrupt the host process.
final class DiskPolishPlugin: PolishPlugin, @unchecked Sendable {
    let id: String
    let name: String
    let version: String
    let capabilities: [PluginCapability]

    private let executor: DiskPluginExecutor

    init(descriptor: PluginDescriptor, pluginDirectory: URL) throws {
        guard descriptor.capabilities == [.customPolish] else {
            let unsupported = descriptor.capabilities
                .filter { $0 != .customPolish }
                .map(\.displayName)
                .joined(separator: "、")
            let reason = unsupported.isEmpty
                ? "清单未声明可执行能力"
                : "磁盘运行时暂不支持：\(unsupported)"
            throw PluginError.loadFailed(reason)
        }
        guard let entryPoint = descriptor.entryPoint?.trimmingCharacters(in: .whitespacesAndNewlines),
              !entryPoint.isEmpty else {
            throw PluginError.loadFailed("清单缺少 entryPoint")
        }

        let executableURL = pluginDirectory.appendingPathComponent(entryPoint)
        let resolvedDirectory = pluginDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedExecutable = executableURL.standardizedFileURL.resolvingSymlinksInPath().path
        guard resolvedExecutable.hasPrefix(resolvedDirectory + "/") else {
            throw PluginError.sandboxViolation
        }
        let resolvedURL = URL(fileURLWithPath: resolvedExecutable)
        let isRegularFile = (try? resolvedURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        guard isRegularFile, FileManager.default.isExecutableFile(atPath: resolvedExecutable) else {
            throw PluginError.loadFailed("entryPoint 不存在或不可执行: \(entryPoint)")
        }

        id = descriptor.id
        name = descriptor.name
        version = descriptor.version
        capabilities = descriptor.capabilities
        executor = DiskPluginExecutor(
            executableURL: resolvedURL,
            workingDirectory: pluginDirectory
        )
    }

    func activate() async throws {
        _ = try await executor.invoke(action: "activate")
    }

    func deactivate() async {
        _ = try? await executor.invoke(action: "deactivate")
    }

    func polish(text: String, mode: VoicePolishMode) async throws -> String {
        let response = try await executor.invoke(
            action: "polish",
            text: text,
            mode: mode.rawValue
        )
        guard let result = response.text else {
            throw PluginError.loadFailed("插件响应缺少 text")
        }
        return result
    }
}

private struct DiskPluginRequest: Codable {
    let protocolVersion: Int
    let action: String
    let text: String?
    let mode: String?
}

private struct DiskPluginResponse: Codable {
    let success: Bool
    let text: String?
    let error: String?
}

private final class DiskPluginExecutor: @unchecked Sendable {
    private let executableURL: URL
    private let workingDirectory: URL
    private let timeout: TimeInterval

    init(executableURL: URL, workingDirectory: URL, timeout: TimeInterval = 15) {
        self.executableURL = executableURL
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }

    func invoke(action: String, text: String? = nil, mode: String? = nil) async throws -> DiskPluginResponse {
        let request = DiskPluginRequest(protocolVersion: 1, action: action, text: text, mode: mode)
        let input = try JSONEncoder().encode(request)
        let executableURL = self.executableURL
        let workingDirectory = self.workingDirectory
        let timeout = self.timeout

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdin = Pipe()
                let stdout = Pipe()
                let stderr = Pipe()
                process.executableURL = executableURL
                process.currentDirectoryURL = workingDirectory
                process.standardInput = stdin
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    stdin.fileHandleForWriting.write(input)
                    try stdin.fileHandleForWriting.close()

                    let deadline = Date().addingTimeInterval(timeout)
                    while process.isRunning && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    guard !process.isRunning else {
                        process.terminate()
                        process.waitUntilExit()
                        throw PluginError.loadFailed("插件调用超时（\(Int(timeout)) 秒）")
                    }

                    let output = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
                    guard process.terminationStatus == 0 else {
                        let detail = String(data: errorOutput, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        throw PluginError.loadFailed(detail?.isEmpty == false ? detail! : "进程退出码 \(process.terminationStatus)")
                    }
                    guard output.count <= 1_048_576 else {
                        throw PluginError.loadFailed("插件响应超过 1 MiB 限制")
                    }
                    let response = try JSONDecoder().decode(DiskPluginResponse.self, from: output)
                    guard response.success else {
                        throw PluginError.loadFailed(response.error ?? "插件返回失败")
                    }
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
