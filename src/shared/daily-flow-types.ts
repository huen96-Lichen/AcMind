/**
 * Phase 11: Daily Knowledge Flow types
 * 今日知识流仪表盘数据类型定义
 *
 * ## 数据口径映射
 *
 * Phase 11 实施文档中提到的验收名称与实际代码中的类型名存在差异，
 * 此处明确映射关系，确保验收口径一致：
 *
 * | 验收文档名称     | 实际代码类型        | 存储层              | 说明                     |
 * |------------------|---------------------|---------------------|--------------------------|
 * | CaptureRecord    | CaptureItem         | capture_items 表    | 收集记录，Phase 1-2 引入 |
 * | SourceItem       | SourceItem          | source_items 表     | 结构化内容，Phase 3 引入 |
 * | OutputHistory    | ExportRecord        | export_records 表   | 导出记录，Phase 4 引入   |
 * | ErrorLog         | ErrorRecord         | error_records 表    | 错误记录，Phase 5 引入   |
 *
 * Phase 11 的 DailyFlowItem / AttentionItem / RecentOutputItem 均从上述四张表聚合而来，
 * 不新增独立存储表。
 */

import type { CaptureItem, SourceItem, ExportRecord, ErrorRecord } from './types';

// ─── Status Label Map ──────────────────────────────────────────

/** 用户可读的状态文案映射 */
export const STATUS_LABEL_MAP: Record<string, string> = {
  captured: '已收集',
  processing: '正在整理',
  structured: '已整理',
  exporting: '正在写入 Obsidian',
  exported: '已进入 Obsidian',
  process_failed: '整理失败',
  export_failed: '写入失败',
  transcription_pending: '等待转写',
  transcribing: '正在转写',
  transcribed: '转写完成',
  transcription_failed: '转写失败',
  permission_required: '需要授权',
  conflict_pending: '需要确认',
  template_missing: '模板缺失',
  vault_missing: 'Vault 路径缺失',
  model_unavailable: '模型不可用',
  vaultkeeper_unavailable: 'VaultKeeper 不可用',
  external_job_failed: '外部任务失败',
  external_result_invalid: '外部结果无效',
  external_result_ingest_failed: '外部结果导入失败',
  unknown_error: '需要处理',
};

/** 获取用户可读状态文案 */
export function getUserStatusLabel(status: string): string {
  return STATUS_LABEL_MAP[status] ?? '需要处理';
}

// ─── Source Type Label Map ──────────────────────────────────────

export const SOURCE_TYPE_LABEL_MAP: Record<string, string> = {
  text: '文本',
  clipboard: '剪贴板',
  url: '网页',
  screenshot: '截图',
  file: '文件',
  pdf: 'PDF',
  audio: '语音',
  voice: '语音',
  video: '视频',
  image: '图片',
  unknown: '未知',
};

export function getSourceTypeLabel(sourceType: string): string {
  return SOURCE_TYPE_LABEL_MAP[sourceType] ?? sourceType;
}

// ─── Daily Flow Action ─────────────────────────────────────────

export type DailyFlowAction =
  | 'open_obsidian_file'
  | 'open_detail'
  | 'retry'
  | 'open_source'
  | 'configure_settings'
  | 'ignore';

// ─── Daily Flow Summary ────────────────────────────────────────

export interface DailyFlowSummary {
  date: string;
  captured_count: number;
  structured_count: number;
  exported_count: number;
  needs_attention_count: number;
  failed_count: number;
  pending_count: number;
}

// ─── Daily Flow Item ───────────────────────────────────────────

export interface DailyFlowItem {
  original_id: string;
  title: string;
  summary?: string;
  source_type: string;
  status: string;
  user_status_label: string;
  created_at: number;
  updated_at: number;
  output_path?: string;
  error_message?: string;
  quality_flags?: string[];
  tags?: string[];
  primary_action: DailyFlowAction;
}

// ─── Attention Item ────────────────────────────────────────────

export interface AttentionItem {
  original_id: string;
  /** Error record ID for dismiss/resolve operations */
  error_id?: string;
  title: string;
  reason_code: string;
  user_message: string;
  retryable: boolean;
  source_type: string;
  primary_action: DailyFlowAction;
}

// ─── Recent Output Item ────────────────────────────────────────

export interface RecentOutputItem {
  output_id: string;
  original_id: string;
  title: string;
  output_path: string;
  source_type: string;
  exported_at: number;
  tags?: string[];
}

// ─── Weekly Flow Summary ───────────────────────────────────────

export interface WeeklyFlowSummary {
  week_start: string;
  week_end: string;
  captured_count: number;
  exported_count: number;
  source_type_counts: Record<string, number>;
  top_tags: string[];
  highlights: DailyFlowItem[];
}

// ─── Filter Types ──────────────────────────────────────────────

export type DailyFlowFilter =
  | 'all'
  | 'exported'
  | 'needs_attention'
  | 'pending'
  | 'audio'
  | 'url'
  | 'file'
  | 'today'
  | 'this_week';
