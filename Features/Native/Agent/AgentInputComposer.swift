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
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                wideQuickActionRow
                compactQuickActionRow
            }

            providerStrip

            ZStack(alignment: .topLeading) {
                if trimmedInput.isEmpty {
                    Text("直接和 Agent 说话，或者让它帮你转任务、搜资料、排日程、记笔记。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                }

                TextEditor(text: $inputText)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 78)
                    .padding(3)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(ACColors.softFill.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(ACColors.border.opacity(0.75), lineWidth: 1)
            )

            ViewThatFits(in: .horizontal) {
                wideToolbarRow
                compactToolbarRow
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ACColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }

    private var wideQuickActionRow: some View {
        HStack(spacing: 6) {
            ForEach(AgentActionMode.quickActions) { mode in
                quickActionButton(for: mode)
            }

            Spacer(minLength: 0)

            Button {
                onNewConversation()
            } label: {
                Label("新建对话", systemImage: "square.and.pencil")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var compactQuickActionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AgentActionMode.quickActions) { mode in
                        quickActionButton(for: mode)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                onNewConversation()
            } label: {
                Label("新建对话", systemImage: "square.and.pencil")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }
            .buttonStyle(.plain)
        }
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
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(selectedActionMode == mode ? ACColors.selectedFill.opacity(0.8) : ACColors.softFill.opacity(0.55))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(selectedActionMode == mode ? ACColors.accentBlue.opacity(0.75) : ACColors.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var providerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(providers.prefix(6)) { provider in
                    Button {
                        onProviderSelect(provider.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: selectedProviderID == provider.id ? "checkmark.circle.fill" : "cpu")
                                .font(.system(size: 11, weight: .semibold))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(provider.name.isEmpty ? provider.modelId : provider.name)
                                    .font(ACTypography.mini)
                                    .lineLimit(1)
                                Text(provider.providerType.displayName)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(ACColors.tertiaryText)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(selectedProviderID == provider.id ? ACColors.primaryText : ACColors.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(selectedProviderID == provider.id ? ACColors.selectedFill.opacity(0.8) : ACColors.softFill.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedProviderID == provider.id ? ACColors.accentPurple.opacity(0.55) : ACColors.border.opacity(0.7), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if providers.count > 6 {
                    Menu {
                        ForEach(providers.dropFirst(6)) { provider in
                            Button {
                                onProviderSelect(provider.id)
                            } label: {
                                Text(provider.name.isEmpty ? provider.modelId : provider.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 10, weight: .semibold))
                            Text("更多")
                                .font(ACTypography.mini)
                        }
                        .foregroundStyle(ACColors.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(ACColors.softFill.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(ACColors.border.opacity(0.7), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wideToolbarRow: some View {
        HStack(spacing: 7) {
            toolbarButton(title: "语音", icon: "mic.fill", action: onVoiceInput)
            toolbarButton(title: "附件", icon: "paperclip", action: onAttachFile)
            toolbarButton(title: "工具", icon: "wand.and.stars", action: onTools)

            Spacer(minLength: 0)

            providerMenu

            Button {
                onSend()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 36)
                    .background(ACColors.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(SendButtonHoverStyle())
            .disabled(trimmedInput.isEmpty)
        }
    }

    private var compactToolbarRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                toolbarButton(title: "语音", icon: "mic.fill", action: onVoiceInput)
                toolbarButton(title: "附件", icon: "paperclip", action: onAttachFile)
                toolbarButton(title: "工具", icon: "wand.and.stars", action: onTools)
            }

            HStack(spacing: 8) {
                providerMenu

                Spacer(minLength: 0)

                Button {
                    onSend()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 36)
                        .background(ACColors.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(SendButtonHoverStyle())
                .disabled(trimmedInput.isEmpty)
            }
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
            .background(ACColors.softFill)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            .padding(.vertical, 7)
            .background(ACColors.softFill)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
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
