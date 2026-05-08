import { app } from 'electron'
import path from 'path'
import fs from 'fs'
import crypto from 'crypto'
import log from 'electron-log'
import type { AssetFile, AssetFileKind } from '../../../shared/types'

let assetsDb: import('better-sqlite3').Database | null = null

function getAssetsDb(): import('better-sqlite3').Database {
  if (!assetsDb) {
    throw new Error('Assets database not initialized')
  }
  return assetsDb
}

export async function initAssetStore(): Promise<void> {
  const userDataPath = app.getPath('userData')
  const assetsDir = path.join(userDataPath, 'assets')
  const dbPath = path.join(userDataPath, 'assets.db')

  if (!fs.existsSync(assetsDir)) {
    fs.mkdirSync(assetsDir, { recursive: true })
  }

  assetsDb = new (require('better-sqlite3'))(dbPath)
  
  assetsDb.exec(`
    CREATE TABLE IF NOT EXISTS asset_files (
      id TEXT PRIMARY KEY,
      source_item_id TEXT,
      kind TEXT NOT NULL,
      original_name TEXT,
      local_path TEXT NOT NULL,
      mime_type TEXT,
      size_bytes INTEGER,
      sha256 TEXT,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      metadata TEXT NOT NULL DEFAULT '{}'
    );
    
    CREATE INDEX IF NOT EXISTS idx_asset_files_source_item_id ON asset_files(source_item_id);
  `)

  log.info('AssetStore initialized at:', assetsDir)
}

export function closeAssetStore(): void {
  if (assetsDb) {
    assetsDb.close()
    assetsDb = null
    log.info('AssetStore closed')
  }
}

function inferKind(filePath: string, mimeType?: string): AssetFileKind {
  const ext = path.extname(filePath).toLowerCase()
  const mimeMap: Record<string, AssetFileKind> = {
    '.png': 'image', '.jpg': 'image', '.jpeg': 'image', '.gif': 'image', '.webp': 'image', '.bmp': 'image',
    '.mp3': 'audio', '.wav': 'audio', '.m4a': 'audio', '.aac': 'audio',
    '.mp4': 'video', '.mov': 'video', '.avi': 'video', '.mkv': 'video',
    '.pdf': 'pdf',
    '.docx': 'docx', '.doc': 'docx',
    '.html': 'html', '.htm': 'html',
    '.md': 'markdown', '.markdown': 'markdown'
  }
  return mimeMap[ext] || 'other'
}

function calculateSha256(filePath: string): string {
  const buffer = fs.readFileSync(filePath)
  return crypto.createHash('sha256').update(buffer).digest('hex')
}

export function saveAssetFile(
  sourceItemId: string | undefined,
  originalName: string,
  sourcePath: string,
  mimeType?: string
): AssetFile {
  const db = getAssetsDb()
  const id = crypto.randomUUID()
  const userDataPath = app.getPath('userData')
  const assetsDir = path.join(userDataPath, 'assets')
  const ext = path.extname(originalName)
  const destFileName = `${id}${ext}`
  const destPath = path.join(assetsDir, destFileName)

  fs.copyFileSync(sourcePath, destPath)

  const stat = fs.statSync(destPath)
  const kind = inferKind(destPath, mimeType)
  const sha256 = calculateSha256(destPath)

  db.prepare(`
    INSERT INTO asset_files (id, source_item_id, kind, original_name, local_path, mime_type, size_bytes, sha256)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(id, sourceItemId || null, kind, originalName, destPath, mimeType || null, stat.size, sha256)

  return {
    id,
    sourceItemId,
    kind,
    originalName,
    localPath: destPath,
    mimeType,
    sizeBytes: stat.size,
    sha256,
    createdAt: new Date()
  }
}

export function getAssetFile(id: string): AssetFile | null {
  const db = getAssetsDb()
  const row = db.prepare('SELECT * FROM asset_files WHERE id = ?').get(id) as Record<string, unknown> | undefined
  if (!row) return null

  return {
    id: row.id as string,
    sourceItemId: row.source_item_id as string | undefined,
    kind: row.kind as AssetFileKind,
    originalName: row.original_name as string | undefined,
    localPath: row.local_path as string,
    mimeType: row.mime_type as string | undefined,
    sizeBytes: row.size_bytes as number | undefined,
    sha256: row.sha256 as string | undefined,
    createdAt: new Date((row.created_at as number) * 1000),
    metadata: JSON.parse((row.metadata as string) || '{}')
  }
}

export function getAssetFilesBySourceItem(sourceItemId: string): AssetFile[] {
  const db = getAssetsDb()
  const rows = db.prepare('SELECT * FROM asset_files WHERE source_item_id = ?').all(sourceItemId) as Record<string, unknown>[]
  return rows.map(row => ({
    id: row.id as string,
    sourceItemId: row.source_item_id as string | undefined,
    kind: row.kind as AssetFileKind,
    originalName: row.original_name as string | undefined,
    localPath: row.local_path as string,
    mimeType: row.mime_type as string | undefined,
    sizeBytes: row.size_bytes as number | undefined,
    sha256: row.sha256 as string | undefined,
    createdAt: new Date((row.created_at as number) * 1000),
    metadata: JSON.parse((row.metadata as string) || '{}')
  }))
}

export function deleteAssetFile(id: string): void {
  const db = getAssetsDb()
  const asset = getAssetFile(id)
  if (asset && fs.existsSync(asset.localPath)) {
    fs.unlinkSync(asset.localPath)
  }
  db.prepare('DELETE FROM asset_files WHERE id = ?').run(id)
}

export function readAssetAsBase64(filePath: string): string | null {
  try {
    const buffer = fs.readFileSync(filePath)
    const ext = path.extname(filePath).toLowerCase()
    const mimeTypes: Record<string, string> = {
      '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
      '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp'
    }
    const mimeType = mimeTypes[ext] || 'application/octet-stream'
    return `data:${mimeType};base64,${buffer.toString('base64')}`
  } catch (error) {
    log.error('Failed to read asset:', error)
    return null
  }
}
