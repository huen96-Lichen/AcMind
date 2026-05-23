import Foundation
import AcMindKit

extension AppDelegate {
    var notchPanelEnabled: Bool {
        if UserDefaults.standard.object(forKey: "AppSettings.notchPanelEnabled") != nil {
            return UserDefaults.standard.bool(forKey: "AppSettings.notchPanelEnabled")
        }
        return true
    }

    var desktopCapsuleEnabled: Bool {
        if let data = UserDefaults.standard.data(forKey: "AppSettings.desktopCapsule"),
           let settings = try? JSONDecoder().decode(DesktopCapsuleSettings.self, from: data) {
            return settings.isEnabled
        }
        return true
    }

    var desktopCapsuleAutoShowOnLaunch: Bool {
        if let data = UserDefaults.standard.data(forKey: "AppSettings.desktopCapsule"),
           let settings = try? JSONDecoder().decode(DesktopCapsuleSettings.self, from: data) {
            return settings.showOnLaunch
        }
        return true
    }
}
