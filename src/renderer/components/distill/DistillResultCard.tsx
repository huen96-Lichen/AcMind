import { Button, Card, StatusBadge } from '../../design-system/components';
import type { DistilledOutput, SourceItem } from '../../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

interface DistillResultCardProps {
  output: DistilledOutput;
  sourceItem?: SourceItem;
  onAccept: (outputId: string) => void;
  onAcceptAndExport?: (outputId: string) => void;
  onReject: (outputId: string) => void;
  onEdit: (output: DistilledOutput) => void;
}

// ─── Component ───────────────────────────────────────────────────────────────

/**
 * Distilled output result card.
 * Shows suggested title, summary, category, tags, value score, and clean suggestion.
 */
export function DistillResultCard({
  output,
  sourceItem,
  onAccept,
  onAcceptAndExport,
  onReject,
  onEdit,
}: DistillResultCardProps): JSX.Element {
  const scorePercent = output.valueScore != null ? Math.round(output.valueScore * 100) : null;
  const scoreColor =
    scorePercent == null
      ? 'var(--pm-text-tertiary)'
      : scorePercent >= 70
        ? 'var(--pm-status-success)'
        : scorePercent >= 40
          ? 'var(--pm-status-warning)'
          : 'var(--pm-status-danger)';

  const cleanLabels: Record<string, string> = {
    keep: '保留',
    merge: '合并',
    discard: '丢弃',
  };

  return (
    <Card variant="base" padding={16} className="flex flex-col gap-3">
      {/* Header */}
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          {output.suggestedTitle && (
            <h4
              className="text-[14px] font-semibold truncate"
              style={{ color: 'var(--pm-text-primary)' }}
            >
              {output.suggestedTitle}
            </h4>
          )}
          {sourceItem && (
            <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
              来源：{sourceItem.sourceApp ?? sourceItem.type}
            </span>
          )}
        </div>
        {output.confidence != null && (
          <StatusBadge
            tone={output.confidence >= 0.7 ? 'success' : output.confidence >= 0.4 ? 'warning' : 'danger'}
            label={`${Math.round(output.confidence * 100)}% 置信度`}
            dot={false}
          />
        )}
      </div>

      {/* Summary */}
      {output.summary && (
        <p
          className="text-[12px] leading-relaxed"
          style={{
            color: 'var(--pm-text-secondary)',
            display: '-webkit-box',
            WebkitLineClamp: 3,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden',
          }}
        >
          {output.summary}
        </p>
      )}

      {/* Category + Tags */}
      <div className="flex items-center gap-2 flex-wrap">
        {output.category && (
          <StatusBadge tone="neutral" label={output.category} dot={false} />
        )}
        {output.tags?.map((tag) => (
          <StatusBadge key={tag} tone="neutral" label={tag} dot={false} />
        ))}
      </div>

      {/* Value Score */}
      {scorePercent != null && (
        <div className="flex items-center gap-2">
          <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            价值评分
          </span>
          <div
            className="flex-1 h-2 rounded-full overflow-hidden"
            style={{ background: 'color-mix(in srgb, var(--pm-border-default) 40%, transparent)' }}
          >
            <div
              className="h-full rounded-full"
              style={{
                width: `${scorePercent}%`,
                background: scoreColor,
                transition: 'width var(--motion-base) var(--ease-standard)',
              }}
            />
          </div>
          <span className="text-[11px] font-semibold" style={{ color: scoreColor }}>
            {scorePercent}%
          </span>
        </div>
      )}

      {/* Clean Suggestion */}
      {output.cleanSuggestion && (
        <div className="flex items-center gap-2">
          <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            清理：
          </span>
          <span className="text-[12px] font-medium" style={{ color: 'var(--pm-text-secondary)' }}>
            {cleanLabels[output.cleanSuggestion] ?? output.cleanSuggestion}
          </span>
        </div>
      )}

      {/* Actions */}
      <div className="flex items-center justify-end gap-2 pt-1">
        <Button
          variant="danger"
          size="sm"
          onClick={() => onReject(output.id)}
        >
          拒绝
        </Button>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => onEdit(output)}
        >
          编辑
        </Button>
        <Button
          variant="primary"
          size="sm"
          onClick={() => onAccept(output.id)}
        >
          接受
        </Button>
        {onAcceptAndExport ? (
          <Button
            variant="primary"
            size="sm"
            onClick={() => onAcceptAndExport(output.id)}
          >
            接受并写入 Obsidian
          </Button>
        ) : null}
      </div>
    </Card>
  );
}
