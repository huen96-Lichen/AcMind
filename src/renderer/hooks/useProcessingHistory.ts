import { useCallback, useEffect, useMemo, useState } from 'react';
import type { SourceItem, ExportRecord, ErrorRecord } from '../../shared/types';

// ---------------------------------------------------------------------------
// ProcessingHistoryItem — unified view of a content item's lifecycle
// ---------------------------------------------------------------------------

export interface ModelCallInfo {
  model_tier: string;
  provider: string;
  model_name: string;
  prompt_profile_id: string;
  prompt_profile_version: string;
  created_at: number;
  status: string;
}

export interface VKProcessingInfo {
  external_job_id: string;
  external_processor: string;
  external_processing_status: string;
  external_job_type?: string;
  external_submitted_at?: number;
  external_completed_at?: number;
  external_error?: string;
}

export interface ProcessingHistoryItem {
  /** The source item (always present) */
  sourceItem: SourceItem;
  /** Latest export record (if any) */
  exportRecord: ExportRecord | null;
  /** Open errors associated with this content */
  errors: ErrorRecord[];
  /** Derived display fields */
  title: string;
  sourceType: string;
  currentStatus: string;
  statusTone: 'success' | 'warning' | 'danger' | 'neutral';
  collectedAt: number;
  processedAt: number | null;
  exportedAt: number | null;
  outputPath: string | null;
  retryCount: number;
  errorCount: number;
  lastErrorMessage: string | null;
  /** Phase 8: Model call info from metadata */
  modelCall: ModelCallInfo | null;
  /** Phase 8: Quality score (0-100) */
  qualityScore: number | null;
  /** Phase 8: Quality flags */
  qualityFlags: string[];
  /** Phase 8: Whether fallback was used */
  usedFallback: boolean;
  /** Phase 9: 外部处理服务信息 */
  vkInfo: VKProcessingInfo | null;
}

export type HistoryFilter = 'all' | 'exported' | 'processing' | 'failed' | 'needs_attention' | 'today' | 'week';

