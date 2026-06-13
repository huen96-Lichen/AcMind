import Foundation

public enum PluginCapability: String, Codable, Sendable, CaseIterable {
    case customASR
    case customPolish
    case customInjection

    public var displayName: String {
        switch self {
        case .customASR:
            return "自定义 ASR"
        case .customPolish:
            return "自定义润色"
        case .customInjection:
            return "自定义注入"
        }
    }
}

public protocol Plugin: Sendable {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var capabilities: [PluginCapability] { get }
    
    func activate() async throws
    func deactivate() async
}

public protocol ASRPlugin: Plugin {
    func createTranscriber() throws -> Transcriber
}

public protocol PolishPlugin: Plugin {
    func polish(text: String, mode: VoicePolishMode) async throws -> String
}

public protocol InjectionPlugin: Plugin {
    func createInjector() throws -> TextInjector
}
