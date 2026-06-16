import SwiftUI
import AcMindKit

struct PasteQueuePanel: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @State private var queueItems: [PasteQueue.QueueItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("粘贴队列")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Spacer()

                if !queueItems.isEmpty {
                    Text("\(queueItems.count) 条")
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    Button {
                        Task { await viewModel.clearPasteQueue() }
                        queueItems.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }

            if queueItems.isEmpty {
                Text("右键菜单可添加到队列")
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(queueItems.enumerated()), id: \.element.id) { index, queueItem in
                        HStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .frame(width: 16)

                            if let item = viewModel.items.first(where: { $0.id == queueItem.clipboardItemId }) {
                                Image(systemName: item.type.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(item.type.color)

                                Text(item.textContent?.prefix(30) ?? "...")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                viewModel.removeQueueItem(id: queueItem.id)
                                queueItems.removeAll { $0.id == queueItem.id }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackground.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                        )
                    }
                }

                HStack(spacing: 6) {
                    Button {
                        Task {
                            _ = await viewModel.pasteNextInQueue()
                            queueItems = viewModel.getQueueItems()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                            Text("粘贴下一条")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(AppSurfaceTokens.accentBlue)
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
        )
        .onAppear {
            queueItems = viewModel.getQueueItems()
        }
    }
}
