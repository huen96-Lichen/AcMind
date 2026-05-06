import { useEffect, useCallback, useState } from 'react';
import type { CaptureItem } from '../../../shared/types';
import { AcMindIcon } from '../../design-system/icons';

// ─── Types ───────────────────────────────────────────────────────────────────

interface CaptureItemCardProps {
  item: CaptureItem;
  isSelected: boolean;
  onClick: () => void;
  onDistill?: (id: string) => void;
  onDelete?: (id: string) => void;
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

  // Check if today
  const itemDate = new Date(timestamp * 1000);
  const today = new Date();
  if (
    itemDate.getFullYear() === today.getFullYear() &&
    itemDate.getMonth() === today.getMonth() &&
    itemDate.getDate() === today.getDate()
  ) {
    return `今天 ${String(itemDate.getHours()).padStart(2, '0')}:${String(itemDate.getMinutes()).padStart(2, '0')}`;
  }

  if (diffDays < 7) return `${diffDays} 天前`;
  return new Date(timestamp * 1000).toLocaleDateString('zh-CN');
}

function extractDomain(url: string): string {
  try {
    const parsed = new URL(url);
    return parsed.hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
}

function formatCaptureDate(timestamp: number): string {
  const d = new Date(timestamp * 1000);
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${mm}-${dd} ${hh}:${min}`;
}

/**
 * Generate display title following the priority rules.
 * NEVER shows the full file path as the main title.
 */
function getItemTitle(item: CaptureItem): string {
  // 1. Web/article (has sourceUrl): use item.title or extract domain from URL
  if (item.sourceUrl) {
    return item.title || extractDomain(item.sourceUrl);
  }

  // 2. Image capture (type=image): show "图片捕获 · MM-DD HH:MM"
  if (item.type === 'image') {
    return `图片捕获 · ${formatCaptureDate(item.capturedAt)}`;
  }

  // 2b. Audio capture (type=audio): show filename or "语音录音 · MM-DD HH:MM"
  if (item.type === 'audio') {
    if (item.filePath) {
      const filename = item.filePath.split('/').pop() || '语音录音';
      return filename;
    }
    return `语音录音 · ${formatCaptureDate(item.capturedAt)}`;
  }

  // 3. File import (has filePath): show filename only, not full path
  if (item.filePath) {
    const filename = item.filePath.split('/').pop() || '未命名捕获';
    return filename;
  }

  // 4. Text (type=text): show item.title or truncate rawText to 30 chars
  if (item.type === 'text') {
    if (item.title) return item.title;
    if (item.rawText) {
      return item.rawText.length > 30 ? item.rawText.slice(0, 30) + '...' : item.rawText;
    }
  }

  // 5. Fallback
  return '未命名捕获';
}

/**
 * Get the type icon name for the item.
 */
function getTypeIconName(item: CaptureItem): string {
  if (item.type === 'image') return 'image';
  if (item.type === 'text') return 'text';
  if (item.type === 'audio') return 'ai-workspace';
  if (item.sourceUrl) return 'duplicate';
  // Manual input (no sourceUrl, no filePath, no image)
  return 'edit';
}

/**
 * Get the source label for the item.
 */
function getSourceLabel(item: CaptureItem): string {
  if (item.sourceUrl) return 'Web Clipper';
  if (item.type === 'audio') return '语音录音';
  if (item.filePath) return '文件导入';
  if (item.type === 'image') return 'Electron';
  return '手动输入';
}

/**
 * Get status badge config: label, text color, background color.
 */
function getStatusConfig(status: CaptureItem['status']): { label: string; color: string; bg: string } {
  switch (status) {
    case 'pending':
      return {
        label: '待处理',
        color: 'var(--pm-warning)',
        bg: 'var(--pm-warning-bg)',
      };
    case 'archived':
      return {
        label: '已整理',
        color: 'var(--pm-success)',
        bg: 'var(--pm-success-bg)',
      };
    case 'failed':
      return {
        label: '失败',
        color: 'var(--pm-error)',
        bg: 'var(--pm-error-bg)',
      };
    case 'ignored':
      return {
        label: '已忽略',
        color: 'var(--pm-text-tertiary)',
        bg: 'var(--pm-bg-subtle)',
      };
    case 'distilling':
      return {
        label: '整理中',
        color: 'var(--pm-info)',
        bg: 'var(--pm-info-bg)',
      };
    case 'transcribing':
      return {
        label: '正在转写',
        color: 'var(--pm-info)',
        bg: 'var(--pm-info-bg)',
      };
    case 'transcribed':
      return {
        label: '转写完成',
        color: 'var(--pm-success)',
        bg: 'var(--pm-success-bg)',
      };
    default:
      return {
        label: status,
        color: 'var(--pm-text-tertiary)',
        bg: 'var(--pm-bg-subtle)',
      };
  }
}

function truncateText(text: string, maxLen: number): string {
  if (!text) return '';
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen) + '...';
}

// ─── CaptureItemCard ─────────────────────────────────────────────────────────

/**
 * Card component for a single capture item in the list.
 * Left-right layout: type icon + title + summary + tags | source + status + time
 */
export function CaptureItemCard({ item, isSelected, onClick, onDistill, onDelete }: CaptureItemCardProps): JSX.Element {
  const displayTitle = getItemTitle(item);
  const summaryText = item.rawText || item.userNote || '';
  const statusConfig = getStatusConfig(item.status);
  const [thumbUrl, setThumbUrl] = useState<string | null>(null);
  const [distillProgress, setDistillProgress] = useState<string | null>(null);
  const [navigating, setNavigating] = useState(false);

  // Load thumbnail for image items
  useEffect(() => {
    if (item.type !== 'image' || !item.filePath) {
      setThumbUrl(null);
      return;
    }
    let cancelled = false;
    window.acmind.captureItems.readImage(item.filePath).then((result) => {
      if (cancelled) return;
      if (result.ok && result.dataUrl) {
        setThumbUrl(result.dataUrl);
      }
    }).catch(() => { /* silently fail */ });
    return () => { cancelled = true; };
  }, [item.type, item.filePath]);

  // Load distill progress when status is 'distilling'
  useEffect(() => {
    if (item.status !== 'distilling') {
      setDistillProgress(null);
      return;
    }
    let cancelled = false;
    const load = async () => {
      try {
        const lineage = await window.acmind.sourceItems.getDistillStatus(item.id);
        if (cancelled) return;
        const total = lineage.aiTasks.length;
        const done = lineage.aiTasks.filter((t) => t.status === 'done').length;
        setDistillProgress(total > 0 ? `${done}/${total}` : null);
      } catch {
        // Ignore
      }
    };
    void load();
    const interval = setInterval(() => { void load(); }, 3000);
    return () => { cancelled = true; clearInterval(interval); };
  }, [item.status, item.id]);

  const handleDistill = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    onDistill?.(item.id);
  }, [onDistill, item.id]);

  const handleDelete = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    onDelete?.(item.id);
  }, [onDelete, item.id]);

  const handleRetry = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    // Reset capture item status to pending so it can be distilled again
    window.acmind.captureItems.update(item.id, { status: 'pending' }).then(() => {
      onDistill?.(item.id);
    }).catch(() => {
      // If update fails, try distilling directly
      onDistill?.(item.id);
    });
  }, [onDistill, item.id]);

  const handleViewResult = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    setNavigating(true);
    // Navigate to edit page with the source item
    window.acmind.sourceItems.getByCaptureItemId(item.id).then((sourceItem) => {
      if (sourceItem) {
        window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'edit', itemId: sourceItem.id } }));
      } else {
        setNavigating(false);
      }
    }).catch(() => {
      setNavigating(false);
    });
  }, [item.id]);

  const isPending = item.status === 'pending';
  const isFailed = item.status === 'failed';
  const isArchived = item.status === 'archived';

  return (
    <button
      type="button"
      onClick={onClick}
      className={`acmind-capture-card motion-button ${isSelected ? 'is-selected' : ''}`}
    >
      {/* ── Left Area ── */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: '10px', flex: '1', minWidth: 0 }}>
        {/* Type Icon */}
        <span
          style={{
            flexShrink: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: '32px',
            height: '32px',
            borderRadius: '8px',
            background: 'var(--pm-bg-subtle)',
            color: 'var(--pm-text-secondary)',
          }}
        >
          <AcMindIcon name={getTypeIconName(item) as any} size={16} />
        </span>

        {/* Title + Summary + Tags */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', minWidth: 0, flex: 1 }}>
          {/* Title */}
          <span
            style={{
              fontSize: '15px',
              fontWeight: 600,
              color: 'var(--pm-text-primary)',
              lineHeight: '20px',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {displayTitle}
          </span>

          {/* Summary (one line) */}
          {item.type !== 'image' && summaryText && (
            <span
              style={{
                fontSize: '13px',
                fontWeight: 400,
                color: 'var(--pm-text-secondary)',
                lineHeight: '18px',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                display: 'block',
              }}
            >
              {truncateText(summaryText, 80)}
            </span>
          )}

          {/* Tags Chips */}
          {/* Note: CaptureItem does not have a tags field in current types.
              This is a placeholder for when tags are added. */}
        </div>
      </div>

      {/* ── Right Area ── */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '6px', flexShrink: 0, marginLeft: '16px' }}>
        {/* Source */}
        <span style={{ fontSize: '12px', color: 'var(--pm-text-tertiary)', lineHeight: '16px' }}>
          {getSourceLabel(item)}
        </span>

        {/* Status Badge + Distill Progress */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span
            style={{
              fontSize: '12px',
              fontWeight: 500,
              color: statusConfig.color,
              background: statusConfig.bg,
              borderRadius: '9999px',
              padding: '2px 8px',
              lineHeight: '18px',
              whiteSpace: 'nowrap',
            }}
          >
            {statusConfig.label}
          </span>
          {distillProgress && (
            <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)', lineHeight: '16px' }}>
              {distillProgress}
            </span>
          )}
        </div>

        {/* Time */}
        <span style={{ fontSize: '12px', color: 'var(--pm-text-tertiary)', lineHeight: '16px' }}>
          {getRelativeTime(item.capturedAt)}
        </span>
      </div>

      {/* ── Action buttons (overlay on hover) ── */}
      {(isPending || isFailed || isArchived) && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '4px',
            marginLeft: '12px',
            flexShrink: 0,
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {isPending && (
            <button
              type="button"
              onClick={handleDistill}
              className="acmind-btn acmind-btn-ghost motion-button"
              style={{ color: 'var(--pm-primary)', fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
              title="整理"
            >
              <AcMindIcon name="spark" size={12} />
              整理
            </button>
          )}
          {isFailed && (
            <button
              type="button"
              onClick={handleRetry}
              className="acmind-btn acmind-btn-ghost motion-button"
              style={{ color: 'var(--pm-warning)', fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
              title="重新整理"
            >
              <AcMindIcon name="refresh" size={12} />
              重试
            </button>
          )}
          {isArchived && (
            <button
              type="button"
              onClick={handleViewResult}
              disabled={navigating}
              className="acmind-btn acmind-btn-ghost motion-button"
              style={{ color: 'var(--pm-primary)', fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
              title="查看整理结果"
            >
              <AcMindIcon name="arrow-right" size={12} />
              查看结果
            </button>
          )}
          <button
            type="button"
            onClick={handleDelete}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: 'var(--pm-error)', fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
            title="删除"
          >
            <AcMindIcon name="close" size={12} />
            删除
          </button>
        </div>
      )}
    </button>
  );
}
