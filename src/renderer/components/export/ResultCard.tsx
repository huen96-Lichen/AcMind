import type { ExportRecord, DistilledOutput, SourceItem } from '../../../shared/types';
import { PinStackIcon } from '../../design-system/icons';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface ResultItem {
  record: ExportRecord;
  distilledOutput: DistilledOutput | null;
  sourceItem: SourceItem | null;
}

interface ResultCardProps {
  item: ResultItem;
  onOpenInObsidian: (recordId: string) => void;
  onViewOriginal: (sourceItemId: string) => void;
  onRetry: (recordId: string) => void;
  onRevealInVault: (recordId: string) => void;
  actionLoading?: boolean;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getRelativeTime(timestamp: number): string {
  const now = Date.now();
  const diffMs = now - timestamp * 1000;
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSeconds < 60) return '刚刚';
  if (diffMinutes < 60) return `${diffMinutes} 分钟前`;
  if (diffHours < 24) return `${diffHours} 小时前`;
  if (diffDays < 7) return `${diffDays} 天前`;
  return new Date(timestamp * 1000).toLocaleDateString('zh-CN');
}

function getSourceTypeLabel(sourceItem: SourceItem | null): string {
  if (!sourceItem) return '—';
  switch (sourceItem.source) {
    case 'clipboard': return '剪贴板';
    case 'screenshot': return '截图';
    case 'manual': return '手动录入';
    case 'vault_import': return '知识库';
    case 'audio': return '语音录音';
  }
}

function getSourceTypeIcon(sourceItem: SourceItem | null): string {
  if (!sourceItem) return '📄';
  switch (sourceItem.type) {
    case 'url': return '🔗';
    case 'image': return '🖼';
    case 'text': return '📄';
  }
}

function shortenPath(fullPath: string): string {
  let path = fullPath.replace(/^\/Users\/[^/]+/, '~');
  if (path.length > 52) {
    const parts = path.split('/');
    const filename = parts.pop() || '';
    const dir = parts.join('/');
    if (filename.length > 20) {
      const ext = filename.includes('.') ? '.' + filename.split('.').pop() : '';
      const name = filename.slice(0, 10);
      return `${dir}/${name}...${ext}`;
    }
  }
  return path;
}

// ─── ResultCard ──────────────────────────────────────────────────────────────

