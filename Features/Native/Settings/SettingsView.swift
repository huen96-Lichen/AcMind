import SwiftUI

struct SettingsView: View {
    private let container: ServiceContainer

    init(container: ServiceContainer) {
        self.container = container
    }

    var body: some View {
        SettingsSuiteView(container: container)
    }
}
