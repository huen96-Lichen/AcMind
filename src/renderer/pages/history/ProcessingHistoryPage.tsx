import { useCallback, useState } from 'react';
import type { ProcessingHistoryItem, HistoryFilter } from '../../hooks/useProcessingHistory';
import { useProcessingHistory } from '../../hooks/useProcessingHistory';
import { useToast } from '../../components/shared/ToastViewport';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import {
  Button,
  EmptyState,
  ErrorState,
  LoadingState,
  PageHeader,
  PageShell,
  Section,
  StatusBadge,
} from '../../design-system/components';
import { PinStackIcon, PinStackIconButton } from '../../design-system/icons';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const FILTER_OPTIONS: { key: HistoryFilter; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: 'exported', label: '已进入 Obsidian' },
  { key: 'processing', label: '正在整理' },
  { key: 'failed', label: '失败' },
  { key: 'needs_attention', label: '需要处理' },
  { key: 'today', label: '今日' },
  { key: 'week', label: '本周' },
];

const TIER_LABELS: Record<string, string> = {
  local_light: '本地轻量',
  cloud_standard: '云端标准',
  cloud_advanced: '云端高级',
};

const QUALITY_FLAG_LABELS: Record<string, string> = {
  title_missing: '标题缺失',
  summary_too_short: '摘要过短',
  tags_invalid: '标签无效',
  body_empty: '正文为空',
  markdown_invalid: 'Markdown 无效',
  source_url_missing: '来源 URL 缺失',
  unsupported_inference: '不支持的推断',
  placeholder_generated: '占位生成',
  fallback_used: '已使用降级',
  model_unavailable: '模型不可用',
};

const VK_STATUS_LABELS: Record<string, string> = {
  pending: '等待处理',
  processing: '处理中',
  completed: '已完成',
  failed: '处理失败',
  cancelled: '已取消',
};

const VK_JOB_TYPE_LABELS: Record<string, string> = {
  webpage_extract: '网页抽取',
  pdf_parse: 'PDF 解析',
  docx_parse: 'DOCX 解析',
  image_ocr: '图片 OCR',
  audio_transcribe: '音频转写',
  video_transcribe: '视频转写',
  file_convert: '格式转换',
};

