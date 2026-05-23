import SwiftUI
import AcMindKit

struct ContentView: View {
    private let serviceContainer: ServiceContainer
    @ObservedObject private var appState: AppState
    private let musicService: MusicService
    private let toastManager: ToastManager
    @StateObject private var voiceSession: CompanionVoiceSessionController
    @State private var showQuickNote = false

    init(
        serviceContainer: ServiceContainer,
        appState: AppState,
        musicService: MusicService,
        toastManager: ToastManager
    ) {
        self.serviceContainer = serviceContainer
        self._appState = ObservedObject(wrappedValue: appState)
        self.musicService = musicService
        self.toastManager = toastManager
        self._voiceSession = StateObject(
            wrappedValue: CompanionVoiceSessionController(
                container: serviceContainer,
                appState: appState,
                toastManager: toastManager
            )
        )
    }

    var body: some View {
        AppShell(
            selectedItem: Binding(
                get: { appState.sidebarSelection },
                set: { appState.sidebarSelection = $0 }
            ),
            serviceContainer: serviceContainer,
            appState: appState,
            toastManager: toastManager
        )
            .environmentObject(musicService)
            .environmentObject(toastManager)
            .sheet(isPresented: $voiceSession.isPresented) {
                CompanionVoicePanel(container: serviceContainer, appState: appState, toastManager: toastManager)
                    .transition(.scale.combined(with: .opacity))
            }
            .sheet(isPresented: $showQuickNote) {
                QuickNotePanel(container: serviceContainer, toastManager: toastManager)
                    .transition(.scale.combined(with: .opacity))
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowAgent)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    appState.selectSidebarItem(.agent)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowInbox)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    appState.selectSidebarItem(.inbox)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowSchedule)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    appState.selectSidebarItem(.schedule)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowVoicePanel)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    voiceSession.present(autoStart: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowCapturePanel)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    voiceSession.present(autoStart: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowQuickNote)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showQuickNote = true
                }
            }
    }
}
