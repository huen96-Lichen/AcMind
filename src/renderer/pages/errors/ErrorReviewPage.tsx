import { useCallback, useMemo, useState } from 'react';
import type { ErrorRecord, ErrorType } from '../../../shared/types';
import { useErrorRecords } from '../../hooks/useErrorRecords';
import { useToast } from '../../components/shared/ToastViewport';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { PinStackIcon, PinStackIconButton } from '../../design-system/icons';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ERROR_TYPE_LABELS: Record<ErrorType, string> = {
  capture_failed: '捕获失败',
  process_failed: '处理失败',
  export_failed: '导出失败',
  permission_required: '权限不足',
  conflict_pending: '冲突待处理',
  template_missing: '模板缺失',
  vault_missing: '仓库未配置',
  model_unavailable: '模型不可用',
  // Phase 9.7: VaultKeeper 错误标签
  vaultkeeper_unavailable: '服务不可用',
  external_job_failed: '外部任务失败',
  external_result_invalid: '外部结果无效',
  external_result_ingest_failed: '结果回填失败',
  unknown_error: '未知错误',
};

const ERROR_TYPE_TONES: Record<ErrorType, 'danger' | 'warning' | 'neutral'> = {
  capture_failed: 'danger',
  process_failed: 'warning',
  export_failed: 'danger',
  permission_required: 'warning',
  conflict_pending: 'warning',
  template_missing: 'neutral',
  vault_missing: 'danger',
  model_unavailable: 'warning',
  // Phase 9.7: VaultKeeper 错误色调
  vaultkeeper_unavailable: 'warning',
  external_job_failed: 'danger',
  external_result_invalid: 'warning',
  external_result_ingest_failed: 'warning',
  unknown_error: 'neutral',
};

const STAGE_LABELS: Record<string, string> = {
  capture: '内容捕获',
  clipboard_capture: '剪贴板捕获',
  pipeline_capture: '管道捕获',
  pipeline_process: '自动整理',
  pipeline_export: '管道导出',
  pipeline_retry_export: '重试导出',
  distill_execute: 'AI 整理',
  obsidian_export: 'Obsidian 导出',
  obsidian_batch_export: '批量导出',
};

