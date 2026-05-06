import { useCallback, useEffect, useRef, useState } from 'react';

// ---------------------------------------------------------------------------
// Types (inline to avoid circular deps with shared/types)
// ---------------------------------------------------------------------------

export interface ScheduledTask {
  id: string;
  type: 'auto_distill' | 'auto_export' | 'cleanup';
  name: string;
  cronExpr: string;
  config: Record<string, unknown>;
  enabled: boolean;
  lastRunAt: number | null;
  nextRunAt: number | null;
  nextRunAtEstimated: boolean;
  lastResult: {
    success: boolean;
    startedAt: number;
    finishedAt: number;
    itemsProcessed: number;
    error?: string;
    summary?: string;
  } | null;
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

export interface ScheduledAgentTask {
  id: string;
  name: string;
  cronExpression: string;
  skillName: string;
  inputParams: Record<string, unknown>;
  enabled: boolean;
  lastRunAt: number | null;
  lastRunStatus: 'success' | 'error' | 'timeout' | null;
  lastRunTaskId: string | null;
  createdAt: number;
  updatedAt: number;
}

// ---------------------------------------------------------------------------
// Scheduler API accessor
// ---------------------------------------------------------------------------

const scheduler = (window as unknown as { acmind: { scheduler: {
  getTasks(): Promise<ScheduledTask[]>;
  getTask(id: string): Promise<ScheduledTask | null>;
  createTask(params: Record<string, unknown>): Promise<ScheduledTask>;
  updateTask(id: string, updates: Record<string, unknown>): Promise<ScheduledTask>;
  deleteTask(id: string): Promise<void>;
  toggleTask(id: string, enabled: boolean): Promise<ScheduledTask>;
  runNow(id: string): Promise<TaskExecutionResult>;
} } }).acmind.scheduler;

const scheduledAgentTasks = (window as unknown as { acmind: { scheduledAgentTasks: {
  list(): Promise<{ success: boolean; tasks: ScheduledAgentTask[] }>;
  get(id: string): Promise<{ success: boolean; task: ScheduledAgentTask | null }>;
  create(params: { name: string; cronExpression: string; skillName: string; inputParams?: Record<string, unknown>; enabled?: boolean }): Promise<{ success: boolean; task?: ScheduledAgentTask; error?: string }>;
  update(id: string, updates: Partial<ScheduledAgentTask>): Promise<{ success: boolean; task?: ScheduledAgentTask; error?: string }>;
  delete(id: string): Promise<{ success: boolean }>;
  runNow(id: string): Promise<{ success: boolean; error?: string }>;
  onTaskChanged(callback: (data: { action: string; task: ScheduledAgentTask }) => void): () => void;
} } }).acmind.scheduledAgentTasks;

// ---------------------------------------------------------------------------
// useScheduler — system scheduled tasks
// ---------------------------------------------------------------------------

export interface UseSchedulerResult {
  tasks: ScheduledTask[];
  loading: boolean;
  error: string | null;
  reload: () => Promise<void>;
  createTask: (params: { name: string; type: ScheduledTask['type']; cronExpr: string; enabled?: boolean; config?: Record<string, unknown> }) => Promise<ScheduledTask | null>;
  updateTask: (id: string, updates: Record<string, unknown>) => Promise<ScheduledTask | null>;
  deleteTask: (id: string) => Promise<boolean>;
  toggleTask: (id: string, enabled: boolean) => Promise<ScheduledTask | null>;
  runNow: (id: string) => Promise<TaskExecutionResult | null>;
}

export function useScheduler(): UseSchedulerResult {
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await scheduler.getTasks();
      setTasks(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载系统任务失败');
    } finally {
      setLoading(false);
    }
  }, []);

  const createTask = useCallback(async (params: { name: string; type: ScheduledTask['type']; cronExpr: string; enabled?: boolean; config?: Record<string, unknown> }): Promise<ScheduledTask | null> => {
    try {
      const created = await scheduler.createTask(params);
      setTasks(prev => [...prev, created]);
      return created;
    } catch (err) {
      setError(err instanceof Error ? err.message : '创建任务失败');
      return null;
    }
  }, []);

  const updateTask = useCallback(async (id: string, updates: Record<string, unknown>): Promise<ScheduledTask | null> => {
    try {
      const updated = await scheduler.updateTask(id, updates);
      setTasks(prev => prev.map(t => t.id === id ? updated : t));
      return updated;
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新任务失败');
      return null;
    }
  }, []);

  const deleteTask = useCallback(async (id: string): Promise<boolean> => {
    try {
      await scheduler.deleteTask(id);
      setTasks(prev => prev.filter(t => t.id !== id));
      return true;
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除任务失败');
      return false;
    }
  }, []);

  const toggleTask = useCallback(async (id: string, enabled: boolean): Promise<ScheduledTask | null> => {
    try {
      const updated = await scheduler.toggleTask(id, enabled);
      setTasks(prev => prev.map(t => t.id === id ? updated : t));
      return updated;
    } catch (err) {
      setError(err instanceof Error ? err.message : '切换任务状态失败');
      return null;
    }
  }, []);

  const runNow = useCallback(async (id: string): Promise<TaskExecutionResult | null> => {
    try {
      const result = await scheduler.runNow(id);
      // Refresh to update lastRunAt / lastResult
      reload();
      return result;
    } catch (err) {
      setError(err instanceof Error ? err.message : '执行任务失败');
      return null;
    }
  }, [reload]);

  useEffect(() => {
    reload();
  }, [reload]);

  return { tasks, loading, error, reload, createTask, updateTask, deleteTask, toggleTask, runNow };
}

