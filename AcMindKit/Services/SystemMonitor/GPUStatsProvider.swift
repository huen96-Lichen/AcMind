import Foundation

public final class GPUStatsProvider: SystemMetricProvider, @unchecked Sendable {
    private let runner: ProcessCommandRunning

    public init(runner: ProcessCommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> GPUStats? {
        do {
            let result = try await runner.run(
                executablePath: "/usr/sbin/system_profiler",
                arguments: ["SPDisplaysDataType"]
            )

            guard result.exitCode == 0 else { return nil }

            let name = parseValue(from: result.stdout, key: "Chipset Model")
                ?? parseValue(from: result.stdout, key: "Device ID")

            guard name != nil else { return nil }

            return GPUStats(
                name: name,
                usagePercent: nil,
                temperatureCelsius: nil
            )
        } catch {
            return nil
        }
    }

    private func parseValue(from output: String, key: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("\(key):") else { return nil }
                return trimmed
                    .dropFirst(key.count + 1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .first
    }
}
