import { useEffect, useRef, useState } from 'react';
import type { SourceItem } from '../../../shared/types';
import type { PipelineStage } from '../../hooks/useContentPipeline';

// ─── Types ───────────────────────────────────────────────────────────────────

interface SourceItemCardProps {
  item: SourceItem;
  pipelineStage: PipelineStage | null;
  isSelected: boolean;
  onClick: () => void;
  onToggleSelect?: (id: string) => void;
  onDelete?: (id: string) => void;
  onRetryExport?: (id: string) => void;
  onRetryProcess?: (id: string) => void;
  onOpenInObsidian?: (id: string) => void;
  actionLoading?: boolean;
}

// ─── Status Display ──────────────────────────────────────────────────────────

/** Get display label from pipeline stage (preferred) or SourceItem status */
function getStatusDisplay(item: SourceItem, pipelineStage: PipelineStage | null): { label: string; tone: 'default' | 'running' | 'success' | 'warning' } {
  if (pipelineStage) {
    switch (pipelineStage) {
      case 'captured': return { label: '已收集', tone: 'default' };
      case 'processing': return { label: '正在整理', tone: 'running' };
      case 'structured': return { label: '正在写入 Obsidian', tone: 'running' };
      case 'exporting': return { label: '正在写入 Obsidian', tone: 'running' };
      case 'exported': return { label: '已进入 Obsidian', tone: 'success' };
      case 'process_failed': return { label: '整理失败', tone: 'warning' };
      case 'export_failed': return { label: '写入失败', tone: 'warning' };
      case 'capture_failed': return { label: '收集失败', tone: 'warning' };
      case 'conflict_pending': return { label: '文件冲突', tone: 'warning' };
      case 'permission_required': return { label: '需要权限', tone: 'warning' };
    }
  }
  // Fallback to SourceItem.status
  switch (item.status) {
    case 'inbox': return { label: '已收集', tone: 'default' };
    case 'distilling': return { label: '正在整理', tone: 'running' };
    case 'distilled': return { label: '正在写入 Obsidian', tone: 'running' };
    case 'exported': return { label: '已进入 Obsidian', tone: 'success' };
    case 'archived': return { label: '已进入 Obsidian', tone: 'success' };
  }
}

const TONE_STYLES: Record<string, { bg: string; color: string; dot: string }> = {
  default: { bg: 'rgba(107, 114, 128, 0.08)', color: '#6B7280', dot: '#6B7280' },
  running: { bg: 'rgba(59, 130, 246, 0.08)', color: '#3B82F6', dot: '#3B82F6' },
  success: { bg: 'rgba(16, 185, 129, 0.08)', color: '#10B981', dot: '#10B981' },
  warning: { bg: 'rgba(239, 68, 68, 0.08)', color: '#EF4444', dot: '#EF4444' },
};

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

function formatTimeShort(timestamp: number): string {
  return new Date(timestamp * 1000).toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

function getSourceLabel(source: SourceItem['source']): string {
  switch (source) {
    case 'clipboard': return '剪贴板';
    case 'screenshot': return '屏幕截图';
    case 'manual': return '手动录入';
    case 'vault_import': return '知识库导入';
    case 'audio': return '语音录音';
  }
}

function getTypeIcon(type: SourceItem['type']): string {
  switch (type) {
    case 'url': return '🔗';
    case 'image': return '🖼';
    case 'text': return '📄';
  }
}

function truncateText(text: string | undefined, maxLen: number): string {
  if (!text) return '';
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen) + '...';
}

/** Check if a pipeline stage indicates failure */
function isFailedStage(stage: PipelineStage | null): boolean {
  if (!stage) return false;
  return ['process_failed', 'export_failed', 'capture_failed', 'conflict_pending', 'permission_required'].includes(stage);
}

/** Check if a pipeline stage indicates the item is being processed */
function isProcessingStage(stage: PipelineStage | null): boolean {
  if (!stage) return false;
  return ['captured', 'processing', 'structured', 'exporting'].includes(stage);
}

/** Check if a pipeline stage indicates success */
function isSuccessStage(stage: PipelineStage | null): boolean {
  return stage === 'exported';
}

// ─── Image Thumbnail Sub-component ──────────────────────────────────────────

