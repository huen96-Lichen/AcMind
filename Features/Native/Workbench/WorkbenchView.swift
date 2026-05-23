import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @State private var documents: [WorkbenchDocument] = []
    @State private var searchText = ""
    @State private var activeTool: WorkbenchToolDestination?
    @State private var showImporter = false
    @State private var showComposer = false
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        ACSecondaryPageShell(
            header: {
                ACPageHeader(
                    title: "工作台",
                    subtitle: "导入 Markdown / txt，自动生成摘要、标签、双链关联和本地索引；常用工具已并入此页。"
                ) {
                    HStack(spacing: 12) {
                        ACSearchField("搜索文档", text: $searchText, width: 220, height: ACLayout.controlHeight)
                        ACButton("导入文件", kind: .primary, minWidth: 84) { showImporter = true }
                        ACButton("新建笔记", kind: .secondary, minWidth: 84) {
                            draftTitle = ""
                            draftContent = ""
                            showComposer = true
                        }
                    }
                }
            },
            content: { _ in
                toolLibraryCard
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
        .task {
            loadDocuments()
        }
        .sheet(isPresented: $showComposer) {
            WorkbenchComposerSheet(
                title: $draftTitle,
                content: $draftContent,
                onCancel: { showComposer = false },
                onSave: { title, content in
                    let newDocument = WorkbenchDocument(
                        title: title,
                        path: nil,
                        content: content,
                        summary: WorkbenchDocument.makeSummary(content),
                        tags: WorkbenchDocument.makeTags(content),
                        backlinks: WorkbenchDocument.makeBacklinks(content),
                        section: WorkbenchDocument.classifyDocument(title: title, content: content),
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    documents.insert(newDocument, at: 0)
                    WorkbenchDocumentUtilities.persistDocuments(documents, storageKey: Self.storageKey)
                    showComposer = false
                }
            )
        }
        .sheet(item: $activeTool) { tool in
            tool.makeView(toastManager: toastManager)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText, .text, .item],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private var toolLibraryCard: some View {
        ACCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("工具")
                        .font(ACTypography.sectionTitle)
                        .foregroundStyle(ACColors.primaryText)

                    Spacer(minLength: 0)

                    ACButton("打开 JSON 工具", kind: .primary, minWidth: 104) {
                        activeTool = .json
                    }
                }

                Text("后续我们加入的新功能都会按这种卡片格式继续罗列在这里。")
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(workbenchToolCards) { card in
                        Button {
                            activeTool = card.destination
                        } label: {
                            WorkbenchToolCardView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                toastManager.show(.warning, "没有选择文件")
                return
            }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let document = WorkbenchDocument(
                    title: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    content: content,
                    summary: WorkbenchDocument.makeSummary(content),
                    tags: WorkbenchDocument.makeTags(content),
                    backlinks: WorkbenchDocument.makeBacklinks(content),
                    section: WorkbenchDocument.classifyDocument(title: url.lastPathComponent, content: content),
                    createdAt: Date(),
                    updatedAt: Date()
                )
                documents.insert(document, at: 0)
                WorkbenchDocumentUtilities.persistDocuments(documents, storageKey: Self.storageKey)
                toastManager.show(.success, "已导入 \(url.lastPathComponent)")
            } catch {
                toastManager.show(.error, "文件读取失败: \(error.localizedDescription)")
            }
        case .failure(let error):
            toastManager.show(.error, "文件导入失败: \(error.localizedDescription)")
        }
    }

    private func loadDocuments() {
        documents = WorkbenchDocumentUtilities.loadDocuments(
            storageKey: Self.storageKey,
            fallbackDocuments: Self.seedDocuments
        )
        if documents == Self.seedDocuments {
            WorkbenchDocumentUtilities.persistDocuments(documents, storageKey: Self.storageKey)
        }
    }

    private static let storageKey = "acmind.workbench.documents"

    private static let seedDocuments: [WorkbenchDocument] = [
        .init(
            title: "AcMind 本地工作台说明",
            path: nil,
            content: "这是一个初始说明文档，用于演示本地工作台的真实导入、预览和标签提取能力。#AcMind [[收集箱]]",
            summary: "工作台支持导入 Markdown / txt 文档，自动生成摘要、标签和双链关联。",
            tags: ["AcMind"],
            backlinks: ["收集箱"],
            section: .knowledgeBase,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}

private struct WorkbenchToolCard: View {
    let card: WorkbenchToolCardModel

    var body: some View {
        ACCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ACTypeIcon(card.symbol, tint: card.tint, background: card.tint.opacity(0.12), size: 30)
                    Spacer(minLength: 0)
                    ACBadge(card.state, kind: card.badgeKind)
                }

                Text(card.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text(card.subtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 112)
    }
}
