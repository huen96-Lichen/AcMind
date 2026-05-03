// PinMind Scheduler Service
// Provides scheduled task automation for distillation, export, and cleanup.
// Calls existing pipelines (distillPipeline, obsidianExporter) without modifying them.

import cron from 'node-cron';
import { BrowserWindow } from 'electron';
import { logger } from '../../logger';
import { storage } from '../../storage';
import { distillPipeline } from '../distiller/distillPipeline';
import { obsidianExporter } from '../exporter/obsidianExporter';
import type {
  ScheduledTask,
  ScheduledTaskType,
  TaskExecutionResult,
  CreateTaskParams,
} from './types';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MODULE = 'schedulerService';
const TABLE_NAME = 'scheduled_tasks';

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  cron_expr TEXT NOT NULL,
  config TEXT NOT NULL DEFAULT '{}',
  enabled INTEGER NOT NULL DEFAULT 1,
  last_run_at INTEGER,
  next_run_at INTEGER,
  next_run_at_estimated INTEGER NOT NULL DEFAULT 0,
  last_result TEXT,
  created_at INTEGER NOT NULL
);
`;

// ---------------------------------------------------------------------------
// SchedulerService
// ---------------------------------------------------------------------------

class SchedulerService {
  private initialized = false;
  private tasks: Map<string, ScheduledTask> = new Map();
  private cronJobs: Map<string, { stop: () => void }> = new Map();

  // -------------------------------------------------------------------------
  // Initialization
  // -------------------------------------------------------------------------

  /**
   * Initialize the scheduler. Creates the DB table if needed, loads persisted
   * tasks, and starts all enabled cron jobs.
   */
  init(): void {
    if (this.initialized) return;

    const db = storage.db;
    if (!db) {
      logger.error('app', MODULE, 'init', 'Database not available, scheduler not initialized');
      return;
    }

    // Create table if not exists
    db.exec(CREATE_TABLE_SQL);

    // Load persisted tasks
    const rows = db.prepare(`SELECT * FROM ${TABLE_NAME} ORDER BY created_at DESC`).all() as Record<string, unknown>[];

    for (const row of rows) {
      const task = this.rowToTask(row);
      this.tasks.set(task.id, task);
    }

    // Start enabled tasks
    for (const task of this.tasks.values()) {
      if (task.enabled) {
        this._scheduleTask(task);
      }
    }

    this.initialized = true;
    logger.info('app', MODULE, 'init', `Scheduler initialized with ${this.tasks.size} tasks`, {
      enabledCount: [...this.tasks.values()].filter((t) => t.enabled).length,
    });
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /**
   * Create a new scheduled task and optionally start it.
   */
  createTask(params: CreateTaskParams): ScheduledTask {
    this.ensureInitialized();

    const id = crypto.randomUUID();
    const now = Date.now();

    const task: ScheduledTask = {
      id,
      type: params.type,
      name: params.name,
      cronExpr: params.cronExpr,
      config: params.config,
      enabled: params.enabled ?? true,
      lastRunAt: null,
      nextRunAt: null,
      nextRunAtEstimated: false,
      lastResult: null,
      createdAt: now,
    };

    // Validate cron expression
    if (!cron.validate(params.cronExpr)) {
      throw new Error(`Invalid cron expression: ${params.cronExpr}`);
    }

    // Persist to DB
    this.persistTask(task);

    // Keep in memory
    this.tasks.set(id, task);

    // Start if enabled
    if (task.enabled) {
      this._scheduleTask(task);
    }

    logger.info('app', MODULE, 'createTask', `Task created: ${task.name} (${task.id})`, {
      type: task.type,
      cronExpr: task.cronExpr,
      enabled: task.enabled,
    });

    this.broadcastChange('created', task);

    return task;
  }

  /**
   * Update an existing task's configuration.
   */
  updateTask(id: string, updates: Partial<Pick<ScheduledTask, 'name' | 'cronExpr' | 'config'>>): ScheduledTask {
    this.ensureInitialized();

    const existing = this.tasks.get(id);
    if (!existing) {
      throw new Error(`Task not found: ${id}`);
    }

    // If cron expression is changing, validate it
    if (updates.cronExpr && updates.cronExpr !== existing.cronExpr) {
      if (!cron.validate(updates.cronExpr)) {
        throw new Error(`Invalid cron expression: ${updates.cronExpr}`);
      }
    }

    // If the task was enabled and cron changed, unschedule first
    const needsReschedule = existing.enabled && updates.cronExpr && updates.cronExpr !== existing.cronExpr;
    if (needsReschedule) {
      this._unscheduleTask(id);
    }

    // Apply updates
    const updated: ScheduledTask = {
      ...existing,
      name: updates.name ?? existing.name,
      cronExpr: updates.cronExpr ?? existing.cronExpr,
      config: updates.config ?? existing.config,
    };

    this.tasks.set(id, updated);
    this.persistTask(updated);

    // Reschedule if needed
    if (needsReschedule) {
      this._scheduleTask(updated);
    }

    logger.info('app', MODULE, 'updateTask', `Task updated: ${updated.name} (${id})`, {
      changes: Object.keys(updates),
    });

    this.broadcastChange('updated', updated);

    return updated;
  }

  /**
   * Delete a task: stop its cron job and remove from storage.
   */
  deleteTask(id: string): void {
    this.ensureInitialized();

    const task = this.tasks.get(id);
    if (!task) {
      throw new Error(`Task not found: ${id}`);
    }

    this._unscheduleTask(id);
    this.tasks.delete(id);

    const db = storage.db;
    if (db) {
      db.prepare(`DELETE FROM ${TABLE_NAME} WHERE id = ?`).run(id);
    }

    logger.info('app', MODULE, 'deleteTask', `Task deleted: ${task.name} (${id})`);

    this.broadcastChange('deleted', task);
  }

  /**
   * Enable or disable a task.
   */
  toggleTask(id: string, enabled: boolean): ScheduledTask {
    this.ensureInitialized();

    const task = this.tasks.get(id);
    if (!task) {
      throw new Error(`Task not found: ${id}`);
    }

    if (task.enabled === enabled) {
      return task;
    }

    if (enabled) {
      this._scheduleTask(task);
    } else {
      this._unscheduleTask(id);
    }

    const updated: ScheduledTask = {
      ...task,
      enabled,
      nextRunAt: enabled ? this.computeNextRun(task.cronExpr) : null,
      nextRunAtEstimated: enabled,
    };

    this.tasks.set(id, updated);
    this.persistTask(updated);

    logger.info('app', MODULE, 'toggleTask', `Task ${enabled ? 'enabled' : 'disabled'}: ${task.name} (${id})`);

    this.broadcastChange('updated', updated);

    return updated;
  }

  /**
   * List all tasks.
   */
  getTasks(): ScheduledTask[] {
    this.ensureInitialized();
    return [...this.tasks.values()];
  }

  /**
   * Get a single task by ID.
   */
  getTask(id: string): ScheduledTask | null {
    this.ensureInitialized();
    return this.tasks.get(id) ?? null;
  }

  /**
   * Manually trigger a task execution (regardless of schedule).
   */
  async runTaskNow(id: string): Promise<TaskExecutionResult> {
    this.ensureInitialized();

    const task = this.tasks.get(id);
    if (!task) {
      throw new Error(`Task not found: ${id}`);
    }

    logger.info('app', MODULE, 'runTaskNow', `Manually running task: ${task.name} (${id})`);

    const result = await this._executeTask(task);

    // Update task with result
    const updated: ScheduledTask = {
      ...task,
      lastRunAt: result.startedAt,
      lastResult: result,
    };
    this.tasks.set(id, updated);
    this.persistTask(updated);

    this.broadcastChange('updated', updated);

    return result;
  }

  // -------------------------------------------------------------------------
  // Task execution
  // -------------------------------------------------------------------------

  /**
   * Execute a task based on its type. Resilient: catches errors and returns
   * a failed TaskExecutionResult rather than throwing.
   */
  private async _executeTask(task: ScheduledTask): Promise<TaskExecutionResult> {
    const startedAt = Date.now();

    logger.info('app', MODULE, '_executeTask', `Executing task: ${task.name} (${task.id})`, {
      type: task.type,
    });

    try {
      let result: TaskExecutionResult;

      switch (task.type) {
        case 'auto_distill':
          result = await this.executeAutoDistill(task);
          break;
        case 'auto_export':
          result = await this.executeAutoExport(task);
          break;
        case 'cleanup':
          result = await this.executeCleanup(task);
          break;
        default:
          throw new Error(`Unknown task type: ${(task.type as string)}`);
      }

      logger.info('app', MODULE, '_executeTask', `Task completed: ${task.name}`, {
        success: result.success,
        itemsProcessed: result.itemsProcessed,
        durationMs: result.finishedAt - result.startedAt,
      });

      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);

      logger.error('error', MODULE, '_executeTask', `Task failed: ${task.name}`, {
        error: errorMsg,
        taskId: task.id,
      });

      return {
        success: false,
        startedAt,
        finishedAt: Date.now(),
        itemsProcessed: 0,
        error: errorMsg,
        summary: `Task "${task.name}" failed: ${errorMsg}`,
      };
    }
  }

  /**
   * auto_distill: Query source_items with status='inbox', call
   * distillPipeline.distillBatch() with operations ['summarize', 'classify', 'tag'].
   */
  private async executeAutoDistill(task: ScheduledTask): Promise<TaskExecutionResult> {
    const startedAt = Date.now();

    // Get config overrides
    const config = task.config;
    const operations = (config.operations as string[]) ?? ['summarize', 'classify', 'tag'];
    const tier = config.tier as string | undefined;
    const limit = (config.limit as number) ?? 50;

    // Query inbox items
    const inboxItems = storage.getSourceItems({ status: 'inbox', limit });
    if (inboxItems.length === 0) {
      return {
        success: true,
        startedAt,
        finishedAt: Date.now(),
        itemsProcessed: 0,
        summary: 'No inbox items to distill',
      };
    }

    const sourceItemIds = inboxItems.map((item) => item.id);

    logger.info('ai', MODULE, 'executeAutoDistill', `Starting auto-distill for ${sourceItemIds.length} items`, {
      operations,
      tier: tier ?? 'auto',
    });

    // Call the existing distillPipeline
    const createdTasks = distillPipeline.distillBatch(sourceItemIds, operations as any, tier as any);

    const finishedAt = Date.now();

    return {
      success: true,
      startedAt,
      finishedAt,
      itemsProcessed: createdTasks.length,
      summary: `Created ${createdTasks.length} distillation tasks for ${sourceItemIds.length} inbox items`,
    };
  }

  /**
   * auto_export: Query distilled_outputs with review_status='accepted' that
   * have no export record, then call obsidianExporter.exportBatch().
   */
  private async executeAutoExport(task: ScheduledTask): Promise<TaskExecutionResult> {
    const startedAt = Date.now();

    // Get all accepted distilled outputs
    const acceptedOutputs = storage.getDistilledOutputs({ reviewStatus: 'accepted' });
    if (acceptedOutputs.length === 0) {
      return {
        success: true,
        startedAt,
        finishedAt: Date.now(),
        itemsProcessed: 0,
        summary: 'No accepted distilled outputs to export',
      };
    }

    // Get all existing export records to find which outputs have already been exported
    const existingRecords = storage.getExportRecords({});
    const exportedOutputIds = new Set(existingRecords.map((r) => r.distilledOutputId));

    // Filter to only outputs that haven't been exported yet
    const toExport = acceptedOutputs.filter((o) => !exportedOutputIds.has(o.id));

    if (toExport.length === 0) {
      return {
        success: true,
        startedAt,
        finishedAt: Date.now(),
        itemsProcessed: 0,
        summary: 'All accepted outputs have already been exported',
      };
    }

    const outputIds = toExport.map((o) => o.id);

    logger.info('export', MODULE, 'executeAutoExport', `Starting auto-export for ${outputIds.length} outputs`);

    // Call the existing export pipeline
    const records = obsidianExporter.exportBatch(outputIds);

    const succeeded = records.filter((r) => r.status === 'success').length;
    const failed = records.filter((r) => r.status === 'failed').length;

    const finishedAt = Date.now();

    return {
      success: failed === 0,
      startedAt,
      finishedAt,
      itemsProcessed: records.length,
      summary: `Exported ${succeeded} items successfully, ${failed} failed`,
    };
  }

  /**
   * cleanup: Delete source_items with status='discarded' older than 30 days.
   */
  private async executeCleanup(task: ScheduledTask): Promise<TaskExecutionResult> {
    const startedAt = Date.now();

    const config = task.config;
    const maxAgeDays = (config.maxAgeDays as number) ?? 30;

    const db = storage.db;
    if (!db) {
      throw new Error('Database not available');
    }

    // Calculate the cutoff timestamp (30 days ago in unix seconds)
    const cutoffSeconds = Math.floor(Date.now() / 1000) - maxAgeDays * 24 * 60 * 60;

    // Find discarded items older than the cutoff
    const rows = db
      .prepare(
        `SELECT id FROM source_items WHERE status = 'discarded' AND created_at < ?`,
      )
      .all(cutoffSeconds) as Array<{ id: string }>;

    if (rows.length === 0) {
      return {
        success: true,
        startedAt,
        finishedAt: Date.now(),
        itemsProcessed: 0,
        summary: `No discarded items older than ${maxAgeDays} days`,
      };
    }

    let deleted = 0;
    let errors = 0;

    for (const row of rows) {
      try {
        storage.deleteSourceItem(row.id);
        deleted++;
      } catch (error) {
        errors++;
        logger.error('error', MODULE, 'executeCleanup', `Failed to delete source item: ${row.id}`, {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const finishedAt = Date.now();

    return {
      success: errors === 0,
      startedAt,
      finishedAt,
      itemsProcessed: deleted,
      summary: `Deleted ${deleted} discarded items (${errors} errors)`,
    };
  }

  // -------------------------------------------------------------------------
  // Cron scheduling
  // -------------------------------------------------------------------------

  /**
   * Start a cron job for the given task.
   */
  private _scheduleTask(task: ScheduledTask): void {
    // Stop existing job if any
    this._unscheduleTask(task.id);

    const cronExpr = task.cronExpr;
    if (!cron.validate(cronExpr)) {
      logger.error('error', MODULE, '_scheduleTask', `Invalid cron expression, cannot schedule: ${cronExpr}`, {
        taskId: task.id,
      });
      return;
    }

    const job = cron.schedule(cronExpr, async () => {
      logger.info('app', MODULE, '_scheduleTask', `Cron triggered: ${task.name} (${task.id})`);

      const result = await this._executeTask(task);

      // Update task with result
      const updated: ScheduledTask = {
        ...task,
        lastRunAt: result.startedAt,
        nextRunAt: this.computeNextRun(task.cronExpr),
        nextRunAtEstimated: true,
        lastResult: result,
      };
      this.tasks.set(task.id, updated);
      this.persistTask(updated);

      this.broadcastChange('updated', updated);
    });

    this.cronJobs.set(task.id, job);

    // Update nextRunAt
    const nextRun = this.computeNextRun(cronExpr);
    const updated: ScheduledTask = { ...task, nextRunAt: nextRun, nextRunAtEstimated: nextRun !== null };
    this.tasks.set(task.id, updated);
    this.persistTask(updated);

    logger.info('app', MODULE, '_scheduleTask', `Scheduled task: ${task.name}`, {
      cronExpr,
      nextRunAt: nextRun ? new Date(nextRun).toISOString() : null,
    });
  }

  /**
   * Stop a cron job for the given task ID.
   */
  private _unscheduleTask(taskId: string): void {
    const job = this.cronJobs.get(taskId);
    if (job) {
      job.stop();
      this.cronJobs.delete(taskId);
    }
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  /**
   * Persist a task to the database (upsert).
   */
  private persistTask(task: ScheduledTask): void {
    const db = storage.db;
    if (!db) return;

    db.prepare(`
      INSERT INTO ${TABLE_NAME} (id, type, name, cron_expr, config, enabled, last_run_at, next_run_at, next_run_at_estimated, last_result, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        type = excluded.type,
        name = excluded.name,
        cron_expr = excluded.cron_expr,
        config = excluded.config,
        enabled = excluded.enabled,
        last_run_at = excluded.last_run_at,
        next_run_at = excluded.next_run_at,
        next_run_at_estimated = excluded.next_run_at_estimated,
        last_result = excluded.last_result
    `).run(
      task.id,
      task.type,
      task.name,
      task.cronExpr,
      JSON.stringify(task.config),
      task.enabled ? 1 : 0,
      task.lastRunAt,
      task.nextRunAt,
      task.nextRunAtEstimated ? 1 : 0,
      task.lastResult ? JSON.stringify(task.lastResult) : null,
      task.createdAt,
    );
  }

  /**
   * Convert a database row to a ScheduledTask object.
   */
  private rowToTask(row: Record<string, unknown>): ScheduledTask {
    return {
      id: row.id as string,
      type: row.type as ScheduledTaskType,
      name: row.name as string,
      cronExpr: row.cron_expr as string,
      config: JSON.parse(row.config as string),
      enabled: (row.enabled as number) === 1,
      lastRunAt: (row.last_run_at as number) ?? null,
      nextRunAt: (row.next_run_at as number) ?? null,
      nextRunAtEstimated: (row.next_run_at_estimated as number) === 1,
      lastResult: row.last_result ? JSON.parse(row.last_result as string) : null,
      createdAt: row.created_at as number,
    };
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /**
   * Compute the next run timestamp for a cron expression.
   * Returns null if the expression is invalid.
   */
  private computeNextRun(cronExpr: string): number | null {
    try {
      // Parse the cron expression to compute next run time
      // node-cron doesn't expose a direct "next" calculation, so we estimate
      // by checking if the expression is valid and returning a reasonable
      // approximation. For precise scheduling, the cron library handles it internally.
      if (!cron.validate(cronExpr)) {
        return null;
      }

      // Simple heuristic: parse the minute field to estimate next run
      const parts = cronExpr.split(/\s+/);
      if (parts.length < 5) return null;

      const now = new Date();
      const next = new Date(now);

      // If minute is a specific value, schedule to next occurrence
      const minutePart = parts[0];
      if (minutePart !== '*') {
        const minutes = minutePart.split(',').map((m) => parseInt(m, 10));
        const currentMinute = now.getMinutes();

        // Find next matching minute
        let nextMinute = minutes.find((m) => m > currentMinute);
        if (nextMinute === undefined) {
          nextMinute = minutes[0];
          next.setHours(next.getHours() + 1);
        }
        next.setMinutes(nextMinute, 0, 0);
      } else {
        // Runs every minute, next run is in ~1 minute
        next.setMinutes(next.getMinutes() + 1, 0, 0);
      }

      return next.getTime();
    } catch {
      return null;
    }
  }

  /**
   * Broadcast a scheduler task change to all renderer windows.
   */
  private broadcastChange(action: 'created' | 'updated' | 'deleted', task: ScheduledTask): void {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send('scheduler:task-changed', { action, task });
      }
    }
  }

  /**
   * Ensure the service has been initialized before use.
   */
  private ensureInitialized(): void {
    if (!this.initialized) {
      throw new Error('SchedulerService has not been initialized. Call init() first.');
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const schedulerService = new SchedulerService();