// ---------------------------------------------------------------------------
// useScheduledAgentTasks — agent scheduled tasks
// ---------------------------------------------------------------------------

export interface UseScheduledAgentTasksResult {
  tasks: ScheduledAgentTask[];
  loading: boolean;
  error: string | null;
  reload: () => Promise<void>;
  createTask: (params: { name: string; cronExpression: string; skillName: string; inputParams?: Record<string, unknown>; enabled?: boolean }) => Promise<ScheduledAgentTask | null>;
  updateTask: (id: string, updates: Partial<ScheduledAgentTask>) => Promise<ScheduledAgentTask | null>;
  deleteTask: (id: string) => Promise<boolean>;
  runNow: (id: string) => Promise<boolean>;
}

export function useScheduledAgentTasks(): UseScheduledAgentTasksResult {
  const [tasks, setTasks] = useState<ScheduledAgentTask[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const unsubscribeRef = useRef<(() => void) | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await scheduledAgentTasks.list();
      if (result.success) {
        setTasks(result.tasks);
      } else {
        setError('加载 Agent 定时任务失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载 Agent 定时任务失败');
    } finally {
      setLoading(false);
    }
  }, []);

  const createTask = useCallback(async (params: { name: string; cronExpression: string; skillName: string; inputParams?: Record<string, unknown>; enabled?: boolean }): Promise<ScheduledAgentTask | null> => {
    try {
      const result = await scheduledAgentTasks.create(params);
      if (result.success && result.task) {
        setTasks(prev => [result.task!, ...prev]);
        return result.task;
      }
      setError(result.error ?? '创建任务失败');
      return null;
    } catch (err) {
      setError(err instanceof Error ? err.message : '创建任务失败');
      return null;
    }
  }, []);

  const updateTask = useCallback(async (id: string, updates: Partial<ScheduledAgentTask>): Promise<ScheduledAgentTask | null> => {
    try {
      const result = await scheduledAgentTasks.update(id, updates);
      if (result.success && result.task) {
        setTasks(prev => prev.map(t => t.id === id ? result.task! : t));
        return result.task;
      }
      setError(result.error ?? '更新任务失败');
      return null;
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新任务失败');
      return null;
    }
  }, []);

  const deleteTask = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await scheduledAgentTasks.delete(id);
      if (result.success) {
        setTasks(prev => prev.filter(t => t.id !== id));
        return true;
      }
      setError('删除任务失败');
      return false;
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除任务失败');
      return false;
    }
  }, []);

  const runNow = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await scheduledAgentTasks.runNow(id);
      if (result.success) {
        reload();
        return true;
      }
      setError(result.error ?? '执行任务失败');
      return false;
    } catch (err) {
      setError(err instanceof Error ? err.message : '执行任务失败');
      return false;
    }
  }, [reload]);

  useEffect(() => {
    reload();

    unsubscribeRef.current = scheduledAgentTasks.onTaskChanged((data) => {
      setTasks(prev => {
        const idx = prev.findIndex(t => t.id === data.task.id);
        if (idx >= 0) {
          const next = [...prev];
          next[idx] = data.task;
          return next;
        }
        return [data.task, ...prev];
      });
    });

    return () => {
      unsubscribeRef.current?.();
    };
  }, [reload]);

  return { tasks, loading, error, reload, createTask, updateTask, deleteTask, runNow };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

