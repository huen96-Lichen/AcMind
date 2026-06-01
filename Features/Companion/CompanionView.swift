import SwiftUI
import AcMindKit

// MARK: - Companion View
// 随身主页面 - 系统能力控制中心

struct CompanionView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var isGlobalEnabled = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                CompanionSettingsHeader(isEnabled: $isGlobalEnabled)
                
                // Capsule Card
                CapsuleSettingsCard(
                    isEnabled: $viewModel.companionCapsuleEnabled,
                    isGlobalEnabled: isGlobalEnabled,
                    position: $viewModel.companionCapsulePosition,
                    isExpanded: $viewModel.companionCapsuleExpanded
                )
                
                // Voice Card
                VoiceSettingsCard(
                    isEnabled: $viewModel.companionVoiceEnabled,
                    isGlobalEnabled: isGlobalEnabled,
                    outputMode: $viewModel.companionVoiceOutputMode,
                    saveToInbox: $viewModel.companionVoiceSaveToInbox
                )
                
                // Shortcuts Card
                ShortcutSettingsCard(
                    isEnabled: $viewModel.companionShortcutsEnabled,
                    isGlobalEnabled: isGlobalEnabled,
                    shortcuts: viewModel.companionShortcuts,
                    voiceEnabled: viewModel.companionVoiceEnabled,
                    captureEnabled: viewModel.companionCaptureEnabled
                )
                
                // Capture Card
                CaptureSettingsCard(
                    isEnabled: $viewModel.companionCaptureEnabled,
                    isGlobalEnabled: isGlobalEnabled,
                    autoSaveToInbox: $viewModel.companionCaptureAutoSaveToInbox,
                    textCaptureEnabled: $viewModel.companionCaptureTextEnabled,
                    linkCaptureEnabled: $viewModel.companionCaptureLinkEnabled,
                    saveDestinationIndex: $viewModel.companionCaptureSaveDestinationIndex
                )
                
                // Permissions Section (optional, kept at bottom)
                companionPermissionsSection
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .frame(maxWidth: 1200, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppSurfaceTokens.background)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onChange(of: isGlobalEnabled) { _, newValue in
            if newValue {
                // Save when enabling
                Task {
                    await viewModel.saveCompanionSettings()
                }
            }
        }
        .onChange(of: viewModel.companionCapsuleEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCapsuleShowOnLaunch) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCapsulePosition) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCapsuleExpanded) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionVoiceEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionVoiceOutputMode) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionVoiceSaveToInbox) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionShortcutsEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionShortcuts) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureAutoSaveToInbox) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureTextEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureLinkEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureSaveDestinationIndex) { _, _ in persistCompanionSettings() }
    }
    
    // MARK: - Companion Permissions Section
    private var companionPermissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                
                Text("权限状态")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                CompanionPermissionRow(
                    title: "麦克风权限",
                    description: "用于说入法转文字",
                    status: viewModel.microphonePermissionStatus
                )
                
                CompanionPermissionRow(
                    title: "辅助功能权限",
                    description: "用于全局快捷键监听",
                    status: viewModel.accessibilityPermissionStatus
                )
                
                CompanionPermissionRow(
                    title: "屏幕录制权限",
                    description: "用于截图捕获功能",
                    status: viewModel.screenRecordingPermissionStatus
                )
            }
        }
        .opacity(isGlobalEnabled ? 1.0 : 0.55)
    }

    private func persistCompanionSettings() {
        Task {
            await viewModel.saveCompanionSettings()
        }
    }
}

// MARK: - Companion Permission Row
struct CompanionPermissionRow: View {
    let title: String
    let description: String
    let status: CompanionPermissionStatus
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(status.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(8)
    }
}
