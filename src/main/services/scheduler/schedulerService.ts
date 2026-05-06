// AcMind Scheduler Service
// Provides scheduled task automation for distillation, export, and cleanup.
// Calls existing pipelines (distillPipeline, obsidianExporter) without modifying them.

import { randomUUID } from 'node:crypto';
import cron from 'node-cron';
import { CronExpressionParser } from 'cron-parser';
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
import type { ScheduledAgentTask } from '../../../shared/types';
import { SCHEDULED_AGENT_TASKS_IPC_CHANNELS } from '../../../shared/types';

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

  // Phase D: Scheduled Agent Tasks
  private agentTasks: Map<string, ScheduledAgentTask> = new Map();
  private agentCronJobs: Map<string, { stop: () => void }> = new Map();

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

    // Phase D: Load and start scheduled agent tasks
    const agentTaskList = storage.listScheduledAgentTasks();
    for (const task of agentTaskList) {
      this.agentTasks.set(task.id, task);
      if (task.enabled) {
        this._scheduleAgentTask(task);
      }
    }

    this.initialized = true;
    logger.info('app', MODULE, 'init', `Scheduler initialized with ${this.tasks.size} tasks, ${agentTaskList.length} agent tasks`, {
      enabledCount: [...this.tasks.values()].filter((t) => t.enabled).length,
      enabledAgentCount: agentTaskList.filter((t) => t.enabled).length,
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

    const id = randomUUID();
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
   * Uses cron-parser for accurate next-run calculation.
   */
  private computeNextRun(cronExpr: string): number | null {
    try {
      // Validate with node-cron first
      if (!cron.validate(cronExpr)) {
        return null;
      }

      // Use cron-parser for accurate next-run calculation
      const expression = CronExpressionParser.parse(cronExpr, {
        currentDate: new Date(),
      });

      const nextDate = expression.next().toDate();
      return nextDate.getTime();
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

  // -------------------------------------------------------------------------
  // Phase D: Scheduled Agent Tasks
  // -------------------------------------------------------------------------

  /**
   * Create a new scheduled agent task.
   */
  createScheduledAgentTask(params: {
    name: string;
    cronExpression: string;
    skillName: string;
    inputParams?: Record<string, unknown>;
    enabled?: boolean;
  }): ScheduledAgentTask {
    this.ensureInitialized();

    // Validate cron expression
    if (!cron.validate(params.cronExpression)) {
      throw new Error(`Invalid cron expression: ${params.cronExpression}`);
    }

    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);

    const task: ScheduledAgentTask = {
      id,
      name: params.name,
      cronExpression: params.cronExpression,
      skillName: params.skillName,
      inputParams: params.inputParams ?? {},
      enabled: params.enabled ?? true,
      lastRunAt: null,
      lastRunStatus: null,
      lastRunTaskId: null,
      createdAt: now,
      updatedAt: now,
    };

    storage.insertScheduledAgentTask(task);
    this.agentTasks.set(id, task);

    if (task.enabled) {
      this._scheduleAgentTask(task);
    }

    logger.info('app', MODULE, 'createScheduledAgentTask', `Scheduled agent task created: ${task.name} (${id})`, {
      skillName: task.skillName,
      cronExpression: task.cronExpression,
    });

    this.broadcastAgentTaskChange('created', task);

    return task;
  }

  /**
   * Update a scheduled agent task.
   */
  updateScheduledAgentTask(id: string, updates: Partial<Pick<ScheduledAgentTask, 'name' | 'cronExpression' | 'skillName' | 'inputParams' | 'enabled'>>): ScheduledAgentTask {
    this.ensureInitialized();

    const existing = this.agentTasks.get(id);
    if (!existing) {
      throw new Error(`Scheduled agent task not found: ${id}`);
    }

    // Validate cron expression if changing
    if (updates.cronExpression && !cron.validate(updates.cronExpression)) {
      throw new Error(`Invalid cron expression: ${updates.cronExpression}`);
    }

    // Reschedule if needed
    const needsReschedule = existing.enabled && (updates.cronExpression || updates.enabled === true);
    if (needsReschedule) {
      this._unscheduleAgentTask(id);
    }

    const updated: ScheduledAgentTask = {
      ...existing,
      ...updates,
      updatedAt: Math.floor(Date.now() / 1000),
    };

    storage.updateScheduledAgentTask(id, updated);
    this.agentTasks.set(id, updated);

    if (needsReschedule && updated.enabled) {
      this._scheduleAgentTask(updated);
    }

    logger.info('app', MODULE, 'updateScheduledAgentTask', `Scheduled agent task updated: ${updated.name} (${id})`);

    this.broadcastAgentTaskChange('updated', updated);

    return updated;
  }

  /**
   * Delete a scheduled agent task.
   */
  deleteScheduledAgentTask(id: string): void {
    this.ensureInitialized();

    const task = this.agentTasks.get(id);
    if (!task) {
      throw new Error(`Scheduled agent task not found: ${id}`);
    }

    this._unscheduleAgentTask(id);
    this.agentTasks.delete(id);
    storage.deleteScheduledAgentTask(id);

    logger.info('app', MODULE, 'deleteScheduledAgentTask', `Scheduled agent task deleted: ${task.name} (${id})`);

    this.broadcastAgentTaskChange('deleted', task);
  }

  /**
   * Get a scheduled agent task by ID.
   */
  getScheduledAgentTask(id: string): ScheduledAgentTask | null {
    return this.agentTasks.get(id) ?? null;
  }

  /**
   * List all scheduled agent tasks.
   */
  listScheduledAgentTasks(): ScheduledAgentTask[] {
    return [...this.agentTasks.values()];
  }

  /**
   * Manually run a scheduled agent task now.
   */
  async runScheduledAgentTaskNow(id: string): Promise<void> {
    this.ensureInitialized();

    const task = this.agentTasks.get(id);
    if (!task) {
      throw new Error(`Scheduled agent task not found: ${id}`);
    }

    logger.info('app', MODULE, 'runScheduledAgentTaskNow', `Manually running scheduled agent task: ${task.name} (${id})`);

    await this._executeAgentTask(task);
  }

  /**
   * Schedule an agent task with cron.
   */
  private _scheduleAgentTask(task: ScheduledAgentTask): void {
    this._unscheduleAgentTask(task.id);

    if (!cron.validate(task.cronExpression)) {
      logger.error('error', MODULE, '_scheduleAgentTask', `Invalid cron expression: ${task.cronExpression}`, {
        taskId: task.id,
      });
      return;
    }

    const job = cron.schedule(task.cronExpression, async () => {
      logger.info('app', MODULE, '_scheduleAgentTask', `Cron triggered for agent task: ${task.name} (${task.id})`);
      await this._executeAgentTask(task);
    });

    this.agentCronJobs.set(task.id, job);

    logger.info('app', MODULE, '_scheduleAgentTask', `Scheduled agent task: ${task.name}`, {
      cronExpression: task.cronExpression,
    });
  }

  /**
   * Unschedule an agent task.
   */
  private _unscheduleAgentTask(taskId: string): void {
    const job = this.agentCronJobs.get(taskId);
    if (job) {
      job.stop();
      this.agentCronJobs.delete(taskId);
    }
  }

  /**
   * Execute a scheduled agent task.
   */
  private async _executeAgentTask(task: ScheduledAgentTask): Promise<void> {
    const { agentTaskService } = await import('../chat/agentTaskService');

    try {
      const agentTask = agentTaskService.createTask({
        sessionId: `__scheduled_${task.id}__`,
        name: task.name,
        skillName: task.skillName,
        inputParams: task.inputParams,
      });

      await agentTaskService.runTask(agentTask.id);

      const completedTask = agentTaskService.getTask(agentTask.id);
      const status = completedTask?.status === 'completed' ? 'success' : 'error';

      const updated: ScheduledAgentTask = {
        ...task,
        lastRunAt: Math.floor(Date.now() / 1000),
        lastRunStatus: status,
        lastRunTaskId: agentTask.id,
        updatedAt: Math.floor(Date.now() / 1000),
      };

      storage.updateScheduledAgentTask(task.id, updated);
      this.agentTasks.set(task.id, updated);
      this.broadcastAgentTaskChange('updated', updated);

      logger.info('app', MODULE, '_executeAgentTask', `Agent task executed: ${task.name}`, {
        status,
        taskId: agentTask.id,
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);

      const updated: ScheduledAgentTask = {
        ...task,
        lastRunAt: Math.floor(Date.now() / 1000),
        lastRunStatus: 'error',
        lastRunTaskId: null,
        updatedAt: Math.floor(Date.now() / 1000),
      };

      storage.updateScheduledAgentTask(task.id, updated);
      this.agentTasks.set(task.id, updated);
      this.broadcastAgentTaskChange('updated', updated);

      logger.error('error', MODULE, '_executeAgentTask', `Agent task execution failed: ${task.name}`, {
        error: errorMsg,
      });
    }
  }

  /**
   * Broadcast a scheduled agent task change to all renderer windows.
   */
  private broadcastAgentTaskChange(action: 'created' | 'updated' | 'deleted', task: ScheduledAgentTask): void {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.TASK_CHANGED, { action, task });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const schedulerService = new SchedulerService();
