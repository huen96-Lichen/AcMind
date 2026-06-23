import AppKit
import SwiftUI
import AcMindKit
import ImageIO

struct InboxItemCard: View {
    let item: SourceItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onMore: () -> Void

    @State private var isHovered = false

    private var previewText: String {
        if let text = item.previewText, !text.isEmpty {
            return text
        } else if let transcript = item.transcript, !transcript.isEmpty {
            return transcript
        } else if let ocr = item.ocrText, !ocr.isEmpty {
            return ocr
        }
        return ""
    }

    private var duration: TimeInterval {
        if let durationStr = item.metadata["duration"], let duration = TimeInterval(durationStr) {
            return duration
        }
        return 60
    }

    private var metadata: MaterialCardMetadata {
        MaterialCardMetadataFactory.source(
            title: item.title,
            kind: item.type.displayName,
            source: item.sourceApp,
            timestamp: item.createdAt
        )
    }
    private var previewHeight: CGFloat {
        ContentCardPresentation.previewHeight(for: item.type, text: previewText)
    }
    private var cardHeight: CGFloat {
        ContentCardPresentation.cardHeight(for: item.type, text: previewText)
    }

    var body: some View {
        MaterialCardShell(
            isSelected: isSelected,
            isHovered: isHovered,
            cardHeight: cardHeight,
            onSelect: onSelect,
            header: { headerBar },
            preview: { previewBody },
            footer: { cardMetadata },
            actions: { actionBar }
        )
        .onHover { isHovered = $0 }
        .contextMenu { contextMenuItems }
    }

    private var cardMetadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metadata.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.92)

            HStack(spacing: 6) {
                metadataLine
            }
        }
        .frame(maxWidth: .infinity, minHeight: ContentCardPresentation.materialMetadataMinHeight, alignment: .topLeading)
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.type.color)

            Text(item.type.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer(minLength: 0)
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Text(metadata.subtitle)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text("·")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            Text(formatTimeShort(item.createdAt))
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button(action: onMore) {
            Image(systemName: "ellipsis")
                .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .opacity(isHovered ? 1 : 0)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(AppSurfaceTokens.cardBackground.opacity(isHovered ? 0.82 : 0.68)))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        switch item.type {
        case .audio:
            audioPreview
        case .screenshot, .image:
            imagePreview
        case .text:
            textPreview
        case .webpage:
            linkPreview
        case .pdf, .docx, .unknownFile:
            filePreview
        case .video:
            videoPreview
        }
    }

    private var audioPreview: some View {
        HStack(spacing: 8) {
            InboxWaveformPreview(duration: duration, color: item.type.color)

            Text(duration.formattedDuration)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fontWeight(.medium)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: previewHeight, maxHeight: previewHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.56))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var imagePreview: some View {
        ZStack(alignment: .topLeading) {
            if let path = item.contentPath {
                ImagePreview(url: URL(fileURLWithPath: path), type: item.type)
            } else {
                placeholderPreview
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .stroke(AppSurfaceTokens.secondaryText.opacity(0.16), lineWidth: 1)
        )
        .clipped()
    }

    private var textPreview: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .fill(item.type.color.opacity(0.10))

            VStack(alignment: .leading, spacing: 8) {
                Text(previewText.prefix(120).description)
                    .font(.subheadline)
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.92)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .frame(height: previewHeight)
        .overlay(
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.18), lineWidth: 1)
        )
        .clipped()
    }

    private var linkPreview: some View {
        RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
            .fill(AppSurfaceTokens.cardBackground.opacity(0.62))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    if let url = item.originalUrl {
                        Text(extractDomain(url))
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)

                    Text(url)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                        .lineLimit(2)
                        .minimumScaleFactor(0.92)
                    }
                }
                .padding(12)
            }
            .frame(height: previewHeight)
            .overlay(
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.18), lineWidth: 1)
            )
            .clipped()
    }

    private var filePreview: some View {
        RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
            .fill(AppSurfaceTokens.cardBackground.opacity(0.62))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewText.prefix(96).description)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.92)
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    Spacer(minLength: 0)
                }
                .padding(12)
            }
            .frame(height: previewHeight)
            .overlay(
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.18), lineWidth: 1)
            )
            .clipped()
    }

    private var videoPreview: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                    Text(previewText.prefix(40).description)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.92)
            }

            Spacer()

            Text(duration.formattedDuration)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: previewHeight, maxHeight: previewHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.56))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.18), lineWidth: 1)
        )
        .clipped()
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("AI 整理") {
            copySummary()
            AppState.shared.navigate(to: .agent)
        }

        Button("复制内容") {
            copySummary()
        }

        Divider()

        Button("移动到工作台") {
            AppState.shared.navigate(to: .workbench)
        }

        Button("删除") {
            NotificationCenter.default.post(name: .acmindDeleteSourceItem, object: item.id)
        }
    }

    private func copySummary() {
        let text = item.previewText ?? item.transcript ?? item.ocrText ?? item.title ?? ""
        guard text.isEmpty == false else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var placeholderPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                .fill(item.type.color.opacity(0.12))

            Image(systemName: item.type.iconName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(item.type.color)
        }
    }

    private func formatTimeShort(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }

    private func extractDomain(_ urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

private struct ImagePreview: View {
    let url: URL
    let type: SourceType
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                        .fill(type.color.opacity(0.12))

                    Image(systemName: type.iconName)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(type.color)
                }
            }
        }
        .task(id: url.path) {
            let loaded = await Self.loadThumbnail(from: url)
            await MainActor.run {
                image = loaded
            }
        }
    }

    private static func loadThumbnail(from url: URL) async -> NSImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return NSImage(contentsOf: url)
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(ContentCardPresentation.thumbnailHeight * 2.4, 480))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return NSImage(contentsOf: url)
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