export function cronToReadable(cron: string): string {
  const map: Record<string, string> = {
    '0 */2 * * *': '每2小时',
    '0 0 * * *': '每天午夜',
    '0 8 * * *': '每天早上8点',
    '0 20 * * *': '每天晚上8点',
    '0 0 * * 0': '每周日午夜',
    '0 0 1 * *': '每月1号',
    '0 7 * * *': '每天早上7点',
    '0 9 * * *': '每天早上9点',
    '0 12 * * *': '每天中午12点',
    '0 18 * * *': '每天下午6点',
    '0 22 * * *': '每天晚上10点',
    '0 0 * * 1': '每周一午夜',
    '0 0 * * 5': '每周五午夜',
    '30 8 * * 1': '每周一早上8:30',
  };
  return map[cron] || cron;
}

export function taskTypeLabel(type: string): string {
  const map: Record<string, string> = {
    auto_distill: '自动整理',
    auto_export: '自动导出',
    cleanup: '自动清理',
  };
  return map[type] || type;
}

export function taskTypeBadgeTone(type: string): 'info' | 'success' | 'warning' {
  const map: Record<string, 'info' | 'success' | 'warning'> = {
    auto_distill: 'info',
    auto_export: 'success',
    cleanup: 'warning',
  };
  return map[type] || 'info';
}

export function relativeTime(ts: number | null): string {
  if (ts === null) return '—';
  const diff = Date.now() - ts;
  const absDiff = Math.abs(diff);
  const future = diff < 0;
  const minutes = Math.floor(absDiff / 60000);
  const hours = Math.floor(absDiff / 3600000);
  const days = Math.floor(absDiff / 86400000);
  let text: string;
  if (minutes < 1) text = '刚刚';
  else if (minutes < 60) text = `${minutes}分钟`;
  else if (hours < 24) text = `${hours}小时`;
  else text = `${days}天`;
  return future ? `${text}后` : `${text}前`;
}

export function formatTime(ts: number | null): string {
  if (ts === null) return '—';
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

export function runStatusLabel(status: 'success' | 'error' | 'timeout' | null): string {
  if (!status) return '未执行';
  const map: Record<string, string> = {
    success: '成功',
    error: '失败',
    timeout: '超时',
  };
  return map[status] || status;
}

export function runStatusTone(status: 'success' | 'error' | 'timeout' | null): 'success' | 'danger' | 'warning' | 'disabled' {
  if (!status) return 'disabled';
  const map: Record<string, 'success' | 'danger' | 'warning'> = {
    success: 'success',
    error: 'danger',
    timeout: 'warning',
  };
  return map[status] || 'disabled';
}
