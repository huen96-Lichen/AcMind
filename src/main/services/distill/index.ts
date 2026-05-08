import log from 'electron-log'
import { chat, completion, getDefaultProvider } from '../ai'
import { getSourceItem, updateSourceItem, createSourceItem } from '../storage'
import type { SourceItem, DistilledNote } from '../../../shared/types'

export interface DistillResult {
  success: boolean
  distilledNote?: DistilledNote
  error?: string
}

const DISTILL_SYSTEM_PROMPT = `你是一个知识蒸馏助手。请将用户提供的内容提炼成结构化的笔记。

输出格式要求（JSON）：
{
  "title": "提炼的标题（少于30字）",
  "summary": "100字以内的摘要",
  "tags": ["标签1", "标签2", "标签3"],
  "suggestedFolder": "建议的Obsidian文件夹",
  "bodyMarkdown": "详细的Markdown格式笔记内容，包含:\n- 关键概念\n- 核心要点（用列表）\n- 相关思考\n- 行动建议（如有）",
  "qualityFlags": ["insightful", "actionable", "reference"] // 质量标记
}

请只输出JSON，不要有其他内容。`

export async function distillSourceItem(sourceItemId: string): Promise<DistillResult> {
  try {
    const sourceItem = getSourceItem(sourceItemId)
    if (!sourceItem) {
      return { success: false, error: 'Source item not found' }
    }

    log.info('Starting distillation for:', sourceItem.id)

    await updateSourceItem(sourceItemId, { status: 'distilling' })

    const content = sourceItem.previewText || sourceItem.ocrText || sourceItem.transcript || ''
    
    if (!content.trim()) {
      return { success: false, error: 'No content to distill' }
    }

    const provider = getDefaultProvider()
    if (!provider) {
      return { success: false, error: 'No AI provider configured' }
    }

    const messages = [
      { role: 'system' as const, content: DISTILL_SYSTEM_PROMPT },
      { role: 'user' as const, content: `请蒸馏以下内容：\n\n${content}` }
    ]

    const response = await chat(provider.id, messages)

    let result: Partial<DistilledNote> = {}
    try {
      const jsonMatch = response.content.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0])
      }
    } catch (parseError) {
      log.warn('Failed to parse AI response as JSON:', parseError)
    }

    const distilledNote: DistilledNote = {
      id: crypto.randomUUID(),
      sourceItemIds: [sourceItemId],
      title: result.title || sourceItem.title || '无标题',
      summary: result.summary || '',
      tags: result.tags || [],
      suggestedFolder: result.suggestedFolder,
      bodyMarkdown: result.bodyMarkdown || content,
      qualityFlags: result.qualityFlags || [],
      modelProvider: provider.name,
      modelName: provider.modelId,
      reviewStatus: 'pending',
      createdAt: new Date(),
      updatedAt: new Date()
    }

    const noteItem = await createSourceItem({
      type: 'text',
      source: 'distilled',
      status: 'distilled',
      title: distilledNote.title,
      previewText: distilledNote.summary,
      contentPath: '',
      tags: distilledNote.tags,
      assetFileIds: sourceItem.assetFileIds,
      metadata: {
        distilledNoteId: distilledNote.id,
        bodyMarkdown: distilledNote.bodyMarkdown,
        qualityFlags: distilledNote.qualityFlags,
        modelProvider: distilledNote.modelProvider,
        modelName: distilledNote.modelName
      }
    })

    await updateSourceItem(sourceItemId, { status: 'distilled' })

    log.info('Distillation completed:', noteItem.id)

    return {
      success: true,
      distilledNote: { ...distilledNote, id: noteItem.id }
    }
  } catch (error) {
    log.error('Distillation failed:', error)
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}

export async function distillBatch(sourceItemIds: string[]): Promise<DistillResult[]> {
  const results: DistillResult[] = []
  for (const id of sourceItemIds) {
    const result = await distillSourceItem(id)
    results.push(result)
  }
  return results
}

export async function quickDistill(content: string): Promise<string> {
  const provider = getDefaultProvider()
  if (!provider) {
    throw new Error('No AI provider configured')
  }

  const messages = [
    { role: 'system' as const, content: '你是一个知识提炼助手。请用简洁的语言总结以下内容，突出关键要点。' },
    { role: 'user' as const, content }
  ]

  const response = await chat(provider.id, messages)
  return response.content
}
