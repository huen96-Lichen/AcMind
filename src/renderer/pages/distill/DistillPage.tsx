import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { useToast } from '../../components/shared/ToastViewport';
import { FallbackBadge } from '../../components/FallbackBadge';
import type { SourceItem, DistilledOutput } from '../../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

type OrganizeTab = 'pending' | 'confirming' | 'done';

const TABS: { key: OrganizeTab; label: string }[] = [
  { key: 'pending', label: '待整理' },
  { key: 'confirming', label: '待确认' },
  { key: 'done', label: '已完成' },
];

const STATUS_MAP: Record<OrganizeTab, string[]> = {
  pending: ['inbox', 'distilling'],
  confirming: ['distilled'],
  done: ['exported'],
};

/** Track which sourceItems are currently being distilled */
type DistillingState = Record<string, boolean>;

// ─── Component ───────────────────────────────────────────────────────────────

export function DistillPage(): JSX.Element {
  const { addToast } = useToast();
  const [activeTab, setActiveTab] = useState<OrganizeTab>('pending');
  const [items, setItems] = useState<SourceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null);
  const [distilledOutput, setDistilledOutput] = useState<DistilledOutput | null>(null);
  const [loadingOutput, setLoadingOutput] = useState(false);
  const [distilling, setDistilling] = useState<DistillingState>({});
  const [distillError, setDistillError] = useState<Record<string, string>>({});
  const prevSelectedRef = useRef<string | null>(null);

  // ── Load items ──

  const loadItems = useCallback(async (preserveSelection = false) => {
    try {
      setLoading(true);
      setError(null);
      const allItems = await window.acmind.sourceItems.list({});
      const statuses = STATUS_MAP[activeTab];
      const filtered = allItems.filter((item) => statuses.includes(item.status));
      setItems(filtered);

      if (preserveSelection && prevSelectedRef.current) {
        const prev = filtered.find((i) => i.id === prevSelectedRef.current);
        if (prev) {
          setSelectedItem(prev);
        } else if (filtered.length > 0) {
          setSelectedItem(filtered[0]);
        } else {
          setSelectedItem(null);
          setDistilledOutput(null);
        }
      } else if (filtered.length > 0 && !selectedItem) {
        setSelectedItem(filtered[0]);
      } else if (filtered.length === 0) {
        setSelectedItem(null);
        setDistilledOutput(null);
      }
    } catch {
      setError('加载失败，请稍后重试。');
    } finally {
      setLoading(false);
    }
  }, [activeTab, selectedItem]);

  // ── Load distilled output for selected item ──

  const loadDistilledOutput = useCallback(async (sourceItemId: string) => {
    setLoadingOutput(true);
    try {
      const outputs = await window.acmind.distilledOutputs.list({ sourceItemId });
      const preferred =
        outputs.find((o) => o.operation === 'summarize' || Boolean(o.contentMarkdown)) ??
        outputs[0] ??
        null;
      setDistilledOutput(preferred);
    } catch {
      setDistilledOutput(null);
    } finally {
      setLoadingOutput(false);
    }
  }, []);

  // ── Effects ──

  useEffect(() => {
    void loadItems();
  }, [loadItems]);

  useEffect(() => {
    const unsubscribe = window.acmind.onRecordsChanged(() => {
      prevSelectedRef.current = selectedItem?.id ?? null;
      void loadItems(true);
    });
    return unsubscribe;
  }, [loadItems, selectedItem]);

  useEffect(() => {
    if (selectedItem && (activeTab === 'confirming' || activeTab === 'done')) {
      void loadDistilledOutput(selectedItem.id);
    } else {
      setDistilledOutput(null);
    }
  }, [selectedItem, activeTab, loadDistilledOutput]);

  // ── Distill: real IPC call ──

  const handleDistill = useCallback(async (item: SourceItem) => {
    try {
      setDistilling((prev) => ({ ...prev, [item.id]: true }));
      setDistillError((prev) => {
        const next = { ...prev };
        delete next[item.id];
        return next;
      });

      // Update status to distilling first
      await window.acmind.sourceItems.update(item.id, { status: 'distilling' });

      // Call real distill pipeline
      await window.acmind.distill.run([item.id], ['summarize']);

      addToast('整理完成', 'success');
    } catch (err) {
      const msg = err instanceof Error ? err.message : '整理失败';
      setDistillError((prev) => ({ ...prev, [item.id]: msg }));
      addToast(msg, 'error');
      // Revert status on failure
      try {
        await window.acmind.sourceItems.update(item.id, { status: 'inbox' });
      } catch { /* ignore revert error */ }
    } finally {
      setDistilling((prev) => ({ ...prev, [item.id]: false }));
    }
  }, [addToast]);

  // ── Retry distill ──

  const handleRetry = useCallback(async (item: SourceItem) => {
    try {
      setDistilling((prev) => ({ ...prev, [item.id]: true }));
      setDistillError((prev) => {
        const next = { ...prev };
        delete next[item.id];
        return next;
      });

      await window.acmind.sourceItems.update(item.id, { status: 'distilling' });
      await window.acmind.distill.run([item.id], ['summarize']);

      addToast('重新整理完成', 'success');
    } catch (err) {
      const msg = err instanceof Error ? err.message : '重新整理失败';
      setDistillError((prev) => ({ ...prev, [item.id]: msg }));
      addToast(msg, 'error');
      try {
        await window.acmind.sourceItems.update(item.id, { status: 'inbox' });
      } catch { /* ignore */ }
    } finally {
      setDistilling((prev) => ({ ...prev, [item.id]: false }));
    }
  }, [addToast]);

  // ── Batch distill all pending items ──

  const handleDistillAll = useCallback(async () => {
    const inboxItems = items.filter((i) => i.status === 'inbox');
    if (inboxItems.length === 0) {
      addToast('没有待整理的内容', 'info');
      return;
    }

    const ids = inboxItems.map((i) => i.id);
    const newDistilling = Object.fromEntries(ids.map((id) => [id, true]));
    setDistilling((prev) => ({ ...prev, ...newDistilling }));

    // Update all statuses to distilling
    for (const id of ids) {
      try {
        await window.acmind.sourceItems.update(id, { status: 'distilling' });
      } catch { /* continue */ }
    }

    try {
      await window.acmind.distill.run(ids, ['summarize']);
      addToast(`已提交 ${ids.length} 条整理任务`, 'success');
    } catch (err) {
      const msg = err instanceof Error ? err.message : '批量整理失败';
      addToast(msg, 'error');
      // Revert failed items
      for (const id of ids) {
        try {
          await window.acmind.sourceItems.update(id, { status: 'inbox' });
        } catch { /* ignore */ }
      }
    } finally {
      const clearState = Object.fromEntries(ids.map((id) => [id, false]));
      setDistilling((prev) => ({ ...prev, ...clearState }));
    }
  }, [items, addToast]);

  // ── Confirm & export ──

  const handleConfirmExport = useCallback(async (item: SourceItem) => {
    try {
      const outputs = await window.acmind.distilledOutputs.list({ sourceItemId: item.id });
      const preferredOutput =
        outputs.find((output) => output.operation === 'summarize' || Boolean(output.contentMarkdown)) ??
        outputs[0] ??
        null;

      if (!preferredOutput) {
        throw new Error('未找到可入库的蒸馏结果');
      }

      await window.acmind.export.single(preferredOutput.id);
      addToast('已入库', 'success');
    } catch (err) {
      addToast(err instanceof Error ? err.message : '入库失败', 'error');
    }
  }, [addToast]);

  // ── Skip ──

  const handleSkip = useCallback(async (item: SourceItem) => {
    try {
      await window.acmind.sourceItems.delete(item.id);
      addToast('已跳过', 'success');
    } catch {
      addToast('操作失败', 'error');
    }
  }, [addToast]);

  // ── Helpers ──

  const formatTime = (ts: number) => {
    const diff = Math.floor(Date.now() / 1000 - ts);
    if (diff < 60) return '刚刚';
    if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`;
    return new Date(ts * 1000).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
  };

  const isItemDistilling = (item: SourceItem) => distilling[item.id] === true;
  const pendingCount = items.filter((i) => i.status === 'inbox').length;

  // ── Render ──

  return (
    <PageShell className="flex h-full flex-col overflow-hidden">
      <div className="px-6 pt-5">
        <PageHeader
          title="整理"
          description="AI 整理收集的内容"
          actions={
            activeTab === 'pending' && pendingCount > 0 ? (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => void handleDistillAll()}
                disabled={Object.values(distilling).some(Boolean)}
              >
                全部整理 ({pendingCount})
              </Button>
            ) : undefined
          }
        />
      </div>

      <div className="px-6 pb-2">
        <div className="flex gap-1">
          {TABS.map((tab) => (
            <Button
              key={tab.key}
              variant={activeTab === tab.key ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => { setActiveTab(tab.key); setSelectedItem(null); }}
            >
              {tab.label}
            </Button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center flex-1">
          <LoadingState title="正在加载" description="正在读取整理内容。" />
        </div>
      ) : error ? (
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请稍后重试。"
          action={{ label: '重新加载', onClick: () => void loadItems() }}
        />
      ) : items.length === 0 ? (
        <div className="flex items-center justify-center flex-1 px-6">
          <EmptyState
            icon={<AcMindIcon name="sb-ai-process" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title={emptyTitle(activeTab)}
            description={emptyDesc(activeTab)}
            action={activeTab === 'pending' ? {
              label: '去收集',
              onClick: () => window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'capture-inbox' } })),
            } : undefined}
          />
        </div>
      ) : (
        <div className="flex min-h-0 flex-1 px-6 pb-4 gap-4">
          {/* ── Left: Item list ── */}
          <div className="flex flex-col min-w-0 w-[35%] shrink-0 gap-1.5 overflow-auto">
            {items.map((item) => {
              const distillingItem = isItemDistilling(item);
              const hasError = Boolean(distillError[item.id]);
              return (
                <button
                  key={item.id}
                  type="button"
                  disabled={distillingItem}
                  className={`flex items-center gap-3 rounded-[10px] px-3 py-2.5 text-left transition-all ${
                    selectedItem?.id === item.id
                      ? 'bg-[color:var(--pm-brand-soft)] border border-[color:var(--pm-brand)]'
                      : hasError
                        ? 'bg-red-50/50 border border-red-200'
                        : 'bg-[color:var(--pm-bg-surface-soft,rgba(255,255,255,0.5))] border border-transparent hover:border-[color:var(--pm-border-light)]'
                  }`}
                  onClick={() => setSelectedItem(item)}
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="truncate text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                        {item.title || item.previewText || '未命名内容'}
                      </p>
                      {distillingItem && (
                        <span className="shrink-0 inline-block w-3 h-3 border-2 border-[color:var(--pm-brand)] border-t-transparent rounded-full animate-spin" />
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        {formatTime(item.createdAt)}
                      </p>
                      {hasError && (
                        <p className="text-[11px] text-red-500 truncate">
                          {distillError[item.id]}
                        </p>
                      )}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>

          {/* ── Right: Detail panel ── */}
          <div className="flex min-w-0 flex-1 flex-col rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-white/50 overflow-hidden">
            {selectedItem ? (
              <>
                <div className="shrink-0 px-4 py-3 border-b border-[color:var(--pm-border-subtle)]">
                  <div className="flex items-center justify-between">
                    <h3 className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
                      {selectedItem.title || '未命名内容'}
                    </h3>
                    <StatusBadge
                      tone={statusTone(selectedItem.status, isItemDistilling(selectedItem))}
                      label={statusLabel(selectedItem.status, isItemDistilling(selectedItem))}
                    />
                  </div>
                </div>
                <div className="flex-1 min-h-0 overflow-auto p-4">
                  {/* Distilling progress */}
                  {isItemDistilling(selectedItem) ? (
                    <div className="flex flex-col items-center justify-center gap-3 py-12">
                      <div className="w-8 h-8 border-2 border-[color:var(--pm-brand)] border-t-transparent rounded-full animate-spin" />
                      <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-secondary)' }}>
                        AI 正在整理中...
                      </p>
                      <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        整理完成后将自动刷新
                      </p>
                    </div>
                  ) : distilledOutput?.contentMarkdown ? (
                    <div className="flex flex-col gap-3">
                      {Boolean((selectedItem.metadata as Record<string, unknown>)?.used_fallback) && <FallbackBadge />}
                      {distilledOutput.suggestedTitle && (
                        <div>
                          <div className="text-[11px] font-semibold uppercase tracking-wider mb-1" style={{ color: 'var(--pm-text-tertiary)' }}>
                            AI 标题
                          </div>
                          <p className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
                            {distilledOutput.suggestedTitle}
                          </p>
                        </div>
                      )}
                      {distilledOutput.summary && (
                        <div>
                          <div className="text-[11px] font-semibold uppercase tracking-wider mb-1" style={{ color: 'var(--pm-text-tertiary)' }}>
                            摘要
                          </div>
                          <p className="text-[13px] leading-relaxed" style={{ color: 'var(--pm-text-secondary)' }}>
                            {distilledOutput.summary}
                          </p>
                        </div>
                      )}
                      <div>
                        <div className="text-[11px] font-semibold uppercase tracking-wider mb-1" style={{ color: 'var(--pm-text-tertiary)' }}>
                          Markdown 草稿
                        </div>
                        <pre
                          className="text-[12px] leading-relaxed whitespace-pre-wrap font-mono rounded-[8px] p-3"
                          style={{
                            color: 'var(--pm-text-secondary)',
                            background: 'var(--pm-bg-surface-soft, rgba(255,255,255,0.5))',
                            border: '0.5px solid var(--pm-border-subtle)',
                            maxHeight: 300,
                            overflow: 'auto',
                          }}
                        >
                          {distilledOutput.contentMarkdown}
                        </pre>
                      </div>
                      {distilledOutput.tags && distilledOutput.tags.length > 0 && (
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="text-[11px] font-semibold" style={{ color: 'var(--pm-text-tertiary)' }}>标签:</span>
                          {distilledOutput.tags.map((tag: string) => (
                            <span
                              key={tag}
                              className="inline-block rounded-full px-2 py-0.5 text-[11px]"
                              style={{
                                background: 'var(--pm-brand-soft, rgba(255,107,43,0.08))',
                                color: 'var(--pm-brand, #ff6b2b)',
                              }}
                            >
                              {tag}
                            </span>
                          ))}
                        </div>
                      )}
                      <div className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        置信度: {distilledOutput.confidence != null ? `${Math.round(distilledOutput.confidence * 100)}%` : '-'} ·
                        操作: {distilledOutput.operation || '-'}
                      </div>
                    </div>
                  ) : loadingOutput ? (
                    <LoadingState title="加载中" description="正在读取整理结果..." />
                  ) : (
                    <p className="text-[13px] leading-relaxed" style={{ color: 'var(--pm-text-secondary)' }}>
                      {selectedItem.previewText || '暂无内容'}
                    </p>
                  )}
                </div>
                {/* ── Action bar ── */}
                <div className="shrink-0 px-4 py-3 border-t border-[color:var(--pm-border-subtle)] flex items-center gap-2">
                  {activeTab === 'pending' && selectedItem.status === 'inbox' && (
                    <Button
                      variant="primary"
                      size="sm"
                      onClick={() => void handleDistill(selectedItem)}
                      disabled={isItemDistilling(selectedItem)}
                    >
                      开始整理
                    </Button>
                  )}
                  {activeTab === 'pending' && selectedItem.status === 'inbox' && distillError[selectedItem.id] && (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => void handleDistill(selectedItem)}
                      disabled={isItemDistilling(selectedItem)}
                    >
                      重试
                    </Button>
                  )}
                  {activeTab === 'confirming' && (
                    <>
                      <Button variant="secondary" size="sm" onClick={() => window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'review' } }))}>
                        去审阅
                      </Button>
                      <Button variant="primary" size="sm" onClick={() => void handleConfirmExport(selectedItem)}>
                        确认并入库
                      </Button>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => void handleRetry(selectedItem)}
                        disabled={isItemDistilling(selectedItem)}
                      >
                        重新整理
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => void handleSkip(selectedItem)}>
                        跳过
                      </Button>
                    </>
                  )}
                </div>
              </>
            ) : (
              <div className="flex items-center justify-center flex-1">
                <EmptyState
                  icon={<AcMindIcon name="sb-ai-process" size={24} style={{ color: 'var(--pm-text-tertiary)' }} />}
                  title="选择一条内容"
                  description="在左侧列表中选择查看详情"
                />
              </div>
            )}
          </div>
        </div>
      )}
    </PageShell>
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function emptyTitle(tab: OrganizeTab): string {
  if (tab === 'pending') return '还没有待整理内容';
  if (tab === 'confirming') return '还没有整理结果';
  return '还没有已完成内容';
}

function emptyDesc(tab: OrganizeTab): string {
  if (tab === 'pending') return '先收集一条内容';
  if (tab === 'confirming') return '先整理一条内容';
  return '确认后会出现在这里';
}

function statusTone(status: string, isDistilling?: boolean): 'success' | 'warning' | 'danger' | 'neutral' | 'processing' {
  if (isDistilling) return 'processing';
  if (status === 'distilled' || status === 'exported') return 'success';
  if (status === 'distilling') return 'processing';
  if (status === 'inbox') return 'warning';
  return 'neutral';
}

function statusLabel(status: string, isDistilling?: boolean): string {
  if (isDistilling) return '整理中...';
  if (status === 'inbox') return '待整理';
  if (status === 'distilling') return '整理中';
  if (status === 'distilled') return '待确认';
  if (status === 'exported') return '已入库';
  if (status === 'archived') return '已归档';
  return status;
}
