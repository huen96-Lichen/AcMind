export type ScheduledTaskType = 'auto_distill' | 'auto_export' | 'cleanup';

export interface ScheduledTask {
  id: string;
  type: ScheduledTaskType;
  name: string;
  cronExpr: string;        // e.g. '0 */2 * * *' = every 2 hours
  config: Record<string, unknown>;  // task-specific config
  enabled: boolean;
  lastRunAt: number | null;
  nextRunAt: number | null;
  /** nextRunAt is a heuristic estimate, not a precise cron calculation */
  nextRunAtEstimated: boolean;
  lastResult: TaskExecutionResult | null;
  createdAt: number;
}

export interface TaskExecutionResult {
  success: boolean;
  startedAt: number;
  finishedAt: number;
  itemsProcessed: number;
  error?: string;
  summary?: string;
}

export interface CreateTaskParams {
  type: ScheduledTaskType;
  name: string;
  cronExpr: string;
  config: Record<string, unknown>;
  enabled?: boolean;
}
