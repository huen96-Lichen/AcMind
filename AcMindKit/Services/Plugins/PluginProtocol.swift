import Foundation

public enum PluginCapability: String, Codable, Sendable, CaseIterable {
    case customASR
    case customPolish
    case customInjection
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
