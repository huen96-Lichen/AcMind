/**
 * Phase 11: Daily Knowledge Flow data aggregation hook
 * 从已有数据源聚合今日知识流视图所需数据
 */

import { useCallback, useMemo } from 'react';
import { useCaptureItems } from './useCaptureItems';
import { useSourceItems } from './useSourceItems';
import { useExportRecords } from './useExportRecords';
import { useErrorRecords } from './useErrorRecords';
import type {
  DailyFlowSummary,
  DailyFlowItem,
  AttentionItem,
  RecentOutputItem,
  WeeklyFlowSummary,
  DailyFlowAction,
  DailyFlowFilter,
} from '../../shared/daily-flow-types';
import { getUserStatusLabel, getSourceTypeLabel } from '../../shared/daily-flow-types';
import type { CaptureItem, SourceItem, ExportRecord, ErrorRecord } from '../../shared/types';

// ─── Helpers ───────────────────────────────────────────────────

function isToday(ts: number): boolean {
  const d = new Date(ts);
  const now = new Date();
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  );
}

function isThisWeek(ts: number): boolean {
  const now = new Date();
  const dayOfWeek = now.getDay() || 7; // Sunday = 7
  const weekStart = new Date(now);
  weekStart.setHours(0, 0, 0, 0);
  weekStart.setDate(now.getDate() - dayOfWeek + 1); // Monday
  return ts >= weekStart.getTime();
}

function getWeekRange(): { week_start: string; week_end: string } {
  const now = new Date();
  const dayOfWeek = now.getDay() || 7;
  const weekStart = new Date(now);
  weekStart.setHours(0, 0, 0, 0);
  weekStart.setDate(now.getDate() - dayOfWeek + 1);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 6);
  return {
    week_start: weekStart.toISOString().slice(0, 10),
    week_end: weekEnd.toISOString().slice(0, 10),
  };
}

