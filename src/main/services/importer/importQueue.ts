// AcMind Import Queue
// Manages async import task execution with progress tracking

import crypto from 'node:crypto';
import path from 'node:path';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import type { ImportTask, ImportOptions, PinItem } from '../../../shared/types';
import { IPC_CHANNELS } from '../../../shared/types';
import { storage } from '../../storage';
import { logger } from '../../logger';
import { vaultScanner } from './vaultScanner';
import { BrowserWindow } from 'electron';

export class ImportQueue {
  private currentTask: ImportTask | null = null;
  private cancelRequested = false;

  startImport(options: ImportOptions): string {
    if (this.currentTask && (this.currentTask.status === 'importing' || this.currentTask.status === 'scanning')) {
      throw new Error('An import task is already running');
    }

    const id = `imp_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const task: ImportTask = {
      id,
      vaultPath: options.vaultPath,
      folderPath: options.folderPath ?? '',
      status: 'scanning',
      totalFiles: 0,
      importedCount: 0,
      skippedCount: 0,
      failedCount: 0,
      excludePatterns: options.excludePatterns ?? [],
      includePatterns: options.includePatterns ?? [],
      createdAt: Math.floor(Date.now() / 1000),
    };

    storage.insertImportTask(task);
    this.currentTask = task;
    this.cancelRequested = false;

    // Execute async
    this.executeImport(task, options).catch(err => {
      logger.error('export', 'importQueue', 'executeImport', `Import failed: ${id}`, {
        error: err instanceof Error ? err.message : String(err),
      });
    });

    return id;
  }

  getStatus(taskId: string): ImportTask | null {
    if (this.currentTask?.id === taskId) return this.currentTask;
    return storage.getImportTask(taskId);
  }

  cancel(taskId: string): boolean {
    if (!this.currentTask || this.currentTask.id !== taskId) return false;
    if (this.currentTask.status !== 'importing' && this.currentTask.status !== 'scanning') return false;
    this.cancelRequested = true;
    return true;
  }

  getHistory(limit?: number): ImportTask[] {
    return storage.getImportTasks({ limit: limit ?? 20 });
  }

  private async executeImport(task: ImportTask, options: ImportOptions): Promise<void> {
    const sourcesDir = path.join(path.dirname(storage.getDbPath()), 'sources');
    mkdirSync(sourcesDir, { recursive: true });

    try {
      // Phase 1: Scan
      this.updateTask(task.id, { status: 'scanning', startedAt: Date.now() });
      const scannedFiles = vaultScanner.scan(options.vaultPath, options);
      const filesToImport = options.selectedFiles
        ? scannedFiles.filter(f => options.selectedFiles!.includes(f.relativePath))
        : scannedFiles.filter(f => !f.willSkip);

      this.updateTask(task.id, { totalFiles: filesToImport.length, status: 'importing' });

      // Phase 2: Import each file
      for (const file of filesToImport) {
        if (this.cancelRequested) {
          this.updateTask(task.id, { status: 'cancelled', finishedAt: Date.now() });
          this.currentTask = null;
          return;
        }

        try {
          const filePath = path.join(options.vaultPath, file.relativePath);
          const content = readFileSync(filePath, 'utf8');
          const hash = createHash('sha256').update(content).digest('hex');

          // Dedup check
          if (options.skipDuplicates !== false) {
            const existing = storage.getSourceItemByHash(hash);
            if (existing) {
              this.incrementCounter(task.id, 'skippedCount');
              continue;
            }
          }

          // Save content file
          const contentPath = path.join(sourcesDir, `${task.id}_${path.basename(file.relativePath)}`);
          writeFileSync(contentPath, content, 'utf8');

          // Create SourceItem
          const sourceItem = {
            id: `si_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`,
            type: 'text' as const,
            source: 'vault_import' as const,
            contentPath,
            contentHash: hash,
            previewText: content.slice(0, 500),
            title: file.title,
            tags: file.tags.length > 0 ? file.tags : undefined,
            createdAt: file.modifiedAt * 1000 || Date.now(),
            status: 'inbox' as const,
            vaultImportPath: file.relativePath,
          };

          storage.insertSourceItem(sourceItem);

          // Phase 8: Also create PinItem so imported file enters Pin Pool
          const now = Math.floor(Date.now() / 1000);
          const pinSourceType: PinItem['sourceType'] = file.relativePath.endsWith('.pdf') ? 'pdf'
            : file.relativePath.endsWith('.docx') ? 'docx'
            : 'file';
          const pin: PinItem = {
            id: crypto.randomUUID(),
            captureItemId: '',
            originalId: sourceItem.id,
            sourceType: pinSourceType,
            title: file.title || path.basename(file.relativePath),
            previewText: content.slice(0, 180),
            rawText: content.slice(0, 2000),
            status: 'pinned',
            createdAt: now,
            pinnedAt: now,
            updatedAt: now,
          };
          storage.insertPinItem(pin);
          for (const win of BrowserWindow.getAllWindows()) {
            if (!win.isDestroyed()) {
              win.webContents.send(IPC_CHANNELS.PIN_POOL_CHANGED, { action: 'created', id: pin.id, timestamp: now });
            }
          }

          this.incrementCounter(task.id, 'importedCount');
        } catch (err) {
          this.incrementCounter(task.id, 'failedCount');
        }
      }

      // Phase 3: Done
      this.updateTask(task.id, {
        status: 'done',
        finishedAt: Date.now(),
      });

      logger.info('export', 'importQueue', 'complete', `Import completed: ${task.id}`, {
        imported: this.currentTask?.importedCount,
        skipped: this.currentTask?.skippedCount,
        failed: this.currentTask?.failedCount,
      });
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      this.updateTask(task.id, { status: 'failed', error: errorMsg, finishedAt: Date.now() });
    } finally {
      this.currentTask = null;
    }
  }

  private updateTask(id: string, patch: Partial<ImportTask>): void {
    storage.updateImportTask(id, patch);
    if (this.currentTask?.id === id) {
      Object.assign(this.currentTask, patch);
    }
  }

  private incrementCounter(id: string, field: 'importedCount' | 'skippedCount' | 'failedCount'): void {
    const task = this.currentTask ?? storage.getImportTask(id);
    if (task) {
      const newValue = (task[field] ?? 0) + 1;
      this.updateTask(id, { [field]: newValue });
    }
  }
}

export const importQueue = new ImportQueue();
