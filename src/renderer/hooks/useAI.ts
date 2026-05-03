/**
 * useAI — AI Runtime 数据 Hook
 *
 * 管理 AI Action CRUD、执行、Job 监控。
 */

import { useState, useEffect, useCallback } from 'react';
import type { AIAction, AIActionType, AiTask, SourceType, ProcessedContent } from '../../shared/types';

interface RunResult {
  success: boolean;
  taskId?: string;
  content?: ProcessedContent;
  rawText?: string;
  modelCall?: { providerId: string; modelId: string; latencyMs: number; promptTokens?: number; completionTokens?: number };
  routingReason?: string;
  qualityScore?: number;
  usedFallback?: boolean;
  error?: string;
}

interface UseAIResult {
  actions: AIAction[];
  jobs: AiTask[];
  loading: boolean;
  error: string | null;
  // Action CRUD
  createAction: (params: { name: string; inputTypes: SourceType[]; actionType: AIActionType; promptProfileId?: string }) => Promise<AIAction | null>;
  updateAction: (id: string, updates: Partial<AIAction>) => Promise<boolean>;
  deleteAction: (id: string) => Promise<boolean>;
  // Action 执行
  runAction: (actionId: string, input: string, sourceType?: SourceType) => Promise<RunResult>;
  // Job 管理
  cancelJob: (id: string) => Promise<boolean>;
  // Provider 健康检查
  healthCheck: (providerId: string) => Promise<{ ok: boolean; latencyMs?: number; error?: string }>;
  // 刷新
  refresh: () => Promise<void>;
}

export function useAI(): UseAIResult {
  const [actions, setActions] = useState<AIAction[]>([]);
  const [jobs, setJobs] = useState<AiTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const [actionsResult, jobsResult] = await Promise.all([
        window.acmind.aiRuntime.listActions(),
        window.acmind.aiRuntime.listJobs(50),
      ]);
      if (actionsResult.success) setActions(actionsResult.actions ?? []);
      if (jobsResult.success) setJobs(jobsResult.jobs ?? []);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void refresh(); }, [refresh]);

  // 监听 Job 变化事件
  useEffect(() => {
    const unsub = window.acmind.aiRuntime.onJobChanged(() => { void refresh(); });
    return unsub;
  }, [refresh]);

  const createAction = useCallback(async (params: { name: string; inputTypes: SourceType[]; actionType: AIActionType; promptProfileId?: string }): Promise<AIAction | null> => {
    try {
      const result = await window.acmind.aiRuntime.createAction(params);
      if (result.success) {
        await refresh();
        return result.action;
      }
      return null;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return null;
    }
  }, [refresh]);

  const updateAction = useCallback(async (id: string, updates: Partial<AIAction>): Promise<boolean> => {
    try {
      const result = await window.acmind.aiRuntime.updateAction(id, updates);
      if (result.success) await refresh();
      return result.success;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return false;
    }
  }, [refresh]);

  const deleteAction = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.aiRuntime.deleteAction(id);
      if (result.success) await refresh();
      return result.success;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return false;
    }
  }, [refresh]);

  const runAction = useCallback(async (actionId: string, input: string, sourceType?: SourceType): Promise<RunResult> => {
    try {
      const result = await window.acmind.aiRuntime.runAction(actionId, input, sourceType);
      await refresh();
      return result;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
      return { success: false, error: msg };
    }
  }, [refresh]);

  const cancelJob = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.aiRuntime.cancelJob(id);
      if (result.success) await refresh();
      return result.success;
    } catch {
      return false;
    }
  }, [refresh]);

  const healthCheck = useCallback(async (providerId: string) => {
    try {
      const result = await window.acmind.aiRuntime.healthCheck(providerId);
      return { ok: result.ok ?? false, latencyMs: result.latencyMs, error: result.error };
    } catch (err) {
      return { ok: false, error: err instanceof Error ? err.message : String(err) };
    }
  }, []);

  return {
    actions,
    jobs,
    loading,
    error,
    createAction,
    updateAction,
    deleteAction,
    runAction,
    cancelJob,
    healthCheck,
    refresh,
  };
}