function getTodayDateStr(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

/** Map CaptureItem status to pipeline stage for user display */
function mapCaptureStatusToStage(status: string): string {
  switch (status) {
    case 'captured': return 'captured';
    case 'processing': return 'processing';
    case 'structured': return 'structured';
    case 'exporting': return 'exporting';
    case 'exported': return 'exported';
    case 'process_failed': return 'process_failed';
    case 'export_failed': return 'export_failed';
    default: return status;
  }
}

/** Map SourceItem status to user-facing status */
function mapSourceStatus(status: string): string {
  switch (status) {
    case 'inbox': return 'captured';
    case 'distilling': return 'processing';
    case 'distilled': return 'structured';
    case 'exported': return 'exported';
    case 'archived': return 'exported';
    default: return status;
  }
}

/** Map CaptureItem type to source_type label key */
function mapCaptureTypeToSourceType(type: string): string {
  switch (type) {
    case 'text': return 'text';
    case 'clipboard': return 'clipboard';
    case 'url': return 'url';
    case 'screenshot': return 'screenshot';
    case 'file': return 'file';
    case 'pdf': return 'pdf';
    case 'audio': return 'audio';
    case 'video': return 'video';
    default: return type;
  }
}

/** Determine primary action for a flow item */
function determinePrimaryAction(
  status: string,
  outputPath?: string,
  retryable?: boolean,
): DailyFlowAction {
  if (status === 'exported' && outputPath) return 'open_obsidian_file';
  if (status === 'export_failed' || status === 'process_failed') {
    return retryable ? 'retry' : 'open_detail';
  }
  if (status === 'structured') return 'open_obsidian_file';
  if (status === 'transcription_pending') return 'open_source';
  return 'open_detail';
}

/** Determine if a CaptureItem has high value for review */
function isHighValue(item: CaptureItem, sourceItem?: SourceItem): boolean {
  // Check quality flags from source item metadata
  const metadata = sourceItem?.metadata as Record<string, unknown> | undefined;
  const qualityFlags = metadata?.quality_flags as string[] | undefined;
  if (qualityFlags) {
    const highValueFlags = ['project_idea_detected', 'todo_detected', 'daily_log_detected'];
    if (highValueFlags.some(f => qualityFlags.includes(f))) return true;
  }
  // Check tags
  const tags = sourceItem?.tags ?? [];
  const highValueTags = ['PinMind', 'Acore', '项目', '产品', '设计', 'idea', 'todo'];
  if (tags.some(t => highValueTags.some(hvt => t.toLowerCase().includes(hvt.toLowerCase())))) return true;
  // Check if has meaningful title (not just "文本收集")
  if (item.title && item.title.length > 10 && !item.title.startsWith('文本收集')) return true;
  return false;
}

/** Get recommendation reason for high-value item */
function getHighValueReason(item: CaptureItem, sourceItem?: SourceItem): string {
  const metadata = sourceItem?.metadata as Record<string, unknown> | undefined;
  const qualityFlags = metadata?.quality_flags as string[] | undefined;
  if (qualityFlags?.includes('project_idea_detected')) return '可能包含项目想法';
  if (qualityFlags?.includes('todo_detected')) return '可能包含待办事项';
  if (qualityFlags?.includes('daily_log_detected')) return '可能包含日志记录';
  const tags = sourceItem?.tags ?? [];
  if (tags.length > 0) return `标签: ${tags.slice(0, 3).join(', ')}`;
  return '内容值得回看';
}

// ─── Main Hook ─────────────────────────────────────────────────

export function useDailyKnowledgeFlow() {
  const { items: captureItems, loading: captureLoading } = useCaptureItems();
  const { items: sourceItems, loading: sourceLoading } = useSourceItems();
  const { records: exportRecords, loading: exportLoading } = useExportRecords();
  const { records: errorRecords, loading: errorLoading } = useErrorRecords({ status: 'open' });

  const loading = captureLoading || sourceLoading || exportLoading || errorLoading;

  // Build source item lookup by captureItemId
  const sourceByCaptureId = useMemo(() => {
    const map = new Map<string, SourceItem>();
    for (const si of sourceItems) {
      if (si.captureItemId) map.set(si.captureItemId, si);
    }
    return map;
  }, [sourceItems]);

  // Build export records lookup by sourceItemId
  const exportsBySourceId = useMemo(() => {
    const map = new Map<string, ExportRecord[]>();
    for (const er of exportRecords) {
      const list = map.get(er.sourceItemId) ?? [];
      list.push(er);
      map.set(er.sourceItemId, list);
    }
    return map;
  }, [exportRecords]);

  // Build error records lookup by original_id
  const errorsByOriginalId = useMemo(() => {
    const map = new Map<string, ErrorRecord[]>();
    for (const er of errorRecords) {
      if (er.original_id) {
        const list = map.get(er.original_id) ?? [];
        list.push(er);
        map.set(er.original_id, list);
      }
    }
    return map;
  }, [errorRecords]);

  // ─── Today's CaptureItems ────────────────────────────────────

  const todayCaptureItems = useMemo(() => {
    return captureItems.filter(ci => isToday(ci.capturedAt));
  }, [captureItems]);

  // ─── Today's Flow Items ──────────────────────────────────────

  const todayFlowItems = useMemo<DailyFlowItem[]>(() => {
    return todayCaptureItems.map(ci => {
      const si = sourceByCaptureId.get(ci.id);
      const exports = si ? (exportsBySourceId.get(si.id) ?? []) : [];
      const errors = errorsByOriginalId.get(ci.id) ?? [];

      // Determine effective status
      let effectiveStatus = mapCaptureStatusToStage(ci.status);
      if (si) {
        const siStatus = mapSourceStatus(si.status);
        // SourceItem status is more granular
        if (siStatus === 'exported') effectiveStatus = 'exported';
        else if (siStatus === 'structured' && effectiveStatus !== 'exported') effectiveStatus = 'structured';
      }

      // Check for errors
      if (errors.length > 0 && errors[0].status === 'open') {
        const errType = errors[0].error_type;
        if (errType === 'process_failed') effectiveStatus = 'process_failed';
        else if (errType === 'export_failed') effectiveStatus = 'export_failed';
        else if (errType === 'capture_failed') effectiveStatus = 'process_failed';
      }

      // Get output path from export record
      const latestExport = exports.find(e => e.status === 'success');
      const outputPath = latestExport
        ? `${latestExport.vaultPath}/${latestExport.relativeFilePath}`
        : undefined;

      // Get summary from distilled output or source item
      const summary = si?.previewText?.slice(0, 120);

      // Get tags
      const tags = si?.tags;

      return {
        original_id: ci.id,
        title: ci.title,
        summary,
        source_type: mapCaptureTypeToSourceType(ci.type),
        status: effectiveStatus,
        user_status_label: getUserStatusLabel(effectiveStatus),
        created_at: ci.capturedAt,
        updated_at: ci.updatedAt,
        output_path: outputPath,
        error_message: errors[0]?.user_message,
        tags,
        primary_action: determinePrimaryAction(effectiveStatus, outputPath, errors[0]?.retryable),
      };
    });
  }, [todayCaptureItems, sourceByCaptureId, exportsBySourceId, errorsByOriginalId]);

  // ─── Daily Summary ───────────────────────────────────────────

  const dailySummary = useMemo<DailyFlowSummary>(() => {
    const captured = todayFlowItems.length;
    const structured = todayFlowItems.filter(i =>
      ['structured', 'exported', 'exporting'].includes(i.status)
    ).length;
    const exported = todayFlowItems.filter(i => i.status === 'exported').length;
    const failed = todayFlowItems.filter(i =>
      ['process_failed', 'export_failed', 'transcription_failed'].includes(i.status)
    ).length;
    const pending = todayFlowItems.filter(i =>
      ['captured', 'processing', 'transcription_pending', 'transcribing'].includes(i.status)
    ).length;
    const needsAttention = failed + pending;

    return {
      date: getTodayDateStr(),
      captured_count: captured,
      structured_count: structured,
      exported_count: exported,
      needs_attention_count: needsAttention,
      failed_count: failed,
      pending_count: pending,
    };
  }, [todayFlowItems]);

  // ─── Attention Items ─────────────────────────────────────────

  const attentionItems = useMemo<AttentionItem[]>(() => {
    const items: AttentionItem[] = [];

    // From today's flow items with issues
    for (const fi of todayFlowItems) {
      if (['process_failed', 'export_failed', 'transcription_failed'].includes(fi.status)) {
        // Find matching error record for error_id
        const matchingError = errorRecords.find(
          er => er.original_id === fi.original_id && er.status === 'open'
        );
        items.push({
          original_id: fi.original_id,
          error_id: matchingError?.error_id,
          title: fi.title,
          reason_code: fi.status,
          user_message: fi.error_message ?? getUserStatusLabel(fi.status),
          retryable: fi.primary_action === 'retry',
          source_type: fi.source_type,
          primary_action: fi.primary_action,
        });
      }
      if (['transcription_pending', 'transcribing'].includes(fi.status)) {
        items.push({
          original_id: fi.original_id,
          title: fi.title,
          reason_code: fi.status,
          user_message: getUserStatusLabel(fi.status),
          retryable: false,
          source_type: fi.source_type,
          primary_action: 'open_source',
        });
      }
    }

    // From open error records (not just today)
    for (const er of errorRecords) {
      if (er.status !== 'open') continue;
      // Skip if already included from today's flow
      if (items.some(i => i.original_id === er.original_id)) continue;
      items.push({
        original_id: er.original_id ?? er.error_id,
        error_id: er.error_id,
        title: `错误: ${er.error_type}`,
        reason_code: er.error_type,
        user_message: er.user_message,
        retryable: er.retryable,
        source_type: 'unknown',
        primary_action: er.retryable ? 'retry' : 'open_detail',
      });
    }

    return items;
  }, [todayFlowItems, errorRecords]);

  // ─── Recent Outputs ──────────────────────────────────────────

  const recentOutputs = useMemo<RecentOutputItem[]>(() => {
    return exportRecords
      .filter(er => er.status === 'success')
      .sort((a, b) => b.exportedAt - a.exportedAt)
      .slice(0, 10)
      .map(er => {
        // Find source item to get title
        const si = sourceItems.find(s => s.id === er.sourceItemId);
        // Find capture item for title
        const ci = si?.captureItemId
          ? captureItems.find(c => c.id === si.captureItemId)
          : undefined;

        return {
          output_id: er.id,
          original_id: si?.captureItemId ?? er.sourceItemId,
          title: ci?.title ?? si?.title ?? '未命名内容',
          output_path: `${er.vaultPath}/${er.relativeFilePath}`,
          source_type: si ? getSourceTypeLabel(si.source) : 'unknown',
          exported_at: er.exportedAt,
          tags: si?.tags,
        };
      });
  }, [exportRecords, sourceItems, captureItems]);

  // ─── Weekly Summary ──────────────────────────────────────────

  const weeklySummary = useMemo<WeeklyFlowSummary>(() => {
    const weekCaptureItems = captureItems.filter(ci => isThisWeek(ci.capturedAt));
    const weekExportRecords = exportRecords.filter(er => isThisWeek(er.exportedAt) && er.status === 'success');

    // Source type distribution
    const sourceTypeCounts: Record<string, number> = {};
    for (const ci of weekCaptureItems) {
      const st = mapCaptureTypeToSourceType(ci.type);
      sourceTypeCounts[st] = (sourceTypeCounts[st] ?? 0) + 1;
    }

    // Top tags
    const tagCounts: Record<string, number> = {};
    for (const si of sourceItems) {
      if (!isThisWeek(si.createdAt)) continue;
      for (const tag of si.tags ?? []) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    const topTags = Object.entries(tagCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([tag]) => tag);

    // Highlights: high-value items from this week
    const highlights: DailyFlowItem[] = [];
    for (const ci of weekCaptureItems) {
      const si = sourceByCaptureId.get(ci.id);
      if (isHighValue(ci, si)) {
        const exports = si ? (exportsBySourceId.get(si.id) ?? []) : [];
        const latestExport = exports.find(e => e.status === 'success');
        const outputPath = latestExport
          ? `${latestExport.vaultPath}/${latestExport.relativeFilePath}`
          : undefined;
        const effectiveStatus = latestExport ? 'exported' : mapCaptureStatusToStage(ci.status);

        highlights.push({
          original_id: ci.id,
          title: ci.title,
          summary: si?.previewText?.slice(0, 120),
          source_type: mapCaptureTypeToSourceType(ci.type),
          status: effectiveStatus,
          user_status_label: getUserStatusLabel(effectiveStatus),
          created_at: ci.capturedAt,
          updated_at: ci.updatedAt,
          output_path: outputPath,
          tags: si?.tags,
          primary_action: determinePrimaryAction(effectiveStatus, outputPath),
        });
      }
    }

    const { week_start, week_end } = getWeekRange();

    return {
      week_start,
      week_end,
      captured_count: weekCaptureItems.length,
      exported_count: weekExportRecords.length,
      source_type_counts: sourceTypeCounts,
      top_tags: topTags,
      highlights: highlights.slice(0, 5),
    };
  }, [captureItems, exportRecords, sourceItems, sourceByCaptureId, exportsBySourceId]);

  // ─── Filtered Items ──────────────────────────────────────────

  const getFilteredItems = (filter: DailyFlowFilter, searchQuery?: string): DailyFlowItem[] => {
    let items = [...todayFlowItems];

    // Apply filter
    switch (filter) {
      case 'exported':
        items = items.filter(i => i.status === 'exported');
        break;
      case 'needs_attention':
        items = items.filter(i =>
          ['process_failed', 'export_failed', 'transcription_failed'].includes(i.status)
        );
        break;
      case 'pending':
        items = items.filter(i =>
          ['captured', 'processing', 'transcription_pending', 'transcribing'].includes(i.status)
        );
        break;
      case 'audio':
        items = items.filter(i => i.source_type === 'audio' || i.source_type === 'voice');
        break;
      case 'url':
        items = items.filter(i => i.source_type === 'url');
        break;
      case 'file':
        items = items.filter(i => i.source_type === 'file' || i.source_type === 'pdf');
        break;
      case 'today':
      case 'all':
      default:
        break;
    }

    // Apply search
    if (searchQuery?.trim()) {
      const q = searchQuery.toLowerCase();
      items = items.filter(i =>
        i.title.toLowerCase().includes(q) ||
        (i.summary?.toLowerCase().includes(q)) ||
        i.source_type.toLowerCase().includes(q) ||
        (i.tags?.some(t => t.toLowerCase().includes(q))) ||
        (i.output_path?.toLowerCase().includes(q))
      );
    }

    return items;
  };

  // ─── High Value Items ────────────────────────────────────────

  const highValueItems = useMemo(() => {
    return weeklySummary.highlights.map(item => ({
      ...item,
      reason: getHighValueReason(
        captureItems.find(c => c.id === item.original_id)!,
        sourceByCaptureId.get(item.original_id),
      ),
      /** 标注推荐来源为规则，避免被误认为模型结果 */
      reason_source: 'rule' as const,
    }));
  }, [weeklySummary.highlights, captureItems, sourceByCaptureId]);

  /** 忽略/关闭指定错误记录 */
  const dismissError = useCallback(async (errorId: string) => {
    await window.pinmind.errors.dismiss(errorId);
  }, []);

  return {
    loading,
    dailySummary,
    todayFlowItems,
    attentionItems,
    recentOutputs,
    weeklySummary,
    highValueItems,
    getFilteredItems,
    dismissError,
  };
}
