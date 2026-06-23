import SwiftUI
import AcMindKit

// MARK: - Companion View
// 随身主页面 - 系统能力控制中心

struct CompanionView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                CompanionSettingsHeader(isEnabled: $viewModel.companionEnabled)
                
                // Capsule Card
                CapsuleSettingsCard(
                    isEnabled: $viewModel.companionCapsuleEnabled,
                    isGlobalEnabled: viewModel.companionEnabled,
                    position: $viewModel.companionCapsulePosition,
                    isExpanded: $viewModel.companionCapsuleExpanded
                )
                
                // Voice Card
                VoiceSettingsCard(
                    isEnabled: $viewModel.companionVoiceEnabled,
                    isGlobalEnabled: viewModel.companionEnabled,
                    outputMode: $viewModel.companionVoiceOutputMode,
                    saveToInbox: $viewModel.companionVoiceSaveToInbox
                )
                
                // Shortcuts Card
                ShortcutSettingsCard(
                    isEnabled: $viewModel.companionShortcutsEnabled,
                    isGlobalEnabled: viewModel.companionEnabled,
                    shortcuts: viewModel.companionShortcuts,
                    voiceEnabled: viewModel.companionVoiceEnabled,
                    captureEnabled: viewModel.companionCaptureEnabled
                )
                
                // Capture Card
                CaptureSettingsCard(
                    isEnabled: $viewModel.companionCaptureEnabled,
                    isGlobalEnabled: viewModel.companionEnabled,
                    textCaptureEnabled: $viewModel.companionCaptureTextEnabled,
                    linkCaptureEnabled: $viewModel.companionCaptureLinkEnabled,
                    saveDestinationIndex: $viewModel.companionCaptureSaveDestinationIndex
                )
                
                // Permissions Section (optional, kept at bottom)
                companionPermissionsSection
            }
            .padding(.horizontal, AppSurfaceTokens.Spacing.xl)
            .padding(.vertical, AppSurfaceTokens.Spacing.lg)
            .frame(maxWidth: AppSurfaceTokens.Layout.pageMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppSurfaceBackdrop())
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onChange(of: viewModel.companionEnabled) { _, _ in persistCompanionSettings() }
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
        .onChange(of: viewModel.companionCaptureTextEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureLinkEnabled) { _, _ in persistCompanionSettings() }
        .onChange(of: viewModel.companionCaptureSaveDestinationIndex) { _, _ in persistCompanionSettings() }
    }
    
    // MARK: - Companion Permissions Section
    private var companionPermissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                
                Text("权限状态")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
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
        .opacity(viewModel.companionEnabled ? 1.0 : 0.55)
        .padding(AppSurfaceTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
        )
    }

    private func persistCompanionSettings() {
        guard viewModel.isApplyingCompanionSettings == false else { return }
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
                    .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                
                Text(description)
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                
                Text(status.displayName)
                    .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                    .foregroundStyle(status.color)
            }
            .padding(.horizontal, AppSurfaceTokens.Spacing.sm)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
        }
        .padding(AppSurfaceTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
        )
    }
}