export function ResultCard({
  item,
  onOpenInObsidian,
  onViewOriginal,
  onRetry,
  onRevealInVault,
  actionLoading,
}: ResultCardProps): JSX.Element {
  const { record, distilledOutput, sourceItem } = item;
  const isSuccess = record.status === 'success';
  const isFailed = record.status === 'failed';
  const isConflict = record.status === 'conflict';

  const title = distilledOutput?.suggestedTitle || sourceItem?.title || record.relativeFilePath.split('/').pop() || '无标题';
  const summary = distilledOutput?.summary || sourceItem?.previewText || '';
  const tags = distilledOutput?.tags || sourceItem?.tags || [];
  const category = distilledOutput?.category || null;

  return (
    <div
      className="pinmind-source-card motion-button"
      style={{
        borderRadius: '14px',
        border: '1px solid rgba(31, 41, 51, 0.06)',
        background: '#FFFFFF',
        padding: '14px 16px',
      }}
    >
      {/* Header: type + source + time + status */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ fontSize: '12px' }}>{getSourceTypeIcon(sourceItem)}</span>
          <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)' }}>{getSourceTypeLabel(sourceItem)}</span>
          {category && (
            <span style={{
              fontSize: '10px', padding: '1px 6px', borderRadius: '4px',
              background: 'rgba(59, 130, 246, 0.06)', color: '#3B82F6', fontWeight: 500,
            }}>
              {category}
            </span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          {/* Status badge */}
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: '3px',
            height: '18px', padding: '0 7px', borderRadius: '999px',
            fontSize: '10px', fontWeight: 500,
            background: isSuccess ? 'rgba(16, 185, 129, 0.08)' : isFailed ? 'rgba(239, 68, 68, 0.08)' : 'rgba(245, 158, 11, 0.08)',
            color: isSuccess ? '#10B981' : isFailed ? '#EF4444' : '#F59E0B',
          }}>
            <span style={{ width: '4px', height: '4px', borderRadius: '50%', background: 'currentColor' }} />
            {isSuccess ? '已进入 Obsidian' : isFailed ? '写入失败' : '文件冲突'}
          </span>
          <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)' }}>
            {getRelativeTime(record.exportedAt)}
          </span>
        </div>
      </div>

      {/* Title */}
      <p style={{
        fontSize: '14px', fontWeight: 600, color: '#1F2933',
        margin: '0 0 4px', lineHeight: '20px',
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
      }}>
        {title}
      </p>

      {/* Summary */}
      {summary && (
        <p style={{
          fontSize: '12px', color: '#6B7280', margin: '0 0 8px',
          lineHeight: '18px', overflow: 'hidden',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
        }}>
          {summary.length > 160 ? summary.slice(0, 160) + '...' : summary}
        </p>
      )}

      {/* Tags */}
      {tags.length > 0 && (
        <div style={{ display: 'flex', gap: '4px', marginBottom: '8px', flexWrap: 'wrap' }}>
          {tags.slice(0, 5).map((tag) => (
            <span
              key={tag}
              style={{
                fontSize: '10px', padding: '1px 6px', borderRadius: '4px',
                background: 'rgba(139, 92, 246, 0.06)', color: '#7C3AED', fontWeight: 500,
              }}
            >
              {tag}
            </span>
          ))}
          {tags.length > 5 && (
            <span style={{ fontSize: '10px', color: 'var(--pm-text-tertiary)' }}>+{tags.length - 5}</span>
          )}
        </div>
      )}

      {/* Output path */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: '6px',
        padding: '6px 10px', borderRadius: '8px',
        background: 'rgba(0, 0, 0, 0.02)',
        marginBottom: '10px',
      }}>
        <PinStackIcon name="sb-obsidian" size={12} style={{ color: 'var(--pm-text-tertiary)', flexShrink: 0 }} />
        <span style={{
          fontSize: '11px', color: 'var(--pm-text-tertiary)',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>
          {shortenPath(record.relativeFilePath)}
        </span>
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); onRevealInVault(record.id); }}
          className="motion-button"
          style={{
            marginLeft: 'auto', flexShrink: 0,
            fontSize: '10px', color: 'var(--pm-text-tertiary)',
            background: 'none', border: 'none', cursor: 'pointer', padding: '2px',
          }}
          title="在文件管理器中显示"
        >
          <PinStackIcon name="duplicate" size={12} />
        </button>
      </div>

      {/* Error message */}
      {isFailed && record.error && (
        <div style={{
          fontSize: '11px', padding: '6px 10px', borderRadius: '6px', marginBottom: '10px',
          background: 'rgba(239, 68, 68, 0.06)', color: '#EF4444',
          border: '1px solid rgba(239, 68, 68, 0.12)',
        }}>
          {record.error}
        </div>
      )}

      {/* Actions */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
        {/* Primary action */}
        {isSuccess && (
          <button
            type="button"
            onClick={() => onOpenInObsidian(record.id)}
            disabled={actionLoading}
            className="pinmind-btn pinmind-btn-ghost motion-button"
            style={{ color: '#16A34A', fontSize: '12px', padding: '3px 8px', fontWeight: 500 }}
          >
            <PinStackIcon name="sb-obsidian" size={12} style={{ marginRight: '4px' }} />
            打开 Obsidian 文件
          </button>
        )}

        {isFailed && (
          <button
            type="button"
            onClick={() => onRetry(record.id)}
            disabled={actionLoading}
            className="pinmind-btn pinmind-btn-ghost motion-button"
            style={{ color: '#EF4444', fontSize: '12px', padding: '3px 8px', fontWeight: 500 }}
          >
            重试写入 Obsidian
          </button>
        )}

        {isConflict && (
          <button
            type="button"
            onClick={() => onRetry(record.id)}
            disabled={actionLoading}
            className="pinmind-btn pinmind-btn-ghost motion-button"
            style={{ color: '#F59E0B', fontSize: '12px', padding: '3px 8px', fontWeight: 500 }}
          >
            重新写入
          </button>
        )}

        {/* Secondary actions */}
        {sourceItem && (
          <button
            type="button"
            onClick={() => onViewOriginal(sourceItem.id)}
            className="pinmind-btn pinmind-btn-ghost motion-button"
            style={{ color: 'var(--pm-text-tertiary)', fontSize: '11px', padding: '3px 8px' }}
          >
            查看原文
          </button>
        )}

        {isSuccess && sourceItem && (
          <button
            type="button"
            onClick={() => {
              window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'edit', itemId: sourceItem.id } }));
            }}
            className="pinmind-btn pinmind-btn-ghost motion-button"
            style={{ color: 'var(--pm-text-tertiary)', fontSize: '11px', padding: '3px 8px' }}
          >
            重新生成
          </button>
        )}
      </div>
    </div>
  );
}
