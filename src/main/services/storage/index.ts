import Database from 'better-sqlite3'
import { app } from 'electron'
import path from 'path'
import fs from 'fs'
import log from 'electron-log'
import type { SourceItem, AppSettings, SourceItemStatus, SourceType, SourceOrigin } from '../../../shared/types'

let db: Database.Database | null = null

const SCHEMA_VERSION = 1

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS source_items (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'text',
  source TEXT NOT NULL DEFAULT 'manual',
  status TEXT NOT NULL DEFAULT 'inbox',
  title TEXT,
  content_path TEXT NOT NULL DEFAULT '',
  content_hash TEXT,
  preview_text TEXT,
  ocr_text TEXT,
  transcript TEXT,
  polished_transcript TEXT,
  source_app TEXT,
  original_url TEXT,
  tags TEXT NOT NULL DEFAULT '[]',
  capture_item_id TEXT,
  vault_import_path TEXT,
  asset_file_ids TEXT NOT NULL DEFAULT '[]',
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_source_items_status ON source_items(status);
CREATE INDEX IF NOT EXISTS idx_source_items_created_at ON source_items(created_at);
CREATE INDEX IF NOT EXISTS idx_source_items_type ON source_items(type);

CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL DEFAULT (unixepoch())
);
`

function getDbPath(): string {
  const userDataPath = app.getPath('userData')
  return path.join(userDataPath, 'acmind.db')
}

export async function initStorage(): Promise<void> {
  const dbPath = getDbPath()
  const dbDir = path.dirname(dbPath)
  
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true })
  }

  log.info(`Opening database at: ${dbPath}`)
  db = new Database(dbPath)
  db.pragma('journal_mode = WAL')
  db.pragma('foreign_keys = ON')

  db.exec(SCHEMA_SQL)

  log.info('Database schema initialized')
}

export function closeStorage(): void {
  if (db) {
    db.close()
    db = null
    log.info('Database closed')
  }
}

export function getDb(): Database.Database {
  if (!db) {
    throw new Error('Database not initialized')
  }
  return db
}

function parseSourceItem(row: Record<string, unknown>): SourceItem {
  return {
    id: row.id as string,
    type: row.type as SourceType,
    source: row.source as SourceOrigin,
    status: row.status as SourceItemStatus,
    title: row.title as string | undefined,
    contentPath: row.content_path as string | undefined,
    contentHash: row.content_hash as string | undefined,
    previewText: row.preview_text as string | undefined,
    ocrText: row.ocr_text as string | undefined,
    transcript: row.transcript as string | undefined,
    polishedTranscript: row.polished_transcript as string | undefined,
    sourceApp: row.source_app as string | undefined,
    originalUrl: row.original_url as string | undefined,
    tags: JSON.parse((row.tags as string) || '[]'),
    captureItemId: row.capture_item_id as string | undefined,
    vaultImportPath: row.vault_import_path as string | undefined,
    assetFileIds: JSON.parse((row.asset_file_ids as string) || '[]'),
    metadata: JSON.parse((row.metadata as string) || '{}'),
    createdAt: new Date((row.created_at as number) * 1000),
    updatedAt: row.updated_at ? new Date((row.updated_at as number) * 1000) : undefined
  }
}

export function getSourceItems(filter?: { status?: SourceItemStatus; type?: SourceType; source?: SourceOrigin; limit?: number; offset?: number }): SourceItem[] {
  const database = getDb()
  let sql = 'SELECT * FROM source_items WHERE 1=1'
  const params: unknown[] = []

  if (filter?.status) {
    sql += ' AND status = ?'
    params.push(filter.status)
  }

  if (filter?.type) {
    sql += ' AND type = ?'
    params.push(filter.type)
  }

  if (filter?.source) {
    sql += ' AND source = ?'
    params.push(filter.source)
  }

  sql += ' ORDER BY created_at DESC'

  if (filter?.limit) {
    sql += ' LIMIT ?'
    params.push(filter.limit)
  }

  if (filter?.offset) {
    sql += ' OFFSET ?'
    params.push(filter.offset)
  }

  const rows = database.prepare(sql).all(...params) as Record<string, unknown>[]
  return rows.map(parseSourceItem)
}

export function getSourceItem(id: string): SourceItem | null {
  const database = getDb()
  const row = database.prepare('SELECT * FROM source_items WHERE id = ?').get(id) as Record<string, unknown> | undefined
  return row ? parseSourceItem(row) : null
}

export function createSourceItem(item: Omit<SourceItem, 'id' | 'createdAt'>): SourceItem {
  const database = getDb()
  const id = crypto.randomUUID()
  const now = Math.floor(Date.now() / 1000)

  database.prepare(`
    INSERT INTO source_items (
      id, type, source, status, title, content_path, content_hash,
      preview_text, ocr_text, transcript, polished_transcript,
      source_app, original_url, tags, capture_item_id, vault_import_path,
      asset_file_ids, metadata, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    item.type,
    item.source,
    item.status,
    item.title || null,
    item.contentPath || '',
    item.contentHash || null,
    item.previewText || null,
    item.ocrText || null,
    item.transcript || null,
    item.polishedTranscript || null,
    item.sourceApp || null,
    item.originalUrl || null,
    JSON.stringify(item.tags || []),
    item.captureItemId || null,
    item.vaultImportPath || null,
    JSON.stringify(item.assetFileIds || []),
    JSON.stringify(item.metadata || {}),
    now,
    now
  )

  return getSourceItem(id)!
}

