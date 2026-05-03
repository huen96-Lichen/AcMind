// PinMind AI Task Queue
// FIFO sequential task queue with status change callbacks

import type { AiTask, AiTaskStatus } from '../../../shared/types';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type TaskFilter = Partial<Pick<AiTask, 'status' | 'sourceItemId' | 'operation'>>;

export type TaskStatusChangeCallback = (task: AiTask) => void;

export interface TaskQueueStats {
  total: number;
  queued: number;
  running: number;
  done: number;
  failed: number;
  cancelled: number;
}

// ---------------------------------------------------------------------------
// TaskQueue
// ---------------------------------------------------------------------------

class TaskQueue {
  private queue: AiTask[] = [];
  private processing = false;
  private paused = false;
  private statusChangeCallbacks: TaskStatusChangeCallback[] = [];

  // -- Callback management --------------------------------------------------

  /**
   * Register a callback to be invoked whenever a task's status changes.
   * Returns an unsubscribe function.
   */
  onStatusChange(callback: TaskStatusChangeCallback): () => void {
    this.statusChangeCallbacks.push(callback);
    return () => {
      this.statusChangeCallbacks = this.statusChangeCallbacks.filter((cb) => cb !== callback);
    };
  }

  private emitStatusChange(task: AiTask): void {
    for (const cb of this.statusChangeCallbacks) {
      try {
        cb(task);
      } catch (error) {
        logger.error('ai', 'taskQueue', 'emitStatusChange', 'Callback error', {
          taskId: task.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  // -- Queue operations -----------------------------------------------------

  /**
   * Add a task to the queue. If the queue is idle, processing starts immediately.
   */
  enqueue(task: AiTask): void {
    this.queue.push(task);
    logger.info('ai', 'taskQueue', 'enqueue', `Task enqueued: ${task.id}`, {
      operation: task.operation,
      sourceItemId: task.sourceItemId,
      queueLength: this.queue.length,
    });

    // Auto-start processing if idle
    if (!this.processing && !this.paused) {
      this.processNext();
    }
  }

  /**
   * Remove and return the next queued task (FIFO).
   * Returns undefined if no queued tasks remain.
   */
  dequeue(): AiTask | undefined {
    const index = this.queue.findIndex((t) => t.status === 'queued');
    if (index === -1) return undefined;

    const [task] = this.queue.splice(index, 1);
    return task;
  }

  /**
   * Peek at the next queued task without removing it.
   */
  getNext(): AiTask | undefined {
    return this.queue.find((t) => t.status === 'queued');
  }

  /**
   * Cancel a task by ID. Only queued or failed tasks can be cancelled.
   */
  cancel(id: string): boolean {
    const task = this.queue.find((t) => t.id === id);
    if (!task) {
      logger.warn('ai', 'taskQueue', 'cancel', `Task not found: ${id}`);
      return false;
    }

    if (task.status !== 'queued' && task.status !== 'failed') {
      logger.warn('ai', 'taskQueue', 'cancel', `Cannot cancel task in status: ${task.status}`, {
        taskId: id,
      });
      return false;
    }

    task.status = 'cancelled';
    logger.info('ai', 'taskQueue', 'cancel', `Task cancelled: ${id}`);
    this.emitStatusChange(task);
    return true;
  }

  /**
   * Cancel every cancellable queued/failed task for a source item.
   * Running tasks are intentionally left alone because the provider call may
   * already be in-flight; callers should treat them as still active.
   */
  cancelBySourceItem(sourceItemId: string): string[] {
    const cancelled: string[] = [];
    for (const task of this.queue) {
      if (task.sourceItemId !== sourceItemId) continue;
      if (task.status !== 'queued' && task.status !== 'failed') continue;

      task.status = 'cancelled';
      task.finishedAt = Date.now();
      cancelled.push(task.id);
      this.emitStatusChange(task);
    }

    if (cancelled.length > 0) {
      logger.info('ai', 'taskQueue', 'cancelBySourceItem', `Cancelled tasks for source item: ${sourceItemId}`, {
        count: cancelled.length,
      });
    }

    return cancelled;
  }

  /**
   * Retry a failed or cancelled task by resetting its status to 'queued'.
   */
  retry(id: string): boolean {
    const task = this.queue.find((t) => t.id === id);
    if (!task) {
      logger.warn('ai', 'taskQueue', 'retry', `Task not found: ${id}`);
      return false;
    }

    if (task.status !== 'failed' && task.status !== 'cancelled') {
      logger.warn('ai', 'taskQueue', 'retry', `Cannot retry task in status: ${task.status}`, {
        taskId: id,
      });
      return false;
    }

    task.status = 'queued';
    task.error = undefined;
    task.startedAt = undefined;
    task.finishedAt = undefined;
    task.latencyMs = undefined;

    logger.info('ai', 'taskQueue', 'retry', `Task queued for retry: ${id}`);
    this.emitStatusChange(task);

    // Auto-start processing if idle
    if (!this.processing && !this.paused) {
      this.processNext();
    }

    return true;
  }

  /**
   * Pause the queue after the current running task finishes.
   * Queued tasks remain stored and will resume later.
   */
  pause(): boolean {
    if (this.paused) {
      return true;
    }

    this.paused = true;
    logger.info('ai', 'taskQueue', 'pause', 'Task queue paused');
    return true;
  }

  /**
   * Resume processing queued tasks.
   */
  resume(): boolean {
    if (!this.paused) {
      return true;
    }

    this.paused = false;
    logger.info('ai', 'taskQueue', 'resume', 'Task queue resumed');

    if (!this.processing) {
      this.processNext();
    }

    return true;
  }

  /**
   * Check whether the queue is paused.
   */
  isPaused(): boolean {
    return this.paused;
  }

  /**
   * Get all tasks, optionally filtered.
   */
  getAll(filter?: TaskFilter): AiTask[] {
    let result = [...this.queue];

    if (filter?.status) {
      result = result.filter((t) => t.status === filter.status);
    }
    if (filter?.sourceItemId) {
      result = result.filter((t) => t.sourceItemId === filter.sourceItemId);
    }
    if (filter?.operation) {
      result = result.filter((t) => t.operation === filter.operation);
    }

    return result;
  }

  /**
   * Get aggregate queue statistics.
   */
  getStats(): TaskQueueStats {
    const total = this.queue.length;
    return {
      total,
      queued: this.queue.filter((t) => t.status === 'queued').length,
      running: this.queue.filter((t) => t.status === 'running').length,
      done: this.queue.filter((t) => t.status === 'done').length,
      failed: this.queue.filter((t) => t.status === 'failed').length,
      cancelled: this.queue.filter((t) => t.status === 'cancelled').length,
    };
  }

  // -- Internal processing --------------------------------------------------

  /**
   * Update a task's status in the queue and emit the change.
   */
  updateTaskStatus(id: string, status: AiTaskStatus, patch?: Partial<AiTask>): void {
    const task = this.queue.find((t) => t.id === id);
    if (!task) return;

    const prevStatus = task.status;
    task.status = status;

    if (patch) {
      if (patch.output !== undefined) task.output = patch.output;
      if (patch.error !== undefined) task.error = patch.error;
      if (patch.startedAt !== undefined) task.startedAt = patch.startedAt;
      if (patch.finishedAt !== undefined) task.finishedAt = patch.finishedAt;
      if (patch.latencyMs !== undefined) task.latencyMs = patch.latencyMs;
    }

    logger.info('ai', 'taskQueue', 'statusChange', `Task ${prevStatus} -> ${status}: ${id}`);
    this.emitStatusChange(task);
  }

  /**
   * Process the next queued task. Tasks are processed sequentially (one at a time).
   * The actual task execution is handled by the registered executor.
   */
  private async processNext(): Promise<void> {
    if (this.processing || this.paused) return;

    const task = this.getNext();
    if (!task) return;

    this.processing = true;
    task.status = 'running';
    task.startedAt = Date.now();

    logger.info('ai', 'taskQueue', 'processStart', `Processing task: ${task.id}`, {
      operation: task.operation,
      sourceItemId: task.sourceItemId,
    });
    this.emitStatusChange(task);

    // The pipeline will call completeTask() or failTask() when done
    // We keep processing=true until that happens
  }

  /**
   * Mark the current running task as done and process the next one.
   */
  completeTask(id: string, output: Record<string, unknown>): void {
    const task = this.queue.find((t) => t.id === id);
    if (!task) return;

    task.status = 'done';
    task.output = output;
    task.finishedAt = Date.now();
    task.latencyMs = task.startedAt ? Date.now() - task.startedAt : undefined;

    logger.info('ai', 'taskQueue', 'complete', `Task completed: ${id}`, {
      operation: task.operation,
      latencyMs: task.latencyMs,
    });
    this.emitStatusChange(task);

    this.processing = false;

    // Continue to next task
    setImmediate(() => this.processNext());
  }

  /**
   * Mark the current running task as failed and process the next one.
   */
  failTask(id: string, error: string): void {
    const task = this.queue.find((t) => t.id === id);
    if (!task) return;

    task.status = 'failed';
    task.error = error;
    task.finishedAt = Date.now();
    task.latencyMs = task.startedAt ? Date.now() - task.startedAt : undefined;

    logger.error('ai', 'taskQueue', 'fail', `Task failed: ${id}`, {
      operation: task.operation,
      error,
    });
    this.emitStatusChange(task);

    this.processing = false;

    // Continue to next task
    setImmediate(() => this.processNext());
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const taskQueue = new TaskQueue();
