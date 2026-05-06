import { useCallback, useEffect, useRef, useState } from 'react';
import type { AgentTask, AgentTaskEvent } from '../../shared/types';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface UseAgentTasksResult {
  tasks: AgentTask[];
  loading: boolean;
  error: string | null;
  loadTasks: () => Promise<void>;
  createTask: (params: { sessionId: string; name: string; skillName?: string; inputParams?: Record<string, unknown> }) => Promise<AgentTask | null>;
  updateTask: (id: string, updates: Partial<AgentTask>) => Promise<void>;
  deleteTask: (id: string) => Promise<void>;
  runNow: (id: string) => Promise<void>;
  cancelTask: (id: string) => Promise<void>;
  getHistory: (taskId: string) => Promise<AgentTaskEvent[]>;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

export function useAgentTasks(): UseAgentTasksResult {
  const [tasks, setTasks] = useState<AgentTask[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadTasks = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await window.acmind.agentTasks.list();
      if (result.success) {
        setTasks(result.tasks);
      } else {
        setError('加载任务列表失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载任务列表失败');
    } finally {
      setLoading(false);
    }
  }, []);

  const createTask = useCallback(async (params: { sessionId: string; name: string; skillName?: string; inputParams?: Record<string, unknown> }): Promise<AgentTask | null> => {
    try {
      const result = await window.acmind.agentTasks.create(params);
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

  const updateTask = useCallback(async (id: string, updates: Partial<AgentTask>): Promise<void> => {
    try {
      const result = await window.acmind.agentTasks.update(id, updates);
      if (result.success && result.task) {
        setTasks(prev => prev.map(t => t.id === id ? result.task! : t));
      } else {
        setError(result.error ?? '更新任务失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新任务失败');
    }
  }, []);

  const deleteTask = useCallback(async (id: string): Promise<void> => {
    try {
      const result = await window.acmind.agentTasks.delete(id);
      if (result.success) {
        setTasks(prev => prev.filter(t => t.id !== id));
      } else {
        setError('删除任务失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除任务失败');
    }
  }, []);

  const runNow = useCallback(async (id: string): Promise<void> => {
    try {
      const result = await window.acmind.agentTasks.runNow(id);
      if (result.success && result.task) {
        setTasks(prev => prev.map(t => t.id === id ? result.task! : t));
      } else {
        setError(result.error ?? '执行任务失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '执行任务失败');
    }
  }, []);

  const cancelTask = useCallback(async (id: string): Promise<void> => {
    try {
      await window.acmind.agentTasks.cancel(id);
    } catch (err) {
      setError(err instanceof Error ? err.message : '取消任务失败');
    }
  }, []);

  const getHistory = useCallback(async (taskId: string): Promise<AgentTaskEvent[]> => {
    try {
      const result = await window.acmind.agentTasks.history(taskId);
      return result.success ? result.events : [];
    } catch {
      return [];
    }
  }, []);

  // Listen for real-time task changes
  const unsubscribeRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    loadTasks();

    unsubscribeRef.current = window.acmind.agentTasks.onTaskChanged((data) => {
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
  }, [loadTasks]);

  return {
    tasks,
    loading,
    error,
    loadTasks,
    createTask,
    updateTask,
    deleteTask,
    runNow,
    cancelTask,
    getHistory,
  };
}
