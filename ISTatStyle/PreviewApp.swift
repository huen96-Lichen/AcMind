import SwiftUI

@main
struct ISTatPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ISPreviewDemo()
                .frame(minWidth: 400, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 420, height: 750)
    }
}