const STATUS_LABELS: Record<string, string> = {
  open: '待处理',
  resolved: '已解决',
  dismissed: '已忽略',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatTime(timestamp: number): string {
  const d = new Date(timestamp * 1000);
  const now = new Date();
  const isToday = d.toDateString() === now.toDateString();
  const time = d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  if (isToday) return `今天 ${time}`;
  return d.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' }) + ` ${time}`;
}

function getActionForError(errorType: ErrorType): { label: string; icon: 'act-edit' | 'line-inbox' | 'sb-settings' | 'act-more' | 'status-success'; action: string } | null {
  switch (errorType) {
    case 'process_failed':
      return { label: '重试整理', icon: 'act-edit', action: 'retry-process' };
    case 'export_failed':
      return { label: '重试写入', icon: 'line-inbox', action: 'retry-export' };
    case 'permission_required':
      return { label: '去设置权限', icon: 'sb-settings', action: 'go-settings' };
    case 'conflict_pending':
      return { label: '处理冲突', icon: 'act-edit', action: 'go-export' };
    case 'model_unavailable':
      return { label: '检查模型设置', icon: 'sb-settings', action: 'go-settings' };
    case 'template_missing':
      return { label: '检查模板包', icon: 'sb-settings', action: 'go-settings' };
    case 'capture_failed':
      return { label: '重试捕获', icon: 'line-inbox', action: 'retry-capture' };
    case 'vault_missing':
      return { label: '配置仓库', icon: 'sb-settings', action: 'go-settings' };
    case 'unknown_error':
      return { label: '查看详情', icon: 'act-more', action: 'show-detail' };
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// ErrorCard
// ---------------------------------------------------------------------------

function ErrorCard({
  record,
  onAction,
  onDismiss,
  onResolve,
  onShowDetail,
  isRetrying,
}: {
  record: ErrorRecord;
  onAction: (record: ErrorRecord, action: string) => void;
  onDismiss: (errorId: string) => void;
  onResolve: (errorId: string) => void;
  onShowDetail: (record: ErrorRecord) => void;
  isRetrying: boolean;
}): JSX.Element {
  const action = getActionForError(record.error_type);
  const tone = ERROR_TYPE_TONES[record.error_type];
  const isResolved = record.status !== 'open';

  const toneColors = {
    danger: {
      bg: 'color-mix(in srgb, var(--pm-status-danger) 6%, transparent)',
      border: 'color-mix(in srgb, var(--pm-status-danger) 16%, transparent)',
      dot: 'var(--pm-status-danger)',
      text: 'var(--pm-status-danger)',
    },
    warning: {
      bg: 'color-mix(in srgb, var(--pm-status-warning, #f59e0b) 6%, transparent)',
      border: 'color-mix(in srgb, var(--pm-status-warning, #f59e0b) 16%, transparent)',
      dot: 'var(--pm-status-warning, #f59e0b)',
      text: 'var(--pm-status-warning, #f59e0b)',
    },
    neutral: {
      bg: 'color-mix(in srgb, var(--pm-text-tertiary) 6%, transparent)',
      border: 'color-mix(in srgb, var(--pm-text-tertiary) 12%, transparent)',
      dot: 'var(--pm-text-tertiary)',
      text: 'var(--pm-text-tertiary)',
    },
  };
  const colors = toneColors[tone];

  return (
    <div
      style={{
        borderRadius: '10px',
        border: `1px solid ${isResolved ? 'var(--border-light)' : colors.border}`,
        background: isResolved ? 'var(--pm-bg-card, #fff)' : colors.bg,
        padding: '16px 20px',
        opacity: isResolved ? 0.6 : 1,
        transition: 'opacity 0.2s',
      }}
    >
      {/* Top row: type badge + time + status */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '5px',
              fontSize: '11px',
              fontWeight: 600,
              color: isResolved ? 'var(--pm-text-tertiary)' : colors.text,
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
            }}
          >
            <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: isResolved ? 'var(--pm-text-tertiary)' : colors.dot }} />
            {ERROR_TYPE_LABELS[record.error_type]}
          </span>
          <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)' }}>
            {STAGE_LABELS[record.stage] ?? record.stage}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)' }}>
            {formatTime(record.created_at)}
          </span>
          {isResolved && (
            <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)', fontWeight: 500 }}>
              {STATUS_LABELS[record.status]}
            </span>
          )}
        </div>
      </div>

      {/* User message */}
      <div style={{ fontSize: '13px', color: 'var(--pm-text-primary)', lineHeight: 1.5, marginBottom: '14px' }}>
        {record.user_message}
      </div>

      {/* Bottom row: retryable badge + actions */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {record.retryable && record.status === 'open' && (
            <span
              style={{
                fontSize: '11px',
                color: 'var(--pm-status-success, #22c55e)',
                background: 'color-mix(in srgb, var(--pm-status-success, #22c55e) 10%, transparent)',
                padding: '2px 8px',
                borderRadius: '4px',
                fontWeight: 500,
              }}
            >
              可重试{record.retry_count > 0 ? ` · 已重试 ${record.retry_count} 次` : ''}
            </span>
          )}
          {record.original_id && (
            <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)' }}>
              ID: {record.original_id.slice(0, 12)}...
            </span>
          )}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          {record.status === 'open' && action && (
            <button
              onClick={() => onAction(record, action.action)}
              disabled={isRetrying}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '5px',
                fontSize: '12px',
                fontWeight: 500,
                color: isRetrying ? 'var(--pm-text-tertiary)' : 'var(--primary)',
                background: 'transparent',
                border: 'none',
                cursor: isRetrying ? 'wait' : 'pointer',
                padding: '4px 10px',
                borderRadius: '6px',
                transition: 'background 0.15s',
                opacity: isRetrying ? 0.6 : 1,
              }}
              onMouseEnter={(e) => { if (!isRetrying) (e.currentTarget as HTMLButtonElement).style.background = 'color-mix(in srgb, var(--primary) 8%, transparent)'; }}
              onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'transparent'; }}
            >
              <PinStackIcon name={action.icon} size={14} />
              {isRetrying ? '重试中...' : action.label}
            </button>
          )}

          {record.status === 'open' && (
            <>
              <button
                onClick={() => onResolve(record.error_id)}
                title="标记为已解决"
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: '28px',
                  height: '28px',
                  borderRadius: '6px',
                  border: 'none',
                  background: 'transparent',
                  color: 'var(--pm-text-tertiary)',
                  cursor: 'pointer',
                  transition: 'background 0.15s',
                }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'color-mix(in srgb, var(--pm-status-success, #22c55e) 10%, transparent)'; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'transparent'; }}
              >
                <PinStackIcon name="status-success" size={15} />
              </button>
              <button
                onClick={() => onDismiss(record.error_id)}
                title="忽略此错误"
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: '28px',
                  height: '28px',
                  borderRadius: '6px',
                  border: 'none',
                  background: 'transparent',
                  color: 'var(--pm-text-tertiary)',
                  cursor: 'pointer',
                  transition: 'background 0.15s',
                }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'color-mix(in srgb, var(--pm-text-tertiary) 8%, transparent)'; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'transparent'; }}
              >
                <PinStackIcon name="close" size={14} />
              </button>
            </>
          )}

          {record.status !== 'open' && (
            <button
              onClick={() => onShowDetail(record)}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '5px',
                fontSize: '12px',
                color: 'var(--pm-text-tertiary)',
                background: 'transparent',
                border: 'none',
                cursor: 'pointer',
                padding: '4px 10px',
                borderRadius: '6px',
              }}
            >
              <PinStackIcon name="act-more" size={14} />
              详情
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// ErrorDetailDialog
// ---------------------------------------------------------------------------

