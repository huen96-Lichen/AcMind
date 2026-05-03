import { useCallback, useEffect, useState } from 'react';
import { ScrollContainer } from '../shared/ScrollContainer';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  LoadingState,
  Section,
  StatusBadge,
} from '../../design-system/components';
import type { AiOperation, AiTier, SourceItem } from '../../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

interface DistillBatchPanelProps {
  onComplete?: () => void;
}

// ─── Operations ──────────────────────────────────────────────────────────────

const OPERATIONS: { key: AiOperation; label: string }[] = [
  { key: 'rename', label: '重命名' },
  { key: 'summarize', label: '摘要' },
  { key: 'classify', label: '分类' },
  { key: 'tag', label: '打标签' },
  { key: 'valueScore', label: '价值评分' },
  { key: 'cleanSuggest', label: '清理建议' },
];

const TIERS: { key: AiTier; label: string }[] = [
  { key: 'local_light', label: '本地轻量' },
  { key: 'cloud_standard', label: '云端标准' },
  { key: 'cloud_advanced', label: '云端高级' },
];

// ─── Component ───────────────────────────────────────────────────────────────

/**
 * Batch distillation panel.
 * Select source items, choose operations, and submit for AI processing.
 */
export function DistillBatchPanel({ onComplete }: DistillBatchPanelProps): JSX.Element {
  const [items, setItems] = useState<SourceItem[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [selectedOps, setSelectedOps] = useState<Set<AiOperation>>(new Set(['summarize']));
  const [tier, setTier] = useState<AiTier>('local_light');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [progress, setProgress] = useState<{ current: number; total: number } | null>(null);

  const loadItems = useCallback(async () => {
    try {
      setError(null);
      const inboxItems = await window.acmind.sourceItems.list({ status: 'inbox' });
      const distilledItems = await window.acmind.sourceItems.list({ status: 'distilled' });
      setItems([...inboxItems, ...distilledItems]);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadItems();
  }, [loadItems]);

  const toggleItem = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const toggleOp = (op: AiOperation) => {
    setSelectedOps((prev) => {
      const next = new Set(prev);
      if (next.has(op)) {
        next.delete(op);
      } else {
        next.add(op);
      }
      return next;
    });
  };

  const selectAll = () => {
    if (selectedIds.size === items.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(items.map((i) => i.id)));
    }
  };

  const handleSubmit = async () => {
    if (selectedIds.size === 0 || selectedOps.size === 0) return;

    try {
      setSubmitting(true);
      setProgress({ current: 0, total: selectedIds.size });
      setError(null);

      const ids = Array.from(selectedIds);
      const ops = Array.from(selectedOps);

      for (let i = 0; i < ids.length; i++) {
        await window.acmind.distill.run([ids[i]], ops, tier);
        setProgress({ current: i + 1, total: ids.length });
      }

      setSelectedIds(new Set());
      setSelectedOps(new Set());
      setProgress(null);
      onComplete?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const canSubmit = selectedIds.size > 0 && selectedOps.size > 0 && !submitting;

  return (
    <ScrollContainer>
      <div className="p-4 flex flex-col gap-4">
        {/* Mock 模式提示 */}
        <Card variant="base" padding={12}>
          <div className="flex items-center gap-2 mb-1">
            <StatusBadge tone="warning" label="规则模式" dot />
          </div>
          <p className="text-[12px] leading-relaxed" style={{ color: 'var(--pm-text-secondary)' }}>
            当前未配置可用的 AI 模型，批量整理将使用规则模板引擎（非真实 AI）。
            如需真实 AI 整理，请先在{' '}
            <button
              type="button"
              className="underline font-medium"
              style={{ color: 'var(--pm-brand-primary)' }}
              onClick={() => window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'settings' } }))}
            >
              设置
            </button>{' '}
            中配置 AI 模型。
          </p>
        </Card>

        {/* Source Items Selection */}
        <Card variant="base" padding={16}>
          <Section
            title="待整理内容"
            compact
            action={
              <Button variant="ghost" size="sm" onClick={selectAll}>
                {selectedIds.size === items.length ? '取消全选' : '全选'}
              </Button>
            }
          >
            {loading ? (
              <LoadingState title="正在加载内容..." description="请稍候" />
            ) : error ? (
              <ErrorState
                title="加载失败"
                reason={error}
                suggestion="请稍后重试"
              />
            ) : items.length === 0 ? (
              <EmptyState
                title="暂无可整理内容"
                description="先收集一些内容，再回来进行整理。"
              />
            ) : (
              <div className="flex flex-col gap-1 max-h-[240px] overflow-y-auto scroll-smooth-y">
                {items.map((item) => (
                  <label
                    key={item.id}
                    className="flex items-center gap-2 p-2 rounded-lg cursor-pointer motion-interactive"
                    style={{
                      background: selectedIds.has(item.id)
                        ? 'color-mix(in srgb, var(--pm-brand-soft) 60%, white 40%)'
                        : 'transparent',
                      border: selectedIds.has(item.id)
                        ? '1px solid color-mix(in srgb, var(--pm-brand-primary) 20%, transparent)'
                        : '1px solid transparent',
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={selectedIds.has(item.id)}
                      onChange={() => toggleItem(item.id)}
                      className="accent-[color:var(--pm-brand-primary)]"
                    />
                    <div className="min-w-0 flex-1">
                      <span className="text-[12px] font-medium block truncate" style={{ color: 'var(--pm-text-primary)' }}>
                        {item.previewText ?? item.type}
                      </span>
                      <span className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        {item.sourceApp ?? item.source} &middot; {item.type}
                      </span>
                    </div>
                  </label>
                ))}
              </div>
            )}

            {selectedIds.size > 0 && (
              <div className="mt-2 text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                已选择 {selectedIds.size} 项
              </div>
            )}
          </Section>
        </Card>

        {/* Default Plan */}
        <Card variant="base" padding={16}>
          <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <h4 className="text-[13px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
                默认整理方案
              </h4>
              <p className="mt-1 text-[12px] leading-5" style={{ color: 'var(--pm-text-secondary)' }}>
                已选「整理成可收藏笔记」：自动生成标题、摘要、分类、标签、价值判断和清理建议。
              </p>
            </div>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setShowAdvanced((value) => !value)}
            >
              {showAdvanced ? '收起高级选项' : '展开高级选项'}
            </Button>
          </div>
        </Card>

        {/* Operations */}
        {showAdvanced ? (
          <Card variant="base" padding={16}>
            <Section title="整理内容" compact>
              <div className="flex flex-wrap gap-2">
                {OPERATIONS.map((op) => (
                  <Button
                    key={op.key}
                    variant={selectedOps.has(op.key) ? 'primary' : 'secondary'}
                    size="sm"
                    onClick={() => toggleOp(op.key)}
                  >
                    {op.label}
                  </Button>
                ))}
              </div>
            </Section>
          </Card>
        ) : null}

        {/* Tier */}
        {showAdvanced ? (
          <Card variant="base" padding={16}>
            <Section title="整理方式" compact>
              <div className="flex gap-2">
                {TIERS.map((t) => (
                  <Button
                    key={t.key}
                    variant={tier === t.key ? 'primary' : 'secondary'}
                    size="sm"
                    onClick={() => setTier(t.key)}
                  >
                    {t.label}
                  </Button>
                ))}
              </div>
            </Section>
          </Card>
        ) : null}

        {/* Progress */}
        {progress && (
          <Card variant="base" padding={16}>
            <div className="flex items-center justify-between mb-2">
              <span className="text-[12px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                正在整理...
              </span>
              <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                {progress.current} / {progress.total}
              </span>
            </div>
            <div
              className="h-2 rounded-full overflow-hidden"
              style={{ background: 'color-mix(in srgb, var(--pm-border-default) 40%, transparent)' }}
            >
              <div
                className="h-full rounded-full"
                style={{
                  width: `${(progress.current / progress.total) * 100}%`,
                  background: 'var(--pm-brand-primary)',
                  transition: 'width var(--motion-base) var(--ease-standard)',
                }}
              />
            </div>
          </Card>
        )}

        {/* Submit */}
        <div className="flex items-center justify-end gap-2">
          <Button
            variant="primary"
            disabled={!canSubmit}
            busy={submitting}
            onClick={handleSubmit}
          >
            {submitting ? '正在整理...' : `整理 ${selectedIds.size} 项`}
          </Button>
        </div>
      </div>
    </ScrollContainer>
  );
}
