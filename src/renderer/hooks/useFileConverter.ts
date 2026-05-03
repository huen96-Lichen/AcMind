/**
 * useFileConverter — 文件转换模块数据 Hook
 *
 * 管理文件转 Markdown 的转换操作、任务列表、预览。
 */

import { useState, useEffect, useCallback } from 'react';
import type { ProcessJob, SourceItem } from '../../shared/types';

interface ConvertResult {
  success: boolean;
  jobId: string;
  markdown?: string;
  title?: string;
  error?: string;
  engine?: string;
}

interface UseFileConverterResult {
  jobs: ProcessJob[];
  loading: boolean;
  error: string | null;
  // 转换操作
  convert: (filePath: string) => Promise<ConvertResult>;
  preview: (filePath: string) => Promise<{ success: boolean; markdown?: string; title?: string; error?: string; engine?: string }>;
  saveToInbox: (jobId: string, markdown: string, title?: string, filePath?: string) => Promise<SourceItem | null>;
  // 刷新
  refresh: () => Promise<void>;
}

export function useFileConverter(): UseFileConverterResult {
  const [jobs, setJobs] = useState<ProcessJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await window.acmind.fileConverter.listJobs(50);
      if (result.success) {
        setJobs(result.jobs ?? []);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // 初始加载
  useEffect(() => {
    void refresh();
  }, [refresh]);

  // 监听任务变化事件
  useEffect(() => {
    const unsub = window.acmind.fileConverter.onJobsChanged(() => {
      void refresh();
    });
    return unsub;
  }, [refresh]);

  const convert = useCallback(async (filePath: string): Promise<ConvertResult> => {
    try {
      const result = await window.acmind.fileConverter.convert(filePath);
      await refresh();
      return result;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
      return { success: false, jobId: '', error: msg };
    }
  }, [refresh]);

  const preview = useCallback(async (filePath: string) => {
    try {
      return await window.acmind.fileConverter.preview(filePath);
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  }, []);

  const saveToInbox = useCallback(async (jobId: string, markdown: string, title?: string, filePath?: string): Promise<SourceItem | null> => {
    try {
      const result = await window.acmind.fileConverter.saveToInbox(jobId, markdown, title, filePath);
      if (result.success && result.sourceItem) {
        await refresh();
        return result.sourceItem;
      }
      return null;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return null;
    }
  }, [refresh]);

  return {
    jobs,
    loading,
    error,
    convert,
    preview,
    saveToInbox,
    refresh,
  };
}
