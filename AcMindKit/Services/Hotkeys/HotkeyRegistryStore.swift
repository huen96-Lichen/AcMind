import Foundation
import Dispatch

public enum HotkeyRegistryStore {
    private static let storageKey = "hotkeys.registry.v1"

    public static func load(from defaults: UserDefaults = .standard) -> [KeyboardShortcut] {
        let read: () -> [KeyboardShortcut] = {
            guard let data = defaults.data(forKey: storageKey),
                  let shortcuts = try? JSONDecoder().decode([KeyboardShortcut].self, from: data) else {
                return []
            }
            return shortcuts
        }

        if Thread.isMainThread {
            return read()
        } else {
            return DispatchQueue.main.sync(execute: read)
        }
    }

    public static func save(_ shortcuts: [KeyboardShortcut], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }

        let write = {
            defaults.set(data, forKey: storageKey)
        }

        if Thread.isMainThread {
            write()
        } else {
            DispatchQueue.main.sync(execute: write)
        }
    }

    public static func clear(from defaults: UserDefaults = .standard) {
        let write = {
            defaults.removeObject(forKey: storageKey)
        }

        if Thread.isMainThread {
            write()
        } else {
            DispatchQueue.main.sync(execute: write)
        }
    }
}
