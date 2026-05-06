import { join } from 'path'
import { readFile, writeFile, rename, mkdir } from 'fs/promises'
import { existsSync } from 'fs'
import { randomUUID } from 'crypto'
import type { DictationHistoryEntry, VoicePolishMode } from '../../shared/types'

// ─── Constants ────────────────────────────────────────────────

const MAX_ENTRIES = 200
const FILENAME = 'dictation-history.json'

// ─── DictationHistoryStore ────────────────────────────────────

/**
 * Persistent dictation history store backed by a JSON file.
 *
 * Inspired by OpenLess persistence.rs.
 * - Max 200 entries (FIFO eviction)
 * - Atomic writes (write .tmp then rename)
 * - Lazy initialization
 */
export class DictationHistoryStore {
  private storageDir: string
  private entries: DictationHistoryEntry[] = []
  private initialized = false
  private writePending = false
  private dirty = false

  constructor(storageDir: string) {
    this.storageDir = storageDir
  }

  private get filePath(): string {
    return join(this.storageDir, FILENAME)
  }

  private get tmpFilePath(): string {
    return join(this.storageDir, `${FILENAME}.tmp`)
  }

  /** Ensure the store is loaded from disk */
  private async ensureInit(): Promise<void> {
    if (this.initialized) return

    if (!existsSync(this.filePath)) {
      this.entries = []
      this.initialized = true
      return
    }

    try {
      const raw = await readFile(this.filePath, 'utf-8')
      const parsed = JSON.parse(raw)
      this.entries = Array.isArray(parsed) ? parsed : []
    } catch {
      // Corrupted file — start fresh
      this.entries = []
    }

    this.initialized = true
  }

  /** Persist entries to disk (atomic write) */
  private async persist(): Promise<void> {
    if (this.writePending) {
      this.dirty = true
      return
    }

    this.writePending = true

    try {
      // Ensure directory exists
      await mkdir(this.storageDir, { recursive: true })

      // Write to temp file then rename for atomicity
      const tmpPath = this.tmpFilePath
      await writeFile(tmpPath, JSON.stringify(this.entries, null, 2), 'utf-8')
      await rename(tmpPath, this.filePath)
    } catch (err) {
      console.error('[DictationHistoryStore] Failed to persist:', err)
    } finally {
      this.writePending = false

      // If another write was requested while we were writing, do it again
      if (this.dirty) {
        this.dirty = false
        await this.persist()
      }
    }
  }

  /**
   * List history entries, newest first.
   * @param limit  Max entries to return (default: 50)
   * @param offset Skip this many entries from the start
   */
  async list(limit = 50, offset = 0): Promise<DictationHistoryEntry[]> {
    await this.ensureInit()
    return this.entries
      .slice(offset, offset + limit)
  }

  /**
   * Append a new dictation entry.
   * Automatically assigns id and timestamp.
   * Enforces MAX_ENTRIES limit (FIFO eviction).
   */
  async append(
    entry: Omit<DictationHistoryEntry, 'id' | 'timestamp'>,
  ): Promise<DictationHistoryEntry> {
    await this.ensureInit()

    const newEntry: DictationHistoryEntry = {
      ...entry,
      id: randomUUID(),
      timestamp: Date.now(),
    }

    this.entries.unshift(newEntry)

    // Enforce FIFO limit
    if (this.entries.length > MAX_ENTRIES) {
      this.entries.length = MAX_ENTRIES
    }

    // Persist asynchronously (fire-and-forget from caller's perspective)
    this.persist().catch(() => {})

    return newEntry
  }

  /**
   * Delete a history entry by id.
   * @returns true if the entry was found and deleted
   */
  async delete(id: string): Promise<boolean> {
    await this.ensureInit()

    const index = this.entries.findIndex((e) => e.id === id)
    if (index === -1) return false

    this.entries.splice(index, 1)
    this.persist().catch(() => {})

    return true
  }

  /** Clear all history entries */
  async clear(): Promise<void> {
    await this.ensureInit()
    this.entries = []
    this.persist().catch(() => {})
  }
}

// ─── Lazy Singleton ───────────────────────────────────────────

let _instance: DictationHistoryStore | null = null

/**
 * Get or create the singleton DictationHistoryStore.
 *
 * @param storageDir  Directory for the JSON file. Only used on first call;
 *                    subsequent calls ignore this parameter.
 */
export function getDictationHistoryStore(storageDir: string): DictationHistoryStore {
  if (!_instance) {
    _instance = new DictationHistoryStore(storageDir)
  }
  return _instance
}

/** Reset the singleton (useful for testing) */
export function resetDictationHistoryStore(): void {
  _instance = null
}