function ImageThumbnail({ contentPath }: { contentPath: string }) {
  const [src, setSrc] = useState<string | null>(null);
  const [loadError, setLoadError] = useState(false);
  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    setSrc(null);
    setLoadError(false);

    const loadThumbnail = async () => {
      try {
        const win = window as any;
        if (win.acmind?.sourceItems?.readImage) {
          const result = await win.acmind.sourceItems.readImage(contentPath);
          if (mountedRef.current && result) {
            setSrc(result);
          }
        } else {
          if (mountedRef.current) {
            setSrc(`file://${contentPath}`);
          }
        }
      } catch {
        if (mountedRef.current) setLoadError(true);
      }
    };

    loadThumbnail();

    return () => {
      mountedRef.current = false;
    };
  }, [contentPath]);

  if (loadError || !src) {
    return (
      <div className="acmind-image-card-thumbnail acmind-image-card-thumbnail-fallback">
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect x="2" y="2" width="18" height="18" rx="4" stroke="currentColor" strokeWidth="1.4" />
          <circle cx="7.5" cy="8" r="1.8" stroke="currentColor" strokeWidth="1.2" />
          <path d="M2 15L6.5 10.5L10 14L15 9L20 13.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
    );
  }

  return (
    <img
      className="acmind-image-card-thumbnail"
      src={src}
      alt=""
      onError={() => setLoadError(true)}
      loading="lazy"
    />
  );
}

// ─── Status Badge ────────────────────────────────────────────────────────────

function StatusBadge({ item, pipelineStage }: { item: SourceItem; pipelineStage: PipelineStage | null }): JSX.Element {
  const { label, tone } = getStatusDisplay(item, pipelineStage);
  const style = TONE_STYLES[tone];

  return (
    <span
      style={{
        display: 'inline-flex', alignItems: 'center', gap: '4px',
        height: '20px', padding: '0 8px', borderRadius: '999px',
        background: style.bg, color: style.color,
        fontSize: '11px', fontWeight: 500, flexShrink: 0,
      }}
    >
      <span style={{ width: '5px', height: '5px', borderRadius: '50%', background: style.dot }} />
      {label}
    </span>
  );
}

// ─── SourceItemCard ──────────────────────────────────────────────────────────

