import { app, dialog } from 'electron'
import path from 'path'
import fs from 'fs'
import log from 'electron-log'
import { getSettings, getSourceItem, updateSourceItem } from '../storage'
import type { SourceItem } from '../../../shared/types'

export interface ExportOptions {
  vaultPath: string
  folder?: string
  autoFrontmatter?: boolean
  conflictStrategy?: 'rename' | 'skip' | 'overwrite'
}

export interface ExportResult {
  success: boolean
  filePath?: string
  error?: string
}

function generateFrontmatter(item: SourceItem): string {
  const metadata = item.metadata || {}
  const tags = item.tags || []
  const created = new Date(item.createdAt).toISOString().split('T')[0]
  const updated = item.updatedAt ? new Date(item.updatedAt).toISOString().split('T')[0] : created

  let frontmatter = '---\n'
  frontmatter += `title: "${item.title || '无标题'}"\n`
  frontmatter += `created: ${created}\n`
  frontmatter += `updated: ${updated}\n`
  
  if (tags.length > 0) {
    frontmatter += `tags: [${tags.map(t => `"${t}"`).join(', ')}]\n`
  }
  
  if (item.source) {
    frontmatter += `source: ${item.source}\n`
  }
  
  if (item.originalUrl) {
    frontmatter += `url: "${item.originalUrl}"\n`
  }

  if (metadata.distilledNoteId) {
    frontmatter += `type: distilled\n`
    frontmatter += `qualityFlags: [${(metadata.qualityFlags || []).map(f => `"${f}"`).join(', ')}]\n`
  }

  for (const [key, value] of Object.entries(metadata)) {
    if (!['distilledNoteId', 'bodyMarkdown', 'qualityFlags'].includes(key)) {
      frontmatter += `${key}: ${JSON.stringify(value)}\n`
    }
  }

  frontmatter += '---\n\n'
  return frontmatter
}

function sanitizeFilename(name: string): string {
  return name
    .replace(/[<>:"/\\|?*]/g, '_')
    .replace(/\s+/g, '_')
    .slice(0, 100)
}

function getUniqueFilePath(basePath: string, fileName: string): string {
  let filePath = path.join(basePath, `${sanitizeFilename(fileName)}.md`)
  
  if (!fs.existsSync(filePath)) {
    return filePath
  }

  let counter = 1
  while (fs.existsSync(filePath)) {
    filePath = path.join(basePath, `${sanitizeFilename(fileName)}_${counter}.md`)
    counter++
  }
  
  return filePath
}

export async function exportToObsidian(item: SourceItem, options?: Partial<ExportOptions>): Promise<ExportResult> {
  try {
    const settings = getSettings()
    const vaultPath = options?.vaultPath || settings.vaultPath

    if (!vaultPath) {
      return { success: false, error: 'Vault path not configured' }
    }

    if (!fs.existsSync(vaultPath)) {
      return { success: false, error: 'Vault path does not exist' }
    }

    const folder = options?.folder || 'Inbox'
    const fullPath = path.join(vaultPath, folder)
    
    if (!fs.existsSync(fullPath)) {
      fs.mkdirSync(fullPath, { recursive: true })
    }

    const fileName = item.title || `note_${Date.now()}`
    let filePath = getUniqueFilePath(fullPath, fileName)

    const metadata = item.metadata || {}
    let bodyContent = ''

    if (metadata.bodyMarkdown) {
      bodyContent = metadata.bodyMarkdown as string
    } else if (item.previewText) {
      bodyContent = item.previewText
    } else if (item.ocrText) {
      bodyContent = item.ocrText
    } else {
      bodyContent = '（无内容）'
    }

    let fileContent = ''
    if (options?.autoFrontmatter !== false && settings.autoFrontmatter) {
      fileContent = generateFrontmatter(item) + bodyContent
    } else {
      fileContent = bodyContent
    }

    fs.writeFileSync(filePath, fileContent, 'utf-8')

    await updateSourceItem(item.id, { 
      status: 'exported',
      vaultImportPath: filePath
    })

    log.info('Exported to Obsidian:', filePath)

    return { success: true, filePath }
  } catch (error) {
    log.error('Export failed:', error)
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}

export async function exportBatch(items: SourceItem[], options?: Partial<ExportOptions>): Promise<ExportResult[]> {
  const results: ExportResult[] = []
  for (const item of items) {
    const result = await exportToObsidian(item, options)
    results.push(result)
  }
  return results
}

export async function selectVaultPath(): Promise<string | null> {
  const result = await dialog.showOpenDialog({
    properties: ['openDirectory'],
    title: '选择 Obsidian 仓库'
  })

  if (result.canceled || result.filePaths.length === 0) {
    return null
  }

  return result.filePaths[0]
}

export function getVaultStats(vaultPath: string): { total: number; folders: string[] } {
  try {
    if (!fs.existsSync(vaultPath)) {
      return { total: 0, folders: [] }
    }

    const folders: string[] = []
    let total = 0

    const entries = fs.readdirSync(vaultPath, { withFileTypes: true })
    for (const entry of entries) {
      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        folders.push(entry.name)
        
        const subEntries = fs.readdirSync(path.join(vaultPath, entry.name), { withFileTypes: true })
        total += subEntries.filter(e => e.isFile() && e.name.endsWith('.md')).length
      }
    }

    return { total, folders }
  } catch (error) {
    log.error('Failed to get vault stats:', error)
    return { total: 0, folders: [] }
  }
}
