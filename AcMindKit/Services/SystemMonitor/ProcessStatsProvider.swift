import Foundation

public final class ProcessStatsProvider: SystemMetricProvider, @unchecked Sendable {
    private let runner: ProcessCommandRunning

    public init(runner: ProcessCommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> [ProcessStats] {
        do {
            let result = try await runner.run(
                executablePath: "/bin/ps",
                arguments: ["-axo", "pid=,pcpu=,rss=,comm="]
            )

            guard result.exitCode == 0 else { return [] }

            return parse(psOutput: result.stdout)
                .sorted { $0.cpuPercent > $1.cpuPercent }
                .prefix(5)
                .map { $0 }
        } catch {
            return []
        }
    }

    private func parse(psOutput: String) -> [ProcessStats] {
        psOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let parts = trimmed.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
                guard parts.count >= 4 else { return nil }

                guard let pid = Int32(parts[0]),
                      let cpu = Double(parts[1]),
                      let rss = Double(parts[2]) else {
                    return nil
                }

                let name = parts.dropFirst(3).joined(separator: " ")
                return ProcessStats(
                    id: pid,
                    name: name,
                    cpuPercent: cpu,
                    memoryBytes: UInt64(max(0, rss) * 1024)
                )
            }
    }
}
