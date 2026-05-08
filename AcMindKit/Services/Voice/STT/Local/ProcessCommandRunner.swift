import Foundation

// MARK: - Process Command Result

/// 命令行执行结果
public struct ProcessCommandResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

// MARK: - Process Command Running Protocol

/// 命令行运行协议（用于测试注入）
public protocol ProcessCommandRunning: Sendable {
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?
    ) async throws -> ProcessCommandResult
}

extension ProcessCommandRunning {
    func run(executablePath: String, arguments: [String]) async throws -> ProcessCommandResult {
        try await run(
            executablePath: executablePath,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil
        )
    }
}

// MARK: - Process Command Runner

/// 默认命令行运行器
/// 使用非阻塞管道避免死锁（参考 Typeflux ProcessCommandRunner）
public final class ProcessCommandRunner: ProcessCommandRunning {
    private final class OutputBuffer: @unchecked Sendable {
        private var data = Data()
        private let lock = NSLock()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let snapshot = data
            lock.unlock()
            return snapshot
        }
    }

    public init() {}

    public func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> ProcessCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            if let environment {
                var merged = ProcessInfo.processInfo.environment
                environment.forEach { key, value in merged[key] = value }
                process.environment = merged
            }
            if let currentDirectoryURL {
                process.currentDirectoryURL = currentDirectoryURL
            }

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // 非阻塞累积输出，防止管道缓冲区满导致死锁
            let stdoutData = OutputBuffer()
            let stderrData = OutputBuffer()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                stdoutData.append(handle.availableData)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                stderrData.append(handle.availableData)
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                stdoutData.append(remainingStdout)
                stderrData.append(remainingStderr)

                let result = ProcessCommandResult(
                    stdout: String(decoding: stdoutData.snapshot(), as: UTF8.self),
                    stderr: String(decoding: stderrData.snapshot(), as: UTF8.self),
                    exitCode: process.terminationStatus
                )

                if process.terminationStatus == 0 {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(
                        throwing: STTError.transcriptionFailed(
                            result.stderr.isEmpty ? result.stdout : result.stderr
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