function ErrorDetailDialog({
  record,
  onClose,
}: {
  record: ErrorRecord;
  onClose: () => void;
}): JSX.Element {
  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 100,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'rgba(0,0,0,0.3)',
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: 'var(--pm-bg-canvas, #fff)',
          borderRadius: '14px',
          border: '1px solid var(--border-light)',
          boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          width: '520px',
          maxWidth: '90vw',
          maxHeight: '80vh',
          overflow: 'auto',
          padding: '24px',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
          <div>
            <div style={{ fontSize: '15px', fontWeight: 600, color: 'var(--pm-text-primary)', marginBottom: '4px' }}>
              错误详情
            </div>
            <div style={{ fontSize: '12px', color: 'var(--pm-text-tertiary)' }}>
              {record.error_id}
            </div>
          </div>
          <PinStackIconButton icon="close" label="关闭" tone="ghost" size="sm" onClick={onClose} />
        </div>

        {/* Fields */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <DetailRow label="错误类型" value={ERROR_TYPE_LABELS[record.error_type]} />
          <DetailRow label="发生阶段" value={STAGE_LABELS[record.stage] ?? record.stage} />
          <DetailRow label="用户提示" value={record.user_message} />
          <DetailRow label="系统消息" value={record.message} />
          <DetailRow label="是否可重试" value={record.retryable ? '是' : '否'} />
          <DetailRow label="重试次数" value={`${record.retry_count} 次`} />
          <DetailRow label="发生时间" value={new Date(record.created_at * 1000).toLocaleString('zh-CN')} />
          <DetailRow label="状态" value={STATUS_LABELS[record.status]} />
          {record.original_id && <DetailRow label="内容 ID" value={record.original_id} />}
          {record.output_id && <DetailRow label="输出 ID" value={record.output_id} />}
          {record.resolved_at && <DetailRow label="解决时间" value={new Date(record.resolved_at * 1000).toLocaleString('zh-CN')} />}

          {/* Dev-only: raw error behind toggle */}
          {record.raw_error && (
            <div style={{ marginTop: '8px', borderTop: '1px solid var(--border-light)', paddingTop: '8px' }}>
              <DevOnlySection rawError={record.raw_error} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// DevOnlySection — raw error behind developer toggle
// ---------------------------------------------------------------------------

function DevOnlySection({ rawError }: { rawError: string }): JSX.Element {
  const [expanded, setExpanded] = useState(false);

  return (
    <div>
      <button
        onClick={() => setExpanded(!expanded)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          fontSize: '11px',
          fontWeight: 600,
          color: 'var(--pm-text-tertiary)',
          background: 'transparent',
          border: 'none',
          cursor: 'pointer',
          padding: '4px 0',
          textTransform: 'uppercase',
          letterSpacing: '0.5px',
        }}
      >
        <PinStackIcon name={expanded ? 'act-more' : 'line-inbox'} size={12} />
        {expanded ? '收起开发者信息' : '开发者信息'}
      </button>
      {expanded && (
        <pre
          style={{
            fontSize: '11px',
            color: 'var(--pm-text-secondary)',
            background: 'var(--pm-bg-sidebar, #f8f8f8)',
            borderRadius: '8px',
            padding: '12px',
            margin: '6px 0 0',
            whiteSpace: 'pre-wrap',
            wordBreak: 'break-all',
            maxHeight: '200px',
            overflow: 'auto',
            fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
          }}
        >
          {rawError}
        </pre>
      )}
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div style={{ display: 'flex', gap: '12px', fontSize: '13px' }}>
      <div style={{ width: '100px', flexShrink: 0, color: 'var(--pm-text-tertiary)', fontWeight: 500 }}>{label}</div>
      <div style={{ color: 'var(--pm-text-primary)', lineHeight: 1.5 }}>{value}</div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// ErrorReviewPage
// ---------------------------------------------------------------------------

export function ErrorReviewPage(): JSX.Element {
  const { records, openCount, loading, error: loadError, refresh, resolve, dismiss, clearResolved } = useErrorRecords();
  const { addToast } = useToast();
  const [filter, setFilter] = useState<'all' | 'open' | 'resolved'>('all');
  const [detailRecord, setDetailRecord] = useState<ErrorRecord | null>(null);

  const filteredRecords = useMemo(() => {
    if (filter === 'open') return records.filter((r) => r.status === 'open');
    if (filter === 'resolved') return records.filter((r) => r.status !== 'open');
    return records;
  }, [records, filter]);

  const [retryingId, setRetryingId] = useState<string | null>(null);

  const handleAction = useCallback(async (record: ErrorRecord, action: string) => {
    switch (action) {
      case 'go-settings':
        window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'settings' } }));
        break;
      case 'go-export':
        window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'export' } }));
        break;
      case 'retry-process':
      case 'retry-export':
      case 'retry-capture': {
        if (!window.acmind?.retry) {
          addToast('重试功能不可用', 'error');
          return;
        }
        setRetryingId(record.error_id);
        try {
          const result = await window.acmind.retry.error(record.error_id);
          if (result.success) {
            addToast(result.user_message, 'success');
          } else {
            addToast(result.user_message, 'error');
          }
        } catch (err) {
          addToast('重试操作失败', 'error');
        } finally {
          setRetryingId(null);
          void refresh();
        }
        break;
      }
      case 'show-detail':
        setDetailRecord(record);
        break;
      default:
        addToast('此操作暂未实现', 'info');
        break;
    }
    void refresh();
  }, [refresh, addToast]);

  const handleDismiss = useCallback(async (errorId: string) => {
    await dismiss(errorId);
    addToast('已忽略此错误', 'info');
  }, [dismiss, addToast]);

  const handleResolve = useCallback(async (errorId: string) => {
    await resolve(errorId);
    addToast('已标记为已解决', 'success');
  }, [resolve, addToast]);

  const handleClearResolved = useCallback(async () => {
    const count = await clearResolved();
    if (count > 0) {
      addToast(`已清除 ${count} 条已处理记录`, 'success');
    }
  }, [clearResolved, addToast]);

  return (
    <div className="flex h-full flex-col" style={{ overflow: 'hidden' }}>
      {/* Header */}
      <div
        className="shrink-0"
        style={{
          borderBottom: '1px solid var(--border-light)',
          padding: '20px 24px 16px',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
          <div>
            <h2 style={{ fontSize: '16px', fontWeight: 600, color: 'var(--pm-text-primary)', margin: 0 }}>
              错误回看
            </h2>
            <p style={{ fontSize: '12px', color: 'var(--pm-text-tertiary)', margin: '4px 0 0' }}>
              查看和处理自动化流程中的失败内容
            </p>
          </div>
          {records.some((r) => r.status !== 'open') && (
            <button
              onClick={() => void handleClearResolved()}
              style={{
                fontSize: '12px',
                color: 'var(--pm-text-tertiary)',
                background: 'transparent',
                border: '1px solid var(--border-light)',
                borderRadius: '6px',
                padding: '5px 12px',
                cursor: 'pointer',
              }}
            >
              清除已处理
            </button>
          )}
        </div>

        {/* Filter tabs */}
        <div style={{ display: 'flex', gap: '4px' }}>
          {(['all', 'open', 'resolved'] as const).map((tab) => {
            const count = tab === 'all'
              ? records.length
              : tab === 'open'
                ? openCount
                : records.length - openCount;
            const isActive = filter === tab;
            return (
              <button
                key={tab}
                onClick={() => setFilter(tab)}
                style={{
                  fontSize: '12px',
                  fontWeight: isActive ? 600 : 400,
                  color: isActive ? 'var(--pm-text-primary)' : 'var(--pm-text-tertiary)',
                  background: isActive ? 'color-mix(in srgb, var(--pm-text-primary) 8%, transparent)' : 'transparent',
                  border: 'none',
                  borderRadius: '6px',
                  padding: '5px 12px',
                  cursor: 'pointer',
                  transition: 'all 0.15s',
                }}
              >
                {tab === 'all' ? '全部' : tab === 'open' ? '待处理' : '已处理'}
                {count > 0 && (
                  <span style={{ marginLeft: '5px', opacity: 0.7 }}>({count})</span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Content */}
      <ScrollContainer className="flex-1 min-h-0">
        <div style={{ padding: '16px 24px 24px', maxWidth: '720px' }}>
          {loadError && (
            <div
              style={{
                fontSize: '12px',
                padding: '12px',
                borderRadius: '8px',
                background: 'rgba(239, 68, 68, 0.08)',
                color: 'var(--pm-status-danger)',
                border: '1px solid rgba(239, 68, 68, 0.16)',
                marginBottom: '16px',
              }}
            >
              加载失败: {loadError}
            </div>
          )}

          {loading ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '40px 0' }}>
              <span style={{ fontSize: '13px', color: 'var(--pm-text-tertiary)' }}>加载中...</span>
            </div>
          ) : filteredRecords.length === 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 0', gap: '12px' }}>
              <PinStackIcon
                name="status-success"
                size={36}
                style={{ color: 'var(--pm-text-tertiary)', opacity: 0.4 }}
              />
              <div style={{ fontSize: '14px', fontWeight: 500, color: 'var(--pm-text-secondary)' }}>
                {filter === 'open' ? '没有待处理的错误' : '没有错误记录'}
              </div>
              <div style={{ fontSize: '12px', color: 'var(--pm-text-tertiary)' }}>
                {filter === 'open' ? '所有自动化流程均正常运行' : '暂无记录'}
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {filteredRecords.map((record) => (
                <ErrorCard
                  key={record.error_id}
                  record={record}
                  onAction={handleAction}
                  onDismiss={handleDismiss}
                  onResolve={handleResolve}
                  onShowDetail={setDetailRecord}
                  isRetrying={retryingId === record.error_id}
                />
              ))}
            </div>
          )}
        </div>
      </ScrollContainer>

      {/* Detail dialog */}
      {detailRecord && (
        <ErrorDetailDialog record={detailRecord} onClose={() => setDetailRecord(null)} />
      )}
    </div>
  );
}
