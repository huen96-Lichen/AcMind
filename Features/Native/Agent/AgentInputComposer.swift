import SwiftUI
import AcMindKit

struct AgentInputComposer: View {
    @Binding var inputText: String
    @Binding var selectedActionMode: AgentActionMode
    @Binding var selectedProviderID: String

    let providers: [ProviderConfig]
    let onProviderSelect: (String) -> Void
    let onSend: () -> Void
    let onVoiceInput: () -> Void
    let onAttachFile: () -> Void
    let onTools: () -> Void
    let onNewConversation: () -> Void

    init(
        inputText: Binding<String> = .constant(""),
        selectedActionMode: Binding<AgentActionMode> = .constant(.auto),
        selectedProviderID: Binding<String> = .constant(""),
        providers: [ProviderConfig] = [],
        onProviderSelect: @escaping (String) -> Void = { _ in },
        onSend: @escaping () -> Void = {},
        onVoiceInput: @escaping () -> Void = {},
        onAttachFile: @escaping () -> Void = {},
        onTools: @escaping () -> Void = {},
        onNewConversation: @escaping () -> Void = {}
    ) {
        self._inputText = inputText
        self._selectedActionMode = selectedActionMode
        self._selectedProviderID = selectedProviderID
        self.providers = providers
        self.onProviderSelect = onProviderSelect
        self.onSend = onSend
        self.onVoiceInput = onVoiceInput
        self.onAttachFile = onAttachFile
        self.onTools = onTools
        self.onNewConversation = onNewConversation
    }

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activeProvider: ProviderConfig? {
        providers.first(where: { $0.id == selectedProviderID }) ?? providers.first
    }

    private var providerLabel: String {
        if let provider = activeProvider {
            return "\(provider.name) · \(provider.modelId)"
        }
        return "本地回退"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AcMindSurfaceTokens.sectionGap) {
            quickIntentTabs
            providerSelectorRow
            textInputArea
            composerActionsRow
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AcMindSurfaceTokens.composerCornerRadius, style: .continuous)
                .fill(AcMindSurfaceTokens.secondarySurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AcMindSurfaceTokens.composerCornerRadius, style: .continuous)
                .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
        )
    }

    private var quickIntentTabs: some View {
        HStack(spacing: AcMindSurfaceTokens.controlGap) {
            ForEach(AgentActionMode.quickActions) { mode in
                quickActionButton(for: mode)
            }

            Spacer(minLength: 0)

            Button {
                onNewConversation()
            } label: {
                Label("新建对话", systemImage: "square.and.pencil")
                    .font(ACTypography.miniMedium)
                    .foregroundStyle(ACColors.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var providerSelectorRow: some View {
        HStack(spacing: 8) {
            Text("模型")
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.secondaryText)

            providerMenu

            Spacer(minLength: 0)
        }
        .frame(height: 44)
    }

    private var textInputArea: some View {
        ZStack(alignment: .topLeading) {
            if trimmedInput.isEmpty {
                Text("直接和 Agent 说话，或者让它帮你转任务、搜资料、排日程、记笔记。")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.tertiaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }

            TextEditor(text: $inputText)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 84)
                .padding(4)
                .background(Color.clear)
        }
        .frame(minHeight: 84)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AcMindSurfaceTokens.primarySurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
        )
    }

    private var composerActionsRow: some View {
        HStack(spacing: AcMindSurfaceTokens.controlGap) {
            toolbarButton(title: "语音", icon: "mic.fill", action: onVoiceInput)
            toolbarButton(title: "附件", icon: "paperclip", action: onAttachFile)
            toolbarButton(title: "工具", icon: "wand.and.stars", action: onTools)

            Spacer(minLength: 0)

            Button {
                onNewConversation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                    Text("新建")
                        .font(ACTypography.mini)
                }
                .foregroundStyle(ACColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(AcMindSurfaceTokens.primarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                onSend()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(ACColors.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(SendButtonHoverStyle())
            .disabled(trimmedInput.isEmpty)
        }
    }

    private var providerMenu: some View {
        Menu {
            ForEach(providers) { provider in
                Button {
                    onProviderSelect(provider.id)
                } label: {
                    Text(provider.name)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 0) {
                    Text("模型")
                        .font(.system(size: 10, weight: .medium))
                    Text(providerLabel)
                        .font(ACTypography.mini)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundStyle(ACColors.primaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(AcMindSurfaceTokens.primarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickActionButton(for mode: AgentActionMode) -> some View {
        Button {
            selectedActionMode = mode
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = mode.suggestedPrompt
            }
        } label: {
            Text(mode.displayName)
                .font(ACTypography.mini)
                .foregroundStyle(selectedActionMode == mode ? ACColors.primaryText : ACColors.secondaryText)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selectedActionMode == mode ? ACColors.selectedFill.opacity(0.85) : ACColors.softFill.opacity(0.6))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(selectedActionMode == mode ? ACColors.accentBlue.opacity(0.75) : ACColors.border.opacity(0.6), lineWidth: 1)
        )
    }

    private func toolbarButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(ACTypography.mini)
            }
            .foregroundStyle(ACColors.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(AcMindSurfaceTokens.primarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(HoverButtonStyle())
    }
}

struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(hex: "#F8F8F8") : ACColors.softFill)
    }
}

struct SendButtonHoverStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
