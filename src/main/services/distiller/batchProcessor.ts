// PinMind Batch Processor
// Processes multiple distill tasks with concurrency control and progress tracking

import crypto from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { BrowserWindow } from 'electron';
import type { AiOperation, AiTier, AiTask, DistilledOutput } from '../../../shared/types';
import { IPC_CHANNELS } from '../../../shared/types';
import { storage } from '../../storage';
import { logger } from '../../logger';
import { tierRouter } from './tierRouter';
import { realDistiller } from './realDistiller';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface BatchProgress {
  batchId: string;
  total: number;
  done: number;
  failed: number;
  running: number;
  cancelled: boolean;
}

export interface BatchResult {
  batchId: string;
  tasks: AiTask[];
  outputs: DistilledOutput[];
  errors: Array<{ sourceItemId: string; operation: AiOperation; error: string }>;
}

export type BatchProgressCallback = (progress: BatchProgress) => void;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_CONCURRENCY = 3;

// ---------------------------------------------------------------------------
// BatchProcessor
// ---------------------------------------------------------------------------

class BatchProcessor {
  private activeBatches = new Map<string, {
    total: number;
    done: number;
    failed: number;
    running: number;
    cancelled: boolean;
    progressCallbacks: BatchProgressCallback[];
  }>();

  /**
   * Process multiple distill tasks with concurrency control.
   * Returns a BatchResult with all tasks, outputs, and errors.
   */
  async process(
    sourceItemIds: string[],
    operations: AiOperation[],
    tier?: AiTier,
    onProgress?: BatchProgressCallback,
  ): Promise<BatchResult> {
    const batchId = `batch_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

    // Build the full list of work items
    const workItems: Array<{ sourceItemId: string; operation: AiOperation }> = [];
    for (const sourceItemId of sourceItemIds) {
      for (const operation of operations) {
        workItems.push({ sourceItemId, operation });
      }
    }

    const total = workItems.length;
    const tasks: AiTask[] = [];
    const outputs: DistilledOutput[] = [];
    const errors: BatchResult['errors'] = [];

    // Initialize batch state
    this.activeBatches.set(batchId, {
      total,
      done: 0,
      failed: 0,
      running: 0,
      cancelled: false,
      progressCallbacks: onProgress ? [onProgress] : [],
    });

    logger.info('ai', 'batchProcessor', 'process', `Batch started: ${batchId}`, {
      total,
      sourceItemCount: sourceItemIds.length,
      operationCount: operations.length,
      concurrency: DEFAULT_CONCURRENCY,
    });

    this.emitProgress(batchId);

    // Process with concurrency limit
    const semaphore = new Semaphore(DEFAULT_CONCURRENCY);

    const promises = workItems.map(async (item) => {
      const batchState = this.activeBatches.get(batchId);
      if (!batchState || batchState.cancelled) return;

      await semaphore.acquire();
      batchState.running++;
      this.emitProgress(batchId);

      try {
        const result = await this.processOne(item.sourceItemId, item.operation, tier);
        if (result.task) tasks.push(result.task);
        if (result.output) outputs.push(result.output);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        errors.push({ sourceItemId: item.sourceItemId, operation: item.operation, error: errorMsg });
        batchState.failed++;
      } finally {
        batchState.running--;
        batchState.done++;
        semaphore.release();
        this.emitProgress(batchId);
      }
    });

    await Promise.all(promises);

    // Update source item statuses
    for (const sourceItemId of sourceItemIds) {
      this.checkAndUpdateSourceItemStatus(sourceItemId);
    }

    // Clean up batch state
    this.activeBatches.delete(batchId);

    logger.info('ai', 'batchProcessor', 'complete', `Batch completed: ${batchId}`, {
      total,
      succeeded: outputs.length,
      failed: errors.length,
    });

    return { batchId, tasks, outputs, errors };
  }

  /**
   * Cancel an active batch. Already running tasks will complete,
   * but pending tasks will not start.
   */
  cancel(batchId: string): boolean {
    const batchState = this.activeBatches.get(batchId);
    if (!batchState) {
      logger.warn('ai', 'batchProcessor', 'cancel', `Batch not found: ${batchId}`);
      return false;
    }
    batchState.cancelled = true;
    logger.info('ai', 'batchProcessor', 'cancel', `Batch cancelled: ${batchId}`);
    this.emitProgress(batchId);
    return true;
  }

  /**
   * Get the current progress of a batch.
   */
  getStatus(batchId: string): BatchProgress | null {
    const batchState = this.activeBatches.get(batchId);
    if (!batchState) return null;

    return {
      batchId,
      total: batchState.total,
      done: batchState.done,
      failed: batchState.failed,
      running: batchState.running,
      cancelled: batchState.cancelled,
    };
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  /**
   * Process a single (sourceItem, operation) pair.
   */
  private async processOne(
    sourceItemId: string,
    operation: AiOperation,
    tier?: AiTier,
  ): Promise<{ task: AiTask | null; output: DistilledOutput | null }> {
    // Fetch source item
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) {
      throw new Error(`SourceItem not found: ${sourceItemId}`);
    }

    const content = this.resolveSourceContent(sourceItem);

    // Route to provider
    const routeResult = tier
      ? tierRouter.routeToTier(operation, tier)
      : tierRouter.route(operation);

    // Create AiTask record
    const taskId = `ai_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const now = Math.floor(Date.now() / 1000);
    const task: AiTask = {
      id: taskId,
      sourceItemId,
      tier: routeResult.tier,
      operation,
      status: routeResult.useMock ? 'failed' : 'running',
      provider: routeResult.provider?.name ?? '',
      model: routeResult.provider?.modelId ?? '',
      input: { content },
      error: routeResult.useMock ? routeResult.reason : undefined,
      createdAt: now,
      updatedAt: now,
      startedAt: now,
      finishedAt: routeResult.useMock ? Date.now() : undefined,
    };
    storage.insertAiTask(task);

    if (routeResult.useMock || !routeResult.provider) {
      throw new Error(routeResult.reason);
    }

    // Update source item status
    storage.updateSourceItem(sourceItemId, { status: 'distilling' });

    // Execute
    const startTime = Date.now();
    let result: Record<string, unknown>;

    result = await realDistiller.runTask(routeResult.provider, operation, content);

    const latencyMs = Date.now() - startTime;

    // Update task as done
    storage.updateAiTask(taskId, {
      status: 'done',
      output: result,
      finishedAt: Date.now(),
      latencyMs,
    });

    // Build and save distilled output
    const outputId = `do_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const distilledOutput: DistilledOutput = {
      id: outputId,
      sourceItemId,
      taskId,
      suggestedTitle: result.suggestedTitle as string | undefined,
      summary: result.summary as string | undefined,
      category: result.category as string | undefined,
      tags: result.tags as string[] | undefined,
      documentType: result.documentType as DistilledOutput['documentType'] | undefined,
      contentMarkdown: result.contentMarkdown as string | undefined,
      valueScore: result.valueScore as number | undefined,
      cleanSuggestion: result.cleanSuggestion as DistilledOutput['cleanSuggestion'] | undefined,
      confidence: 0.8,
      reviewStatus: 'pending',
      createdAt: Math.floor(Date.now() / 1000),
    };
    storage.insertDistilledOutput(distilledOutput);

    return { task, output: distilledOutput };
  }

  /**
   * Check if all tasks for a source item are done and update its status.
   * Also writes back CaptureItem terminal state and broadcasts events.
   */
  private checkAndUpdateSourceItemStatus(sourceItemId: string): void {
    const storageTasks = storage.getAiTasks({ sourceItemId });
    const pending = storageTasks.filter(
      (t) => t.status === 'queued' || t.status === 'running',
    );
    if (pending.length === 0) {
      storage.updateSourceItem(sourceItemId, { status: 'distilled' });

      // Write back CaptureItem terminal state
      const sourceItem = storage.getSourceItem(sourceItemId);
      if (sourceItem?.captureItemId) {
        const captureItem = storage.getCaptureItem(sourceItem.captureItemId);
        if (captureItem && captureItem.status === 'distilling') {
          const doneTasks = storageTasks.filter((t) => t.status === 'done');
          const newStatus = doneTasks.length > 0 ? 'archived' : 'failed';
          storage.updateCaptureItem(sourceItem.captureItemId, { status: newStatus });
          // Broadcast captureItems.changed
          const timestamp = Math.floor(Date.now() / 1000);
          for (const win of BrowserWindow.getAllWindows()) {
            if (!win.isDestroyed()) {
              win.webContents.send(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, {
                action: 'updated',
                id: sourceItem.captureItemId,
                timestamp,
              });
            }
          }
          logger.info('ai', 'batchProcessor', 'updateStatus', `CaptureItem ${newStatus}: ${sourceItem.captureItemId}`);
        }
      }
    }
  }

  private resolveSourceContent(sourceItem: { contentPath?: string; previewText?: string; ocrText?: string; originalUrl?: string }): string {
    if (sourceItem.contentPath && existsSync(sourceItem.contentPath)) {
      try {
        const content = readFileSync(sourceItem.contentPath, 'utf8');
        if (content.trim()) return content;
      } catch (error) {
        logger.warn('ai', 'batchProcessor', 'resolveSourceContent', 'Failed to read full source content, falling back to preview', {
          contentPath: sourceItem.contentPath,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return sourceItem.previewText ?? sourceItem.ocrText ?? sourceItem.originalUrl ?? '';
  }

  /**
   * Emit progress to all registered callbacks for a batch.
   */
  private emitProgress(batchId: string): void {
    const batchState = this.activeBatches.get(batchId);
    if (!batchState) return;

    const progress: BatchProgress = {
      batchId,
      total: batchState.total,
      done: batchState.done,
      failed: batchState.failed,
      running: batchState.running,
      cancelled: batchState.cancelled,
    };

    for (const cb of batchState.progressCallbacks) {
      try {
        cb(progress);
      } catch (error) {
        logger.error('ai', 'batchProcessor', 'progressCallback', 'Progress callback error', {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Simple semaphore for concurrency control
// ---------------------------------------------------------------------------

class Semaphore {
  private queue: Array<() => void> = [];
  private running = 0;

  constructor(private max: number) {}

  async acquire(): Promise<void> {
    if (this.running < this.max) {
      this.running++;
      return;
    }
    return new Promise<void>((resolve) => {
      this.queue.push(() => {
        this.running++;
        resolve();
      });
    });
  }

  release(): void {
    this.running--;
    const next = this.queue.shift();
    if (next) next();
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const batchProcessor = new BatchProcessor();
