import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorderView: View {
    @Binding var shortcut: String
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack(spacing: 8) {
                if isRecording {
                    Text("按下快捷键...")
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                } else if shortcut.isEmpty {
                    Text("点击录制")
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                } else {
                    Text(shortcut)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(isRecording ? AppSurfaceTokens.accentBlue.opacity(0.12) : AppSurfaceTokens.cardBackground.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(isRecording ? AppSurfaceTokens.accentBlue.opacity(0.5) : AppSurfaceTokens.separator.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleEvent(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            shortcut = ""
            stopRecording()
            return
        }

        guard event.type == .keyDown else { return }

        var components: [String] = []

        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        if modifiers.contains(.command) {
            components.append("⌘")
        }

        if let key = keyString(for: event.keyCode) {
            components.append(key)
        }

        if !components.isEmpty {
            shortcut = components.joined()
            stopRecording()
        }
    }

    private func keyString(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default: return nil
        }
    }
}
