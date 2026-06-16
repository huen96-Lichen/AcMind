import SwiftUI

// MARK: - Toast Type

enum NotchToastType {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        }
    }
}

// MARK: - Toast Item

struct NotchToastItem: Identifiable {
    let id = UUID()
    let type: NotchToastType
    let message: String
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: NotchToastItem?
    @Published var isShowing = false

    private var dismissTask: Task<Void, Never>?

    func show(_ type: NotchToastType, _ message: String) {
        dismissTask?.cancel()

        let item = NotchToastItem(type: type, message: message)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = item
            isShowing = true
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isShowing = false
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            isShowing = false
        }
    }
}

// MARK: - Toast View

struct NotchToastView: View {
    @ObservedObject private var manager = ToastManager.shared

    var body: some View {
        if let toast = manager.currentToast, manager.isShowing {
            HStack(spacing: 10) {
                Image(systemName: toast.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(toast.type.color)

                Text(toast.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary)

                Spacer()

                Button(action: { manager.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 260)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(toast.type.color.opacity(0.25), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
