import { useExportRecords } from '../../hooks/useExportRecords';
import { ScrollContainer } from '../shared/ScrollContainer';
import { EmptyState } from '../shared/EmptyState';
import type { ExportRecord } from '../../../shared/types';

// ─── Status Badge ────────────────────────────────────────────────────────────

const STATUS_CONFIG: Record<ExportRecord['status'], { label: string; color: string }> = {
  success: { label: '成功', color: 'var(--pm-status-success)' },
  conflict: { label: '冲突', color: 'var(--pm-status-warning)' },
  failed: { label: '失败', color: 'var(--pm-status-danger)' },
};

function ExportStatusBadge({ status }: { status: ExportRecord['status'] }): JSX.Element {
  const config = STATUS_CONFIG[status];
  return (
    <span
      className="acmind-status-badge"
      data-status={status}
      style={{
        color: config.color,
        borderColor: `color-mix(in srgb, ${config.color} 30%, transparent)`,
        background: `color-mix(in srgb, ${config.color} 8%, transparent)`,
      }}
    >
      {config.label}
    </span>
  );
}

// ─── Export Row ──────────────────────────────────────────────────────────────

interface ExportRowProps {
  record: ExportRecord;
  onRevealInVault: (recordId: string) => void;
  onRetry: (recordId: string) => void;
}

function ExportRow({ record, onRevealInVault, onRetry }: ExportRowProps): JSX.Element {
  const formatTime = (ts: number) => {
    const d = new Date(ts * 1000);
    return d.toLocaleString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div className="acmind-export-row">
      <div className="flex items-center gap-3 flex-1 min-w-0">
        <span
          className="text-[12px] font-medium truncate"
          style={{ color: 'var(--pm-text-primary)' }}
        >
          {record.relativeFilePath.split('/').pop() ?? record.relativeFilePath}
        </span>
        <span className="text-[11px] truncate" style={{ color: 'var(--pm-text-tertiary)' }}>
          {record.vaultPath}
        </span>
        <ExportStatusBadge status={record.status} />
      </div>
      <div className="flex items-center gap-3 flex-shrink-0">
        <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
          {formatTime(record.exportedAt)}
        </span>
        <div className="flex items-center gap-1">
          {record.status === 'success' && (
            <button
              type="button"
              className="acmind-btn acmind-btn-secondary motion-button"
              style={{ height: 28, fontSize: 11, paddingInline: 8 }}
              onClick={() => onRevealInVault(record.id)}
            >
              在 Obsidian 中打开
            </button>
          )}
          {record.status === 'failed' && (
            <button
              type="button"
              className="acmind-btn acmind-btn-primary motion-button"
              style={{ height: 28, fontSize: 11, paddingInline: 8 }}
              onClick={() => onRetry(record.id)}
            >
              重试写入
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── ExportHistory ───────────────────────────────────────────────────────────

/**
 * Export history list component.
 * Shows past export records with status badges and actions.
 */
export function ExportHistory(): JSX.Element {
  const { records, loading, error } = useExportRecords();
  const recordById = new Map(records.map((record) => [record.id, record]));

  const handleRevealInVault = async (recordId: string) => {
    try {
      await window.acmind.export.revealInVault(recordId);
    } catch {
      // Silently fail
    }
  };

  const handleRetry = async (recordId: string) => {
    try {
      const record = recordById.get(recordId);
      if (record?.sourceItemId && window.acmind?.pipeline) {
        await window.acmind.pipeline.retryExport(record.sourceItemId);
        return;
      }

      await window.acmind.export.retry(recordId);
    } catch {
      // Silently fail
    }
  };

  return (
    <ScrollContainer>
      <div className="p-4">
        {loading ? (
          <div className="flex items-center justify-center py-8">
            <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
              正在加载历史...
            </span>
          </div>
        ) : error ? (
          <div
            className="text-[12px] p-3 rounded-lg"
            style={{
              background: 'rgba(201, 75, 75, 0.08)',
              color: 'var(--pm-status-danger)',
              border: '1px solid rgba(201, 75, 75, 0.16)',
            }}
          >
            加载历史失败：{error}
          </div>
        ) : records.length === 0 ? (
          <EmptyState
            icon={'\u{1F4C4}'}
            title={'暂无写入历史'}
            description={'成功写入 Obsidian 的内容会在这里显示。'}
          />
        ) : (
          <div className="flex flex-col gap-1">
            {records.map((record) => (
              <ExportRow
                key={record.id}
                record={record}
                onRevealInVault={handleRevealInVault}
                onRetry={handleRetry}
              />
            ))}
          </div>
        )}
      </div>
    </ScrollContainer>
  );
}
