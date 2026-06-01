import Foundation

public actor PluginManager {
    public static let shared = PluginManager()
    
    private var plugins: [String: Plugin] = [:]
    private var asrPlugins: [String: ASRPlugin] = [:]
    private var polishPlugins: [String: PolishPlugin] = [:]
    private var injectionPlugins: [String: InjectionPlugin] = [:]
    
    private let pluginsDirectory: URL
    
    public init() {
        pluginsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AcMind/Plugins")
    }
    
    public func discoverPlugins() async {
        guard FileManager.default.fileExists(atPath: pluginsDirectory.path) else { return }
    }
    
    public func register(plugin: Plugin) async throws {
        plugins[plugin.id] = plugin
        if let asrPlugin = plugin as? ASRPlugin {
            asrPlugins[plugin.id] = asrPlugin
        }
        if let polishPlugin = plugin as? PolishPlugin {
            polishPlugins[plugin.id] = polishPlugin
        }
        if let injectionPlugin = plugin as? InjectionPlugin {
            injectionPlugins[plugin.id] = injectionPlugin
        }
        try await plugin.activate()
    }
    
    public func unregister(pluginId: String) async {
        if let plugin = plugins.removeValue(forKey: pluginId) {
            await plugin.deactivate()
        }
        asrPlugins.removeValue(forKey: pluginId)
        polishPlugins.removeValue(forKey: pluginId)
        injectionPlugins.removeValue(forKey: pluginId)
    }
    
    public func getASRPlugins() -> [String: ASRPlugin] { asrPlugins }
    public func getPolishPlugins() -> [String: PolishPlugin] { polishPlugins }
    public func getInjectionPlugins() -> [String: InjectionPlugin] { injectionPlugins }
    public func getAllPlugins() -> [String: Plugin] { plugins }
}
