import Foundation
import Combine

@MainActor
public final class SystemHardwareHelperInstaller: ObservableObject {
    @Published public private(set) var isInstalled = false
    @Published public private(set) var isRunning = false
    @Published public private(set) var isInstalling = false
    @Published public private(set) var lastMessage: String?

    private let fileManager: FileManager
    private let processRunner: ProcessRunner
    private let helperLabel: String
    private let helperSourceName: String

    public init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunner = FoundationProcessRunner(),
        helperLabel: String = SystemHardwareAccess.defaultHelperInstallLabel,
        helperSourceName: String = SystemHardwareAccess.defaultHelperInstallLabel
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
        self.helperLabel = helperLabel
        self.helperSourceName = helperSourceName
    }

    public func refreshStatus() {
        let helperBinaryExists = fileManager.fileExists(atPath: installedHelperBinaryURL.path)
        let helperPlistExists = fileManager.fileExists(atPath: installedLaunchDaemonURL.path)
        isInstalled = helperBinaryExists && helperPlistExists
        isRunning = isLaunchDaemonRunning()
    }

    public func install() async -> Bool {
        guard let sourceBinaryURL = embeddedHelperBinaryURL else {
            lastMessage = "找不到 helper 二进制，先重新构建应用"
            return false
        }

        isInstalling = true
        defer { isInstalling = false }

        do {
            try fileManager.createDirectory(
                at: fileManager.temporaryDirectory,
                withIntermediateDirectories: true
            )

            let plistURL = try writeLaunchDaemonPlist()
            let command = try buildInstallCommand(sourceBinaryURL: sourceBinaryURL, plistURL: plistURL)
            let result = try processRunner.runAppleScript(command: command)

            refreshStatus()
            if result.exitCode == 0 {
                lastMessage = "helper 已安装"
                return true
            }

            lastMessage = result.output.isEmpty ? result.error : result.output
            return false
        } catch {
            lastMessage = error.localizedDescription
            return false
        }
    }

    public func uninstall() async -> Bool {
        isInstalling = true
        defer { isInstalling = false }

        do {
            let command = """
            set -e
            launchctl bootout system/\(helperLabel) >/dev/null 2>&1 || true
            rm -f \(shellQuoted(installedLaunchDaemonURL.path))
            rm -f \(shellQuoted(installedHelperBinaryURL.path))
            """
            let result = try processRunner.runAppleScript(command: command)
            refreshStatus()

            if result.exitCode == 0 {
                lastMessage = "helper 已移除"
                return true
            }

            lastMessage = result.output.isEmpty ? result.error : result.output
            return false
        } catch {
            lastMessage = error.localizedDescription
            return false
        }
    }

    public var helperBinaryPath: String {
        embeddedHelperBinaryURL?.path ?? installedHelperBinaryURL.path
    }

    public var helperInstallDescription: String {
        if isInstalled && isRunning {
            return "helper 已安装并运行"
        }
        if isInstalled {
            return "helper 已安装，等待启动"
        }
        return "helper 未安装"
    }

    private var embeddedHelperBinaryURL: URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchServices")
            .appendingPathComponent(helperSourceName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private var installedHelperBinaryURL: URL {
        URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(helperLabel)")
    }

    private var installedLaunchDaemonURL: URL {
        URL(fileURLWithPath: "/Library/LaunchDaemons/\(helperLabel).plist")
    }

    private func buildInstallCommand(sourceBinaryURL: URL, plistURL: URL) throws -> String {
        let shellCommand = commandsForInstall(sourceBinaryURL: sourceBinaryURL, plistURL: plistURL).joined(separator: " && ")
        return "do shell script \(appleScriptQuoted(shellCommand)) with administrator privileges"
    }

    private func commandsForInstall(sourceBinaryURL: URL, plistURL: URL) -> [String] {
        [
            "set -e",
            "install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools",
            "install -d -o root -g wheel -m 755 /Library/LaunchDaemons",
            "cp \(shellQuoted(sourceBinaryURL.path)) \(shellQuoted(installedHelperBinaryURL.path))",
            "chown root:wheel \(shellQuoted(installedHelperBinaryURL.path))",
            "chmod 755 \(shellQuoted(installedHelperBinaryURL.path))",
            "cp \(shellQuoted(plistURL.path)) \(shellQuoted(installedLaunchDaemonURL.path))",
            "chown root:wheel \(shellQuoted(installedLaunchDaemonURL.path))",
            "chmod 644 \(shellQuoted(installedLaunchDaemonURL.path))",
            "launchctl bootout system/\(helperLabel) >/dev/null 2>&1 || true",
            "launchctl bootstrap system \(shellQuoted(installedLaunchDaemonURL.path))",
            "launchctl enable system/\(helperLabel)",
            "launchctl kickstart -k system/\(helperLabel)"
        ]
    }

    private func writeLaunchDaemonPlist() throws -> URL {
        let plist: [String: Any] = [
            "Label": helperLabel,
            "ProgramArguments": [installedHelperBinaryURL.path],
            "MachServices": [helperLabel: true],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background"
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        let url = fileManager.temporaryDirectory.appendingPathComponent("\(helperLabel).plist")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func isLaunchDaemonRunning() -> Bool {
        let result = processRunner.run("/bin/launchctl", arguments: ["print", "system/\(helperLabel)"])
        return result.exitCode == 0
    }

    private func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptQuoted(_ string: String) -> String {
        "\"\(string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

public protocol ProcessRunner {
    func run(_ launchPath: String, arguments: [String]) -> ProcessResult
    func runAppleScript(command: String) throws -> ProcessResult
}

public struct ProcessResult {
    public let exitCode: Int32
    public let output: String
    public let error: String

    public init(exitCode: Int32, output: String, error: String) {
        self.exitCode = exitCode
        self.output = output
        self.error = error
    }
}

public final class FoundationProcessRunner: ProcessRunner {
    public init() {}

    public func run(_ launchPath: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ProcessResult(exitCode: -1, output: "", error: error.localizedDescription)
        }

        let output = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, output: output, error: error)
    }

    public func runAppleScript(command: String) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", command]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw error
        }

        let output = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, output: output, error: error)
    }
}
