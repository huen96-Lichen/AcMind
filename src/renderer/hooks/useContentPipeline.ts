import { useCallback, useState } from 'react';

// ─── Types ───────────────────────────────────────────────────────────────────

export type PipelineStage =
  | 'captured'
  | 'processing'
  | 'structured'
  | 'exporting'
  | 'exported'
  | 'capture_failed'
  | 'process_failed'
  | 'export_failed'
  | 'conflict_pending'
  | 'permission_required';

export interface PipelineResult {
  success: boolean;
  sourceItemId: string;
  stage: PipelineStage;
  outputPath?: string;
  relativePath?: string;
  exportRecord?: {
    id: string;
    sourceItemId: string;
    vaultPath: string;
    relativeFilePath: string;
    status: string;
  };
  error?: string;
}

export interface PipelineOptions {
  skipExport?: boolean;
  vaultPath?: string;
  defaultFolder?: string;
  source?: 'manual' | 'clipboard' | 'webpage' | 'file';
  project?: string;
}

interface UseContentPipelineReturn {
  /** Current processing state */
  processing: boolean;
  /** Current pipeline stage */
  stage: PipelineStage;
  /** Last pipeline result */
  lastResult: PipelineResult | null;
  /** Error message if any */
  error: string | null;
  /** Process text through the full pipeline */
  processText: (text: string, options?: PipelineOptions) => Promise<PipelineResult>;
  /** Retry a failed export for a source item */
  retryExport: (sourceItemId: string) => Promise<PipelineResult>;
  /** Get pipeline status for a source item */
  getStatus: (sourceItemId: string) => Promise<PipelineStage>;
  /** Reset state */
  reset: () => void;
}

// ─── Stage labels (Chinese) ─────────────────────────────────────────────────

export const PIPELINE_STAGE_LABELS: Record<PipelineStage, string> = {
  captured: '已收集',
  processing: '正在整理...',
  structured: '已整理',
  exporting: '正在写入 Obsidian...',
  exported: '已进入 Obsidian',
  capture_failed: '收集失败',
  process_failed: '整理失败',
  export_failed: '导出失败',
  conflict_pending: '文件冲突',
  permission_required: '需要权限',
};

export const PIPELINE_STAGE_COLORS: Record<PipelineStage, string> = {
  captured: '#6B7280',
  processing: '#3B82F6',
  structured: '#8B5CF6',
  exporting: '#F59E0B',
  exported: '#10B981',
  capture_failed: '#EF4444',
  process_failed: '#EF4444',
  export_failed: '#EF4444',
  conflict_pending: '#F59E0B',
  permission_required: '#F59E0B',
};

// ─── Hook ────────────────────────────────────────────────────────────────────

/**
 * Custom hook for the V2.1 Content Pipeline.
 * Provides a simple interface to process text through the full pipeline.
 */
export function useContentPipeline(): UseContentPipelineReturn {
  const [processing, setProcessing] = useState(false);
  const [stage, setStage] = useState<PipelineStage>('captured');
  const [lastResult, setLastResult] = useState<PipelineResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const processText = useCallback(async (
    text: string,
    options?: PipelineOptions,
  ): Promise<PipelineResult> => {
    if (!window.pinmind?.pipeline) {
      const result: PipelineResult = {
        success: false,
        sourceItemId: '',
        stage: 'capture_failed',
        error: 'Pipeline API not available',
      };
      setLastResult(result);
      setError(result.error!);
      return result;
    }

    setProcessing(true);
    setError(null);
    setStage('processing');

    try {
      const result = await window.pinmind.pipeline.processText(text, options as Record<string, unknown>);
      setStage(result.stage);
      setLastResult(result);

      if (!result.success) {
        setError(result.error ?? 'Unknown error');
      }

      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      const result: PipelineResult = {
        success: false,
        sourceItemId: '',
        stage: 'process_failed',
        error: errorMsg,
      };
      setStage(result.stage);
      setLastResult(result);
      setError(errorMsg);
      return result;
    } finally {
      setProcessing(false);
    }
  }, []);

  const getStatus = useCallback(async (sourceItemId: string): Promise<PipelineStage> => {
    if (!window.pinmind?.pipeline) return 'capture_failed';
    try {
      return await window.pinmind.pipeline.getStatus(sourceItemId);
    } catch {
      return 'capture_failed';
    }
  }, []);

  const retryExport = useCallback(async (sourceItemId: string): Promise<PipelineResult> => {
    if (!window.pinmind?.pipeline) {
      const result: PipelineResult = {
        success: false,
        sourceItemId,
        stage: 'export_failed',
        error: 'Pipeline API not available',
      };
      setLastResult(result);
      setError(result.error!);
      return result;
    }

    setProcessing(true);
    setError(null);
    setStage('exporting');

    try {
      const result = await window.pinmind.pipeline.retryExport(sourceItemId);
      setStage(result.stage);
      setLastResult(result);

      if (!result.success) {
        setError(result.error ?? 'Unknown error');
      }

      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      const result: PipelineResult = {
        success: false,
        sourceItemId,
        stage: 'export_failed',
        error: errorMsg,
      };
      setStage(result.stage);
      setLastResult(result);
      setError(errorMsg);
      return result;
    } finally {
      setProcessing(false);
    }
  }, []);

  const reset = useCallback(() => {
    setProcessing(false);
    setStage('captured');
    setLastResult(null);
    setError(null);
  }, []);

  return {
    processing,
    stage,
    lastResult,
    error,
    processText,
    retryExport,
    getStatus,
    reset,
  };
}
