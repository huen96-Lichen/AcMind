// PinMind Distillation Pipeline Orchestrator
// Coordinates task creation, queueing, execution, and result storage
// Phase 4: Now supports real AI providers via tierRouter + realDistiller
// Phase 4: Supports batch processing via batchProcessor

import crypto from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { BrowserWindow } from 'electron';
import type {
  AiTask,
  AiTier,
  AiOperation,
  DistilledOutput,
  ProviderConfig,
} from '../../../shared/types';
import { IPC_CHANNELS } from '../../../shared/types';
import { storage } from '../../storage';
import { settings } from '../../settings';
import { logger } from '../../logger';
import { errorService } from '../../errorService';
import { taskQueue } from '../aiHub/taskQueue';
import { realDistiller } from './realDistiller';
import { mockDistiller } from './mockDistiller';
import { tierRouter } from './tierRouter';
import { batchProcessor, type BatchResult } from './batchProcessor';

// ---------------------------------------------------------------------------
// Helper: generate unique ID
// ---------------------------------------------------------------------------

function makeId(prefix: string): string {
  return `${prefix}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

function listProvidersFromAllSources(): ProviderConfig[] {
  const merged = new Map<string, ProviderConfig>();
  for (const provider of settings.load().providers ?? []) {
    merged.set(provider.id, provider);
  }
  for (const provider of storage.getProviderConfigs()) {
    merged.set(provider.id, provider);
  }
  return Array.from(merged.values());
}

// ---------------------------------------------------------------------------
// DistillPipeline
// ---------------------------------------------------------------------------

class DistillPipeline {
  private initialized = false;

  /**
   * Broadcast an AiTask status change to all renderer windows.
   */
  private broadcastTaskStatus(task: AiTask): void {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.AI_TASKS_STATUS_CHANGED, task);
      }
    }
  }

  /**
   * Broadcast a records.changed event to all renderer windows.
   */
  private broadcastRecordsChanged(action: 'created' | 'updated' | 'deleted', id: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action, id, timestamp });
      }
    }
  }

  /**
   * Broadcast a captureItems.changed event to all renderer windows.
   */
  private broadcastCaptureItemChanged(action: 'created' | 'updated' | 'deleted', captureItemId: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, { action, id: captureItemId, timestamp });
      }
    }
  }

  /**
   * Initialize the pipeline. Sets up the task queue status change listener
   * to persist results and update source items when tasks complete.
   * Also recovers any interrupted tasks from a previous session.
   */
  init(): void {
    if (this.initialized) return;

    // Listen for task status changes to trigger persistence and source item updates
    taskQueue.onStatusChange((task) => {
      if (task.status === 'running') {
        this.executeTask(task);
      }
    });

    // Recover interrupted tasks from previous session
    this.recoverInterruptedTasks();

    this.initialized = true;
    logger.info('ai', 'distillPipeline', 'init', 'Distillation pipeline initialized (with real distiller support)');
  }

  /**
   * Recover tasks that were interrupted by an app restart.
   * - 'queued' tasks are re-enqueued for execution.
   * - 'running' tasks are marked as 'failed' (cannot safely resume).
   */
  private recoverInterruptedTasks(): void {
    const allTasks = storage.getAiTasks({});
    const interrupted = allTasks.filter((t) => t.status === 'running');

    const queuedCount = allTasks.filter((t) => t.status === 'queued').length;
    if (queuedCount > 0) {
      logger.info('ai', 'distillPipeline', 'recover', `Leaving ${queuedCount} queued tasks paused until explicit retry`);
    }

    if (interrupted.length === 0) return;

    logger.info('ai', 'distillPipeline', 'recover', `Recovering ${interrupted.length} interrupted tasks`);

    for (const task of interrupted) {
      if (task.status === 'running') {
        // App restart means the task was interrupted; mark as failed
        storage.updateAiTask(task.id, {
          status: 'failed',
          error: '应用重启，任务中断',
          finishedAt: Date.now(),
        });
        this.broadcastTaskStatus({
          ...task,
          status: 'failed',
          error: '应用重启，任务中断',
          finishedAt: Date.now(),
        });
      }
    }

    // Check all affected SourceItems for terminal state
    const affectedSourceIds = [...new Set(interrupted.map((t) => t.sourceItemId))];
    for (const sourceItemId of affectedSourceIds) {
      this.checkAndUpdateSourceItemStatus(sourceItemId);
    }
  }

  /**
   * Run a single distillation operation on a source item.
   * Creates an AiTask, enqueues it, and returns the task.
   */
  distill(
    sourceItemId: string,
    operation: AiOperation,
    tier?: AiTier,
  ): AiTask {
    // Fetch the source item to get content
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) {
      throw new Error(`SourceItem not found: ${sourceItemId}`);
    }

    const content = this.resolveSourceContent(sourceItem);

    // Route to provider to determine provider/model info
    const routeResult = tier
      ? tierRouter.routeToTier(operation, tier)
      : tierRouter.route(operation);

    const now = Math.floor(Date.now() / 1000);
    const task: AiTask = {
      id: makeId('ai'),
      sourceItemId,
      tier: routeResult.tier,
      operation,
      status: 'queued',
      provider: routeResult.provider?.name ?? 'mock-fallback',
      model: routeResult.provider?.modelId ?? 'mock',
      input: { content, useMock: routeResult.useMock },
      createdAt: now,
      updatedAt: now,
    };

    // Persist task to storage
    storage.insertAiTask(task);

    if (routeResult.useMock) {
      logger.warn('ai', 'distillPipeline', 'distill', '[Mock Fallback] No real provider, using mockDistiller', {
        sourceItemId,
        operation,
        reason: routeResult.reason,
      });
    }

    // Update source item status to 'distilling'
    storage.updateSourceItem(sourceItemId, { status: 'distilling' });

    // Enqueue for processing (real or mock)
    taskQueue.enqueue(task);

    logger.info('ai', 'distillPipeline', 'distill', `Distillation task created: ${task.id}`, {
      sourceItemId,
      operation,
      tier: routeResult.tier,
      provider: task.provider,
      model: task.model,
      useMock: routeResult.useMock,
    });

    return task;
  }

  /**
   * Run multiple distillation operations on multiple source items.
   * Creates and enqueues a task for each (sourceItem, operation) pair.
   */
  distillBatch(
    sourceItemIds: string[],
    operations: AiOperation[],
    tier?: AiTier,
  ): AiTask[] {
    const tasks: AiTask[] = [];

    for (const sourceItemId of sourceItemIds) {
      for (const operation of operations) {
        try {
          const task = this.distill(sourceItemId, operation, tier);
          tasks.push(task);
        } catch (error) {
          logger.error('ai', 'distillPipeline', 'distillBatch', 'Failed to create task', {
            sourceItemId,
            operation,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
    }

    logger.info('ai', 'distillPipeline', 'distillBatch', `Batch distillation started`, {
      taskCount: tasks.length,
      sourceItemCount: sourceItemIds.length,
      operationCount: operations.length,
    });

    return tasks;
  }

  /**
   * Run batch processing via batchProcessor (Phase 4).
   * Uses concurrency control and progress tracking.
   * Returns a batchId for progress monitoring.
   */
  async distillBatchAsync(
    sourceItemIds: string[],
    operations: AiOperation[],
    tier?: AiTier,
    onProgress?: (progress: import('./batchProcessor').BatchProgress) => void,
  ): Promise<BatchResult> {
    logger.info('ai', 'distillPipeline', 'distillBatchAsync', 'Starting async batch distillation', {
      sourceItemCount: sourceItemIds.length,
      operationCount: operations.length,
      tier: tier ?? 'auto',
    });

    return batchProcessor.process(sourceItemIds, operations, tier, onProgress);
  }

  /**
   * Cancel an active batch by batchId.
   */
  cancelBatch(batchId: string): boolean {
    return batchProcessor.cancel(batchId);
  }

  /**
   * Get batch progress by batchId.
   */
  getBatchStatus(batchId: string): import('./batchProcessor').BatchProgress | null {
    return batchProcessor.getStatus(batchId);
  }

  /**
   * Execute a running task: call the distiller (real or mock), save result, update source item.
   * This is triggered automatically by the task queue when a task starts running.
   */
  private async executeTask(task: AiTask): Promise<void> {
    logger.info('ai', 'distillPipeline', 'executeTask', `Executing task: ${task.id}`, {
      operation: task.operation,
      sourceItemId: task.sourceItemId,
      provider: task.provider,
    });

    try {
      let output: Record<string, unknown>;
      const useMock = task.input.useMock === true;

      if (useMock || !task.provider || task.provider === 'mock-fallback') {
        // Mock fallback path — clearly labeled
        logger.warn('ai', 'distillPipeline', 'executeTask', '[Mock Fallback] Using mockDistiller', {
          taskId: task.id,
          operation: task.operation,
        });
        output = await mockDistiller.runTask(task.operation, task.input);
      } else {
        // Find the provider config and use real distiller
        const providers = listProvidersFromAllSources();
        const provider = providers.find((p) => p.name === task.provider && p.enabled);

        if (provider) {
          const content = String(task.input.content ?? '');
          output = await realDistiller.runTask(provider, task.operation, content);
        } else {
          throw new Error(`Configured provider is unavailable: ${task.provider}`);
        }
      }

      // Mark task as complete in the queue
      taskQueue.completeTask(task.id, output);

      // Persist task update to storage
      const updatedTask: AiTask = {
        ...task,
        status: 'done',
        output,
        finishedAt: Date.now(),
        latencyMs: task.startedAt ? Date.now() - task.startedAt : undefined,
      };
      storage.updateAiTask(task.id, {
        status: 'done',
        output,
        finishedAt: Date.now(),
        latencyMs: task.startedAt ? Date.now() - task.startedAt : undefined,
      });

      // Save distilled output
      const distilledOutput = this.buildDistilledOutput(task, output);
      storage.insertDistilledOutput(distilledOutput);

      // Check if all tasks for this source item are done
      this.checkAndUpdateSourceItemStatus(task.sourceItemId);

      // Broadcast task status to renderer
      this.broadcastTaskStatus(updatedTask);
      this.broadcastRecordsChanged('created', distilledOutput.id);

      logger.info('ai', 'distillPipeline', 'executeTask', `Task executed successfully: ${task.id}`, {
        operation: task.operation,
        provider: task.provider,
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);

      // Mark task as failed in the queue
      taskQueue.failTask(task.id, errorMsg);

      // Persist failure to storage
      storage.updateAiTask(task.id, {
        status: 'failed',
        error: errorMsg,
        finishedAt: Date.now(),
        latencyMs: task.startedAt ? Date.now() - task.startedAt : undefined,
      });

      this.checkAndUpdateSourceItemStatus(task.sourceItemId);

      // Broadcast failure to renderer
      this.broadcastTaskStatus({
        ...task,
        status: 'failed',
        error: errorMsg,
        finishedAt: Date.now(),
      });

      logger.error('ai', 'distillPipeline', 'executeTask', `Task execution failed: ${task.id}`, {
        operation: task.operation,
        error: errorMsg,
      });

      // Record to unified error model
      const sourceItem = storage.getSourceItem(task.sourceItemId);
      errorService.recordError({
        errorType: errorMsg.includes('provider') || errorMsg.includes('model') || errorMsg.includes('API')
          ? 'model_unavailable'
          : 'process_failed',
        originalId: sourceItem?.originalId,
        outputId: task.id,
        stage: 'distill_execute',
        error,
        userMessage: errorMsg.includes('provider') || errorMsg.includes('model') || errorMsg.includes('API')
          ? 'AI 模型不可用，请检查模型配置或网络连接。'
          : 'AI 蒸馏处理失败，请稍后重试。',
      });
    }
  }

  /**
   * Build a DistilledOutput from a completed task's output.
   */
  private buildDistilledOutput(task: AiTask, output: Record<string, unknown>): DistilledOutput {
    return {
      id: makeId('do'),
      sourceItemId: task.sourceItemId,
      taskId: task.id,
      operation: task.operation,
      suggestedTitle: output.suggestedTitle as string | undefined,
      summary: output.summary as string | undefined,
      category: output.category as string | undefined,
      tags: output.tags as string[] | undefined,
      documentType: output.documentType as DistilledOutput['documentType'] | undefined,
      contentMarkdown: output.contentMarkdown as string | undefined,
      valueScore: output.valueScore as number | undefined,
      cleanSuggestion: output.cleanSuggestion as DistilledOutput['cleanSuggestion'] | undefined,
      confidence: typeof output.confidence === 'number' ? output.confidence : 0.8,
      reviewStatus: 'pending',
      createdAt: Math.floor(Date.now() / 1000),
    };
  }

  /**
   * Use the full captured/imported source when available. previewText is only a UI
   * preview and must not be treated as the distillation input.
   */
  private resolveSourceContent(sourceItem: { contentPath?: string; previewText?: string; ocrText?: string; originalUrl?: string }): string {
    if (sourceItem.contentPath && existsSync(sourceItem.contentPath)) {
      try {
        const content = readFileSync(sourceItem.contentPath, 'utf8');
        if (content.trim()) return content;
      } catch (error) {
        logger.warn('ai', 'distillPipeline', 'resolveSourceContent', 'Failed to read full source content, falling back to preview', {
          contentPath: sourceItem.contentPath,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return sourceItem.previewText ?? sourceItem.ocrText ?? sourceItem.originalUrl ?? '';
  }

  /**
   * Check if all queued/running tasks for a source item are done.
   * If so, update the source item status to 'distilled' and write back
   * the CaptureItem terminal state (archived or failed).
   */
  private checkAndUpdateSourceItemStatus(sourceItemId: string): void {
    const allTasks = taskQueue.getAll({ sourceItemId });
    const pendingTasks = allTasks.filter(
      (t) => t.status === 'queued' || t.status === 'running',
    );

    if (pendingTasks.length === 0) {
      // Also check storage for any remaining queued tasks
      const storageTasks = storage.getAiTasks({ sourceItemId });
      const storagePending = storageTasks.filter(
        (t) => t.status === 'queued' || t.status === 'running',
      );

      if (storagePending.length === 0) {
          // Only mark as 'distilled' if at least one task succeeded;
          // otherwise revert to 'inbox' so the user can retry.
          const doneTasks = storageTasks.filter((t) => t.status === 'done');
          const newStatus = doneTasks.length > 0 ? 'distilled' : 'inbox';
          storage.updateSourceItem(sourceItemId, { status: newStatus });
          logger.info('ai', 'distillPipeline', 'updateStatus', `SourceItem ${newStatus}: ${sourceItemId}`, {
            doneCount: doneTasks.length,
            failedCount: storageTasks.filter((t) => t.status === 'failed').length,
          });

        // Write back CaptureItem terminal state
        const sourceItem = storage.getSourceItem(sourceItemId);
        if (sourceItem?.captureItemId) {
          const captureItem = storage.getCaptureItem(sourceItem.captureItemId);
          if (captureItem && captureItem.status === 'distilling') {
            const captureStatus = doneTasks.length > 0 ? 'archived' : 'failed';
            storage.updateCaptureItem(sourceItem.captureItemId, { status: captureStatus });
            this.broadcastCaptureItemChanged('updated', sourceItem.captureItemId);
            logger.info('ai', 'distillPipeline', 'updateStatus', `CaptureItem ${captureStatus}: ${sourceItem.captureItemId}`);
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const distillPipeline = new DistillPipeline();