const STATUS_TONE_COLORS = {
  success: {
    bg: 'color-mix(in srgb, var(--pm-status-success, #22c55e) 8%, transparent)',
    border: 'color-mix(in srgb, var(--pm-status-success, #22c55e) 20%, transparent)',
    text: 'var(--pm-status-success, #22c55e)',
  },
  warning: {
    bg: 'color-mix(in srgb, var(--pm-status-warning, #f59e0b) 8%, transparent)',
    border: 'color-mix(in srgb, var(--pm-status-warning, #f59e0b) 20%, transparent)',
    text: 'var(--pm-status-warning, #f59e0b)',
  },
  danger: {
    bg: 'color-mix(in srgb, var(--pm-status-danger) 8%, transparent)',
    border: 'color-mix(in srgb, var(--pm-status-danger) 20%, transparent)',
    text: 'var(--pm-status-danger)',
  },
  neutral: {
    bg: 'color-mix(in srgb, var(--pm-text-tertiary) 6%, transparent)',
    border: 'color-mix(in srgb, var(--pm-text-tertiary) 12%, transparent)',
    text: 'var(--pm-text-tertiary)',
  },
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatTime(timestamp: number): string {
  const d = new Date(timestamp);
  const now = new Date();
  const isToday = d.toDateString() === now.toDateString();
  const time = d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  if (isToday) return `今天 ${time}`;
  return d.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' }) + ` ${time}`;
}

// ---------------------------------------------------------------------------
// HistoryCard
// ---------------------------------------------------------------------------

function HistoryCard({
  item,
  onOpenFile,
  onViewContent,
  onViewErrors,
  onRetry,
  onCopyPath,
  onRegenerate,
  onManualIngest,
  onResubmit,
  regeneratingId,
  ingestingJobId,
}: {
  item: ProcessingHistoryItem;
  onOpenFile: (item: ProcessingHistoryItem) => void;
  onViewContent: (item: ProcessingHistoryItem) => void;
  onViewErrors: (item: ProcessingHistoryItem) => void;
  onRetry: (item: ProcessingHistoryItem) => void;
  onCopyPath: (path: string) => void;
  onRegenerate: (item: ProcessingHistoryItem) => void;
  onManualIngest: (item: ProcessingHistoryItem) => void;
  onResubmit: (item: ProcessingHistoryItem) => void;
  regeneratingId: string | null;
  ingestingJobId: string | null;
}): JSX.Element {
  const colors = STATUS_TONE_COLORS[item.statusTone];
  const [expanded, setExpanded] = useState(false);

  return (
    <div
      style={{
        borderRadius: '10px',
        border: `1px solid ${colors.border}`,
        background: colors.bg,
        padding: '14px 18px',
        transition: 'all 0.15s',
      }}
    >
      {/* Row 1: Title + Status + Time */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flex: 1, minWidth: 0 }}>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '5px',
              fontSize: '11px',
              fontWeight: 600,
              color: colors.text,
              flexShrink: 0,
            }}
          >
            <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: colors.text }} />
            {item.currentStatus}
          </span>
          <span
            style={{
              fontSize: '13px',
              fontWeight: 500,
              color: 'var(--pm-text-primary)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
            title={item.title}
          >
            {item.title}
          </span>
        </div>
        <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)', flexShrink: 0, marginLeft: '12px' }}>
          {formatTime(item.collectedAt)}
        </span>
      </div>

      {/* Row 2: Meta info */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', fontSize: '11px', color: 'var(--pm-text-tertiary)', marginBottom: '10px', flexWrap: 'wrap' }}>
        <span>{item.sourceType}</span>
        <span style={{ opacity: 0.4 }}>·</span>
        <span>ID: {item.sourceItem.originalId?.slice(0, 12) ?? item.sourceItem.id.slice(0, 12)}</span>
        {item.outputPath && (
          <>
            <span style={{ opacity: 0.4 }}>·</span>
            <span
              style={{
                cursor: 'pointer',
                color: 'var(--primary)',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                maxWidth: '200px',
              }}
              title={item.outputPath}
              onClick={() => onCopyPath(item.outputPath!)}
            >
              {item.outputPath}
            </span>
          </>
        )}
        {item.retryCount > 0 && (
          <>
            <span style={{ opacity: 0.4 }}>·</span>
            <span>重试 {item.retryCount} 次</span>
          </>
        )}
        {item.errorCount > 0 && (
          <>
            <span style={{ opacity: 0.4 }}>·</span>
            <span style={{ color: 'var(--pm-status-danger)' }}>{item.errorCount} 个错误</span>
          </>
        )}
        {/* Phase 8: Model call info */}
        {item.modelCall && (
          <>
            <span style={{ opacity: 0.4 }}>·</span>
            <span title={`${item.modelCall.provider}/${item.modelCall.model_name}`}>
              {TIER_LABELS[item.modelCall.model_tier] ?? item.modelCall.model_tier}
            </span>
          </>
        )}
        {item.qualityScore !== null && (
          <>
            <span style={{ opacity: 0.4 }}>·</span>
            <span style={{ color: item.qualityScore >= 70 ? 'var(--pm-status-success)' : item.qualityScore >= 40 ? 'var(--pm-status-warning)' : 'var(--pm-status-danger)' }}>
              质量 {item.qualityScore}
            </span>
          </>
        )}
        {item.usedFallback && (
          <>
            <span style={{ opacity: 0.4 }}>·</span>
            <span style={{ color: 'var(--pm-status-warning)' }}>已降级</span>
          </>
        )}
      </div>

      {/* Phase 8: Quality flags */}
      {item.qualityFlags.length > 0 && (
        <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap', marginBottom: '10px' }}>
          {item.qualityFlags.map((flag) => (
            <span
              key={flag}
              style={{
                fontSize: '10px',
                fontWeight: 500,
                color: 'var(--pm-status-warning)',
                background: 'color-mix(in srgb, var(--pm-status-warning) 10%, transparent)',
                border: '1px solid color-mix(in srgb, var(--pm-status-warning) 20%, transparent)',
                borderRadius: '4px',
                padding: '1px 6px',
              }}
            >
              {QUALITY_FLAG_LABELS[flag] ?? flag}
            </span>
          ))}
        </div>
      )}

      {/* Phase 9: VaultKeeper processing status */}
      {item.vkInfo && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            fontSize: '11px',
            color: 'var(--pm-text-tertiary)',
            marginBottom: '10px',
            padding: '6px 10px',
            borderRadius: '6px',
            background: 'color-mix(in srgb, var(--primary) 4%, transparent)',
            border: '1px solid color-mix(in srgb, var(--primary) 10%, transparent)',
          }}
        >
          <span style={{ fontWeight: 600, color: 'var(--primary)' }}>处理服务</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span>{VK_JOB_TYPE_LABELS[item.vkInfo.external_job_type ?? ''] ?? item.vkInfo.external_job_type ?? '未知类型'}</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span
            style={{
              color: item.vkInfo.external_processing_status === 'completed'
                ? 'var(--pm-status-success)'
                : item.vkInfo.external_processing_status === 'failed'
                  ? 'var(--pm-status-danger)'
                  : item.vkInfo.external_processing_status === 'processing'
                    ? 'var(--pm-status-warning)'
                    : 'var(--pm-text-tertiary)',
            }}
          >
            {VK_STATUS_LABELS[item.vkInfo.external_processing_status] ?? item.vkInfo.external_processing_status}
          </span>
          {item.vkInfo.external_job_id && (
            <>
              <span style={{ opacity: 0.4 }}>·</span>
              <span>Job: {item.vkInfo.external_job_id.slice(0, 8)}</span>
            </>
          )}
          {item.vkInfo.external_error && (
            <>
              <span style={{ opacity: 0.4 }}>·</span>
              <span style={{ color: 'var(--pm-status-danger)' }}>{item.vkInfo.external_error}</span>
            </>
          )}
        </div>
      )}

      {/* Row 3: Last error (if any) */}
      {item.lastErrorMessage && (
        <div
          style={{
            fontSize: '12px',
            color: 'var(--pm-status-danger)',
            background: 'color-mix(in srgb, var(--pm-status-danger) 6%, transparent)',
            borderRadius: '6px',
            padding: '6px 10px',
            marginBottom: '10px',
          }}
        >
          {item.lastErrorMessage}
        </div>
      )}

      {/* Row 4: Actions */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
        {item.outputPath && item.statusTone === 'success' && (
          <ActionButton icon="line-inbox" label="打开文件" onClick={() => onOpenFile(item)} />
        )}
        <ActionButton icon="act-edit" label="查看原文" onClick={() => onViewContent(item)} />
        {item.errorCount > 0 && (
          <ActionButton icon="status-error" label="查看错误" onClick={() => onViewErrors(item)} tone="danger" />
        )}
        {(item.statusTone === 'danger' || item.statusTone === 'warning') && item.errors.length > 0 && (
          <ActionButton icon="line-inbox" label="重试" onClick={() => onRetry(item)} />
        )}
        {/* Phase 8: Regeneration button */}
        <ActionButton
          icon="act-more"
          label={regeneratingId === item.sourceItem.id ? '重新生成中...' : '重新生成'}
          onClick={() => onRegenerate(item)}
        />
        {/* Phase 9: VK action buttons */}
        {item.vkInfo && item.vkInfo.external_processing_status === 'completed' && (
          <ActionButton
            icon="line-inbox"
            label={ingestingJobId === item.vkInfo.external_job_id ? '回填中...' : '手动回填'}
            onClick={() => onManualIngest(item)}
          />
        )}
        {item.vkInfo && (item.vkInfo.external_processing_status === 'failed' || item.vkInfo.external_processing_status === 'cancelled') && (
          <ActionButton
            icon="line-inbox"
            label="重新提交 VK"
            onClick={() => onResubmit(item)}
          />
        )}
        <div style={{ flex: 1 }} />
        <button
          onClick={() => setExpanded(!expanded)}
          style={{
            fontSize: '11px',
            color: 'var(--pm-text-tertiary)',
            background: 'transparent',
            border: 'none',
            cursor: 'pointer',
            padding: '2px 6px',
            borderRadius: '4px',
          }}
        >
          {expanded ? '收起' : '详情'}
        </button>
      </div>

      {/* Expanded detail */}
      {expanded && (
        <div
          style={{
            marginTop: '12px',
            paddingTop: '12px',
            borderTop: '1px solid var(--border-light)',
            display: 'flex',
            flexDirection: 'column',
            gap: '6px',
            fontSize: '12px',
          }}
        >
          <InfoRow label="内容 ID" value={item.sourceItem.id} />
          {item.sourceItem.originalId && <InfoRow label="Original ID" value={item.sourceItem.originalId} />}
          <InfoRow label="来源类型" value={item.sourceType} />
          <InfoRow label="来源应用" value={item.sourceItem.sourceApp ?? '未知'} />
          <InfoRow label="收集时间" value={new Date(item.collectedAt).toLocaleString('zh-CN')} />
          {item.processedAt && <InfoRow label="处理时间" value={new Date(item.processedAt * 1000).toLocaleString('zh-CN')} />}
          {item.exportedAt && <InfoRow label="导出时间" value={new Date(item.exportedAt).toLocaleString('zh-CN')} />}
          {item.outputPath && <InfoRow label="输出路径" value={item.outputPath} />}
          <InfoRow label="重试次数" value={`${item.retryCount} 次`} />
          <InfoRow label="错误数量" value={`${item.errorCount} 个`} />
          {item.lastErrorMessage && <InfoRow label="最近错误" value={item.lastErrorMessage} />}
          {/* Phase 8: Model call detail */}
          {item.modelCall && (
            <>
              <div style={{ marginTop: '8px', marginBottom: '4px', fontSize: '11px', fontWeight: 600, color: 'var(--pm-text-tertiary)' }}>
                模型调用信息
              </div>
              <InfoRow label="模型层级" value={TIER_LABELS[item.modelCall.model_tier] ?? item.modelCall.model_tier} />
              <InfoRow label="Provider" value={item.modelCall.provider} />
              <InfoRow label="模型名称" value={item.modelCall.model_name} />
              <InfoRow label="Prompt Profile" value={`${item.modelCall.prompt_profile_id} v${item.modelCall.prompt_profile_version}`} />
              <InfoRow label="调用状态" value={item.modelCall.status} />
            </>
          )}
          {item.qualityScore !== null && <InfoRow label="质量评分" value={`${item.qualityScore}/100`} />}
          {item.usedFallback && <InfoRow label="降级处理" value="是" />}
          {/* Phase 9: VK detail */}
          {item.vkInfo && (
            <>
              <div style={{ marginTop: '8px', marginBottom: '4px', fontSize: '11px', fontWeight: 600, color: 'var(--pm-text-tertiary)' }}>
                处理详情
              </div>
              <InfoRow label="Job ID" value={item.vkInfo.external_job_id || '无'} />
              <InfoRow label="任务类型" value={VK_JOB_TYPE_LABELS[item.vkInfo.external_job_type ?? ''] ?? item.vkInfo.external_job_type ?? '未知'} />
              <InfoRow label="处理状态" value={VK_STATUS_LABELS[item.vkInfo.external_processing_status] ?? item.vkInfo.external_processing_status} />
              {item.vkInfo.external_submitted_at && <InfoRow label="提交时间" value={new Date(item.vkInfo.external_submitted_at * 1000).toLocaleString('zh-CN')} />}
              {item.vkInfo.external_completed_at && <InfoRow label="完成时间" value={new Date(item.vkInfo.external_completed_at * 1000).toLocaleString('zh-CN')} />}
              {item.vkInfo.external_error && <InfoRow label="错误信息" value={item.vkInfo.external_error} />}
            </>
          )}
          {item.errors.length > 0 && (
            <div style={{ marginTop: '4px' }}>
              <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--pm-text-tertiary)', marginBottom: '4px' }}>
                关联错误记录
              </div>
              {item.errors.map((err) => (
                <div
                  key={err.error_id}
                  style={{
                    fontSize: '11px',
                    color: 'var(--pm-text-secondary)',
                    padding: '4px 8px',
                    background: 'color-mix(in srgb, var(--pm-text-tertiary) 4%, transparent)',
                    borderRadius: '4px',
                    marginBottom: '4px',
                  }}
                >
                  [{err.error_type}] {err.user_message}
                  <span style={{ marginLeft: '8px', color: 'var(--pm-text-tertiary)' }}>
                    {formatTime(err.created_at)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Small UI components
// ---------------------------------------------------------------------------

function ActionButton({
  icon,
  label,
  onClick,
  tone,
}: {
  icon: 'line-inbox' | 'act-edit' | 'status-error' | 'act-more';
  label: string;
  onClick: () => void;
  tone?: 'danger';
}): JSX.Element {
  const color = tone === 'danger' ? 'var(--pm-status-danger)' : 'var(--pm-text-secondary)';
  return (
    <button
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '4px',
        fontSize: '11px',
        color,
        background: 'transparent',
        border: 'none',
        cursor: 'pointer',
        padding: '3px 8px',
        borderRadius: '5px',
        transition: 'background 0.15s',
      }}
      onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'color-mix(in srgb, var(--pm-text-tertiary) 8%, transparent)'; }}
      onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'transparent'; }}
    >
      <PinStackIcon name={icon} size={13} />
      {label}
    </button>
  );
}

function InfoRow({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div style={{ display: 'flex', gap: '10px' }}>
      <div style={{ width: '80px', flexShrink: 0, color: 'var(--pm-text-tertiary)', fontWeight: 500 }}>{label}</div>
      <div style={{ color: 'var(--pm-text-primary)', wordBreak: 'break-all' }}>{value}</div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// ContentPreviewDialog
// ---------------------------------------------------------------------------

function ContentPreviewDialog({
  item,
  onClose,
}: {
  item: ProcessingHistoryItem;
  onClose: () => void;
}): JSX.Element {
  const [content, setContent] = useState<string>('加载中...');
  const [error, setError] = useState<string | null>(null);

  const loadContent = useCallback(async () => {
    try {
      const result = await window.pinmind.sourceItems.getContent(item.sourceItem.id);
      if (result?.text) {
        setContent(result.text);
      } else if (result?.dataUrl) {
        setContent('[图片内容]');
      } else {
        setContent('无内容');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载失败');
    }
  }, [item.sourceItem.id]);

  // eslint-disable-next-line react-hooks/rules-of-hooks
  useState(() => { void loadContent(); });

  return (
    <div
      style={{ position: 'fixed', inset: 0, zIndex: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(0,0,0,0.3)' }}
      onClick={onClose}
    >
      <div
        style={{
          background: 'var(--pm-bg-canvas, #fff)',
          borderRadius: '14px',
          border: '1px solid var(--border-light)',
          boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          width: '600px',
          maxWidth: '90vw',
          maxHeight: '80vh',
          overflow: 'auto',
          padding: '24px',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <div style={{ fontSize: '15px', fontWeight: 600, color: 'var(--pm-text-primary)' }}>原文内容</div>
          <PinStackIconButton icon="close" label="关闭" tone="ghost" size="sm" onClick={onClose} />
        </div>
        {error ? (
          <div style={{ fontSize: '12px', color: 'var(--pm-status-danger)' }}>{error}</div>
        ) : (
          <pre
            style={{
              fontSize: '12px',
              color: 'var(--pm-text-primary)',
              background: 'var(--pm-bg-sidebar, #f8f8f8)',
              borderRadius: '8px',
              padding: '16px',
              margin: 0,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-all',
              maxHeight: '60vh',
              overflow: 'auto',
              fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
              lineHeight: 1.6,
            }}
          >
            {content}
          </pre>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// ProcessingHistoryPage
// ---------------------------------------------------------------------------

export function ProcessingHistoryPage(): JSX.Element {
  const { items, loading, error: loadError, filter, setFilter, refresh } = useProcessingHistory();
  const { addToast } = useToast();
  const [previewItem, setPreviewItem] = useState<ProcessingHistoryItem | null>(null);
  const [retryingId, setRetryingId] = useState<string | null>(null);
  const [regeneratingId, setRegeneratingId] = useState<string | null>(null);
  const [ingestingJobId, setIngestingJobId] = useState<string | null>(null);

  const handleOpenFile = useCallback(async (item: ProcessingHistoryItem) => {
    if (!item.exportRecord) return;
    try {
      await window.pinmind.export.openFile(item.exportRecord.id);
    } catch {
      addToast('无法打开文件，请检查 Obsidian 仓库路径', 'error');
    }
  }, [addToast]);

  const handleViewContent = useCallback((item: ProcessingHistoryItem) => {
    setPreviewItem(item);
  }, []);

  const handleViewErrors = useCallback((item: ProcessingHistoryItem) => {
    window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'errors' } }));
  }, []);

  const handleRetry = useCallback(async (item: ProcessingHistoryItem) => {
    if (!window.pinmind?.retry || item.errors.length === 0) return;
    const latestError = item.errors[0];
    setRetryingId(latestError.error_id);
    try {
      const result = await window.pinmind.retry.error(latestError.error_id);
      if (result.success) {
        addToast(result.user_message, 'success');
      } else {
        addToast(result.user_message, 'error');
      }
    } catch {
      addToast('重试失败', 'error');
    } finally {
      setRetryingId(null);
      void refresh();
    }
  }, [addToast, refresh]);

  const handleCopyPath = useCallback(async (path: string) => {
    try {
      await navigator.clipboard.writeText(path);
      addToast('路径已复制', 'success');
    } catch {
      addToast('复制失败', 'error');
    }
  }, [addToast]);

  // Phase 8: Regeneration handler
  const handleRegenerate = useCallback(async (item: ProcessingHistoryItem) => {
    if (!window.pinmind?.pipeline?.regenerate) {
      addToast('重新生成功能不可用', 'error');
      return;
    }
    setRegeneratingId(item.sourceItem.id);
    try {
      const result = await window.pinmind.pipeline.regenerate(item.sourceItem.id, {
        regenerationTier: 'cloud_standard',
      });
      if (result?.success) {
        addToast('重新生成完成', 'success');
      } else {
        addToast(result?.error ?? '重新生成失败', 'error');
      }
    } catch {
      addToast('重新生成失败', 'error');
    } finally {
      setRegeneratingId(null);
      void refresh();
    }
  }, [addToast, refresh]);

  // Phase 9: Manual ingest handler
  const handleManualIngest = useCallback(async (item: ProcessingHistoryItem) => {
    if (!item.vkInfo?.external_job_id) return;
    setIngestingJobId(item.vkInfo.external_job_id);
    try {
      const result = await window.pinmind.vk.manualIngest(item.vkInfo.external_job_id, item.sourceItem.originalId ?? undefined) as any;
      if (result?.success) {
        addToast('手动回填完成', 'success');
      } else {
        addToast(result?.error ?? '手动回填失败', 'error');
      }
    } catch {
      addToast('手动回填失败', 'error');
    } finally {
      setIngestingJobId(null);
      void refresh();
    }
  }, [addToast, refresh]);

  // Phase 9: Resubmit VK job handler
  const handleResubmit = useCallback(async (item: ProcessingHistoryItem) => {
    if (!item.sourceItem.originalId) return;
    try {
      const result = await window.pinmind.vk.resubmitJob(item.sourceItem.originalId) as any;
      if (result?.success) {
        addToast('重新提交成功', 'success');
      } else {
        addToast(result?.error ?? result?.message ?? '重新提交失败', 'error');
      }
    } catch {
      addToast('重新提交失败', 'error');
    } finally {
      void refresh();
    }
  }, [addToast, refresh]);

  // Count summary
  const totalCount = items.length;
  const failedCount = items.filter((i) => i.statusTone === 'danger').length;

  return (
    <PageShell className="flex h-full min-h-0 flex-col gap-4 p-0">
      <div className="px-6 pt-5">
        <PageHeader
          title="处理历史"
          description="追踪整理和入库的执行记录"
          meta={
            <div className="flex items-center gap-2">
              {totalCount > 0 ? <StatusBadge tone="neutral" label={`${totalCount} 条`} /> : null}
              {failedCount > 0 ? <StatusBadge tone="danger" label={`${failedCount} 个失败`} /> : null}
            </div>
          }
          actions={
            <Button
              variant="secondary"
              size="sm"
              leadingIcon={<PinStackIcon name="refresh" size={14} />}
              onClick={() => void refresh()}
            >
              刷新
            </Button>
          }
        />
      </div>

      <div className="px-6">
        <Section title="筛选" description="按状态和时间范围查看处理记录。" compact>
          <div className="flex flex-wrap gap-1.5">
            {FILTER_OPTIONS.map((opt) => {
              const isActive = filter === opt.key;
              return (
                <button
                  key={opt.key}
                  type="button"
                  onClick={() => setFilter(opt.key)}
                  className="motion-button rounded-full border px-3 py-1.5 text-[12px]"
                  style={{
                    fontWeight: isActive ? 600 : 400,
                    color: isActive ? 'var(--pm-text-primary)' : 'var(--pm-text-tertiary)',
                    background: isActive ? 'color-mix(in srgb, var(--pm-text-primary) 8%, transparent)' : 'transparent',
                    borderColor: isActive ? 'color-mix(in srgb, var(--pm-text-primary) 16%, transparent)' : 'var(--pm-border-subtle)',
                  }}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </Section>
      </div>

      <ScrollContainer className="flex-1 min-h-0">
        <div className="px-6 pb-6 max-w-[860px]">
          {loadError ? (
            <div className="pb-4">
              <ErrorState
                title="处理历史加载失败"
                reason={loadError}
                suggestion="请刷新页面后再试，或稍后重新打开此页。"
                action={{ label: '重新加载', onClick: () => void refresh() }}
              />
            </div>
          ) : null}

          {loading ? (
            <LoadingState
              title="正在加载处理历史"
              description="正在读取执行记录。"
            />
          ) : items.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="sb-results" size={36} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="暂无处理记录"
              description="整理和入库的执行记录将显示在这里。"
              action={{
                label: '去收集箱',
                onClick: () => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'capture-inbox' })),
              }}
            />
          ) : (
            <div className="flex flex-col gap-2">
              {items.map((item) => (
                <HistoryCard
                  key={item.sourceItem.id}
                  item={item}
                  onOpenFile={handleOpenFile}
                  onViewContent={handleViewContent}
                  onViewErrors={handleViewErrors}
                  onRetry={handleRetry}
                  onCopyPath={handleCopyPath}
                  onRegenerate={handleRegenerate}
                  onManualIngest={handleManualIngest}
                  onResubmit={handleResubmit}
                  regeneratingId={regeneratingId}
                  ingestingJobId={ingestingJobId}
                />
              ))}
            </div>
          )}
        </div>
      </ScrollContainer>

      {previewItem && <ContentPreviewDialog item={previewItem} onClose={() => setPreviewItem(null)} />}
    </PageShell>
  );
}
