import { useMemo } from 'react';

/* ===== Types ===== */

export interface SearchResult {
  id: string;
  type: 'source_item' | 'distilled_output';
  title: string;
  preview: string;
  score: number;
  vectorScore: number | null;
  keywordScore: number | null;
  rank: number;
  source: 'vector' | 'keyword' | 'hybrid';
  metadata: {
    category?: string;
    tags?: string[];
    createdAt: number;
    status?: string;
    exportRecordIds?: string[];
    exportRecordCount?: number;
  };
}

interface SearchResultCardProps {
  result: SearchResult;
  onClick?: (id: string) => void;
  onViewExports?: (id: string) => void;
}

/* ===== Helpers ===== */

const SOURCE_BADGE_STYLES: Record<string, { bg: string; text: string; label: string }> = {
  vector: { bg: 'var(--pm-purple-bg)', text: 'var(--pm-purple-text)', label: '向量' },
  keyword: { bg: 'var(--pm-running-bg)', text: 'var(--pm-running-text)', label: '关键词' },
  hybrid: { bg: 'var(--pm-success-bg)', text: 'var(--pm-success-text)', label: '混合' },
};

const TYPE_BADGE_STYLES: Record<string, { bg: string; text: string; label: string }> = {
  source_item: { bg: 'var(--pm-primary-soft)', text: 'var(--pm-brand-text)', label: '源项目' },
  distilled_output: { bg: 'var(--pm-info-bg)', text: 'var(--pm-info-text)', label: '整理结果' },
};

function formatRelativeTime(timestamp: number): string {
  const now = Date.now();
  const then = timestamp * 1000;
  const diffMs = now - then;
  const diffMin = Math.floor(diffMs / 60000);
  const diffHour = Math.floor(diffMs / 3600000);
  const diffDay = Math.floor(diffMs / 86400000);

  if (diffMin < 1) return '刚刚';
  if (diffMin < 60) return `${diffMin} 分钟前`;
  if (diffHour < 24) return `${diffHour} 小时前`;
  if (diffDay < 2) return '昨天';
  if (diffDay < 7) return `${diffDay} 天前`;
  return new Date(then).toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit' });
}

function formatScore(score: number): string {
  return (score * 100).toFixed(1);
}

/* ===== Component ===== */

export function SearchResultCard({ result, onClick, onViewExports }: SearchResultCardProps): JSX.Element {
  const sourceStyle = SOURCE_BADGE_STYLES[result.source] ?? SOURCE_BADGE_STYLES.hybrid;
  const typeStyle = TYPE_BADGE_STYLES[result.type] ?? TYPE_BADGE_STYLES.source_item;

  const highlightedPreview = useMemo(() => {
    // Split by <mark> tags and render highlighted segments
    const parts = result.preview.split(/(<mark>.*?<\/mark>)/g);
    return parts.map((part, i) => {
      if (part.startsWith('<mark>') && part.endsWith('</mark>')) {
        const text = part.slice(6, -7);
        return (
          <mark
            key={i}
            className="rounded-sm px-0.5"
            style={{
              background: 'var(--pm-warning-bg)',
              color: 'var(--pm-warning-text)',
            }}
          >
            {text}
          </mark>
        );
      }
      return <span key={i}>{part}</span>;
    });
  }, [result.preview]);

  const tags = result.metadata.tags ?? [];

  return (
    <article
      className="group cursor-pointer rounded-lg border border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-bg-surface)] p-4 transition-all"
      style={{
        boxShadow: 'var(--pm-shadow-card)',
      }}
      onClick={() => onClick?.(result.id)}
      onMouseEnter={(e) => {
        (e.currentTarget as HTMLElement).style.background = 'var(--pm-bg-card-hover)';
        (e.currentTarget as HTMLElement).style.borderColor = 'var(--pm-border-light)';
        (e.currentTarget as HTMLElement).style.boxShadow = 'var(--pm-shadow-card-hover)';
      }}
      onMouseLeave={(e) => {
        (e.currentTarget as HTMLElement).style.background = 'var(--pm-bg-surface)';
        (e.currentTarget as HTMLElement).style.borderColor = 'var(--pm-border-subtle)';
        (e.currentTarget as HTMLElement).style.boxShadow = 'var(--pm-shadow-card)';
      }}
    >
      {/* Top row: badges + score */}
      <div className="flex items-center gap-2">
        {/* Type badge */}
        <span
          className="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold"
          style={{ background: typeStyle.bg, color: typeStyle.text }}
        >
          {typeStyle.label}
        </span>

        {/* Source badge */}
        <span
          className="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold"
          style={{ background: sourceStyle.bg, color: sourceStyle.text }}
        >
          {sourceStyle.label}
        </span>

        {/* Score */}
        <span
          className="ml-auto inline-flex items-center rounded-md px-1.5 py-0.5 text-[10px] font-medium tabular-nums"
          style={{
            background: 'var(--pm-bg-subtle)',
            color: 'var(--pm-text-tertiary)',
          }}
        >
          {formatScore(result.score)}
        </span>
      </div>

      {/* Title */}
      <h3
        className="mt-2 text-sm font-semibold leading-snug"
        style={{
          color: 'var(--pm-text-primary)',
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}
      >
        {result.title}
      </h3>

      {/* Preview with highlights */}
      <p
        className="mt-1.5 text-xs leading-relaxed"
        style={{
          color: 'var(--pm-text-secondary)',
          display: '-webkit-box',
          WebkitLineClamp: 3,
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}
      >
        {highlightedPreview}
      </p>

      {/* Bottom row: metadata */}
      <div className="mt-3 flex items-center gap-3">
        {/* Category (for distilled_output) */}
        {result.type === 'distilled_output' && result.metadata.category && (
          <span
            className="inline-flex items-center rounded-md px-1.5 py-0.5 text-[10px] font-medium"
            style={{
              background: 'var(--pm-purple-bg)',
              color: 'var(--pm-purple-text)',
            }}
          >
            {result.metadata.category}
          </span>
        )}

        {/* Tags */}
        {tags.length > 0 && (
          <div className="flex items-center gap-1">
            {tags.slice(0, 3).map((tag) => (
              <span
                key={tag}
                className="inline-flex items-center rounded-md px-1.5 py-0.5 text-[10px] font-medium"
                style={{
                  background: 'var(--pm-primary-soft)',
                  color: 'var(--pm-text-secondary)',
                  maxWidth: 72,
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {tag}
              </span>
            ))}
            {tags.length > 3 && (
              <span
                className="text-[10px]"
                style={{ color: 'var(--pm-text-muted)' }}
              >
                +{tags.length - 3}
              </span>
            )}
          </div>
        )}

        {/* Spacer */}
        <div className="flex-1" />

        {/* Export record indicator */}
        {result.metadata.exportRecordCount && result.metadata.exportRecordCount > 0 && (
          <span
            className="inline-flex items-center rounded-md px-1.5 py-0.5 text-[10px] font-medium cursor-pointer hover:opacity-80"
            style={{
              background: 'var(--pm-success-bg)',
              color: 'var(--pm-success-text)',
            }}
            onClick={(e) => {
              e.stopPropagation();
              onViewExports?.(result.id);
            }}
          >
            已导出 {result.metadata.exportRecordCount} 条
          </span>
        )}

        {/* Relative time */}
        <span
          className="shrink-0 text-[10px]"
          style={{ color: 'var(--pm-text-muted)' }}
        >
          {formatRelativeTime(result.metadata.createdAt)}
        </span>
      </div>
    </article>
  );
}