export interface UseProcessingHistoryReturn {
  items: ProcessingHistoryItem[];
  loading: boolean;
  error: string | null;
  filter: HistoryFilter;
  setFilter: (f: HistoryFilter) => void;
  refresh: () => Promise<void>;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const SOURCE_TYPE_LABELS: Record<string, string> = {
  clipboard: '剪贴板',
  screenshot: '截图',
  manual: '手动输入',
  vault_import: '仓库导入',
};

function resolveStatus(item: SourceItem, exportRecord: ExportRecord | null, errors: ErrorRecord[]): {
  status: string;
  tone: 'success' | 'warning' | 'danger' | 'neutral';
} {
  if (errors.length > 0) {
    return { status: '失败', tone: 'danger' };
  }
  if (exportRecord?.status === 'success') {
    return { status: '已进入 Obsidian', tone: 'success' };
  }
  if (exportRecord?.status === 'conflict') {
    return { status: '冲突待处理', tone: 'warning' };
  }
  if (item.status === 'exported') {
    return { status: '已导出', tone: 'success' };
  }
  if (item.status === 'distilled') {
    return { status: '待导出', tone: 'neutral' };
  }
  if (item.status === 'distilling') {
    return { status: '正在整理', tone: 'warning' };
  }
  // Phase 9: 外部处理服务状态
  const meta = (item as any).metadata ?? {};
  const vkStatus = meta.external_processing_status as string | undefined;
  if (vkStatus === 'processing') {
    return { status: 'VK 处理中', tone: 'warning' };
  }
  if (vkStatus === 'pending') {
    return { status: 'VK 等待中', tone: 'neutral' };
  }
  if (vkStatus === 'failed') {
    return { status: 'VK 处理失败', tone: 'danger' };
  }
  if (item.status === 'inbox') {
    return { status: '待处理', tone: 'neutral' };
  }
  return { status: item.status, tone: 'neutral' };
}

function isToday(timestamp: number): boolean {
  return new Date(timestamp).toDateString() === new Date().toDateString();
}

function isThisWeek(timestamp: number): boolean {
  const now = new Date();
  const d = new Date(timestamp);
  const weekStart = new Date(now);
  weekStart.setDate(now.getDate() - now.getDay());
  weekStart.setHours(0, 0, 0, 0);
  return d >= weekStart;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

export function useProcessingHistory(): UseProcessingHistoryReturn {
  const [sourceItems, setSourceItems] = useState<SourceItem[]>([]);
  const [exportRecords, setExportRecords] = useState<ExportRecord[]>([]);
  const [errors, setErrors] = useState<ErrorRecord[]>([]);
  const [processedAtMap, setProcessedAtMap] = useState<Record<string, number | null>>({});
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filter, setFilter] = useState<HistoryFilter>('all');

  const loadData = useCallback(async () => {
    if (!window.acmind) { setLoading(false); return; }
    try {
      setLoading(true);
      setLoadError(null);

      const [items, exports, errs] = await Promise.all([
        window.acmind.sourceItems.list({ limit: 200 }),
        window.acmind.export.history({ limit: 200 }),
        window.acmind.errors.list({ limit: 200 }),
      ]);

      setSourceItems(items);
      setExportRecords(exports);
      setErrors(errs.filter((e: ErrorRecord) => e.status === 'open'));

      // Batch fetch processedAt from content_state_history
      try {
        const ids = items.map((i) => i.id);
        const patMap = await window.acmind.pipeline.batchProcessedAt(ids);
        setProcessedAtMap(patMap);
      } catch {
        // Non-critical, leave map empty
      }
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void loadData(); }, [loadData]);

  const items: ProcessingHistoryItem[] = useMemo(() => {
    // Build a map of sourceItemId -> export records (latest first)
    const exportMap = new Map<string, ExportRecord>();
    for (const er of exportRecords) {
      const existing = exportMap.get(er.sourceItemId);
      if (!existing || er.exportedAt > existing.exportedAt) {
        exportMap.set(er.sourceItemId, er);
      }
    }

    // Build a map of original_id -> errors
    const errorMap = new Map<string, ErrorRecord[]>();
    for (const err of errors) {
      if (err.original_id) {
        const list = errorMap.get(err.original_id) ?? [];
        list.push(err);
        errorMap.set(err.original_id, list);
      }
    }

    return sourceItems.map((si) => {
      const er = exportMap.get(si.id) ?? null;
      const errs = si.originalId ? (errorMap.get(si.originalId) ?? []) : [];
      const { status, tone } = resolveStatus(si, er, errs);

      // Phase 8: Extract model call and quality info from metadata
      const meta = (si as any).metadata ?? {};
      const modelCall = (meta.model_call as ModelCallInfo) ?? null;
      const qualityScore = (meta.quality_score as number) ?? null;
      const qualityFlags = (meta.quality_flags as string[]) ?? [];
      const usedFallback = (meta.used_fallback as boolean) ?? false;

      // Phase 9: Extract VK processing info from metadata
      const vkInfo: VKProcessingInfo | null = meta.external_processor === 'external' ? {
        external_job_id: (meta.external_job_id as string) ?? '',
        external_processor: 'external',
        external_processing_status: (meta.external_processing_status as string) ?? 'unknown',
        external_job_type: (meta.external_job_type as string) ?? undefined,
        external_submitted_at: (meta.external_submitted_at as number) ?? undefined,
        external_completed_at: (meta.external_completed_at as number) ?? undefined,
        external_error: (meta.external_error as string) ?? undefined,
      } : null;

      return {
        sourceItem: si,
        exportRecord: er,
        errors: errs,
        title: si.title ?? si.previewText?.slice(0, 60) ?? '无标题',
        sourceType: SOURCE_TYPE_LABELS[si.source] ?? si.source,
        currentStatus: status,
        statusTone: tone,
        collectedAt: si.createdAt,
        processedAt: processedAtMap[si.id] ?? null,
        exportedAt: er?.exportedAt ?? null,
        outputPath: er?.relativeFilePath ?? null,
        retryCount: errs.reduce((sum, e) => sum + e.retry_count, 0),
        errorCount: errs.length,
        lastErrorMessage: errs.length > 0 ? errs[0].user_message : null,
        modelCall,
        qualityScore,
        qualityFlags,
        usedFallback,
        vkInfo,
      };
    });
  }, [sourceItems, exportRecords, errors]);

  const filteredItems = useMemo(() => {
    switch (filter) {
      case 'exported':
        return items.filter((i) => i.currentStatus === '已进入 Obsidian' || i.currentStatus === '已导出');
      case 'processing':
        return items.filter((i) => i.currentStatus === '正在整理');
      case 'failed':
        return items.filter((i) => i.statusTone === 'danger');
      case 'needs_attention':
        return items.filter((i) => i.statusTone === 'warning' || i.statusTone === 'danger');
      case 'today':
        return items.filter((i) => isToday(i.collectedAt));
      case 'week':
        return items.filter((i) => isThisWeek(i.collectedAt));
      default:
        return items;
    }
  }, [items, filter]);

  return {
    items: filteredItems,
    loading,
    error: loadError,
    filter,
    setFilter,
    refresh: loadData,
  };
}