export function SourceItemCard({
  item,
  pipelineStage,
  isSelected,
  onClick,
  onToggleSelect,
  onDelete,
  onRetryExport,
  onRetryProcess,
  onOpenInObsidian,
  actionLoading,
}: SourceItemCardProps): JSX.Element {
  const isImage = item.type === 'image';
  const failed = isFailedStage(pipelineStage);
  const processing = isProcessingStage(pipelineStage);
  const exported = isSuccessStage(pipelineStage) || (!pipelineStage && (item.status === 'exported' || item.status === 'archived'));

  if (isImage) {
    return (
      <div
        onClick={onClick}
        className={`acmind-source-card acmind-image-card motion-button relative ${isSelected ? 'is-selected' : ''}`}
        role="button"
        tabIndex={0}
      >
        {onToggleSelect && (
          <button
            type="button"
            onClick={(event) => {
              event.stopPropagation();
              onToggleSelect(item.id);
            }}
            className="absolute left-3 top-3 z-10 inline-flex h-5 w-5 items-center justify-center rounded-full border"
            style={{
              borderColor: isSelected ? 'var(--pm-brand-primary)' : 'rgba(31,41,51,0.18)',
              background: isSelected ? 'var(--pm-brand-primary)' : 'rgba(255,255,255,0.92)',
              color: isSelected ? '#fff' : 'var(--pm-text-tertiary)',
            }}
          >
            <span className="text-[10px] leading-none">{isSelected ? '✓' : ''}</span>
          </button>
        )}
        <div className="acmind-image-card-layout">
          <ImageThumbnail contentPath={item.contentPath} />
          <div className="acmind-image-card-content">
            <div className="acmind-image-card-title-row">
              <span className="acmind-image-card-title">
                {getSourceLabel(item.source)} · {formatTimeShort(item.createdAt)}
              </span>
              <span className="acmind-source-card-time">{getRelativeTime(item.createdAt)}</span>
            </div>
            <div className="acmind-image-card-subtitle">
              <StatusBadge item={item} pipelineStage={pipelineStage} />
            </div>
          </div>
          <div className="acmind-image-card-badges">
            <span className="acmind-media-badge acmind-media-badge-image">图片</span>
          </div>
        </div>
      </div>
    );
  }

  // ── Text / URL card ──
  const previewText = item.previewText || item.ocrText || item.originalUrl || '';

  return (
    <div
      onClick={onClick}
      className={`acmind-source-card acmind-text-card motion-button relative ${isSelected ? 'is-selected' : ''}`}
      style={{ cursor: 'pointer' }}
    >
      {onToggleSelect && (
        <button
          type="button"
          onClick={(event) => {
            event.stopPropagation();
            onToggleSelect(item.id);
          }}
          className="absolute right-3 top-3 z-10 inline-flex h-5 w-5 items-center justify-center rounded-full border"
          style={{
            borderColor: isSelected ? 'var(--pm-brand-primary)' : 'rgba(31,41,51,0.18)',
            background: isSelected ? 'var(--pm-brand-primary)' : 'rgba(255,255,255,0.92)',
            color: isSelected ? '#fff' : 'var(--pm-text-tertiary)',
          }}
        >
          <span className="text-[10px] leading-none">{isSelected ? '✓' : ''}</span>
        </button>
      )}
      {/* Header: type + source + time + status */}
      <div className="acmind-source-card-header">
        <div className="flex items-center gap-2">
          <span className="text-[12px]">{getTypeIcon(item.type)}</span>
          {item.sourceApp ? (
            <span className="acmind-source-card-app">{item.sourceApp}</span>
          ) : (
            <span style={{ fontSize: '11px', color: 'var(--pm-text-tertiary)' }}>{getSourceLabel(item.source)}</span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <StatusBadge item={item} pipelineStage={pipelineStage} />
          <span className="acmind-source-card-time">{getRelativeTime(item.createdAt)}</span>
        </div>
      </div>

      {/* Body: title + preview */}
      <div className="acmind-source-card-body">
        {item.title && (
          <p style={{ fontSize: '13px', fontWeight: 600, color: '#1F2933', margin: '0 0 4px', lineHeight: '18px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {item.title}
          </p>
        )}
        <p className="acmind-source-card-text">
          {truncateText(previewText, 120) || '无预览内容'}
        </p>
        {/* Tags */}
        {item.tags && item.tags.length > 0 && (
          <div style={{ display: 'flex', gap: '4px', marginTop: '6px', flexWrap: 'wrap' }}>
            {item.tags.slice(0, 4).map((tag) => (
              <span
                key={tag}
                style={{
                  fontSize: '10px', padding: '1px 6px', borderRadius: '4px',
                  background: 'rgba(139, 92, 246, 0.06)', color: '#7C3AED',
                  fontWeight: 500,
                }}
              >
                {tag}
              </span>
            ))}
            {item.tags.length > 4 && (
              <span style={{ fontSize: '10px', color: 'var(--pm-text-tertiary)' }}>
                +{item.tags.length - 4}
              </span>
            )}
          </div>
        )}
      </div>

      {/* ── Action buttons (based on pipeline stage) ── */}
      <div
        style={{
          display: 'flex', alignItems: 'center', gap: '4px',
          padding: '4px 12px 8px',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* ── Failed: primary retry action ── */}
        {failed && pipelineStage === 'process_failed' && onRetryProcess && (
          <button
            type="button"
            onClick={() => onRetryProcess(item.id)}
            disabled={actionLoading}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: '#EF4444', fontSize: '11px', padding: '2px 6px', fontWeight: 500 }}
          >
            重试整理
          </button>
        )}

        {failed && pipelineStage === 'export_failed' && onRetryExport && (
          <button
            type="button"
            onClick={() => onRetryExport(item.id)}
            disabled={actionLoading}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: '#EF4444', fontSize: '11px', padding: '2px 6px', fontWeight: 500 }}
          >
            重试写入 Obsidian
          </button>
        )}

        {failed && pipelineStage === 'capture_failed' && onRetryProcess && (
          <button
            type="button"
            onClick={() => onRetryProcess(item.id)}
            disabled={actionLoading}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: '#EF4444', fontSize: '11px', padding: '2px 6px', fontWeight: 500 }}
          >
            重试整理
          </button>
        )}

        {failed && (pipelineStage === 'conflict_pending' || pipelineStage === 'permission_required') && onRetryExport && (
          <button
            type="button"
            onClick={() => onRetryExport(item.id)}
            disabled={actionLoading}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: '#F59E0B', fontSize: '11px', padding: '2px 6px', fontWeight: 500 }}
          >
            重新写入
          </button>
        )}

        {/* ── Processing: status indicator ── */}
        {processing && (
          <span style={{ fontSize: '11px', color: '#3B82F6', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{ width: '4px', height: '4px', borderRadius: '50%', background: '#3B82F6', animation: 'pulse 1.5s infinite' }} />
            {pipelineStage === 'processing' ? '正在整理' : pipelineStage === 'exporting' ? '正在写入 Obsidian' : pipelineStage === 'structured' ? '正在写入 Obsidian' : '已收集'}
          </span>
        )}

        {/* ── Exported: open in Obsidian ── */}
        {exported && onOpenInObsidian && (
          <button
            type="button"
            onClick={() => onOpenInObsidian(item.id)}
            disabled={actionLoading}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: '#16A34A', fontSize: '11px', padding: '2px 6px', fontWeight: 500 }}
          >
            打开 Obsidian 文件
          </button>
        )}

        {/* ── Secondary: view detail ── */}
        {!failed && (
          <button
            type="button"
            onClick={() => {
              window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'edit', itemId: item.id } }));
            }}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: 'var(--pm-text-tertiary)', fontSize: '11px', padding: '2px 6px' }}
          >
            查看详情
          </button>
        )}

        {/* Delete (always available) */}
        {onDelete && (
          <button
            type="button"
            onClick={() => onDelete(item.id)}
            className="acmind-btn acmind-btn-ghost motion-button"
            style={{ color: 'var(--pm-text-tertiary)', fontSize: '11px', padding: '2px 6px', marginLeft: 'auto' }}
          >
            删除
          </button>
        )}
      </div>
    </div>
  );
}