export function updateSourceItem(id: string, updates: Partial<SourceItem>): SourceItem {
  const database = getDb()
  const now = Math.floor(Date.now() / 1000)
  
  const fields: string[] = []
  const values: unknown[] = []

  if (updates.type !== undefined) { fields.push('type = ?'); values.push(updates.type) }
  if (updates.source !== undefined) { fields.push('source = ?'); values.push(updates.source) }
  if (updates.status !== undefined) { fields.push('status = ?'); values.push(updates.status) }
  if (updates.title !== undefined) { fields.push('title = ?'); values.push(updates.title) }
  if (updates.contentPath !== undefined) { fields.push('content_path = ?'); values.push(updates.contentPath) }
  if (updates.previewText !== undefined) { fields.push('preview_text = ?'); values.push(updates.previewText) }
  if (updates.ocrText !== undefined) { fields.push('ocr_text = ?'); values.push(updates.ocrText) }
  if (updates.transcript !== undefined) { fields.push('transcript = ?'); values.push(updates.transcript) }
  if (updates.tags !== undefined) { fields.push('tags = ?'); values.push(JSON.stringify(updates.tags)) }
  if (updates.metadata !== undefined) { fields.push('metadata = ?'); values.push(JSON.stringify(updates.metadata)) }
  
  fields.push('updated_at = ?')
  values.push(now)
  values.push(id)

  database.prepare(`UPDATE source_items SET ${fields.join(', ')} WHERE id = ?`).run(...values)

  return getSourceItem(id)!
}

export function deleteSourceItem(id: string): void {
  const database = getDb()
  database.prepare('DELETE FROM source_items WHERE id = ?').run(id)
}

export function searchSourceItems(query: string): SourceItem[] {
  const database = getDb()
  const searchPattern = `%${query}%`
  
  const rows = database.prepare(`
    SELECT * FROM source_items 
    WHERE title LIKE ? OR preview_text LIKE ? OR ocr_text LIKE ?
    ORDER BY created_at DESC
    LIMIT 50
  `).all(searchPattern, searchPattern, searchPattern) as Record<string, unknown>[]

  return rows.map(parseSourceItem)
}

export function getSourceItemStats(): { total: number; inbox: number; distilled: number; exported: number } {
  const database = getDb()
  const total = (database.prepare('SELECT COUNT(*) as count FROM source_items').get() as { count: number }).count
  const inbox = (database.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'inbox'").get() as { count: number }).count
  const distilled = (database.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'distilled'").get() as { count: number }).count
  const exported = (database.prepare("SELECT COUNT(*) as count FROM source_items WHERE status = 'exported'").get() as { count: number }).count
  return { total, inbox, distilled, exported }
}

export function getSettings(): AppSettings {
  const database = getDb()
  const row = database.prepare("SELECT value FROM app_settings WHERE key = 'app_settings'").get() as { value: string } | undefined
  
  if (row) {
    try {
      return JSON.parse(row.value)
    } catch {
      log.warn('Failed to parse settings, using defaults')
    }
  }
  
  return {
    theme: 'system',
    language: 'zh-CN',
    vaultPath: '',
    autoCaptureClipboard: true,
    defaultExportTarget: 'obsidian',
    autoFrontmatter: true,
    desktopCapsule: {
      isEnabled: true,
      position: 'top',
      autoHide: true,
      showVoice: true,
      showCapture: true,
      showAgent: true
    }
  }
}

export function updateSettings(updates: Partial<AppSettings>): AppSettings {
  const database = getDb()
  const current = getSettings()
  const updated = { ...current, ...updates }
  
  database.prepare(`
    INSERT OR REPLACE INTO app_settings (key, value) VALUES ('app_settings', ?)
  `).run(JSON.stringify(updated))

  return updated
}
