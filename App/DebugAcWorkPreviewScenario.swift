import Foundation
#if DEBUG
enum DebugAcWorkPreviewScenario {
    static func resolve(arguments: [String] = ProcessInfo.processInfo.arguments) -> AcWorkPreviewScenario? {
        for argument in arguments {
            if argument.hasPrefix("--acwork-preview=") {
                let value = String(argument.dropFirst("--acwork-preview=".count))
                return AcWorkPreviewScenario(rawValue: value)
            }

            if argument.hasPrefix("--acwork-preview-") {
                let value = String(argument.dropFirst("--acwork-preview-".count))
                return AcWorkPreviewScenario(rawValue: value)
            }
        }

        return nil
    }
}
#endif
