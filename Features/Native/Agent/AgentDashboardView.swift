import SwiftUI

struct AgentDashboardView: View {
    private let container: ServiceContainer

    init(container: ServiceContainer) {
        self.container = container
    }

    var body: some View {
        AgentWorkspaceView(container: container)
    }
}
